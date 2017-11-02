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
  NSMutableDictionary* watchedAppsByPid;
  pid_t pidForAxUpdate;
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    _accessibilityInfosByPid = [@{} mutableCopy];
    watchedAppsByPid = [@{} mutableCopy];
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
  
  // on didlaunchapplication notif, observe.
  [[[NSWorkspace sharedWorkspace] notificationCenter] addObserverForName:NSWorkspaceDidLaunchApplicationNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
    
    NSRunningApplication* app = (NSRunningApplication*) note.userInfo[NSWorkspaceApplicationKey];
    if ([[[blockSelf applicationsToObserve] valueForKey:@"processIdentifier"] containsObject:@(app.processIdentifier)]) {
      
      [blockSelf watchNotificationsForApp:app];
      
      // ensure ax info doesn't lag after new windows.
      SIWindow* window = [SIApplication applicationWithRunningApplication:app].focusedWindow;
      [blockSelf updateAccessibilityInfoForElement:window];
      [blockSelf onFocusedWindowChanged:window];
      
    } else {
      __log("%@ is not in list of apps to observe", app);
    }
  }];
  
  // on terminateapplication notif, unobserve.
  [[[NSWorkspace sharedWorkspace] notificationCenter] addObserverForName:NSWorkspaceDidTerminateApplicationNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
    
    NSRunningApplication* app = (NSRunningApplication*) note.userInfo[NSWorkspaceApplicationKey];
    [blockSelf unwatchApp:app];
  }];
  
  // observe all current apps.
  for (NSRunningApplication* app in [self applicationsToObserve]) {
    [self watchNotificationsForApp:app];
  }
  
  __log("%@ is watching the windows", self);
  
  // NOTE it still takes a while for the notifs to actually invoke the handlers. at least with concurrent set up we don't hog the main thread as badly as before.
}

-(void) unwatchWindows {
  // naive impl that loops through the running apps

  for (NSRunningApplication* application in [self applicationsToObserve]) {
    [self unwatchApp:application];
    // FIXME this may contend with the unobservation on app terminate.
  }
}


