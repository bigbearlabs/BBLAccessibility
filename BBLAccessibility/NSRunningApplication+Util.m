//
//  NSRunningApplication+Util.m
//  BBLAccessibility
//
//  Created by ilo on 26/10/2017.
//  Copyright © 2017 Big Bear Labs. All rights reserved.
//

#import "NSRunningApplication+Util.h"

@implementation NSRunningApplication (Util)

-(NSString*) bundleIdentifierThreadSafe {
  __block NSString* bundleId;
  dispatch_sync(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    bundleId = self.bundleIdentifier;
  });
  return bundleId;
}

@end


