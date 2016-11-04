//
//  NMUIElement.m
//  dc
//
//  Created by Work on 20/07/2010.
//  Copyright 2010 Nicholas Moore. All rights reserved.
//

#import "NMUIElement.h"

extern AXError _AXUIElementGetWindow(AXUIElementRef, CGWindowID* out);


static AXUIElementRef _systemWide = NULL;


@implementation NMUIElement

@synthesize elementRef;

+ (void)initialize
{
  if (self == [NMUIElement class]) // standard check to prevent multiple runs
  {
    if (!_systemWide) {
      _systemWide = AXUIElementCreateSystemWide();
    }
  }
}

+ (NMUIElement *)elementAtLocation:(NSPoint)point
{
  AXUIElementRef element=NULL;
  AXUIElementCopyElementAtPosition (_systemWide, point.x, point.y, &element);
  if (element) {
    id elem = [[NMUIElement alloc] initWithElement:element];
    CFRelease(element);
    return elem;
  } else {
    return nil;
  }
}

+ (NMUIElement *) focusedElement
{
  AXUIElementRef result=NULL;
  AXUIElementCopyAttributeValue(_systemWide, kAXFocusedUIElementAttribute, (CFTypeRef *)&result);
  if (result) {
    id elem = [[NMUIElement alloc] initWithElement:result];
    CFRelease(result);
    return elem;
  } else {
    NSLog(@"no focused element...");
    return nil;
  }
}


- (id)initWithElement:(AXUIElementRef)element
{
  if (!(self = [super init])) return nil;
  if(!element) return nil;
  CFRetain(element);
  elementRef=element;
  return self;
}

- (void)dealloc {
  if (elementRef) CFRelease(elementRef);
}

#pragma high-level

-(NSDictionary*) accessibilityInfo {
  NSMutableDictionary* info = [@{} mutableCopy];
  
  //  // only retrieve certain info if contained in windows
  //  if ([[[self windowElement] role] isEqualToString:(NSString *)kAXWindowRole])
  //  {
  NMUIElement *appElement=[self appElement];
  
  //        DISABLED finding the Copy menu item to show its status.
  //        // find and save new menu bar
  //        NMUIElement *menuBar=[appElement menuBar];
  //        menuItem=[self findItemInMenuBar:menuBar usingBlock:^(NMUIElement *element) {
  //            return [[element title] isEqualToString:self.menuItemTitle];
  //        }];
  
  // app-level info.
  info[@"appName"] = [appElement title];
  info[@"pid"] = @([appElement pid]);
  //  }
  
  // AX info.
  info[@"role"] = self.role;
  
  // window info.
  NMUIElement* window = self.windowElement;
  info[@"windowTitle"] = window.title;
  NSPoint origin = window.origin;
  NSSize size = window.size;
  NSRect windowRect = NSMakeRect(origin.x, origin.y, size.width, size.height);
  info[@"windowRect"] = [NSValue valueWithRect:windowRect];
  
  // window id.
  CGWindowID windowId = [NMUIElement windowIdForElement:window.elementRef];
  info[@"windowId"] = @(windowId);

  // selectedText, selectionBounds.
  NMUIElement* elementWithSelection = self.firstChildElementWithSelection;
  if (elementWithSelection) {
    info[@"selectedText"] = elementWithSelection.selectedText;
    info[@"selectionBounds"] = [NSValue valueWithRect:elementWithSelection.selectionBounds];
  }
  
  
  // TODO to provide a more complete AX information:
  
  // (contexter)
  // PoC URL of resource represented by window.

  // (xform)
  // PoC Contents of content-containing control (e.g. TextView or web text area)
  
  // (webbuddy)
  // PoC mouseover'ed URL.
  
  return info;
}

-(NSString*) description {
  return [NSString stringWithFormat:@"%@: role: %@, actions: %@, parent: %@, children: %@", [super description], self.role, self.actionNames, self.parentElement, self.children];
}

#pragma mark App Info

- (pid_t)pid
{
  pid_t result=-1;
  AXUIElementGetPid(elementRef, &result);
  return result;
}

#pragma mark Text Selection

- (NSString *)selectedText
{
  CFTypeRef result = NULL;
  AXUIElementCopyAttributeValue(elementRef, kAXSelectedTextAttribute, &result);
  if (result) {
    return (NSString*)CFBridgingRelease(result);
  } else {
    return self.selectedTextForWebArea;
  }
}

