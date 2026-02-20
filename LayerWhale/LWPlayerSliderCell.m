//
//  LWPlayerSliderCell.m
//  LayerWhale
//
//  Created by Abdullah Arif on 10/25/18.
//  Copyright © 2018 Abdullah Arif. All rights reserved.
//

#import "LWPlayerSliderCell.h"

@implementation LWPlayerSliderCell

- (NSRect)rectOfTickMarkAtIndex:(NSInteger)index {
	double relativePosition =  [self bookmarkAtIndex:index];

	if ( relativePosition == 0 ) {
		return NSZeroRect;
	}

	NSRect track = self.trackRect;
	CGFloat xOffset = relativePosition == 1 ? -1.0 : -2.0;
	CGFloat barWidth = track.size.width - 2.0;
	CGFloat tickWidth = 0.5;//self.numberOfTickMarks >= ( barWidth * 0.5 ) ? 0.5 : 1.0;

	return NSMakeRect( (relativePosition * barWidth) + xOffset, 0.0, tickWidth, track.size.height - 5.0);
}

- (void)drawTickMarks {
	[[NSColor systemPinkColor] set];
	for (NSUInteger i = 0; i < self.numberOfTickMarks; i++) {
		NSRectFill([self rectOfTickMarkAtIndex:i]);
	}
}

- (double)bookmarkAtIndex:(NSInteger)index {
	return index < [self.checkpoints count] ? [self.checkpoints[ index ] doubleValue] : 0.0;
}

// This moves up the progress bar a few pixels such that it's dead center within bookmark ticks.
// Do not think this is too nice
//- (void)drawBarInside:(NSRect)rect flipped:(BOOL)flipped {
//	CGFloat midY = ( self.trackRect.size.height * 0.5 ) - rect.size.height - 1.0 ;
//	rect.origin.y = midY;
//	[super drawBarInside:rect flipped:flipped];
//}

- (double)tickMarkValueAtIndex:(NSInteger)index {
	return [self bookmarkAtIndex:index] * ( [self maxValue] - [self minValue] );
}

- (void)snapToClosestTickMark:(double)position {
    double range = [self maxValue] - [self minValue];
    double threshold = 0.01 * range;
    double closest = [self closestTickMarkValueToValue:position];
    double distance = fabs(position - closest);

	if ( distance < threshold ) {
		[self setDoubleValue:closest];
	}
}

@end
