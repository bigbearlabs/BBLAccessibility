//
//  TestWindowController.h
//  NMTest001
//
//  Created by Nick Moore on 05/10/2011.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "NMUIElement.h"

@interface TestWindowController : NSWindowController {
    // internals
    NMUIElement *menuItem;
    NSTimer *timer;
    
    // ui
    NSString *__strong appDisplayName;
    NSString *__strong menuItemTitle;
    NSString *__strong foundMenuItemTitle;
    NSString *__strong foundMenuItemState;
}

@property (strong) NSString *appDisplayName;
@property (strong) NSString *menuItemTitle;
@property (strong) NSString *foundMenuItemTitle;
@property (strong) NSString *foundMenuItemState;

- (void)handleNewElement:(NMUIElement *)element;

@end