-(NSDictionary*) handlersByNotificationTypesForApplication:(SIApplication*)application {
  __weak BBLAccessibilityPublisher* blockSelf = self;
  return @{
    (NSString*)kAXApplicationActivatedNotification: ^(SIAccessibilityElement *accessibilityElement) {
      [blockSelf updateAccessibilityInfoForElement:application forceUpdate:YES];
      [blockSelf onApplicationActivated:accessibilityElement];
    },
    
    // TODO respond to kAXApplicationDeactivatedNotification since impl needs to hide overlay for improved responsiveness.
    
    (NSString*)kAXFocusedWindowChangedNotification: ^(SIAccessibilityElement *accessibilityElement) {
      SIWindow* window = (SIWindow*) accessibilityElement;
      [blockSelf updateAccessibilityInfoForElement:window];
      [blockSelf onFocusedWindowChanged:window];
    },
    
    (NSString*)kAXWindowCreatedNotification: ^(SIAccessibilityElement *accessibilityElement) {
      [blockSelf updateAccessibilityInfoForElement:accessibilityElement];
      [blockSelf onWindowCreated:(SIWindow*)accessibilityElement];
    },
    
    (NSString*)kAXTitleChangedNotification: ^(SIAccessibilityElement *accessibilityElement) {
      [blockSelf updateAccessibilityInfoForElement:accessibilityElement];
      [blockSelf onTitleChanged:(SIWindow*)accessibilityElement];
    },
    
    (NSString*)kAXWindowMiniaturizedNotification: ^(SIAccessibilityElement *accessibilityElement) {
      [blockSelf updateAccessibilityInfoForElement:accessibilityElement];
      [blockSelf onWindowMinimised:(SIWindow*)accessibilityElement];
    },
    
    (NSString*)kAXWindowDeminiaturizedNotification: ^(SIAccessibilityElement *accessibilityElement) {
      [blockSelf updateAccessibilityInfoForElement:accessibilityElement];
      
      [blockSelf onWindowUnminimised:(SIWindow*)accessibilityElement];
    },
    
    (NSString*)kAXWindowMovedNotification: ^(SIAccessibilityElement *accessibilityElement) {
      [blockSelf updateAccessibilityInfoForElement:accessibilityElement];
      [blockSelf onWindowMoved:(SIWindow*)accessibilityElement];
    },
    
    (NSString*)kAXWindowResizedNotification: ^(SIAccessibilityElement *accessibilityElement) {
      [blockSelf updateAccessibilityInfoForElement:accessibilityElement];
      [blockSelf onWindowResized:(SIWindow*)accessibilityElement];
    },
    
    (NSString*)kAXFocusedUIElementChangedNotification: ^(SIAccessibilityElement *accessibilityElement) {
      [blockSelf updateAccessibilityInfoForElement:accessibilityElement];
      [blockSelf onFocusedElementChanged:accessibilityElement];
    },
    
    (NSString*)kAXUIElementDestroyedNotification: ^(SIAccessibilityElement *accessibilityElement) {
      [blockSelf updateAccessibilityInfoForElement:accessibilityElement];
      [blockSelf onElementDestroyed:accessibilityElement];
    },

    // observe appropriately for text selection handling.
    // NOTE some apps, e.g. iterm, seem to fail to notify observers properly.
    // FIXME investigate why not working with Notes.app
    // INVESTIGATE sierra + safari: notifies only for some windows.
    // during investigation we saw that inspecting with Prefab UI Browser 'wakes up' the windows such that they send out notifications only after inspection.
    (NSString*)kAXSelectedTextChangedNotification: ^(SIAccessibilityElement *accessibilityElement) {
      NSString* selectedText = accessibilityElement.selectedText;
      
      // guard: xcode spams us with notifs even when no text has changed, so only notify when value has changed.
      id previousSelectedText = blockSelf.accessibilityInfosByPid[@(accessibilityElement.processIdentifier)].selectedText;
      if (previousSelectedText == nil || [previousSelectedText length] == 0) {
        previousSelectedText = @"";
      }
      if ( selectedText == previousSelectedText
          ||
          [selectedText isEqualToString:previousSelectedText]) {
        // no need to update.
      }
      else {
        
        [blockSelf updateAccessibilityInfoForElement:accessibilityElement];
        
        [blockSelf onTextSelectionChanged:accessibilityElement];
      }
    },

  };

}

-(void) watchNotificationsForApp:(NSRunningApplication*)app {
  SIApplication* application = [SIApplication applicationWithRunningApplication:app];
  
  // * observe ax notifications for the app asynchronously.
  // TODO timeout and alert user.
  
  [self execAsync:^{

    id handlersByNotificationTypes = [self handlersByNotificationTypesForApplication:application];
    for (NSString* notification in handlersByNotificationTypes) {
      SIAXNotificationHandler handler = (SIAXNotificationHandler) handlersByNotificationTypes[notification];
      [application observeNotification:(__bridge CFStringRef)(notification) withElement:application handler:handler];
    }
    
    // in order for the notifications to work, we must retain the SIApplication.
    @synchronized(watchedAppsByPid) {
      watchedAppsByPid[@(application.processIdentifier)] = application;
    }
    
    __log("%@ registered observation for app %@", self, application);
  }];
}

-(void) unwatchApp:(NSRunningApplication*)app {
  // synchronise to avoid contending with #execAsync
  @synchronized(self) {
    @synchronized(watchedAppsByPid) {
      id pid = @(app.processIdentifier);
      SIApplication* application = watchedAppsByPid[pid];
      if (application == nil) {
        __log("no application for pid %@", pid);
        return;
      }
      
      for (NSString* notification in [self handlersByNotificationTypesForApplication:application]) {
        [application unobserveNotification:(__bridge CFStringRef)notification withElement:application];
      }
    
      [watchedAppsByPid removeObjectForKey:@(application.processIdentifier)];
      
      __log("%@ deregistered observation for app %@", self, application);
    }
  }
}


#pragma mark -

