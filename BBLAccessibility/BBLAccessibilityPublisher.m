#import "BBLAccessibilityPublisher.h"
#import <Silica/Silica.h>
#import <AppKit/AppKit.h>
#import "logging.h"


// FIXME some performance problems with:
// console.app (too frequent notifs for title change)
// xcode.app (frequent ax event vomits)

@interface BBLAccessibilityPublisher ()
  @property(readwrite,copy) NSDictionary<NSNumber*,AccessibilityInfo*>* accessibilityInfosByPid;
@end



@implementation BBLAccessibilityPublisher
{
  NSMutableDictionary<NSNumber*, SIApplication*>* watchedAppsByPid;  // RENAME -> observedAppsByPid
  
  id launchObservation;
  id terminateObservation;

  // control load of concurrent queue.
  dispatch_semaphore_t semaphore;
  dispatch_queue_t serialQueue;
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    _accessibilityInfosByPid = [@{} mutableCopy];
    watchedAppsByPid = [@{} mutableCopy];
    
    serialQueue = dispatch_queue_create("BBLAccessiblityPublisher-serial", DISPATCH_QUEUE_SERIAL);
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


#pragma mark -

-(void) watchWindows {
  __weak BBLAccessibilityPublisher* blockSelf = self;
  
  id applicationsToObserve = [blockSelf applicationsToObserve];
  
  [self execAsyncSynchronisingOn:self block:^{
    
    // on didlaunchapplication notif, observe.
    self->launchObservation = [[[NSWorkspace sharedWorkspace] notificationCenter] addObserverForName:NSWorkspaceDidLaunchApplicationNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
      
      NSRunningApplication* app = (NSRunningApplication*) note.userInfo[NSWorkspaceApplicationKey];
      if ([[applicationsToObserve valueForKey:@"bundleIdentifier"] containsObject:app.bundleIdentifier]) {

        [blockSelf observeAxEventsForApplication:app];
        
        // ensure ax info doesn't lag after new windows.
        SIWindow* window = [SIApplication applicationWithRunningApplication:app].focusedWindow;
        [blockSelf updateAccessibilityInfoForElement:window axNotification:kAXFocusedWindowChangedNotification];
        [blockSelf onFocusedWindowChanged:window];
        
      } else {
        __log("%@ is not in list of apps to observe", app);
      }
    }];
    
    // on terminateapplication notif, unobserve.
    self->terminateObservation = [[[NSWorkspace sharedWorkspace] notificationCenter] addObserverForName:NSWorkspaceDidTerminateApplicationNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
      
      NSRunningApplication* app = (NSRunningApplication*) note.userInfo[NSWorkspaceApplicationKey];
      [blockSelf unobserveAxEventsForApplication:app];
    }];

  }];

  // observe all current apps.
  // NOTE it still takes a while for the notifs to actually invoke the handlers. at least with concurrent set up we don't hog the main thread as badly as before.
  for (NSRunningApplication* app in applicationsToObserve) {
    [self execAsyncSynchronisingOn:app block:^{
      [blockSelf observeAxEventsForApplication:app];
    }];
  }
  
  __log("%@ is watching the windows", self);
  
    
}

// RENAME -> observeAxEvents
-(void) unwatchWindows {
  // naive impl that loops through the running apps
  
  for (NSRunningApplication* app in [self applicationsToObserve]) {
    [self execAsyncSynchronisingOn:app block:^{
      [self unobserveAxEventsForApplication:app];
      // FIXME this may contend with the unobservation on app terminate.
    }];
  }
  
  [self execAsyncSynchronisingOn:self block:^{
  
    if (self->launchObservation) {
      [[[NSWorkspace sharedWorkspace] notificationCenter]
        removeObserver:self->launchObservation];
    }
    
    if (self->terminateObservation) {
      [[[NSWorkspace sharedWorkspace] notificationCenter]
        removeObserver:self->terminateObservation];
    }
  }];

}


