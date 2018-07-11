//
//  TestWindowController.m
//  NMTest001
//
//  Created by Nick Moore on 05/10/2011.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "TestWindowController.h"


@implementation TestWindowController

@synthesize appDisplayName, menuItemTitle, foundMenuItemTitle, foundMenuItemState;


- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (NMUIElement *)findItemInMenuBar:(NMUIElement *)menuBar usingBlock:(BOOL (^)(NMUIElement *))block;
{
    __block NMUIElement *result=nil;
    NSUInteger expectedMenu=3; // note: searching edit menu only
    NSUInteger expectedDepth=2;
    [[menuBar childAtIndex:expectedMenu] enumerateDescendentsToDepth:expectedDepth
                                                          usingBlock:^(NMUIElement *element, NSUInteger depth, const NSUInteger *path, BOOL *stop) {
                                                              if (depth==expectedDepth)
                                                              {
                                                                  if (block(element))
                                                                  {
                                                                      result=element;
                                                                      *stop=YES;
                                                                  }
                                                              }
                                                          }];
    return result;
}

// called frequently to poll the menu item state and update the ui
- (void)timerRoutine
{
    NSString *titleString=[NSString stringWithFormat:@"no match for '%@'", self.menuItemTitle];
    NSString *stateString=@"unknown";
    
    if (menuItem) {
        titleString=[menuItem title];
        stateString=[menuItem enabled]?@"+++ Enabled +++":@"--- Disabled ---";
    }
    
    // update the UI
    self.foundMenuItemTitle=titleString;
    self.foundMenuItemState=stateString;
}

- (void)handleNewElement:(NMUIElement *)element
{
    // find and save new menu bar
    NMUIElement *appElement=[element appElement];
    NMUIElement *menuBar=[appElement menuBar];
    menuItem=[self findItemInMenuBar:menuBar usingBlock:^(NMUIElement *element) {
        return [[element title] isEqualToString:self.menuItemTitle];
    }];

    // what it this app's name and pid
    self.appDisplayName=[NSString stringWithFormat:@"%@ (%i)", [appElement title],[appElement pid]];
    [self timerRoutine];    
}


- (void)windowDidLoad
{
    [super windowDidLoad];
    [self.window setLevel:NSFloatingWindowLevel];
    self.menuItemTitle=@"Copy";
    self.appDisplayName=@"(click in an app window)";

    timer=[NSTimer scheduledTimerWithTimeInterval:0.025 target:self selector:@selector(timerRoutine) userInfo:nil repeats:YES];
}

- (void)showWindow:(id)sender
{
    [self.window center];
    [self.window makeKeyAndOrderFront:self];
}

@end
