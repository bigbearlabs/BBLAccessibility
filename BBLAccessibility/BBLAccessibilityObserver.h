#import <Foundation/Foundation.h>
#import <Silica/Silica.h>
#import "AccessibilityInfo.h"

@interface BBLAccessibilityObserver : NSObject


@property(readonly) NSArray<NSRunningApplication*>* applicationsToObserve;

@property(readonly,copy) NSDictionary<NSNumber*,AccessibilityInfo*>* accessibilityInfosByPid;  // a growing dict of ax infos.


-(void) watchWindows;

-(void) unwatchWindows;


-(void) onApplicationActivated:(SIAccessibilityElement*)element;

-(void) onFocusedElementChanged:(SIAccessibilityElement*)element;

-(void) onFocusedWindowChanged:(SIWindow*)window;


-(void) onWindowCreated:(SIWindow*)window;

-(void) onWindowMinimised:(SIWindow*)window;

-(void) onWindowUnminimised:(SIWindow*)window;

-(void) onWindowMoved:(SIWindow*)window;

-(void) onWindowResized:(SIWindow*)window;


-(void) onTitleChanged:(SIWindow*)window;

-(void) onTextSelectionChanged:(SIAccessibilityElement*)element;

-(void) onElementDestroyed:(SIAccessibilityElement*)element;


-(void) updateAccessibilityInfoForElement:(SIAccessibilityElement*)siElement forceUpdate:(BOOL)forceUpdate;


-(SIWindow*) keyWindowForApplication:(SIApplication*) application;


// util

-(void) concurrentlyWithContext:(NSDictionary*)context block:(void(^)(void))block;

@end

