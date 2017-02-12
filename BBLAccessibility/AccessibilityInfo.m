//
//  AccessibilityInfo.m
//  BBLAccessibility
//
//  Created by ilo on 18.11.16.
//  Copyright © 2016 Big Bear Labs. All rights reserved.
//

#import "AccessibilityInfo.h"


@implementation AccessibilityInfo

-(instancetype)initWithAppElement:(SIApplication*)element;
{
  NSArray* visibleWindows = element.visibleWindows;
  if (visibleWindows.count > 0) {
    return [self initWithAppElement:element FocusedElement:visibleWindows[0]];
  }
  else {
    return [self initWithAppElement:element FocusedElement:element];
  }
}

-(instancetype)initWithAppElement:(SIApplication*)appElement FocusedElement:(SIAccessibilityElement*)element;
{
  self = [super init];
  if (self) {
    _appName = appElement.title;
    _bundleId = appElement.runningApplication.bundleIdentifier;
    _pid = appElement.processIdentifier;
    
    _role = element.role;
    
    SIWindow* window;
    if ([[element class] isEqual:[SIWindow class]]) {
      window = (SIWindow*) element;
    }
    else {
      window = appElement.focusedWindow;
      // ASSUMES we're never interested in AccessibilityInfo belonging to other windows.
    }

    _windowAxElement = window.copy;
    
    _windowTitle = window.title;
    _windowId = @(window.windowID).stringValue;
    _windowRect = window.frame;
    _windowRole = window.role;
    _windowSubrole = window.subrole;

    
    // properties related to the selection. this part probably needs more hardening.
    _selectedText = element.selectedText;
    if (_selectedText) {
      _selectionBounds = element.selectionBounds;
    }
    
  }
  return self;
}

-(NSString *)description {
  return [NSString stringWithFormat:@"%@, %@, %@, %@, %@, %@, %@, %@, focusedElementRole: %@, windowRole: %@, windowSubrole: %@",
          _appName, [NSNumber numberWithUnsignedInteger:_pid], _bundleId, _windowTitle, _windowId, [NSValue valueWithRect:_windowRect], _selectedText, [NSValue valueWithRect:_selectionBounds], _role, _windowRole, _windowSubrole];
}


- (BOOL)isEqual:(id)other
{
  if (other == self) {
    return YES;
  } else {
    return [[self description] isEqualToString:[other description]];
  }
}

- (NSUInteger)hash
{
  return [[self description] hash];
}


@end


