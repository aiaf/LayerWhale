//
// Created by Abdullah Arif on 8/9/18.
// Copyright (c) 2018 Abdullah Arif. All rights reserved.
//

#import "NSBezierPath+CGPathGeneration.h"


@implementation NSBezierPath(CGPathGeneration)

- (CGPathRef)newCGPath {
    NSInteger numElements = [self elementCount];
    CGMutablePathRef path = NULL;

    if ( numElements > 0 )  {
         path = CGPathCreateMutable();
        NSPoint points[3];

        for (NSInteger i = 0; i < numElements; i++ )  {
            NSBezierPathElement element = [self elementAtIndex:i associatedPoints:points];
            switch ( element ) {
                case NSMoveToBezierPathElement:
                    CGPathMoveToPoint(path, NULL, points[0].x, points[0].y);
                    break;
                case NSLineToBezierPathElement:
                    CGPathAddLineToPoint(path, NULL, points[0].x, points[0].y);
                    break;
                case NSCurveToBezierPathElement:
                    CGPathAddCurveToPoint(path, NULL, points[0].x, points[0].y,
                            points[1].x, points[1].y,
                            points[2].x, points[2].y);
                    break;
                case NSClosePathBezierPathElement:
                    CGPathCloseSubpath(path);
                    break;
            }
        }

       // immutablePath = CGPathCreateCopy(path);
       // CGPathRelease(path);
    }

    return path;
}

@end
