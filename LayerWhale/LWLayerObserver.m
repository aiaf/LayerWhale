//
// Created by Abdullah Arif on 7/3/18.
// Copyright (c) 2018 Abdullah Arif. All rights reserved.
//

#import "LWLayerObserver.h"
#import "GSLayer+LWTimeline.h"
#import <GlyphsCore/GSCallbackHandler.h>


@implementation LWLayerObserver

+ (LWLayerObserver *)perpetualObserver
{
    static LWLayerObserver *perpetualObserver = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        perpetualObserver = [[LWLayerObserver alloc] init];
		perpetualObserver.activated = NO;
    });

    return perpetualObserver;
}

- (void)activate {
	if ( !self.activated ) {
    	[GSCallbackHandler addCallback:self forOperation:GSPrepareLayerCallbackName];
		self.activated = YES;
	}
}

- (void)deactivate {
	if ( self.activated ) {
    	[GSCallbackHandler removeCallback:self forOperation:GSPrepareLayerCallbackName];
		self.activated = NO;
	}
}

/*
 * This gets invoked for GSPrepareLayerCallbackName
 */
- (void)processLayer:(GSLayer*)layer originalGlyph:(GSGlyph*)originalGlyph withInstance:(GSInstance*)instance
{
    /*
     * TODO: watch out for possible point of failure here
     * - processBezierPath:... only gets invoked if we implement -processLayer:...
     * Even an empty implementation will do.
     * Maybe erroneously, maybe not, we just need to be aware.
     *
     * If this fails in future Glyphs version, must then inject the recording functionality into
     * - (void)drawForegroundForLayer:(GSLayer *)layer options:(NSDictionary *)options
     * with GSDrawForegroundCallbackName
     */
}

/*
 * This gets invoked as a side effect of processLayer:originalGlyph:withInstance
 * This will give us proper node/path changes, even intermediary changes (e.g. moving a handle but not then releasing the mouse at its original position)
 */
- (void)processBezierPath:(NSBezierPath*)bezierPath openBezierPath:(NSBezierPath*)openBezierPath secondaryPath:(NSBezierPath*)secondaryPath forLayer:(GSLayer*)layer {
   // NSLog(@"processBezier for glyph.%@ id.%@", layer.glyph.name, layer.layerId);
    if ([layer lw_hasTimeline] ) {
        LWTimeline* timeline = [layer lw_timeline];
        if ( timeline.isRecording ) {
            NSTimeInterval editTime = [[NSDate date] timeIntervalSince1970];
            //NSLog(@"PROC isRecording and will do %f", editTime);
            dispatch_async(dispatch_get_main_queue(), ^{
                [timeline recordLayer:layer atTime:editTime];
            });
        }
    }
}
//
//- (BOOL)respondsToSelector:(SEL)aSelector {
//    NSLog(@"respondsToSelector: %@", NSStringFromSelector(aSelector));
//    return [super respondsToSelector:aSelector];
//}

@end
