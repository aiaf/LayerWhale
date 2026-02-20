//
// Created by Abdullah Arif on 8/21/18.
// Copyright (c) 2018 Abdullah Arif. All rights reserved.
//

#import "NSColor+LWUtility.h"


@implementation NSColor (LWUtility)

- (BOOL)lw_isDark {
    size_t count = CGColorGetNumberOfComponents(self.CGColor);
    const CGFloat *componentColors = CGColorGetComponents(self.CGColor);

    CGFloat darknessScore = 0;
    if (count == 2) {
        darknessScore = (((componentColors[0]*255) * 299) + ((componentColors[0]*255) * 587) + ((componentColors[0]*255) * 114)) / 1000;
    } else if (count == 4) {
        darknessScore = (((componentColors[0]*255) * 299) + ((componentColors[1]*255) * 587) + ((componentColors[2]*255) * 114)) / 1000;
    }

    return darknessScore < 125;
}

- (NSColor *)lw_inverted:(BOOL)invert {
    if ( !invert ) {
        return self;
    }

    const CGFloat *components = CGColorGetComponents(self.CGColor);

    if ( CGColorGetNumberOfComponents(self.CGColor) == 2 ) {
        return [NSColor colorWithCalibratedWhite:1.0-components[0] alpha:components[1]];
    }

    return [NSColor colorWithCalibratedRed:1.0-components[0]
                                     green:1.0-components[1]
                                      blue:1.0-components[2]
                                     alpha:components[3]];
}

@end