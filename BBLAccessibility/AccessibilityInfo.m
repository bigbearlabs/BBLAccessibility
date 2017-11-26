//
//  AccessibilityInfo.m
//  BBLAccessibility
//
//  Created by ilo on 18.11.16.
//  Copyright © 2016 Big Bear Labs. All rights reserved.
//

#import "AccessibilityInfo.h"


@implementation AccessibilityInfo
{
  SIAccessibilityElement* _focusedElement;
}


-(instancetype)initWithAppElement:(SIApplication*)app axNotification:(CFStringRef)axNotification;
{
  NSArray* visibleWindows = app.visibleWindows;
  if (visibleWindows.count != 0) {
    return [self initWithAppElement:app focusedElement:app.focusedWindow axNotification:axNotification];
  }
  else {
    return [self initWithAppElement:app focusedElement:nil axNotification:axNotification];
  }
}


// TODO keep reference of element and maybe even the notif responsible for creation, to better keep track of the context of ax events.
/// not thread-safe -- caller must ensure thread confinement.
-(instancetype)initWithAppElement:(SIApplication*)appElement
                   focusedElement:(SIAccessibilityElement*)focusedElement
                   axNotification:(CFStringRef)axNotification
{
  self = [super init];
  if (self) {
    _axNotification = (__bridge CFStringRef _Nonnull)([(__bridge NSString*)axNotification copy]);
    
    _appName = appElement.title;
    _bundleId = appElement.runningApplication.bundleIdentifier;
    _pid = appElement.processIdentifier;
    
    _focusedElement = focusedElement;
    _role = focusedElement.role;
    
    SIWindow* window;
    if ([[focusedElement class] isEqual:[SIWindow class]]) {
      window = (SIWindow*) focusedElement;
    }
    else if ([focusedElement.role isEqualToString:(NSString*)kAXWindowRole]) {
      window = [[SIWindow alloc] initWithAXElement:focusedElement.axElementRef];
    }
    else {
      window = focusedElement.window;
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
          @"ax: %@, app: %@, pid: %@, bundleId: %@, title: %@, windowId: %@, windowRect: %@, selectedText: %@, selectionBounds: %@, role: %@, windowRole: %@, windowSubrole: %@",
    _axNotification, _appName, @(_pid), _bundleId, _windowTitle, _windowId, [NSValue valueWithRect:_windowRect], selectedText, [NSValue valueWithRect:_selectionBounds], _role, _windowRole, _windowSubrole
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