-(NSDictionary*) handlersByNotificationTypesForApplication:(SIApplication*)application {
  __weak BBLAccessibilityPublisher* blockSelf = self;
  return @{
    (NSString*)kAXApplicationActivatedNotification: ^(SIAccessibilityElement *accessibilityElement) {
      [blockSelf updateAccessibilityInfoForElement:application axNotification:kAXApplicationActivatedNotification forceUpdate:YES];
      [blockSelf onApplicationActivated:application];
    },
    
    (NSString*)kAXApplicationDeactivatedNotification: ^(SIAccessibilityElement *accessibilityElement) {
      [blockSelf updateAccessibilityInfoForElement:application axNotification:kAXApplicationDeactivatedNotification forceUpdate:YES];
      [blockSelf onApplicationDeactivated:accessibilityElement];
    },
    
    
    (NSString*)kAXFocusedWindowChangedNotification: ^(SIAccessibilityElement *accessibilityElement) {
      SIWindow* window = [SIWindow windowForElement:accessibilityElement];
      if (window == nil) {
        SIApplication* app = [SIApplication applicationForProcessIdentifier:accessibilityElement.processIdentifier];
        window = app.focusedWindow;

      }
      [blockSelf updateAccessibilityInfoForElement:window axNotification:kAXFocusedWindowChangedNotification forceUpdate:YES];
      [blockSelf onFocusedWindowChanged:window];
    },
    
    (NSString*)kAXMainWindowChangedNotification: ^(SIAccessibilityElement *accessibilityElement) {
      SIWindow* window =
        [SIWindow windowForElement:accessibilityElement];
      if (window == nil) {
        SIApplication* app = [SIApplication applicationForProcessIdentifier: accessibilityElement.processIdentifier];
        window = app.focusedWindow;
      }
      
      [blockSelf updateAccessibilityInfoForElement:window axNotification:kAXMainWindowChangedNotification forceUpdate:YES];
      //      [blockSelf onMainWindowChanged:accessibilityElement];
    },
    

    (NSString*)kAXWindowCreatedNotification: ^(SIAccessibilityElement *accessibilityElement) {
      SIWindow* window = [[SIWindow alloc] initWithAXElement:accessibilityElement.axElementRef];
      [blockSelf updateAccessibilityInfoForElement:window axNotification:kAXWindowCreatedNotification];
      [blockSelf onWindowCreated:(SIWindow*)window];
    },
    
    (NSString*)kAXTitleChangedNotification: ^(SIAccessibilityElement *accessibilityElement) {
      [blockSelf updateAccessibilityInfoForElement:accessibilityElement axNotification:kAXTitleChangedNotification];
      [blockSelf onTitleChanged:(SIWindow*)accessibilityElement];
    },
    
    (NSString*)kAXWindowMiniaturizedNotification: ^(SIAccessibilityElement *accessibilityElement) {
      [blockSelf updateAccessibilityInfoForElement:accessibilityElement axNotification:kAXWindowMiniaturizedNotification];
      [blockSelf onWindowMinimised:(SIWindow*)accessibilityElement];
    },
    
    (NSString*)kAXWindowDeminiaturizedNotification: ^(SIAccessibilityElement *accessibilityElement) {
      [blockSelf updateAccessibilityInfoForElement:accessibilityElement axNotification:kAXWindowDeminiaturizedNotification];
      
      [blockSelf onWindowUnminimised:(SIWindow*)accessibilityElement];
    },
    
    (NSString*)kAXWindowMovedNotification: ^(SIAccessibilityElement *accessibilityElement) {
      [blockSelf updateAccessibilityInfoForElement:accessibilityElement axNotification:kAXWindowMovedNotification];
      [blockSelf onWindowMoved:(SIWindow*)accessibilityElement];
    },
    
    (NSString*)kAXWindowResizedNotification: ^(SIAccessibilityElement *accessibilityElement) {
      [blockSelf updateAccessibilityInfoForElement:accessibilityElement axNotification:kAXWindowResizedNotification];
      [blockSelf onWindowResized:(SIWindow*)accessibilityElement];
    },
    
    (NSString*)kAXFocusedUIElementChangedNotification: ^(SIAccessibilityElement *accessibilityElement) {
      [blockSelf updateAccessibilityInfoForElement:accessibilityElement axNotification:kAXFocusedUIElementChangedNotification];
      [blockSelf onFocusedElementChanged:accessibilityElement];
    },
    
    (NSString*)kAXUIElementDestroyedNotification: ^(SIAccessibilityElement *accessibilityElement) {
      SIWindow* window = [SIWindow windowForElement:accessibilityElement];

      id element = window != nil ? window : accessibilityElement;
      [blockSelf updateAccessibilityInfoForElement:element axNotification:kAXUIElementDestroyedNotification];
      
      
      [blockSelf onElementDestroyed:accessibilityElement];
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
        
        [blockSelf onTextSelectionChanged:accessibilityElement];
      }
    },
  };

}

