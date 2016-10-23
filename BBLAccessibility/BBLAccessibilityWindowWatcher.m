//
//  BBLAccessibilityWindowWatcher.m
//
//  Created by Andy Park on 15/04/2016.
//
//

#import "BBLAccessibilityWindowWatcher.h"
#import <NMAccessibility/NMAccessibility.h>


@implementation BBLAccessibilityWindowWatcher
{
  NSMutableArray* watchedApps;
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    _accessibilityInfosByPid = [@{} mutableCopy];
    watchedApps = [@[] mutableCopy];
  }
  return self;
}

-(NSArray*) applicationsToObserve {
  return [[NSWorkspace sharedWorkspace] runningApplications];

//  // DEBUG selected text not reported on some safari windows, only on Sierra (10.12).
//  return [NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.apple.Safari"];
}


-(void) watchWindows {
  // on didlaunchapplication notif, observe.
  [[[NSWorkspace sharedWorkspace] notificationCenter] addObserverForName:NSWorkspaceDidLaunchApplicationNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
    
    NSRunningApplication* app = (NSRunningApplication*) note.userInfo[NSWorkspaceApplicationKey];
    if ([[[self applicationsToObserve] valueForKey:@"processIdentifier"] containsObject:@(app.processIdentifier)]) {
      SIApplication* application = [SIApplication applicationWithRunningApplication:app];
      [self watchNotificationsForApp:application];
    } else {
      NSLog(@"%@ is not in list of apps to observe", app);
    }
  }];
  
  // on terminateapplication notif, unobserve.
  [[[NSWorkspace sharedWorkspace] notificationCenter] addObserverForName:NSWorkspaceDidTerminateApplicationNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
    
    NSRunningApplication* app = (NSRunningApplication*) note.userInfo[NSWorkspaceApplicationKey];
    SIApplication* application = [watchedApps firstObjectCommonWithArray:@[[SIApplication applicationWithRunningApplication:app]]];
    [self unwatchApp:application];
  }];
  
  // observe all current apps.
  for (NSRunningApplication* app in [self applicationsToObserve]) {
    if ([[[self applicationsToObserve] valueForKey:@"processIdentifier"] containsObject:@(app.processIdentifier)]) {
      id application = [SIApplication applicationWithRunningApplication:app];
      [self watchNotificationsForApp:application];
    } else {
      NSLog(@"%@ is not in list of apps to observe", app);
    }
  }
  
  NSLog(@"%@ is watching the windows", self);
  
  // NOTE it still takes a while for the notifs to actually invoke the handlers. at least with concurrent set up we don't hog the main thread as badly as before.
}

-(void) unwatchWindows {
  // naive impl that loops through the running apps

  for (id application in [self applicationsToObserve]) {
    id app = [SIApplication applicationWithRunningApplication:application];
    [self unwatchApp:app];
    // FIXME this contends with the unobservation on app terminate.
  }
}


-(void) watchNotificationsForApp:(SIApplication*)application {
  [self concurrently:^{
    dispatch_async(dispatch_get_main_queue(), ^{
      [application observeNotification:kAXApplicationActivatedNotification
                           withElement:application
                               handler:^(SIAccessibilityElement *accessibilityElement) {
                                 [self updateAccessibilityInfoFor:accessibilityElement];
                                 
                                 [self onApplicationActivated:accessibilityElement];
                               }];
      
      // TODO respond to kAXApplicationDeactivatedNotification since impl needs to hide overlay for improved responsiveness.
      
      [application observeNotification:kAXFocusedWindowChangedNotification
                           withElement:application
                               handler:^(SIAccessibilityElement *accessibilityElement) {
                                 [self updateAccessibilityInfoFor:accessibilityElement];
                                 
                                 [self onFocusedWindowChanged:(SIWindow*)accessibilityElement];
                               }];
      
      [application observeNotification:kAXWindowCreatedNotification
                           withElement:application
                               handler:^(SIAccessibilityElement *accessibilityElement) {
                                 [self updateAccessibilityInfoFor:accessibilityElement];

                                 [self onWindowCreated:(SIWindow*)accessibilityElement];
                               }];
      
      [application observeNotification:kAXTitleChangedNotification
                           withElement:application
                               handler:^(SIAccessibilityElement *accessibilityElement) {
                                 [self updateAccessibilityInfoFor:accessibilityElement];

                                 [self onTitleChanged:accessibilityElement];
                               }];

      [application observeNotification:kAXWindowMiniaturizedNotification
                           withElement:application
                               handler:^(SIAccessibilityElement *accessibilityElement) {
                                 [self updateAccessibilityInfoFor:accessibilityElement];

                                 [self onWindowMinimised:(SIWindow*)accessibilityElement];
                               }];
      
      [application observeNotification:kAXWindowDeminiaturizedNotification
                           withElement:application
                               handler:^(SIAccessibilityElement *accessibilityElement) {
                                 [self updateAccessibilityInfoFor:accessibilityElement];

                                 [self onWindowUnminimised:(SIWindow*)accessibilityElement];
                               }];
      
      [application observeNotification:kAXWindowMovedNotification
                           withElement:application
                               handler:^(SIAccessibilityElement *accessibilityElement) {
                                 [self updateAccessibilityInfoFor:accessibilityElement];

                                 [self onWindowMoved:(SIWindow*)accessibilityElement];
                               }];
      
      [application observeNotification:kAXWindowResizedNotification
                           withElement:application
                               handler:^(SIAccessibilityElement *accessibilityElement) {
                                 [self updateAccessibilityInfoFor:accessibilityElement];

                                 [self onWindowResized:(SIWindow*)accessibilityElement];
                               }];
      

      // ABORT we ended up with far too many notifs when using this.
      //  [application observeNotification:kAXFocusedUIElementChangedNotification
      //                       withElement:application
      //                           handler:^(SIAccessibilityElement *accessibilityElement) {
      //                             [self onFocusedElementChanged:accessibilityElement];
      //                           }];
      

      // observe appropriately for text selection handling.
      // NOTE some apps, e.g. iterm, seem to fail to notify observers properly.
      // INVESTIGATE sierra + safari: notifies only for some windows.
      // during investigation we saw that inspecting with Prefab UI Browser 'wakes up' the windows such that they send out notifications only after inspection.
      [application observeNotification:kAXSelectedTextChangedNotification
                           withElement:application
                               handler:^(SIAccessibilityElement *accessibilityElement) {
                                 // guard: xcode spams us with notifs even when no text has changed, so only notify when value has changed.
                                 NSDictionary* newAccessibilityInfo = [self accessibilityInfoFor:accessibilityElement.axElementRef];
                                 if ((newAccessibilityInfo[@"selectedText"]) != self.accessibilityInfosByPid[@(accessibilityElement.processIdentifier)][@"selectedText"]) {
                                   [self updateAccessibilityInfoFor:accessibilityElement];

                                   [self onTextSelectionChanged:accessibilityElement];
                                 }
                               }];
      
      [watchedApps addObject:application];
      
      NSLog(@"setup observers for %@", application);
    });
  }];
}
-(void) updateAccessibilityInfoFor:(SIAccessibilityElement*)siElement {
  pid_t pid = siElement.processIdentifier;
  ((NSMutableDictionary*) self.accessibilityInfosByPid)[@(pid)] = [self accessibilityInfoFor:siElement.axElementRef];
}


