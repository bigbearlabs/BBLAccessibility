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


-(instancetype)initWithAppElement:(SIApplication*)app axNotification:(CFStringRef)axNotification bundleId:(NSString*)bundleId;
{
  SIWindow* focusedWindow = app.focusedWindow;
  return [self initWithAppElement:app
                   focusedElement:focusedWindow
                   axNotification:axNotification
                          bundleId: bundleId];
}


// TODO keep reference of element and maybe even the notif responsible for creation, to better keep track of the context of ax events.
/// not thread-safe -- caller must ensure thread confinement.
-(instancetype)initWithAppElement:(SIApplication*)appElement
                   focusedElement:(SIAccessibilityElement*)focusedElement
                   axNotification:(CFStringRef)axNotification
                         bundleId:(NSString*)bundleId
{
  self = [super init];
  if (self) {
    _axNotification = [(__bridge NSString*)axNotification copy];
    
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

    _bundleId = bundleId;
    
    
  }
  return self;
}


-(NSString*) text {
  return _focusedElement.text;
}

-(NSString*)selectedText {
  return _focusedElement.selectedText;
}
-(NSRect)selectionBounds {
  return _focusedElement.selectionBounds;
}

-(NSString *)description {
  NSObject* selectedText = self.selectedText;
  NSUInteger selectedTextHash = selectedText.hash;
  NSUInteger selectionBoundsHash = self.selectedText != nil ?
    @(self.selectionBounds).hash
    : 0;
  
    return [NSString stringWithFormat:
            @"ax: %@, app: %@, pid: %@, bundleId: %@, title: %@, windowId: %@, windowRect: %@, selectedTextHash: %@, selectionBoundsHash: %@, role: %@, windowRole: %@, windowSubrole: %@",
      _axNotification, _appName, @(_pid), _bundleId, _windowTitle, _windowId, [NSValue valueWithRect:_windowRect], @(selectedTextHash), @(selectionBoundsHash), _role, _windowRole, _windowSubrole
    ];
}


- (BOOL)isEqual:(id)other
{
  if (other == nil) {
    return NO;
  }
  if (other == self) {
    return YES;
  }
  
  AccessibilityInfo* theOther = (AccessibilityInfo*) other;
  return
    [_axNotification isEqual:theOther.axNotification]
      && NSEqualRects(_windowRect, theOther.windowRect)
      && [_focusedElement isEqual:theOther->_focusedElement]
        // should cover bundle id, pid
      && [_role isEqual:theOther.role]
      && [_windowElement isEqual:theOther.windowElement]
        // should cover window id, window role, window subrole
      && [_windowTitle isEqual:theOther.windowTitle];
}

- (NSUInteger)hash
{
  return @[
           _axNotification,
           @(_windowRect),
           _focusedElement,
           _role,
           _windowElement,
           _windowTitle
           ].hash;
}


@end