// selected text query specific for web views.
- (NSString *)selectedTextForWebArea {
  CFTypeRef range = NULL;
  AXUIElementCopyAttributeValue(elementRef, CFSTR("AXSelectedTextMarkerRange"), &range);
  
  CFTypeRef val = NULL;
  AXError err = AXUIElementCopyParameterizedAttributeValue(self.elementRef, CFSTR("AXStringForTextMarkerRange"), range, &val);
  
  if (range) CFRelease(range);

  if (err == kAXErrorSuccess) {
    return (NSString*)CFBridgingRelease(val);
  }
  else {
    // NSLog(@"err AXStringForTextMarkerRange: %d", (int)err);
    return nil;
  }
}

-(CGRect) selectionBounds {
  // query selected text range.
  AXValueRef selectedRangeValue = NULL;
  AXError err = AXUIElementCopyAttributeValue(self.elementRef, kAXSelectedTextRangeAttribute, (CFTypeRef *)&selectedRangeValue);
  if (err != kAXErrorSuccess) {
    
    // query web area selected text range.
    err = AXUIElementCopyAttributeValue(elementRef, CFSTR("AXSelectedTextMarkerRange"), (CFTypeRef *)&selectedRangeValue);
    if (err != kAXErrorSuccess) {
      
      // CASE Preview.app: AXGroup doesn't have the selectedTextRange, but its child AXStaticText does.
      if ([self.role isEqualToString:(__bridge NSString*)kAXGroupRole]) {
        AXUIElementRef staticText = (__bridge AXUIElementRef)(self.children[0]);
        NMUIElement* staticTextElem = [[NMUIElement alloc] initWithElement:staticText];
        CGRect result = staticTextElem.selectionBounds;
        return result;
      }
      
      else {
        NSLog(@"query for selection ranged failed on %@", self);
        NSLog(@"diagnosis: %@", self.description);
        return CGRectZero;
      }
    }
  }
  
  // query bounds of range.
  CGRect result;
  AXValueRef selectionBoundsValue = NULL;
  if (AXUIElementCopyParameterizedAttributeValue(self.elementRef, kAXBoundsForRangeParameterizedAttribute, selectedRangeValue, (CFTypeRef *)&selectionBoundsValue) == kAXErrorSuccess) {
    // get value out
    AXValueGetValue(selectionBoundsValue, kAXValueCGRectType, &result);
  }
  
  else {
    // couldn't query bounds of range.
    
    // DEBUG
//    id names = [self parameterisedAttributeNames];
//    NSLog(@"parameterised attribute names for %@: %@", self, names);
    
    // query bounds of web area selected text range.
    if (AXUIElementCopyParameterizedAttributeValue(self.elementRef, CFSTR("AXBoundsForTextMarkerRange"), selectedRangeValue, (CFTypeRef *)&selectionBoundsValue) == kAXErrorSuccess) {
      AXValueGetValue(selectionBoundsValue, kAXValueCGRectType, &result);
    }
    else {
      // all queries for bounds failed.
    }
  }
  
  CFRelease(selectedRangeValue);
  CFRelease(selectionBoundsValue);
  
  // NSLog(@"bounds: %@", [NSValue valueWithRect:rect]);
  
  if (CGRectIsEmpty(result)) {
//    @throw [NSException exceptionWithName:@"AXQueryFailedException" reason:[NSString stringWithFormat:@"couldn't retrieve bounds for selected text on element %@", self] userInfo:nil];
  }
  
  return result;
}

- (NMUIElement*)firstChildElementWithSelection {
  NMUIElement* element = self;
  while (element) {
    id text = element.selectedText;
    
    if (text) {
      return element;
    }
    else {
      // walk up element tree.
      element = element.parentElement;
    }
  }
  
  // couldn't retrieve selected text.
  return nil;
}

#pragma mark Parent roles (including self)
- (NSSet *)allParentRoles
{
  NSMutableSet *result=[NSMutableSet set];
  NMUIElement *p=self;
  
  while (p)
  {
    NSString *role=p.role;
    if (role) {
      [result addObject:role];
    }
    p=p.parentElement;
  }
  return result;
}

