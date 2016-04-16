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

@end
