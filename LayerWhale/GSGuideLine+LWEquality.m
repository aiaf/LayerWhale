//
// Created by Abdullah Arif on 7/27/18.
// Copyright (c) 2018 Abdullah Arif. All rights reserved.
//

#import "GSGuideLine+LWEquality.h"


@implementation GSGuideLine (LWEquality)

- (BOOL)lw_isEqualToGuideLine:(GSGuideLine *)otherGuideLine {
    if ( !otherGuideLine ) {
        return NO;
    }

    if ( [self isEqualTo:otherGuideLine] ) {
        return YES;
    }

    if ( !NSEqualPoints(self.position, otherGuideLine.position) ) {
        return NO;
    }

    if ( self.angle != otherGuideLine.angle ) {
        return NO;
    }

    if ( self.alignment != otherGuideLine.alignment ) {
        return NO;
    }
    
    return [self.name isEqualToString:otherGuideLine.name];
}

@end