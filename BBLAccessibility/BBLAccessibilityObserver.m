#import "BBLAccessibilityObserver.h"
#import <Silica/Silica.h>
#import <AppKit/AppKit.h>
//#import <os/log.h>

//#define   __log(...) os_log_info(OS_LOG_DEFAULT, __VA_ARGS__);
// DISABLED until we can do base builds on 10.12...
#define   __log(...) NSLog(@__VA_ARGS__);



@interface BBLAccessibilityObserver ()
  @property(readwrite,copy) NSDictionary<NSNumber*,AccessibilityInfo*>* accessibilityInfosByPid;
@end



@implementation BBLAccessibilityObserver
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

- (void)dealloc
{
  [self unwatchWindows];
}

-(NSArray<NSRunningApplication*>*) applicationsToObserve {
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
      __log("%@ is not in list of apps to observe", app);
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
      __log("%@ is not in list of apps to observe", app);
    }
  }
  
  // react to running application change.
  [[NSWorkspace sharedWorkspace] addObserver:self forKeyPath:@"frontmostApplication" options:NSKeyValueObservingOptionNew context:nil];
  
  __log("%@ is watching the windows", self);
  
  // NOTE it still takes a while for the notifs to actually invoke the handlers. at least with concurrent set up we don't hog the main thread as badly as before.
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
  if ([keyPath isEqualToString:@"frontmostApplication"]) {
    
    NSRunningApplication* frontmostApplication = change[NSKeyValueChangeNewKey];
    
    id bundleIdsInScope = [self.applicationsToObserve valueForKey:@"processIdentifier"];
    if ([bundleIdsInScope containsObject:frontmostApplication.bundleIdentifier]) {
      // this app is in in watch scope.
    
      id accessibilityInfo = [[AccessibilityInfo alloc] initWithAppElement:[SIApplication applicationWithRunningApplication:frontmostApplication]];
      id data = self.accessibilityInfosByPid.mutableCopy;
      data[@(frontmostApplication.processIdentifier)] = accessibilityInfo;
      self.accessibilityInfosByPid = data;
    }
  }
  else {
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
  }
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
      
      __log("%@ observing app %@", self, application);

      [application observeNotification:kAXApplicationActivatedNotification
                           withElement:application
                               handler:^(SIAccessibilityElement *accessibilityElement) {
                                 [self updateAccessibilityInfoForElement:accessibilityElement forceUpdate:YES];
                                 
                                 [self onApplicationActivated:accessibilityElement];
                               }];
      
      // TODO respond to kAXApplicationDeactivatedNotification since impl needs to hide overlay for improved responsiveness.
      
      [application observeNotification:kAXFocusedWindowChangedNotification
                           withElement:application
                               handler:^(SIAccessibilityElement *accessibilityElement) {
                                 [self updateAccessibilityInfoForElement:accessibilityElement];
                                 
                                 [self onFocusedWindowChanged:(SIWindow*)accessibilityElement];
                               }];
      
      [application observeNotification:kAXWindowCreatedNotification
                           withElement:application
                               handler:^(SIAccessibilityElement *accessibilityElement) {
                                 [self updateAccessibilityInfoForElement:accessibilityElement];

                                 [self onWindowCreated:(SIWindow*)accessibilityElement];
                               }];
      
      [application observeNotification:kAXTitleChangedNotification
                           withElement:application
                               handler:^(SIAccessibilityElement *accessibilityElement) {
                                 [self updateAccessibilityInfoForElement:accessibilityElement];

                                 [self onTitleChanged:(SIWindow*)accessibilityElement];
                               }];

      [application observeNotification:kAXWindowMiniaturizedNotification
                           withElement:application
                               handler:^(SIAccessibilityElement *accessibilityElement) {
                                 [self updateAccessibilityInfoForElement:accessibilityElement];

                                 [self onWindowMinimised:(SIWindow*)accessibilityElement];
                               }];
      
      [application observeNotification:kAXWindowDeminiaturizedNotification
                           withElement:application
                               handler:^(SIAccessibilityElement *accessibilityElement) {
                                 [self updateAccessibilityInfoForElement:accessibilityElement];

                                 [self onWindowUnminimised:(SIWindow*)accessibilityElement];
                               }];
      
      [application observeNotification:kAXWindowMovedNotification
                           withElement:application
                               handler:^(SIAccessibilityElement *accessibilityElement) {
                                 [self updateAccessibilityInfoForElement:accessibilityElement];

                                 [self onWindowMoved:(SIWindow*)accessibilityElement];
                               }];
      
      [application observeNotification:kAXWindowResizedNotification
                           withElement:application
                               handler:^(SIAccessibilityElement *accessibilityElement) {
                                 [self updateAccessibilityInfoForElement:accessibilityElement];

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
           NSString* selectedText = accessibilityElement.selectedText;

           // guard: xcode spams us with notifs even when no text has changed, so only notify when value has changed.
           id previousSelectedText = self.accessibilityInfosByPid[@(accessibilityElement.processIdentifier)].selectedText;
           if (previousSelectedText == nil || [previousSelectedText length] == 0) {
             previousSelectedText = @"";
           }
           if ( selectedText == previousSelectedText
               ||
               [selectedText isEqualToString:previousSelectedText]) {
             // no need to update.
           }
           else {
             
             [self updateAccessibilityInfoForElement:accessibilityElement];
    
             [self onTextSelectionChanged:accessibilityElement];
           }
         }];
      
      [watchedApps addObject:application];
      
    });
  }];
}