-(void) observeAxEventsForApplication:(NSRunningApplication*)application {
  SIApplication* siApp = [SIApplication applicationWithRunningApplication:application];
  
  // * observe ax notifications for the app asynchronously.
  // TODO timeout and alert user.

  id handlersByNotificationTypes = [self handlersByNotificationTypesForApplication:siApp];
  for (NSString* notification in handlersByNotificationTypes) {
    SIAXNotificationHandler handler = (SIAXNotificationHandler) handlersByNotificationTypes[notification];
    [siApp observeNotification:(__bridge CFStringRef)notification withElement:siApp handler:handler];
  }
  
  // in order for the notifications to work, we must retain the SIApplication.
  @synchronized(watchedAppsByPid) {
    watchedAppsByPid[@(application.processIdentifier)] = siApp;
  }
  
  __log("%@ registered observation for app %@", self, application);
}

-(void) unobserveAxEventsForApplication:(NSRunningApplication*)application {

  @synchronized(watchedAppsByPid) {
    
    NSNumber* pid = @(application.processIdentifier);
    SIApplication* siApp = watchedAppsByPid[pid];
    if (siApp == nil) {
        __log("%@ %@ was not being observed.", application.bundleIdentifier, pid);
      return;
    }
    
    for (NSString* notification in [self handlersByNotificationTypesForApplication:siApp]) {
      [siApp unobserveNotification:(__bridge CFStringRef)notification withElement:siApp];
    }
  
    [watchedAppsByPid removeObjectForKey:pid];
    
    __log("%@ deregistered observation for app %@", self, application);
  }
}


#pragma mark -