- (NMUIElement *)findParentWithRole:(NSString *)role
{
  NMUIElement *p=self;
  while (p)
  {
    if ([p.role isEqualToString:role]) {
      return p;
    }
    p=p.parentElement;
  }
  return nil;
}

# pragma mark String Attributes

- (NSString *)role
{
  CFTypeRef result;
  AXUIElementCopyAttributeValue(elementRef, kAXRoleAttribute, &result);
  return (NSString*) CFBridgingRelease((CFTypeRef)result);
}

- (NSString *)subRole
{
  CFTypeRef result;
  AXUIElementCopyAttributeValue(elementRef, kAXSubroleAttribute, (CFTypeRef *)&result);
  return (NSString*) CFBridgingRelease((CFTypeRef)result);
}

- (NSString *)title
{
  CFTypeRef result;
  AXUIElementCopyAttributeValue(elementRef, kAXTitleAttribute, (CFTypeRef *)&result);
  return (NSString*) CFBridgingRelease((CFTypeRef)result);
}

- (NSString *)menuCmdCharacter
{
  CFTypeRef result;
  AXUIElementCopyAttributeValue(elementRef, kAXMenuItemCmdCharAttribute, (CFTypeRef *)&result);
  return (NSString*) CFBridgingRelease((CFTypeRef)result);
}

- (NSNumber *)menuCmdKeycode
{
  CFTypeRef result;
  AXUIElementCopyAttributeValue(elementRef, kAXMenuItemCmdVirtualKeyAttribute, (CFTypeRef *)&result);
  return (NSNumber*) CFBridgingRelease((CFTypeRef)result);
}

- (NSNumber *)menuCmdModifiers
{
  CFTypeRef result;
  AXUIElementCopyAttributeValue(elementRef, kAXMenuItemCmdModifiersAttribute, (CFTypeRef *)&result);
  return (NSNumber*)CFBridgingRelease( result);
}

#pragma mark Boolean Attributes

- (BOOL)selected
{
  CFBooleanRef result=NULL;
  AXUIElementCopyAttributeValue(elementRef, kAXSelectedAttribute, (CFTypeRef *)&result);
  return(result && CFBooleanGetValue(result));
}

- (BOOL)enabled
{
  CFBooleanRef result=NULL;
  AXUIElementCopyAttributeValue(elementRef, kAXEnabledAttribute, (CFTypeRef *)&result);
  return(result && CFBooleanGetValue(result));
}

- (BOOL)main
{
  CFBooleanRef result=NULL;
  AXUIElementCopyAttributeValue(elementRef, kAXMainAttribute, (CFTypeRef *)&result);
  return(result && CFBooleanGetValue(result));
}

- (BOOL)hasChildren
{
  CFArrayRef children=NULL;
  AXUIElementCopyAttributeValue(elementRef, kAXChildrenAttribute, (CFTypeRef *)&children);
  return(children && CFArrayGetCount(children)>0);
}

- (BOOL)hasSelectedChildren
{
  CFArrayRef children=NULL;
  AXUIElementCopyAttributeValue(elementRef, kAXSelectedChildrenAttribute, (CFTypeRef *)&children);
  BOOL retval = (children && CFArrayGetCount(children)>0);
  if (children) CFRelease(children);
  return retval;
}

#pragma mark Window Attributes

- (NSPoint)origin
{
  CGPoint result=NSPointToCGPoint(NSZeroPoint);
  AXValueRef ref=NULL;
  AXUIElementCopyAttributeValue(elementRef, kAXPositionAttribute, (CFTypeRef *)&ref);
  if(ref)
  {
    AXValueGetValue(ref, kAXValueCGPointType, &result);
    CFRelease(ref);
  }
  return NSPointFromCGPoint(result);
}

- (NSSize)size
{
  CGSize result=NSSizeToCGSize(NSZeroSize);
  AXValueRef ref=NULL;
  AXUIElementCopyAttributeValue(elementRef, kAXSizeAttribute, (CFTypeRef *)&ref);
  if(ref)
  {
    AXValueGetValue(ref, kAXValueCGSizeType, &result);
    CFRelease(ref);
  }
  return NSSizeFromCGSize(result);
}

- (NSNumber *)insertionPointLineNumber
{
  CFTypeRef result=nil;
  AXUIElementCopyAttributeValue(elementRef, kAXInsertionPointLineNumberAttribute, (CFTypeRef *)&result);
  return (NSNumber*)CFBridgingRelease(result);
}

