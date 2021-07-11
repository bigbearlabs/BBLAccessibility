#import "BBLAccessibilityPublisher.h"
#import <Silica/Silica.h>
#import <AppKit/AppKit.h>
#import "logging.h"
#import <BBLAccessibility/BBLAccessibility-Swift.h>

// FIXME some performance problems with:
// console.app (too frequent notifs for title change)
// xcode.app (frequent ax event vomits)

@interface BBLAccessibilityPublisher ()
  @property(readwrite,copy) NSDictionary<NSNumber*,AccessibilityInfo*>* accessibilityInfosByPid;
@end



@implementation BBLAccessibilityPublisher
{
  NSMutableDictionary<NSNumber*, SIApplication*>* observedAppsByPid;

  // control load of concurrent queue.
  dispatch_semaphore_t semaphore;
  dispatch_queue_t serialQueue;
  
  id notificationCenterObserverToken;
  
  NSDictionary* _handlersByNotificationTypes;
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    _accessibilityInfosByPid = [@{} mutableCopy];
    
    observedAppsByPid = [@{} mutableCopy];

    serialQueue = dispatch_queue_create(
      "BBLAccessiblityPublisher-serial",
      dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, 0));

    NSUInteger processorCount = NSProcessInfo.processInfo.processorCount;
    semaphore = dispatch_semaphore_create(processorCount);
  }
  return self;
}

- (void)dealloc
{
}


#pragma mark -

-(NSArray<NSRunningApplication*>*) applicationsToObserve {
  return [[NSWorkspace sharedWorkspace] runningApplications];

//  // DEBUG selected text not reported on some safari windows, only on Sierra (10.12).
//  return [NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.apple.Safari"];
}

-(BOOL)shouldObserveApplication: (NSRunningApplication*)application {
  return true;
}

#pragma mark -

-(void) registerForNotification {
  __weak BBLAccessibilityPublisher* blockSelf = self;
  notificationCenterObserverToken = [NSNotificationCenter.defaultCenter addObserverForName:AX_EVENT_NOTIFICATION object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
    
//    __log("!!notif: %@", note);
    
    SIAXNotificationData* axData = note.userInfo[AX_EVENT_NOTIFICATION_DATA];
    
    [blockSelf invokeHandlerForAxNotificationData:axData];
  }];
}

-(void) deregisterForNotification {
  if (notificationCenterObserverToken) {
    [NSNotificationCenter.defaultCenter removeObserver:notificationCenterObserverToken];
  }
}

-(void) invokeHandlerForAxNotificationData:(SIAXNotificationData*) axData {
  CFStringRef notification = axData.axNotification;
  SIAccessibilityElement* siElement = axData.siElement;
  
  NSDictionary* handlers = [self handlersByNotificationTypes];
  SIAXNotificationHandler handler = handlers[(__bridge NSString*)notification];
  
//  SIApplication* siApp = nil;
//  @synchronized (watchedAppsByPid) {
//    siApp = watchedAppsByPid[@(siElement.processIdentifier)];
//  }
//  assert(siApp != nil);
  // DISABLED we saw some notifs from what look like child processes. (e.g. ...webkit.webcontent), in which case we can't get the si app back from the registry.
  
//  [self execAsyncSynchronisingOn:siApp block:^{
    handler(siElement);
//  }];
}

// RENAME -> observeAxEvents
-(void) watchWindows {
  [self registerForNotification];

  __weak BBLAccessibilityPublisher* blockSelf = self;

  // observe ax of newly launched apps.
  [self observeLaunch: ^(NSRunningApplication* _Nonnull app) {
    if ([blockSelf shouldObserveApplication:app]) {
      
      [blockSelf observeAxEventsForApplication:app];
      
      // ensure ax info doesn't lag after new windows.
      SIWindow* window = [SIApplication applicationWithRunningApplication:app].focusedWindow;
      
      SIAXNotificationHandler handler = [blockSelf handlersByNotificationTypes][(__bridge NSString*)kAXFocusedWindowChangedNotification];
      handler(window);

      __log("%@ launched, ax observations added", app);

    } else {
      __log("👺 %@ not in ax observation scope", app);
    }

  }];
    
  // clean up on terminated apps.
  [self observeTerminate: ^(NSRunningApplication* _Nonnull app) {

    if ([blockSelf shouldObserveApplication:app]) {

      [blockSelf unobserveAxEventsForApplication:app];
      
      NSMutableDictionary* axInfos = blockSelf.accessibilityInfosByPid.mutableCopy;
      [axInfos removeObjectForKey:@(app.processIdentifier)];
      
      __log("%@ terminated, ax observations removed", app);
    }
  }];

  // observe all current apps.
  // NOTE it still takes a while for the notifs to actually invoke the handlers. at least with concurrent set up we don't hog the main thread as badly as before.
  for (NSRunningApplication* app in self.applicationsToObserve) {
    if (![self shouldObserveApplication: app]) {
      continue;
    }
    
    [self observeAxEventsForApplication:app];
  }
  
  __log("%@ is watching the windows", self);
}

