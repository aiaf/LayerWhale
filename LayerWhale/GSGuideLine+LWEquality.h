//
// Created by Abdullah Arif on 7/27/18.
// Copyright (c) 2018 Abdullah Arif. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GlyphsCore/GSGuideLine.h>

@interface GSGuideLine (LWEquality)
- (BOOL)lw_isEqualToGuideLine:(GSGuideLine *)otherGuideLine;
@end