//
//  Silica-ext.h
//  BBLAccessibility
//
//  Created by ilo on 19/11/2016.
//  Copyright © 2016 Big Bear Labs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Silica/Silica.h>

@interface SIAccessibilityElement (TextSelection)

-(NSString*) selectedText;

-(NSRect) selectionBounds;

@end


@interface SIAccessibilityElement (Text)

-(NSString*) text;

@end