-(AccessibilityInfo*) accessibilityInfoForElement:(SIAccessibilityElement*)siElement {
  
  // * case: element is an SIApplication.
  if ([[siElement class] isEqual:[SIApplication class]]) {
    return [[AccessibilityInfo alloc] initWithAppElement:(SIApplication*) siElement];
  }

  id appElement = [self appElementForProcessIdentifier:siElement.processIdentifier];
  if (appElement == nil) {
    return nil;
  }

  SIAccessibilityElement* focusedElement = siElement.focusedElement;
  
  // * case: no focused element.
  if (focusedElement == nil) {
    return [[AccessibilityInfo alloc] initWithAppElement:appElement focusedElement:siElement];
  }

  // * default case.
  return [[AccessibilityInfo alloc] initWithAppElement:appElement focusedElement:focusedElement];
}

-(SIApplication*) appElementForProcessIdentifier:(pid_t)processIdentifier {
  @synchronized(watchedAppsByPid) {
    return watchedAppsByPid[@(processIdentifier)];
  }
}

-(void) updateAccessibilityInfoForApplication:(NSRunningApplication*)runningApplication {
  __weak BBLAccessibilityPublisher* blockSelf = self;
  [self execAsync:^{
    SIApplication* app = [SIApplication applicationWithRunningApplication:runningApplication];
    SIWindow* window = app.focusedWindow;
    if (window) {
      [blockSelf updateAccessibilityInfoForElement:window];
    }
  }];
}

-(void) updateAccessibilityInfoForElement:(SIAccessibilityElement*)siElement {
  [self updateAccessibilityInfoForElement:siElement forceUpdate:NO];
}


-(void) updateAccessibilityInfoForElement:(SIAccessibilityElement*)siElement forceUpdate:(BOOL)forceUpdate {
  
  if (pidForAxUpdate == siElement.processIdentifier) {
    // update for is in progress by another thread, so skip.
    return;
  }

  // do this off the main thread, to avoid spins with some ax queries.
  __weak BBLAccessibilityPublisher* blockSelf = self;
  [self execAsync:^{
    pidForAxUpdate = siElement.processIdentifier;
    
    // * case: element's window has an AXUnknown subrole.
    // e.g. the invisible window that gets created when the mouse pointer turns into a 'pointy hand' when overing over clickable WebKit elements.
    if (siElement.class == [SIWindow class]
        && [siElement.subrole isEqualToString:@"AXUnknown"]
        ) {
      __log("%@ is a window with subrole AXUnknown -- will not create ax info.", siElement);
      pidForAxUpdate = 0;
      return;
    }

    AccessibilityInfo* newData = [blockSelf accessibilityInfoForElement:siElement];

    pid_t pid = siElement.processIdentifier;
    AccessibilityInfo* oldData = blockSelf.accessibilityInfosByPid[@(pid)];
    
    if (forceUpdate
        || ![newData isEqual:oldData]) {
      NSMutableDictionary* dictToUpdate = blockSelf.accessibilityInfosByPid.mutableCopy;
      
      dictToUpdate[@(pid)] = newData;
      
      dispatch_async(dispatch_get_main_queue(), ^{
        blockSelf.accessibilityInfosByPid = dictToUpdate.copy;
        pidForAxUpdate = 0;
      });
    }
    else {
      pidForAxUpdate = 0;
    }
    
  }];
}


#pragma mark - handlers

-(void) onApplicationActivated:(SIAccessibilityElement*)element {
  _frontmostProcessIdentifier = element.processIdentifier;
  __log("app activated: %@", element);
}

-(void) onApplicationDeactivated:(SIAccessibilityElement*)element {
  _frontmostProcessIdentifier = 0;
    // ?? how can we actually get this updated?
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


#pragma mark - util

-(SIWindow*) keyWindowForApplication:(SIApplication*) application {
  for (SIWindow* window in application.visibleWindows) {
    if (![window isSheet]) 
      return window;
  }

  @throw [NSException exceptionWithName:@"invalid-state" reason:@"no suitable window to return as key" userInfo:nil];
}

/// asynchronously execute on global concurrent queue, synchronised to self to avoid deadlocks.
-(void) execAsync:(void(^)(void))block {
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
    @synchronized(self) {
      block();
    }
  });
}

@end