-(void) unwatchWindows {

  @synchronized(observedAppsByPid) {
    for (SIApplication* app in observedAppsByPid.allValues) {
      [self unobserveAxEventsForApplication:app.runningApplication];
    }
  }
  
  [self unobserveLaunch];
  
  [self unobserveTerminate];
  
  [self deregisterForNotification];
  
  __log("%@ is no longer watching the windows", self);
}

// FIXME 'application' is a slightly dodgy parameter. consider replacing with the siElement that generated the ax event.
-(NSDictionary*) handlersByNotificationTypes {
  if (!_handlersByNotificationTypes) {
    __weak BBLAccessibilityPublisher* blockSelf = self;
    _handlersByNotificationTypes = @{
      (NSString*)kAXApplicationActivatedNotification: ^(SIAccessibilityElement *accessibilityElement) {
//        id application = (SIApplication*) accessibilityElement;
        [blockSelf updateAccessibilityInfoForElement:accessibilityElement axNotification:kAXApplicationActivatedNotification forceUpdate:YES];
//        [blockSelf onApplicationActivated:application];
      },
      
      (NSString*)kAXApplicationDeactivatedNotification: ^(SIAccessibilityElement *accessibilityElement) {
//        id application = (SIApplication*) accessibilityElement;
        [blockSelf updateAccessibilityInfoForElement:accessibilityElement axNotification:kAXApplicationDeactivatedNotification forceUpdate:YES];
//        [blockSelf onApplicationDeactivated:accessibilityElement];
      },
      
      
      (NSString*)kAXFocusedWindowChangedNotification: ^(SIAccessibilityElement *accessibilityElement) {
//        SIWindow* window = [SIWindow windowForElement:accessibilityElement];
//        if (window == nil) {
//          SIApplication* app = [SIApplication applicationForProcessIdentifier:accessibilityElement.processIdentifier];
//          window = app.focusedWindow;
//
//        }
        [blockSelf updateAccessibilityInfoForElement:accessibilityElement axNotification:kAXFocusedWindowChangedNotification forceUpdate:YES];
//        [blockSelf onFocusedWindowChanged:window];
      },
      
      (NSString*)kAXMainWindowChangedNotification: ^(SIAccessibilityElement *accessibilityElement) {
//        SIWindow* window =
//          [SIWindow windowForElement:accessibilityElement];
//        if (window == nil) {
//          SIApplication* app = [SIApplication applicationForProcessIdentifier: accessibilityElement.processIdentifier];
//          window = app.focusedWindow;
//        }
        
        [blockSelf updateAccessibilityInfoForElement:accessibilityElement axNotification:kAXMainWindowChangedNotification forceUpdate:YES];
        //      [blockSelf onMainWindowChanged:accessibilityElement];
      },
      

      (NSString*)kAXWindowCreatedNotification: ^(SIAccessibilityElement *accessibilityElement) {
//        SIWindow* window = [[SIWindow alloc] initWithAXElement:accessibilityElement.axElementRef];
        [blockSelf updateAccessibilityInfoForElement:accessibilityElement axNotification:kAXWindowCreatedNotification];
//        [blockSelf onWindowCreated:(SIWindow*)window];
      },
      
      (NSString*)kAXTitleChangedNotification: ^(SIAccessibilityElement *accessibilityElement) {
        [blockSelf updateAccessibilityInfoForElement:accessibilityElement axNotification:kAXTitleChangedNotification];
//        [blockSelf onTitleChanged:(SIWindow*)accessibilityElement];
      },
      
      (NSString*)kAXWindowMiniaturizedNotification: ^(SIAccessibilityElement *accessibilityElement) {
        [blockSelf updateAccessibilityInfoForElement:accessibilityElement axNotification:kAXWindowMiniaturizedNotification];
//        [blockSelf onWindowMinimised:(SIWindow*)accessibilityElement];
      },
      
      (NSString*)kAXWindowDeminiaturizedNotification: ^(SIAccessibilityElement *accessibilityElement) {
        [blockSelf updateAccessibilityInfoForElement:accessibilityElement axNotification:kAXWindowDeminiaturizedNotification];
        
//        [blockSelf onWindowUnminimised:(SIWindow*)accessibilityElement];
      },
      
      (NSString*)kAXWindowMovedNotification: ^(SIAccessibilityElement *accessibilityElement) {
        [blockSelf updateAccessibilityInfoForElement:accessibilityElement axNotification:kAXWindowMovedNotification];
//        [blockSelf onWindowMoved:(SIWindow*)accessibilityElement];
      },
      
      (NSString*)kAXWindowResizedNotification: ^(SIAccessibilityElement *accessibilityElement) {
        [blockSelf updateAccessibilityInfoForElement:accessibilityElement axNotification:kAXWindowResizedNotification];
//        [blockSelf onWindowResized:(SIWindow*)accessibilityElement];
      },
      
      (NSString*)kAXFocusedUIElementChangedNotification: ^(SIAccessibilityElement *accessibilityElement) {
        [blockSelf updateAccessibilityInfoForElement:accessibilityElement axNotification:kAXFocusedUIElementChangedNotification];
//        [blockSelf onFocusedElementChanged:accessibilityElement];
      },
      
      (NSString*)kAXUIElementDestroyedNotification: ^(SIAccessibilityElement *accessibilityElement) {
//        SIWindow* window = [SIWindow windowForElement:accessibilityElement];
//
//        id element = window != nil ? window : accessibilityElement;
        [blockSelf updateAccessibilityInfoForElement:accessibilityElement axNotification:kAXUIElementDestroyedNotification];
        
        
//        [blockSelf onElementDestroyed:accessibilityElement];
      },

      // observe appropriately for text selection handling.
      // NOTE some apps, e.g. iterm, seem to fail to notify observers properly.
      // FIXME investigate why not working with Notes.app
      // INVESTIGATE sierra + safari: notifies only for some windows.
      // during investigation we saw that inspecting with Prefab UI Browser 'wakes up' the windows such that they send out notifications only after inspection.
      (NSString*)kAXSelectedTextChangedNotification: ^(SIAccessibilityElement *accessibilityElement) {
        NSString* selectedText = accessibilityElement.selectedText;
        if (selectedText == nil) {
          selectedText = @"";
        }
        
        // guard: xcode spams us with notifs even when no text has changed, so only notify when value has changed.
        id previousSelectedText = blockSelf.accessibilityInfosByPid[@(accessibilityElement.processIdentifier)].selectedText;
        if (previousSelectedText == nil) {
          previousSelectedText = @"";
        }

        if ( selectedText == previousSelectedText
            ||
            [selectedText isEqualToString:previousSelectedText]) {
          // no need to update.
        }
        else {
          
          [blockSelf updateAccessibilityInfoForElement:accessibilityElement axNotification:kAXSelectedTextChangedNotification];
          
//          [blockSelf onTextSelectionChanged:accessibilityElement];
        }
      },
      
      @"AXFocusedTabChanged": ^(SIAccessibilityElement *accessibilityElement) {
        [blockSelf updateAccessibilityInfoForElement:accessibilityElement axNotification:(CFStringRef)@"AXFocusedTabChanged"];
      },
    };
  }
  
  return _handlersByNotificationTypes;
}

