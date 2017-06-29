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

-(instancetype)initWithAppElement:(SIApplication*)appElement FocusedElement:(SIAccessibilityElement*)focusedElement;
{
  self = [super init];
  if (self) {
    _appName = appElement.title;
    _bundleId = appElement.runningApplication.bundleIdentifier;
    _pid = appElement.processIdentifier;
    
    _role = focusedElement.role;
    
    SIWindow* window;
    if ([[focusedElement class] isEqual:[SIWindow class]]) {
      window = (SIWindow*) focusedElement;
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
    _selectedText = focusedElement.selectedText;
    if (_selectedText) {
      _selectionBounds = focusedElement.selectionBounds;
    }
    
  }
  return self;
}

-(NSString *)description {
  id text = _selectedText;
  if (!text) {
    text = @"";
  }
  return [NSString stringWithFormat:
    @"app: %@, pid: %@, bundleId: %@, title: %@, windowId: %@, windowRect: %@, selectedText: %@, selectionBounds: %@, role: %@, windowRole: %@, windowSubrole: %@",
    _appName, @(_pid), _bundleId, _windowTitle, _windowId, [NSValue valueWithRect:_windowRect], text, [NSValue valueWithRect:_selectionBounds], _role, _windowRole, _windowSubrole
  ];
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


