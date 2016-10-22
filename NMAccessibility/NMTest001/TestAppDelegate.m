//
//  NMTest001AppDelegate.m
//  NMTest001
//
//  Created by Nick Moore on 05/10/2011.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "TestAppDelegate.h"

typedef void (^NMAXObservationHandler)(void);



@interface NMAXObservationCentre : NSObject

+(instancetype) sharedInstance;

-(void) observe:(CFStringRef)axNotification withHandler:(NMAXObservationHandler)handler;

@end



@implementation NMAXObservationCentre

+(instancetype) sharedInstance {
  return nil;  // stub
}

-(void) observe:(CFStringRef)axNotification withHandler:(NMAXObservationHandler)handler {
}

@end


@interface TestAppDelegate ()
{
  NSTimer* timer;
}
@end

@implementation TestAppDelegate

- (IBAction)createNewWindow:(id)sender
{
    TestWindowController *windowController=[[TestWindowController alloc] initWithWindowNibName:@"Window"];
    [windowControllers addObject:windowController];
    [windowController showWindow:self];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    windowControllers=[NSMutableArray array];
    [self createNewWindow:self];
    prev_pid=-1;
    
    
    // Insert code here to initialize your application
    [NSEvent addGlobalMonitorForEventsMatchingMask:NSLeftMouseDownMask|NSLeftMouseUpMask handler:^(NSEvent *event) {
        
        // get the UI Element at the mouse location
        CGEventRef eventRef = CGEventCreate(NULL);
        NSPoint point=NSPointFromCGPoint(CGEventGetLocation(eventRef));
        CFRelease(eventRef);
      
        NMUIElement *const element=[NMUIElement elementAtLocation:point];        

        
        NSLog(@"report for element %@: %@", element, element.accessibilityInfo);
        NMUIElement* focusedElement = [NMUIElement focusedElement];
        NSLog(@"report for focused element %@: %@", element, focusedElement.accessibilityInfo);
      
    }];

    // periodically poll for info on first responder element.
    timer=[NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(timerRoutine) userInfo:nil repeats:YES];
  
    // ALT: observe systemwide element for focuseduielement changes, observe focused element for selected text changes.
}

-(void)timerRoutine {
  NMUIElement* focusedElement = [NMUIElement focusedElement];
  NSLog(@"focusedElement: %@ selectedText: %@ selectionBounds: %@", focusedElement, focusedElement.selectedText, focusedElement.selectionBounds);
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{   
    return YES;
}

@end