-(void) observeAxEventsForApplication:(NSRunningApplication*)application {
  SIApplication* siApp = [SIApplication applicationWithRunningApplication:application];
  
  // * observe ax notifications for the app asynchronously.
  // TODO timeout and alert user.
  __weak BBLAccessibilityPublisher* blockSelf = self;
  [blockSelf execAsyncSynchronisingOnObject:siApp block:^{
    NSMutableArray* observationFailures = @[].mutableCopy;
    
    for (NSString* notification in [blockSelf handlersByNotificationTypes]) {
      
      AXError observeResult = [siApp observeAxNotification:(__bridge CFStringRef)notification withElement:siApp];
      if (observeResult != kAXErrorSuccess) {
        [observationFailures addObject:@(observeResult)];
      }
    }
    
    if (observationFailures.count > 0) {
      __log("👺 %@: ax observation failed with codes: %@", siApp, [[[NSSet setWithArray:observationFailures] allObjects] componentsJoinedByString:@", "]);
    }

  
  
  // in order for the notifications to work, we must retain the SIApplication.
  @synchronized(observedAppsByPid) {
    observedAppsByPid[@(application.processIdentifier)] = siApp;
  }
  
  __log("%@ registered observation for app %@", self, application);
}

-(void) unobserveAxEventsForApplication:(NSRunningApplication*)application {

  @synchronized(observedAppsByPid) {
    
    NSNumber* pid = @(application.processIdentifier);
    SIApplication* siApp = observedAppsByPid[pid];
    if (siApp == nil) {
        __log("%@ %@ was not being observed.", application.bundleIdentifier, pid);
      return;
    }
    
    __weak BBLAccessibilityPublisher* blockSelf = self;
    [self execAsyncSynchronisingOnObject:siApp block:^{
      for (NSString* notification in [blockSelf handlersByNotificationTypes]) {
        [siApp unobserveNotification:(__bridge CFStringRef)notification withElement:siApp];
      }
    }];
  
    [observedAppsByPid removeObjectForKey:pid];
    
    __log("%@ deregistered observation for app %@", self, application);
  }
}


#pragma mark -

-(AccessibilityInfo*) accessibilityInfoForElement:(SIAccessibilityElement*)siElement axNotification:(CFStringRef)axNotification {

  // ensure we can reference the app for this element.
  id appElement = [self appElementForProcessIdentifier:siElement.processIdentifier];
  if (appElement == nil) {
    return nil;
  }

  // * case: element is an SIApplication.
  if ([siElement.role isEqual:(NSString*)kAXApplicationRole]) {
    return [[AccessibilityInfo alloc] initWithAppElement:appElement axNotification:axNotification];
  }

  SIAccessibilityElement* focusedElement = siElement.focusedElement;
  
  // * case: no focused element.
  if (focusedElement == nil) {
    return [[AccessibilityInfo alloc] initWithAppElement:appElement focusedElement:siElement axNotification:axNotification];
  }

  // * default case.
  return [[AccessibilityInfo alloc] initWithAppElement:appElement focusedElement:focusedElement axNotification:axNotification];
}

-(SIApplication*) appElementForProcessIdentifier:(pid_t)processIdentifier {
  @synchronized(observedAppsByPid) {
    return observedAppsByPid[@(processIdentifier)];
  }
}

-(void) updateAccessibilityInfoForApplication:(NSRunningApplication*)runningApplication
                               axNotification:(CFStringRef)axNotification
{
  SIApplication* app = [SIApplication applicationWithRunningApplication:runningApplication];
  SIWindow* window = app.focusedWindow;
  if (window) {
    [self updateAccessibilityInfoForElement:window axNotification:axNotification];
  }
}

-(void) updateAccessibilityInfoForElement:(SIAccessibilityElement*)siElement
                           axNotification:(CFStringRef)axNotification
{
  [self updateAccessibilityInfoForElement:siElement axNotification:axNotification forceUpdate:NO];
}


-(void) updateAccessibilityInfoForElement:(SIAccessibilityElement*)siElement
                           axNotification:(CFStringRef)axNotification
                              forceUpdate:(BOOL)forceUpdate
{

  // * updated the published property.
  
  //   dispatch to a queue, to avoid spins if ax query of the target app takes a long time.
  pid_t pid = siElement.processIdentifier;
  __weak BBLAccessibilityPublisher* blockSelf = self;
  [self execAsyncSynchronisingOnPid:pid block:^{
    @autoreleasepool {
      id axInfo = [blockSelf accessibilityInfoForElement:siElement axNotification:axNotification];

      // synchronise state access on main queue.
      // this restricts usage of this class on the main thread!
      dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary* accessibilityInfosByPid = blockSelf.accessibilityInfosByPid;

        if (forceUpdate
            || ![accessibilityInfosByPid[@(pid)] isEqual:axInfo]) {

//          __log("update ax info dict with: %@", siElement);

          NSMutableDictionary* updatedAccessibilityInfosByPid = accessibilityInfosByPid.mutableCopy;
          updatedAccessibilityInfosByPid[@(pid)] = axInfo;

          blockSelf.accessibilityInfosByPid = updatedAccessibilityInfosByPid;
        }
      });
    }
  }];
}


