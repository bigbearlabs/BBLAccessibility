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
  NSString* _bundleId;
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
    _pid = appElement.processIdentifier;
    
    _focusedElement = focusedElement;
    _role = focusedElement.role;
    
    if (focusedElement != nil) {
      _windowElement = [SIWindow windowForElement:focusedElement];
    }
    
    _windowTitle = _windowElement.title;
    _windowId = @(_windowElement.windowID).stringValue;
    _windowRect = _windowElement.frame;
    _windowRole = _windowElement.role;
    _windowSubrole = _windowElement.subrole;

    
    // properties related to the selection. this part probably needs more hardening.
    _selectedText = focusedElement.selectedText;
    if (_selectedText) {
      _selectionBounds = focusedElement.selectionBounds;
    }
    
  }
  return self;
}

-(NSString*) bundleId {
  if (_bundleId == nil) {
    _bundleId = [NSRunningApplication runningApplicationWithProcessIdentifier:_pid].bundleIdentifier;
  }
  return _bundleId;
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
