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
  // control load of concurrent queue.
  dispatch_semaphore_t semaphore;
  dispatch_queue_t serialQueue;
  
  id notificationCenterObserverToken;
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    _accessibilityInfosByPid = [@{} mutableCopy];
    
    _observedAppsByPid = [@{} mutableCopy];

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
  NSMutableArray* apps = @[].mutableCopy;
  for (NSRunningApplication* app in [[NSWorkspace sharedWorkspace] runningApplications]) {
    if ([self shouldObserveApplication:app]) {
      [apps addObject:app];
    }
  }
  return apps;
}

-(BOOL)shouldObserveApplication: (NSRunningApplication*)application {
  return true;
}

#pragma mark -

-(void) observeInternalNotification {
  __weak BBLAccessibilityPublisher* blockSelf = self;
  notificationCenterObserverToken = [NSNotificationCenter.defaultCenter addObserverForName:AX_EVENT_NOTIFICATION object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
    
//    __log("!!notif: %@", note);
    
    SIAXNotificationData* axData = note.userInfo[AX_EVENT_NOTIFICATION_DATA];
    
    [blockSelf invokeHandlerForAxNotificationData:axData];
  }];
}

-(void) unobserveInternalNotification {
  if (notificationCenterObserverToken) {
    [NSNotificationCenter.defaultCenter removeObserver:notificationCenterObserverToken];
  }
}

-(void) invokeHandlerForAxNotificationData:(SIAXNotificationData*) axData {
  CFStringRef notification = axData.axNotification;
  SIAccessibilityElement* siElement = axData.siElement;
    
//  [self execAsyncSynchronisingOn:siApp block:^{
  [self updateAccessibilityInfoForElement:siElement axNotification:notification];
//  }];
}

-(void) observeAxEvents {
  [self observeInternalNotification];

  __weak BBLAccessibilityPublisher* blockSelf = self;

  // observe ax of newly launched apps.
  [self observeLaunch: ^(NSRunningApplication* _Nonnull app) {
    if ([blockSelf shouldObserveApplication:app]) {
      
      NSArray* axResults = [blockSelf observeAxEventsForApplication:app];
      
      [blockSelf handleAxObservationResults:axResults forRunningApplication:app];
      
//      // ensure ax info doesn't lag after new windows.
//      SIWindow* window = [SIApplication applicationWithRunningApplication:app].focusedWindow;
      
//      SIAXNotificationHandler handler = [blockSelf handlersByNotificationTypes][(__bridge NSString*)kAXFocusedWindowChangedNotification];
//      handler(window);
      
      //  check if app is active, manually issue ax notif.
      if ([SIApplication.focusedApplication.runningApplication isEqualTo:app]) {
        [blockSelf updateAccessibilityInfoForApplication:app axNotification:kAXApplicationActivatedNotification];
      }

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
    NSArray* axResults = [self observeAxEventsForApplication:app];
    [self handleAxObservationResults: axResults forRunningApplication:app];
  }
  
  __log("%@ is watching the windows", self);
}

-(void) unobserveAxEvents {

  @synchronized(_observedAppsByPid) {
    for (SIApplication* app in _observedAppsByPid.allValues) {
      [self unobserveAxEventsForApplication:app.runningApplication];
    }
  }
  
  [self unobserveTerminate];
  
  [self unobserveLaunch];
  
  [self unobserveInternalNotification];
  
  __log("%@ is no longer watching the windows", self);
}


// TODO return errors for further processing by callers.
-(NSArray<NSNumber*>*) observeAxEventsForApplication:(NSRunningApplication*)application {
  SIApplication* siApp = [SIApplication applicationWithRunningApplication:application];
  
  __log("%@ registering observation for app %@", self, application);

  NSMutableArray* observationFailures = @[].mutableCopy;
  
  for (NSString* notification in [self axNotificationsToObserve]) {
    
    AXError observeResult = [siApp observeAxNotification:(__bridge CFStringRef)notification withElement:siApp];
    if (observeResult != kAXErrorSuccess) {
      [observationFailures addObject:@(observeResult)];
    }
  }
  
  if (observationFailures.count > 0) {
    __log("👺 %@: ax observation failed with codes: %@", siApp, [[[NSSet setWithArray:observationFailures] allObjects] componentsJoinedByString:@", "]);
    return observationFailures;
  }
  
  // in order for the notifications to work, we must retain the SIApplication.
  @synchronized(_observedAppsByPid) {
    _observedAppsByPid[@(application.processIdentifier)] = siApp;
  }
  
  return @[];
}

-(void) unobserveAxEventsForApplication:(NSRunningApplication*)application {

  @synchronized(_observedAppsByPid) {
    
    NSNumber* pid = @(application.processIdentifier);
    SIApplication* siApp = _observedAppsByPid[pid];
    if (siApp == nil) {
        __log("%@ %@ was not being observed.", application.bundleIdentifier, pid);
      return;
    }
    
    for (NSString* notification in [self axNotificationsToObserve]) {
      [siApp unobserveNotification:(__bridge CFStringRef)notification withElement:siApp];
    }
  
    [_observedAppsByPid removeObjectForKey:pid];
    
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
  @synchronized(_observedAppsByPid) {
    return _observedAppsByPid[@(processIdentifier)];
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
  @synchronized(_observedAppsByPid) {
    application = _observedAppsByPid[@(pid)];
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


-(void) handleAxObservationResults:(NSArray<NSNumber*>*) axResults forRunningApplication:(NSRunningApplication*) application {
  // override.
}


@end



// MARK: -

@interface StateBasedBBLAccessibilityPublisher: BBLAccessibilityPublisher
@end


@implementation StateBasedBBLAccessibilityPublisher

-(void) updateAccessibilityInfoForElement:(SIAccessibilityElement*)siElement
                           axNotification:(CFStringRef)axNotification
                              forceUpdate:(BOOL)forceUpdate
{

  // * case: text selection handling special cases.
  if (CFEqual(axNotification, kAXSelectedTextChangedNotification)) {
    
    // NOTE some apps, e.g. iterm, seem to fail to notify observers properly.
    // FIXME investigate why not working with Notes.app
    // INVESTIGATE sierra + safari: notifies only for some windows.
    // during investigation we saw that inspecting with Prefab UI Browser 'wakes up' the windows such that they send out notifications only after inspection.
    NSString* selectedText = siElement.selectedText;
    if (selectedText == nil) {
      selectedText = @"";
    }

    // guard: xcode spams us with notifs even when no text has changed, so only notify when value has changed.
    id previousSelectedText = self.accessibilityInfosByPid[@(siElement.processIdentifier)].selectedText;  // FIXME synchronise access.
    if (previousSelectedText == nil) {
      previousSelectedText = @"";
    }

    if ( selectedText == previousSelectedText
        ||
        [selectedText isEqual:previousSelectedText]) {
      // no need to update.
      return;
    }
  }

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

@end