#pragma mark - handlers

//-(void) onApplicationActivated:(SIAccessibilityElement*)element {
//  _frontmostProcessIdentifier = element.processIdentifier;
//  __log("app activated: %@", element);
//}
//
//-(void) onApplicationDeactivated:(SIAccessibilityElement*)element {
//  _frontmostProcessIdentifier = [SIApplication focusedApplication].processIdentifier; // ?? too slow?
//  __log("app deactivated: %@", element);
//}
//
//-(void) onFocusedWindowChanged:(SIWindow*)window {
//  _frontmostProcessIdentifier = window.processIdentifier;
//  __log("focused window: %@", window);
//}
//
//-(void) onFocusedElementChanged:(SIAccessibilityElement*)element {
//  __log("focused element: %@", element);
//}
//
//-(void) onWindowCreated:(SIWindow*)window {
//  __log("new window: %@", window);  // NOTE title may not be available yet.
//}
//
//-(void) onTitleChanged:(SIWindow*)window {
//  __log("title changed: %@", window);
//}
//
//-(void) onWindowMinimised:(SIWindow*)window {
//  __log("window minimised: %@",window);  // NOTE title may not be available yet.
//}
//
//-(void) onWindowUnminimised:(SIWindow*)window {
//  __log("window unminimised: %@",window);  // NOTE title may not be available yet.
//}
//
//-(void) onWindowMoved:(SIWindow*)window {
//  __log("window moved: %@",window);  // NOTE title may not be available yet.
//}
//
//-(void) onWindowResized:(SIWindow*)window {
//  __log("window resized: %@",window);  // NOTE title may not be available yet.
//}
//
//-(void) onTextSelectionChanged:(SIAccessibilityElement*)element {
//  __log("text selection changed on element: %@. selection: %@", element, element.selectedText);
//}
//
//-(void) onElementDestroyed:(SIAccessibilityElement*)element {
//  __log("element destroyed: %@", element);
//}


