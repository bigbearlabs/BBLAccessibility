//
//  Silica-ext.m
//  BBLAccessibility
//
//  Created by ilo on 19/11/2016.
//  Copyright © 2016 Big Bear Labs. All rights reserved.
//

#import "Silica-ext.h"

@implementation SIAccessibilityElement (TextSelection)

-(NSString*) selectedText {
  id selectedText = [self stringForKey:kAXSelectedTextAttribute];
  if (selectedText == nil) {
    selectedText = [self selectedTextForWebArea];
  }
  return selectedText;
}

- (NSString *)selectedTextForWebArea {
  CFTypeRef range = NULL;
  AXUIElementCopyAttributeValue(self.axElementRef, CFSTR("AXSelectedTextMarkerRange"), &range);
  
  CFTypeRef val = NULL;
  AXError err = AXUIElementCopyParameterizedAttributeValue(self.axElementRef, CFSTR("AXStringForTextMarkerRange"), range, &val);
  
  if (range) CFRelease(range);
  
  if (err == kAXErrorSuccess) {
    return (NSString*)CFBridgingRelease(val);
  }
  else {
    NSLog(@"err AXStringForTextMarkerRange: %d", (int)err);
    return nil;
  }
}


-(NSRect) selectionBounds {
  // query selected text range.
  AXValueRef selectedRangeValue = NULL;
  AXError err = AXUIElementCopyAttributeValue(self.axElementRef, kAXSelectedTextRangeAttribute, (CFTypeRef *)&selectedRangeValue);
  if (err != kAXErrorSuccess) {
    
    // query web area selected text range.
    err = AXUIElementCopyAttributeValue(self.axElementRef, CFSTR("AXSelectedTextMarkerRange"), (CFTypeRef *)&selectedRangeValue);
    if (err != kAXErrorSuccess) {
      
      // CASE Preview.app: AXGroup doesn't have the selectedTextRange, but its child AXStaticText does.
      if ([self.role isEqualToString:(__bridge NSString*)kAXGroupRole]) {
        AXUIElementRef staticText = (__bridge AXUIElementRef)(self.children[0]);
        SIAccessibilityElement* staticTextElem = [[SIAccessibilityElement alloc] initWithAXElement:staticText];
        CFRelease(staticText);
        NSRect result = staticTextElem.selectionBounds;
        return result;
      }
      
      else {
        NSLog(@"query for selection ranged failed on %@", self);
        NSLog(@"diagnosis: %@", self.description);
        return NSZeroRect;
      }
    }
  }
  
  // query bounds of range.
  NSRect result;
  AXValueRef selectionBoundsValue = NULL;
  if (AXUIElementCopyParameterizedAttributeValue(self.axElementRef, kAXBoundsForRangeParameterizedAttribute, selectedRangeValue, (CFTypeRef *)&selectionBoundsValue) == kAXErrorSuccess) {
    // get value out
    AXValueGetValue(selectionBoundsValue, kAXValueCGRectType, &result);
  }
  
  else {
    // couldn't query bounds of range.
    
    // DEBUG
    //    id names = [self parameterisedAttributeNames];
    //    NSLog(@"parameterised attribute names for %@: %@", self, names);
    
    // query bounds of web area selected text range.
    if (AXUIElementCopyParameterizedAttributeValue(self.axElementRef, CFSTR("AXBoundsForTextMarkerRange"), selectedRangeValue, (CFTypeRef *)&selectionBoundsValue) == kAXErrorSuccess) {
      AXValueGetValue(selectionBoundsValue, kAXValueCGRectType, &result);
    }
    else {
      // all queries for bounds failed.
    }
  }
  
  if (selectedRangeValue) CFRelease(selectedRangeValue);
  if (selectionBoundsValue) CFRelease(selectionBoundsValue);
  
  // NSLog(@"bounds: %@", [NSValue valueWithRect:rect]);
  
  if (NSIsEmptyRect(result)) {
    //    @throw [NSException exceptionWithName:@"AXQueryFailedException" reason:[NSString stringWithFormat:@"couldn't retrieve bounds for selected text on element %@", self] userInfo:nil];
  }
  
  return result;
}

@end
