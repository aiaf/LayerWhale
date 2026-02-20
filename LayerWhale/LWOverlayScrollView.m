//
//  LWOverlayScrollView.m
//  LayerTimeline
//
//  Created by Abdullah Arif on 8/27/18.
//  Copyright © 2018 Abdullah Arif. All rights reserved.
//

#import "LWOverlayScrollView.h"

@implementation LWOverlayScrollView

- (nullable instancetype)initWithCoder:(NSCoder *)coder {
	self = [super initWithCoder:coder];

	if ( self ) {
		[super setScrollerStyle:NSScrollerStyleOverlay];
	}

	return self;
}

- (void)setScrollerStyle:(NSScrollerStyle)style {
	[super setScrollerStyle:NSScrollerStyleOverlay];
}

- (NSScrollerStyle)getScrollerStyle {
	return NSScrollerStyleOverlay;
}

@end
