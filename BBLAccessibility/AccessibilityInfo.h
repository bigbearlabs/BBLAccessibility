//
//  AccessibilityInfo.h
//  BBLAccessibility
//
//  Created by ilo on 18.11.16.
//  Copyright © 2016 Big Bear Labs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Silica/Silica.h>
#import "Silica-ext.h"

@interface AccessibilityInfo : NSObject

@property(readonly) NSString* _Nullable appName;
@property(readonly) NSString* _Nonnull bundleId;
@property(readonly) pid_t pid;

@property(readonly) NSString* _Nullable role;
@property(readonly) NSString* _Nullable windowRole;
@property(readonly) NSString* _Nullable windowSubrole;

@property(readonly) NSString* _Nullable windowTitle;
@property(readonly) NSString* _Nonnull windowId;
@property(readonly) NSRect windowRect;

@property(readonly) NSString* _Nullable selectedText;
@property(readonly) NSRect selectionBounds;

@property(readonly) SIWindow* _Nullable windowAxElement;

-(nonnull instancetype)initWithAppElement:(nonnull SIApplication*)element;

-(nonnull instancetype)initWithFocusedElement:(nonnull SIAccessibilityElement*)element;

@end