- (NSNumber *)numberOfCharacters
{
  CFTypeRef result=nil;
  AXUIElementCopyAttributeValue(elementRef, kAXNumberOfCharactersAttribute, (CFTypeRef *)&result);
  return (NSNumber *)CFBridgingRelease(result);
}

#pragma mark Related Elements

- (NMUIElement *)parentElement
{
  AXUIElementRef result=NULL;
  AXUIElementCopyAttributeValue(elementRef, kAXParentAttribute, (CFTypeRef *)&result);
  id elem = [[NMUIElement alloc] initWithElement:result];
  if (result) CFRelease(result);
  return elem;
}

- (NMUIElement *)topLevelElement
{
  AXUIElementRef result=NULL;
  AXUIElementCopyAttributeValue(elementRef, kAXTopLevelUIElementAttribute, (CFTypeRef *)&result);
  id elem = [[NMUIElement alloc] initWithElement:result];
  if (result) CFRelease(result);
  return elem;
}

- (NMUIElement *)windowElement
{
  NMUIElement *result=nil;
  if ([self.role isEqualToString:(NSString *)kAXWindowRole])
  {
    result=self;
  }
  else
  {
    NMUIElement *top=self.topLevelElement;
    if ([top.role isEqualToString:(NSString *)kAXWindowRole])
    {
      result=top;
    }
  }
  return result;
  
  //  // IT2
  //  AXUIElementRef result=NULL;
  //  AXUIElementCopyAttributeValue(elementRef, kAXWindowAttribute, (CFTypeRef *)&result);
  //  id elem =[[NMUIElement alloc] initWithElement:result];
  // if (result) { CFRelease(result); }
  // return elem;
}

- (NSArray *)children
{
  CFTypeRef result;
  AXUIElementCopyAttributeValue(elementRef, kAXChildrenAttribute, &result);
  return (NSArray*) CFBridgingRelease(result);
}

- (NMUIElement *)appElement
{
  id result=[self findParentWithRole:(NSString *)kAXApplicationRole];
  return result;
}

- (NMUIElement *)menuBar
{
  AXUIElementRef result=NULL;
  AXUIElementRef app=[[self findParentWithRole:(NSString *)kAXApplicationRole] elementRef];
  if (app) {
    AXUIElementCopyAttributeValue(app, kAXMenuBarRole, (CFTypeRef *)&result);
  }
  id elem = [[NMUIElement alloc] initWithElement:result];
  if (result) CFRelease(result);
  return elem;
}

- (NMUIElement *)menuBarDirect
{
  AXUIElementRef result=NULL;
  AXUIElementCopyAttributeValue(elementRef, kAXMenuBarRole, (CFTypeRef *)&result);
  id elem =[[NMUIElement alloc] initWithElement:result];
  if (result) { CFRelease(result); }
  return elem;
}

-(NMUIElement *)childAtIndex:(NSUInteger)index
{
  NMUIElement *result=nil;
  CFTypeRef itemChildren;
  AXUIElementCopyAttributeValue(elementRef, kAXChildrenAttribute, (CFTypeRef *)&itemChildren);
  if (itemChildren&&[(__bridge NSArray*)itemChildren count]>index) {
    result=[[NMUIElement alloc] initWithElement:(AXUIElementRef)[(__bridge NSArray*)itemChildren objectAtIndex:index]];
  }
  return result;
}

- (NMUIElement *)closeButtonElement
{
  AXUIElementRef result=NULL;
  AXUIElementCopyAttributeValue(elementRef, kAXCloseButtonAttribute, (CFTypeRef *)&result);
  id elem =[[NMUIElement alloc] initWithElement:result];
  if (result) { CFRelease(result); }
  return elem;
}

- (NMUIElement *)zoomButtonElement
{
  AXUIElementRef result=NULL;
  AXUIElementCopyAttributeValue(elementRef, kAXZoomButtonAttribute, (CFTypeRef *)&result);
  id elem =[[NMUIElement alloc] initWithElement:result];
  if (result) { CFRelease(result); }
  return elem;
}

- (NMUIElement *)minimizeButtonElement
{
  AXUIElementRef result=NULL;
  AXUIElementCopyAttributeValue(elementRef, kAXMinimizeButtonAttribute, (CFTypeRef *)&result);
  id elem =[[NMUIElement alloc] initWithElement:result];
  if (result) { CFRelease(result); }
  return elem;
}

