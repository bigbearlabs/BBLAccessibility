#import <Foundation/Foundation.h>
#import <Silica/Silica.h>
#import "AccessibilityInfo.h"

@interface BBLAccessibilityPublisher : NSObject

NS_ASSUME_NONNULL_BEGIN

@property(readonly) NSArray<NSRunningApplication*>* applicationsToObserve;

//@property(readonly,copy)NSDictionary<NSNumber*, SIApplication*>* observedAppsByPid;

@property(readonly,copy) NSDictionary<NSNumber*, AccessibilityInfo*>* accessibilityInfosByPid;  // a growing dict of ax infos.

//@property(readonly) pid_t frontmostProcessIdentifier;

@property(readonly,copy,atomic,nonnull) NSDictionary<NSNumber*, NSString*>* bundleIdsByPid; // cache bundle ids as the processes come and go, to avoid hot path to NSRunningApplication.bundleIdentifier / its backing LS function (which showed up a few times as suspicious)

-(BOOL)shouldObserveApplication: (NSRunningApplication*)application;

-(void) observeAxEvents;

-(void) unobserveAxEvents;


-(NSArray<NSNumber*>*) observeAxEventsForApplication:(NSRunningApplication*)application;

-(void) unobserveAxEventsForApplication:(NSRunningApplication*)app;


//-(void) onApplicationActivated:(SIAccessibilityElement*)element;
//
//-(void) onFocusedElementChanged:(SIAccessibilityElement*)element;
//
//-(void) onFocusedWindowChanged:(SIWindow*)window;
//
//
//-(void) onWindowCreated:(SIWindow*)window;
//
//-(void) onWindowMinimised:(SIWindow*)window;
//
//-(void) onWindowUnminimised:(SIWindow*)window;
//
//-(void) onWindowMoved:(SIWindow*)window;
//
//-(void) onWindowResized:(SIWindow*)window;
//
//
//-(void) onTitleChanged:(SIWindow*)window;
//
//-(void) onTextSelectionChanged:(SIAccessibilityElement*)element;
//
//-(void) onElementDestroyed:(SIAccessibilityElement*)element;


-(AccessibilityInfo*) accessibilityInfoForElement:(SIAccessibilityElement*)siElement axNotification:(CFStringRef)axNotification;

//-(void) updateAccessibilityInfoForElement:(SIAccessibilityElement*)siElement axNotification:(CFStringRef)axNotification;
-(void) updateAccessibilityInfoForElement:(SIAccessibilityElement*)siElement axNotification:(CFStringRef)axNotification forceUpdate:(BOOL)forceUpdate;


-(SIWindow*) keyWindowForApplication:(SIApplication*) application;

@property(readonly) AccessibilityInfo* _Nullable focusedWindowAccessibilityInfo;

//-(NSArray<SIWindow*>*) windowsForPid:(pid_t)pid;


-(SIApplication* _Nullable) appElementForProcessIdentifier:(pid_t)processIdentifier;


-(void) execAsyncSynchronisingOnPid:(pid_t)pid block:(void(^)(void))block;

//-(void) execAsyncSynchronisingOnObject:(id)object block:(void(^)(void))block;


-(void) handleAxObservationResults:(NSArray<NSNumber*>*) axResults forRunningApplication:(NSRunningApplication*) application;


// notif center registration
-(void) observeInternalNotification;
-(void) unobserveInternalNotification;


NS_ASSUME_NONNULL_END

@end

