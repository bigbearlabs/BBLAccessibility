//
//  BBLAccessibilityWindowWatcher.m
//  NMTest001
//
//  Created by ilo on 15/04/2016.
//
//

#import "BBLAccessibilityWindowWatcher.h"


@implementation BBLAccessibilityWindowWatcher
{
  NSMutableArray* watchedApps;
}


-(void) watchWindows {
  // on didlaunchapplication notif, observe..
  [[[NSWorkspace sharedWorkspace] notificationCenter] addObserverForName:NSWorkspaceDidLaunchApplicationNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
    
    NSRunningApplication* app = (NSRunningApplication*) note.userInfo[NSWorkspaceApplicationKey];
    SIApplication* application = [SIApplication applicationWithRunningApplication:app];
    [self watchNotificationsForApp:application];
  }];
  
  // on terminateapplication notif, unobserve.
  [[[NSWorkspace sharedWorkspace] notificationCenter] addObserverForName:NSWorkspaceDidTerminateApplicationNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
    NSRunningApplication* app = (NSRunningApplication*) note.userInfo[NSWorkspaceApplicationKey];
    SIApplication* application = [SIApplication applicationWithRunningApplication:app];
    [self unwatchApp:application];
  }];
  
  // for all current apps, observe.
  for (SIApplication* application in [SIApplication runningApplications]) {
    [self watchNotificationsForApp:application];
  }
  
}

-(void) watchNotificationsForApp:(SIApplication*)application {
  [application observeNotification:kAXFocusedWindowChangedNotification
                       withElement:application
                           handler:^(SIAccessibilityElement *accessibilityElement) {
                             [self onFocusedWindowChanged:(SIWindow*)accessibilityElement];
                           }];
  
  [application observeNotification:kAXWindowCreatedNotification
                       withElement:application
                           handler:^(SIAccessibilityElement *accessibilityElement) {
                             [self onWindowCreated:(SIWindow*)accessibilityElement];
                           }];
  
  [application observeNotification:kAXApplicationActivatedNotification
                       withElement:application
                           handler:^(SIAccessibilityElement *accessibilityElement) {
                             [self onApplicationActivated:accessibilityElement];
                           }];
  
  if (!watchedApps) {
    watchedApps = [@[] mutableCopy];
  }
  [watchedApps addObject:application];
}

-(void) unwatchApp:(SIApplication*)application {
  [application unobserveNotification:kAXFocusedWindowChangedNotification withElement:application];
  [application unobserveNotification:kAXWindowCreatedNotification withElement:application];
  [application unobserveNotification:kAXApplicationActivatedNotification withElement:application];
}


-(void) onFocusedWindowChanged:(SIWindow*)window {
  NSLog(@"%@ in focus.", window);
}

-(void) onWindowCreated:(SIWindow*)window {
  NSLog(@"new window: %@",window.title);  // NOTE title may not be available yet.
}

-(void) onApplicationActivated:(SIAccessibilityElement*)element {
  
}

@end