-(AccessibilityInfo*) focusedWindowAccessibilityInfo {
  SIApplication* app = [SIApplication focusedApplication];
  SIWindow* window = [app focusedWindow];
  return [[AccessibilityInfo alloc] initWithAppElement:app focusedElement:window axNotification:kAXFocusedWindowChangedNotification];
}

#pragma mark - util

-(SIWindow*) keyWindowForApplication:(SIApplication*) application {
  for (SIWindow* window in application.windows) {
    if (window.isVisible
      && !window.isSheet) {
      return window;
    }
  }

  @throw [NSException exceptionWithName:@"invalid-state" reason:@"no suitable window to return as key" userInfo:nil];
}

-(void) execAsyncSynchronisingOnPid:(pid_t)pid block:(void(^)(void))block {
  SIApplication* application = nil;
  @synchronized(observedAppsByPid) {
    application = observedAppsByPid[@(pid)];
  }
  if (application == nil) {
//    @throw [[NSException alloc] initWithName:@"app-not-observed" reason:nil userInfo:@{@"pid": pid}];
    
    // retrieve running app, sync on it.
    application = [SIApplication applicationForProcessIdentifier:pid];
//    if (![self shouldObserveApplication:application]) {
//
//    }
  }

  // NOTE if app for pid not observed, we will not be synchronising!
  
  [self execAsyncSynchronisingOnObject:application block:block];
}


/// asynchronously execute on global concurrent queue, synchronised on object to avoid deadlocks.
-(void) execAsyncSynchronisingOnObject:(id)object block:(void(^)(void))block {
  
  // use a semaphore to avoid excessive thread spawning if the code path leading to the global
  // concurrent queue gets hot.
  // do it asyncly to avoid blocking calling thread.
  __weak dispatch_semaphore_t _semaphore = semaphore;
  dispatch_async(serialQueue, ^{
    
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
      @synchronized(object) {
        block();
      }
      dispatch_semaphore_signal(_semaphore);
    });

    dispatch_semaphore_wait(_semaphore, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
  });
}

@end
