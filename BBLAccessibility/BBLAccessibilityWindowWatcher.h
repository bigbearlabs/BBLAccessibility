//
//  BBLAccessibilityWindowWatcher.h
//  NMTest001
//
//  Created by ilo on 15/04/2016.
//
//

#import <Foundation/Foundation.h>
#import <Silica/Silica.h>


@interface BBLAccessibilityWindowWatcher : NSObject


@property(readonly) NSDictionary* accessibilityInfosByPid;  // for the focused app / window.


-(void) watchWindows;


-(void) onApplicationActivated:(SIAccessibilityElement*)element;

-(void) onFocusedWindowChanged:(SIWindow*)window;


-(void) onWindowCreated:(SIWindow*)window;

-(void) onWindowMinimised:(SIWindow*)window;

-(void) onWindowUnminimised:(SIWindow*)window;

-(void) onWindowMoved:(SIWindow*)window;

-(void) onWindowResized:(SIWindow*)window;


-(void) onTextSelectionChanged:(SIAccessibilityElement*)element;


-(SIWindow*) keyWindowForApplication:(SIApplication*) application;

@end
