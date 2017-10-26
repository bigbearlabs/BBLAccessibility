//
//  AccessibilityInfo.m
//  BBLAccessibility
//
//  Created by ilo on 18.11.16.
//  Copyright © 2016 Big Bear Labs. All rights reserved.
//

#import "AccessibilityInfo.h"
#import "NSRunningApplication+Util.h"


@implementation AccessibilityInfo
{
  SIAccessibilityElement* _focusedElement;
}


-(instancetype)initWithAppElement:(SIApplication*)element;
{
  NSArray* visibleWindows = element.visibleWindows;
  if (visibleWindows.count > 0) {
    return [self initWithAppElement:element focusedElement:visibleWindows[0]];
  }
  else {
    return [self initWithAppElement:element focusedElement:element];
  }
}

-(instancetype)initWithAppElement:(SIApplication*)appElement focusedElement:(SIAccessibilityElement*)focusedElement;
{
  self = [super init];
  if (self) {
    _appName = appElement.title;
    _bundleId = appElement.runningApplication.bundleIdentifierThreadSafe;
    _pid = appElement.processIdentifier;
    
    _focusedElement = focusedElement;
    
    
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

-(NSString*) text {
  return _focusedElement.text;
}




-(NSString *)description {
  id selectedText = _selectedText;
  if (!selectedText) {
    selectedText = @"";
  }
  return [NSString stringWithFormat:
    @"app: %@, pid: %@, bundleId: %@, title: %@, windowId: %@, windowRect: %@, selectedText: %@, selectionBounds: %@, role: %@, windowRole: %@, windowSubrole: %@",
    _appName, @(_pid), _bundleId, _windowTitle, _windowId, [NSValue valueWithRect:_windowRect], selectedText, [NSValue valueWithRect:_selectionBounds], _role, _windowRole, _windowSubrole
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