-(AccessibilityInfo*) accessibilityInfoForElement:(SIAccessibilityElement*)siElement {
  if ([[siElement class] isEqual:[SIApplication class]]) {
    return [[AccessibilityInfo alloc] initWithAppElement:(SIApplication*) siElement];
  }
  else {
    id appElement = siElement.app;
    if (appElement) {
      return [[AccessibilityInfo alloc] initWithAppElement:appElement FocusedElement:siElement.focusedElement];
    }
    else {
      // no app element, danger!
      return nil;
    }
  }
}



-(void) updateAccessibilityInfoForElement:(SIAccessibilityElement*)siElement {
  [self updateAccessibilityInfoForElement:siElement forceUpdate:NO];
}


-(void) updateAccessibilityInfoForElement:(SIAccessibilityElement*)siElement forceUpdate:(BOOL)forceUpdate {
  AccessibilityInfo* newData = [self accessibilityInfoForElement:siElement];

  pid_t pid = siElement.processIdentifier;
  AccessibilityInfo* oldData = self.accessibilityInfosByPid[@(pid)];
  
  if (forceUpdate
      || ![newData isEqual:oldData]) {
    NSMutableDictionary* dictToUpdate = self.accessibilityInfosByPid.mutableCopy;
    
    dictToUpdate[@(pid)] = newData;
    
    self.accessibilityInfosByPid = dictToUpdate.copy;
  }
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


#pragma mark - handlers

-(void) onApplicationActivated:(SIAccessibilityElement*)element {
  // work around silica treatment of this event parameter as a SIWindow, when it should be an SIApplication
  id app = [element valueForKey:@"app"];
  __log("app activated: %@", app);
}

-(void) onFocusedWindowChanged:(SIWindow*)window {
  __log("focus: %@", window);
}

-(void) onWindowCreated:(SIWindow*)window {
  __log("new window: %@",window.title);  // NOTE title may not be available yet.
}

-(void) onTitleChanged:(SIWindow*)window {
  __log("title changed: %@", window);
}

-(void) onWindowMinimised:(SIWindow*)window {
  __log("window minimised: %@",window.title);  // NOTE title may not be available yet.
}

-(void) onWindowUnminimised:(SIWindow*)window {
  __log("window unminimised: %@",window.title);  // NOTE title may not be available yet.
}

-(void) onWindowMoved:(SIWindow*)window {
  __log("window moved: %@",window.title);  // NOTE title may not be available yet.
}

-(void) onWindowResized:(SIWindow*)window {
  __log("window resized: %@",window.title);  // NOTE title may not be available yet.
}

-(void) onTextSelectionChanged:(SIAccessibilityElement*)element {
  __log("text selection changed on element: %@. selection: %@", element, element.selectedText);
}



#pragma mark - util

-(SIWindow*) keyWindowForApplication:(SIApplication*) application {
  for (SIWindow* window in application.visibleWindows) {
    if (![window isSheet]) 
      return window;
  }

  @throw [NSException exceptionWithName:@"invalid-state" reason:@"no suitable window to return as key" userInfo:nil];
}

-(void) concurrently:(void(^)(void))block {
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    block();
  });
}

@end
