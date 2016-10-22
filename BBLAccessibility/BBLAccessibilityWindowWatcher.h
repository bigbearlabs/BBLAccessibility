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

-(void) watchWindows;


-(void) onFocusedWindowChanged:(SIWindow*)window;

-(void) onWindowCreated:(SIWindow*)window;

-(void) onApplicationActivated:(SIAccessibilityElement*)element;


-(void) onWindowMinimised:(SIWindow*)window;

-(void) onWindowUnminimised:(SIWindow*)window;

-(void) onWindowMoved:(SIWindow*)window;

-(void) onWindowResized:(SIWindow*)window;

-(void) onTextSelectionChanged:(SIAccessibilityElement*)element text:(NSString*)text bounds:(CGRect)bounds;


-(SIWindow*) keyWindowForApplication:(SIApplication*) application;

@end
