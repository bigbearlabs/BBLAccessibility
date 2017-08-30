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
  if (self.isWebArea) {
    return [self selectedTextForWebArea];
  }
  else {
    id selectedText = [self stringForKey:kAXSelectedTextAttribute];
    return selectedText;
  }
}


- (NSString*) selectedTextForWebArea {
  CFTypeRef range = NULL;
  AXUIElementCopyAttributeValue(self.axElementRef, CFSTR("AXSelectedTextMarkerRange"), &range);
  
  if (range == nil) {
    // no selected range, return nil.
    return nil;
  }
  
  CFTypeRef val = NULL;
  AXError err = AXUIElementCopyParameterizedAttributeValue(self.axElementRef, CFSTR("AXStringForTextMarkerRange"), range, &val);
  
  if (range) CFRelease(range);
  
  if (err == kAXErrorSuccess) {
    return (NSString*)CFBridgingRelease(val);
  }
  else {
    NSLog(@"err AXStringForTextMarkerRange: %d", (int)err);
    if (val) CFRelease(val);
    return nil;
  }
}



-(NSRect) selectionBounds {
  if (self.isWebArea) {
    return [self selectionBoundsForWebArea];
  }
  
  CGRect result = NSZeroRect;

  CFTypeRef selectedRangeValue = NULL;
  CFTypeRef selectionBoundsValue = NULL;
  
  // query selected text range.
  if (AXUIElementCopyAttributeValue(self.axElementRef, kAXSelectedTextRangeAttribute, (CFTypeRef *)&selectedRangeValue) == kAXErrorSuccess) {
    
    // query bounds of range.
    if (AXUIElementCopyParameterizedAttributeValue(self.axElementRef, kAXBoundsForRangeParameterizedAttribute, selectedRangeValue, (CFTypeRef *)&selectionBoundsValue) == kAXErrorSuccess) {
      
      // get value out.
      AXValueGetValue(selectionBoundsValue, kAXValueCGRectType, &result);
    }
    
    else {
      // couldn't query bounds of range.
    }  
  }
  else {
      // CASE Preview.app: AXGroup doesn't have the selectedTextRange, but its child AXStaticText does.
      if ([self.role isEqualToString:(__bridge NSString*)kAXGroupRole]) {
        NSArray* children = self.children;
        if (children.count > 0) {
          AXUIElementRef staticText = (__bridge AXUIElementRef) children[0];
          SIAccessibilityElement* staticTextElem = [[SIAccessibilityElement alloc] initWithAXElement:staticText];
          result = staticTextElem.selectionBounds;
        }
      }
      
      else {
        NSLog(@"query for selection range failed on %@", self.debugDescription);
        result = NSZeroRect;
      }
  }
  
  // NSLog(@"bounds: %@", [NSValue valueWithRect:rect]);
  
  if (NSIsEmptyRect(result)) {
//       @throw [NSException exceptionWithName:@"AXQueryFailedException" reason:[NSString stringWithFormat:@"couldn't retrieve bounds for selected text on element %@", self] userInfo:nil];
  }
  
  if (selectedRangeValue) CFRelease(selectedRangeValue);
  if (selectionBoundsValue) CFRelease(selectionBoundsValue);
  
  return NSRectFromCGRect(result);
}


-(NSRect) selectionBoundsForWebArea {
  // guard against empty selected text.
  if ([self selectedTextForWebArea].length == 0) {
    return NSZeroRect;
  }
  
  NSRect result = NSZeroRect;

  AXValueRef selectedRangeValue = NULL;
  AXValueRef selectionBoundsValue = NULL;

  // query web area selected text range.
  if (AXUIElementCopyAttributeValue(self.axElementRef, CFSTR("AXSelectedTextMarkerRange"), (CFTypeRef *)&selectedRangeValue) == kAXErrorSuccess) {
   
    // query bounds of web area selected text range.
    if (AXUIElementCopyParameterizedAttributeValue(self.axElementRef, CFSTR("AXBoundsForTextMarkerRange"), selectedRangeValue, (CFTypeRef *)&selectionBoundsValue) == kAXErrorSuccess) {
      AXValueGetValue(selectionBoundsValue, kAXValueCGRectType, &result);
    }
    else {
      // query for bounds failed.
    }
  }

  if (selectedRangeValue) CFRelease(selectedRangeValue);
  if (selectionBoundsValue) CFRelease(selectionBoundsValue);
  
  return result;

}


-(BOOL) isWebArea {
  // if i have a AXWebArea role, i am a web area.
  return [self.role isEqualToString:@"AXWebArea"];
}

@end


@implementation SIAccessibilityElement (Text)

-(NSString*) text {
  // REF selectedText:
//  if (self.isWebArea) {
//    return [self selectedTextForWebArea];
//  }
//  else {
//    id selectedText = [self stringForKey:kAXSelectedTextAttribute];
//    return selectedText;
//  }

  // TODO if text element,
  if ([self isTextArea]) {
    id text = [self stringForKey:kAXValueAttribute];
    return text;
  }
  return nil;
}

-(BOOL) isTextArea {
  return [self.role isEqualToString:@"AXTextArea"];
}


@end