-(NSDictionary*) accessibilityInfoFor:(AXUIElementRef)element {
  NMUIElement* nmElement = [[NMUIElement alloc] initWithElement:element];
  return nmElement.accessibilityInfo;
}

-(void) unwatchApp:(SIApplication*)application {
  [application unobserveNotification:kAXSelectedTextChangedNotification withElement:application];
  [application unobserveNotification:kAXWindowResizedNotification withElement:application];
  [application unobserveNotification:kAXWindowMovedNotification withElement:application];
  [application unobserveNotification:kAXWindowDeminiaturizedNotification withElement:application];
  [application unobserveNotification:kAXWindowMiniaturizedNotification withElement:application];
  [application unobserveNotification:kAXTitleChangedNotification withElement:application];
  [application unobserveNotification:kAXWindowCreatedNotification withElement:application];
  [application unobserveNotification:kAXFocusedWindowChangedNotification withElement:application];
  [application unobserveNotification:kAXApplicationActivatedNotification withElement:application];
  
  [watchedApps removeObject:application];
}


-(void) concurrently:(void(^)(void))block {
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    block();
  });
}

#pragma mark - handlers

-(void) onApplicationActivated:(SIAccessibilityElement*)element {
  // work around silica treatment of this event parameter as a SIWindow, when it should be an SIApplication
  id app = [element valueForKey:@"app"];
  NSLog(@"app activated: %@", app);
}

-(void) onFocusedWindowChanged:(SIWindow*)window {
  NSLog(@"focus: %@", window);
}

-(void) onWindowCreated:(SIWindow*)window {
  NSLog(@"new window: %@",window.title);  // NOTE title may not be available yet.
}

-(void) onTitleChanged:(SIAccessibilityElement*)element {
  NSLog(@"title changed: %@", element);
}

-(void) onWindowMinimised:(SIWindow*)window {
  NSLog(@"window minimised: %@",window.title);  // NOTE title may not be available yet.
}

-(void) onWindowUnminimised:(SIWindow*)window {
  NSLog(@"window unminimised: %@",window.title);  // NOTE title may not be available yet.
}

-(void) onWindowMoved:(SIWindow*)window {
  NSLog(@"window moved: %@",window.title);  // NOTE title may not be available yet.
}

-(void) onWindowResized:(SIWindow*)window {
  NSLog(@"window resized: %@",window.title);  // NOTE title may not be available yet.
}

-(void) onTextSelectionChanged:(SIAccessibilityElement*)element {
  NSLog(@"element: %@, ax info: %@", element, self.accessibilityInfosByPid[@(element.processIdentifier)]);
}



#pragma mark - util

-(SIWindow*) keyWindowForApplication:(SIApplication*) application {
  for (SIWindow* window in application.visibleWindows) {
    if (![window isSheet]) 
      return window;
  }

  @throw [NSException exceptionWithName:@"invalid-state" reason:@"no suitable window to return as key" userInfo:nil];
}

@end



