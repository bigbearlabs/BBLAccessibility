//
//  NSRunningApplication+Util.h
//  BBLAccessibility
//
//  Created by ilo on 26/10/2017.
//  Copyright © 2017 Big Bear Labs. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSRunningApplication (Util)

@property(readonly,copy) NSString* _Nullable bundleIdentifierThreadSafe;

@end
