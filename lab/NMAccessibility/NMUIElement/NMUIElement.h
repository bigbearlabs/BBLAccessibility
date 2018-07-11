//
//  NMUIElement.h
//  dc
//
//  Created by Work on 20/07/2010.
//  Copyright 2010 Nicholas Moore. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define NM_UIELEMENT_MAX_PATH_DEPTH 10

@interface NMUIElement : NSObject {
	AXUIElementRef elementRef;
}

@property (readonly) NSDictionary* accessibilityInfo;

@property (readonly) AXUIElementRef elementRef;

@property (readonly) pid_t pid;

@property (readonly) NSString *selectedText;
@property (readonly) CGRect selectionBounds;

@property (readonly) NSString *role;
@property (readonly) NSString *subRole;
@property (readonly) NSString *title;
@property (readonly) NSString *menuCmdCharacter;
@property (readonly) NSNumber *menuCmdKeycode;
@property (readonly) NSNumber *menuCmdModifiers;
@property (readonly) NSSize size;
@property (readonly) NSPoint origin;

@property (readonly) BOOL selected;
@property (readonly) BOOL enabled;
@property (readonly) BOOL main;
@property (readonly) BOOL hasChildren;
@property (readonly) BOOL hasSelectedChildren;

@property (readonly) NSSet *allParentRoles;
@property (readonly) NMUIElement *appElement;
@property (readonly) NMUIElement *menuBarDirect;
@property (readonly) NMUIElement *menuBar;
@property (readonly) NMUIElement *parentElement;
@property (readonly) NMUIElement *topLevelElement;
@property (readonly) NMUIElement *windowElement;
@property (readonly) NMUIElement *closeButtonElement;
@property (readonly) NMUIElement *zoomButtonElement;
@property (readonly) NMUIElement *minimizeButtonElement;
@property (readonly) NMUIElement *toolbarButtonElement;

@property (readonly) NSArray *actionNames;
@property (readonly) NSArray *children;  // children as array of ACUIElementRef
@property (readonly) NSNumber *insertionPointLineNumber;
@property (readonly) NSNumber *numberOfCharacters;

+ (NMUIElement *)elementAtLocation:(NSPoint)point;
+ (NMUIElement *)focusedElement;

- (NMUIElement *)childAtIndex:(NSUInteger)index;
- (id)initWithElement:(AXUIElementRef)element;
- (void)performAction:(NSString *)name;
- (NMUIElement *)findParentWithRole:(NSString *)role;
- (NMUIElement *)topLevelMenuWithIndex:(NSUInteger)index;
- (NMUIElement *)attributeNamed:(NSString *)name;

- (void)enumerateDescendentsToDepth:(NSUInteger)depth
						 usingBlock:(void (^)(NMUIElement *element, NSUInteger depth, const NSUInteger *path, BOOL *stop))block; // nested enumeration of all children


+ (CGWindowID)windowIdForElement:(AXUIElementRef)element;

@end