- (NMUIElement *)toolbarButtonElement
{
  AXUIElementRef result=NULL;
  AXUIElementCopyAttributeValue(elementRef, kAXToolbarButtonAttribute, (CFTypeRef *)&result);
  id elem =[[NMUIElement alloc] initWithElement:result];
  if (result) { CFRelease(result); }
  return elem;
}

- (NMUIElement *)attributeNamed:(NSString *)name
{
  AXUIElementRef result=NULL;
  AXUIElementCopyAttributeValue(elementRef, (__bridge CFTypeRef)name, (CFTypeRef *)&result);
  id elem =[[NMUIElement alloc] initWithElement:result];
  if (result) { CFRelease(result); }
  return elem;
}

- (NSArray *)actionNames
{
  CFArrayRef result;
  AXUIElementCopyActionNames(elementRef, &result);
  return (NSArray*)CFBridgingRelease(result);
}

- (void)performAction:(NSString *)name
{
  AXUIElementPerformAction(elementRef, (__bridge CFStringRef)name);
}

- (NMUIElement *)topLevelMenuWithIndex:(NSUInteger)index
{
  NMUIElement *result=nil;
  NMUIElement *menuBar=[self menuBar];
  if (menuBar) {
    NSArray *menus=[menuBar children];
    if ([menus count]>index) {
      result=[[NMUIElement alloc] initWithElement:(AXUIElementRef)[menus objectAtIndex:index]];
    }
  }
  return result;
}

static void _enumerate(void (^block)(NMUIElement *element, NSUInteger depth, const NSUInteger *path, BOOL *stop),
                       NMUIElement *element, BOOL *stop, NSUInteger depth, NSUInteger maxDepth, NSUInteger *path)
{
  // check depth
  if (depth>maxDepth) {
    return;
  }
  
  // call the block
  block(element, depth, path, stop);
  
  // we are going one level deeper
  NSUInteger *pathLocation=path+depth++;
  
  // enumerate any children
  NSArray *children=(NSArray *)[element children];
  if (children) {
    NSUInteger subChildIndex=0;
    for(id childRef in children)
    {
      if (*stop) {
        break;
      }
      NMUIElement *child=[[NMUIElement alloc] initWithElement:(AXUIElementRef)childRef];
      *pathLocation=subChildIndex++;
      _enumerate(block, child, stop, depth, maxDepth, path);
    }
  }
}

- (void)enumerateDescendentsToDepth:(NSUInteger)maxDepth
                         usingBlock:(void (^)(NMUIElement *element, NSUInteger depth, const NSUInteger *path, BOOL *stop))block;
{
  __block BOOL stop=NO;
  __block NSUInteger path[NM_UIELEMENT_MAX_PATH_DEPTH]={0};
  if (maxDepth>NM_UIELEMENT_MAX_PATH_DEPTH) {
    maxDepth=NM_UIELEMENT_MAX_PATH_DEPTH;
  }
  _enumerate(block, self, &stop, 0, maxDepth, path);
}


#pragma mark AX util methods

+ (CGWindowID)windowIdForElement:(AXUIElementRef)element {
  // IT1 using CG private API.
  CGWindowID out;
  _AXUIElementGetWindow(element, &out);
  return out;
  
  // IT2 for MAS compliance, consider replacing with a filtering op from CGWindowList.
}

+ (NSArray*) windowIdsForPid:(pid_t)pid {
    AXUIElementRef app = AXUIElementCreateApplication(pid);
    CFTypeRef windows = NULL;
    AXError err = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute, &windows);
  
    if (err) {
      NSLog(@"err getting windows: %i", err);
    }
  
    CFRelease(app);

    // pe_debug "elems: #{windows[0]}"

    NSMutableArray* ids = [@[] mutableCopy];
    for (id windowRef in (NSArray*)CFBridgingRelease(windows)) {
      CGWindowID windowId = [self windowIdForElement:(__bridge AXUIElementRef)windowRef];
      [ids addObject:@(windowId)];
    }

    return ids;
}

-(NSArray*) parameterisedAttributeNames {
  CFArrayRef names = NULL;
  AXUIElementCopyParameterizedAttributeNames(self.elementRef, &names);
  return CFBridgingRelease(names);
}

@end