-(AccessibilityInfo*) accessibilityInfoForElement:(SIAccessibilityElement*)siElement axNotification:(CFStringRef)axNotification {
  
  // * case: element is an SIApplication.
  if ([[siElement class] isEqual:[SIApplication class]]) {
    return [[AccessibilityInfo alloc] initWithAppElement:(SIApplication*) siElement axNotification:axNotification];
  }

  id appElement = [self appElementForProcessIdentifier:siElement.processIdentifier];
  if (appElement == nil) {
    return nil;
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
  @synchronized(watchedAppsByPid) {
    return watchedAppsByPid[@(processIdentifier)];
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

  SIApplication* application = nil;
  @synchronized(watchedAppsByPid) {
    application = watchedAppsByPid[@(siElement.processIdentifier)];
  }
  if (application == nil) {
    // impossible!!?
    return;
  }

  // * case: element's window has an AXUnknown subrole.
  // e.g. the invisible window that gets created when the mouse pointer turns into a 'pointy hand' when overing over clickable WebKit elements.
  if (
      (siElement.class == [SIWindow class] || [siElement.role isEqual:(NSString*)kAXWindowRole])
      && [siElement.subrole isEqual:(NSString*)kAXUnknownSubrole]
      ) {
    __log("%@ is a window with subrole AXUnknown -- will not create ax info.", siElement);
    return;
  }
  
  // * updated the published property.
  
  // dispatch to a queue, to avoid spins with some ax queries.
  __weak BBLAccessibilityPublisher* blockSelf = self;
  [self execAsyncSynchronisingOn:application block:^{
    
    NSDictionary* dictToUpdate = [blockSelf newAccessibilityInfosUsingElement:siElement axNotification:axNotification];
    
    if (forceUpdate
        || ![dictToUpdate isEqual:blockSelf.accessibilityInfosByPid]) {
      
      dispatch_async(dispatch_get_main_queue(), ^{
        __log("siElement: %@", siElement);
        blockSelf.accessibilityInfosByPid = dictToUpdate.copy;
      });
    }
    else {
    }
    
  }];
}

-(NSDictionary*) newAccessibilityInfosUsingElement:(SIAccessibilityElement*)siElement axNotification:(CFStringRef)axNotification {
  id pid = @(siElement.processIdentifier);
  
  AccessibilityInfo* newData = [self accessibilityInfoForElement:siElement axNotification:axNotification];
  
  NSMutableDictionary* dictToUpdate = self.accessibilityInfosByPid.mutableCopy;
  dictToUpdate[pid] = newData;
  return dictToUpdate;
}

#pragma mark - handlers

-(void) onApplicationActivated:(SIAccessibilityElement*)element {
  _frontmostProcessIdentifier = element.processIdentifier;
  __log("app activated: %@", element);
}

-(void) onApplicationDeactivated:(SIAccessibilityElement*)element {
  _frontmostProcessIdentifier = [SIApplication focusedApplication].processIdentifier; // ?? too slow?
  __log("app deactivated: %@", element);
}

-(void) onFocusedWindowChanged:(SIWindow*)window {
  _frontmostProcessIdentifier = window.processIdentifier;
  __log("focused window: %@", window);
}

-(void) onFocusedElementChanged:(SIAccessibilityElement*)element {
  __log("focused element: %@", element);
}

-(void) onWindowCreated:(SIWindow*)window {
  __log("new window: %@", window);  // NOTE title may not be available yet.
}

-(void) onTitleChanged:(SIWindow*)window {
  __log("title changed: %@", window);
}

-(void) onWindowMinimised:(SIWindow*)window {
  __log("window minimised: %@",window);  // NOTE title may not be available yet.
}

-(void) onWindowUnminimised:(SIWindow*)window {
  __log("window unminimised: %@",window);  // NOTE title may not be available yet.
}

-(void) onWindowMoved:(SIWindow*)window {
  __log("window moved: %@",window);  // NOTE title may not be available yet.
}

-(void) onWindowResized:(SIWindow*)window {
  __log("window resized: %@",window);  // NOTE title may not be available yet.
}

-(void) onTextSelectionChanged:(SIAccessibilityElement*)element {
  __log("text selection changed on element: %@. selection: %@", element, element.selectedText);
}

-(void) onElementDestroyed:(SIAccessibilityElement*)element {
  __log("element destroyed: %@", element);
}


-(AccessibilityInfo*) focusedWindowAccessibilityInfo {
  id app = [SIApplication focusedApplication];
  id window = [app focusedWindow];
  return [[AccessibilityInfo alloc] initWithAppElement:app focusedElement:window axNotification:kAXFocusedWindowChangedNotification];
}

#pragma mark - util

-(SIWindow*) keyWindowForApplication:(SIApplication*) application {
  for (SIWindow* window in application.visibleWindows) {
    if (![window isSheet]) 
      return window;
  }

  @throw [NSException exceptionWithName:@"invalid-state" reason:@"no suitable window to return as key" userInfo:nil];
}

/// asynchronously execute on global concurrent queue, synchronised onn object to avoid deadlocks.
-(void) execAsyncSynchronisingOn:(id)object block:(void(^)(void))block {
  __weak dispatch_semaphore_t _semaphore = semaphore;
  dispatch_async(serialQueue, ^{
    dispatch_semaphore_wait(_semaphore, dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC));
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
      @synchronized(object) {
        block();
      }
      dispatch_semaphore_signal(_semaphore);
    });
 });
}

@end
