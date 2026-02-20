//
// Created by Abdullah Arif on 7/6/18.
// Copyright (c) 2018 Abdullah Arif. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <GlyphsCore/GSLayer.h>
#import <GlyphsCore/GSGlyph.h>
#import <GlyphsCore/GSPath.h>
#import "LWTimeline.h"
#import "LWPreferences.h"

@interface LWPlayer : NSView {
    CGFloat _handleSize;
    CGFloat _openNodeLineRadius;
    CGColorRef _backgroundCGColor;
    CGColorRef _foregroundStrokeCGColor;
    CGColorRef _foregroundFillCGColor;
    CGColorRef _smoothNodeCGColor;
    CGColorRef _selectedSmoothNodeStrokeCGColor;
    CGColorRef _cornerNodeCGColor;
    CGColorRef _selectedCornerNodeStrokeCGColor;
    CGColorRef _offCurveNodeHandleCGColor;
    CGColorRef _offCurveNodeLineCGColor;
    CGColorRef _metricsCGColor;
    CGColorRef _boundingBoxCGColor;
    CGColorRef _hintsCGColor;
    CGColorRef _anchorsCGColor;
    CGColorRef _guideLinesCGColor;
    CGColorRef _componentsCGolor;
    CGColorRef _selectedComponentsCGColor;
    CGColorRef _selectionCGColor;

    CGFloat _relativeOneWidth;
    CGFloat _clampedLineWidth;
    CGFloat _clampedNodeLineWidth;
    CGFloat _clampedOffCurveLineWidth;
}

@property (weak, nullable) GSLayer *parentGSLayer;
@property (weak, nullable) GSLayer *contextGSLayer;
@property (strong, nullable) LWTimeline *timeline;
@property (getter=isPlaying) BOOL playing;
@property double playheadPosition;
@property NSTimeInterval duration;
@property NSUInteger currentFrame;
@property NSTimeInterval prevFrameTime;
@property NSTimeInterval elapsedTime;
@property (nullable) NSString *elapsedTimeString;
@property NSDateFormatter *frameTimeFormatter;
@property (nullable) NSString *frameTimeString;
@property (nullable) NSTimer *playbackTimer;
@property CGFloat playbackSpeed;
@property NSRect maxRect;

@property (weak, nullable) LWPreferences *prefs;
@property (readonly) CGFloat scaleFactor;

@property (weak, nullable) NSLayoutConstraint *widthConstraint;
@property (weak, nullable) NSLayoutConstraint *heightConstraint;

@property (nullable) NSAffineTransform *transform;
@property (nullable) NSAffineTransform *inverseTransform;


@property BOOL spacePressed;

@property (nullable) NSColor *backgroundColor;
@property (nullable) NSColor *foregroundStrokeColor;
@property (nullable) NSColor *foregroundFillColor;
@property (nullable) NSColor *metricsColor;
@property (nullable) NSColor *guideLinesColor;
@property (nullable) NSColor *hintsColor;
@property (nullable) NSColor *anchorsColor;
@property (nullable) NSColor *componentsColor;
@property (nullable) NSColor *selectedComponentsColor;
@property (nullable) NSColor *selectionColor;
@property (nullable) NSColor *cornerNodeColor;
@property (nullable) NSColor *smoothNodeColor;
@property (nullable) NSColor *offCurveNodeHandleColor;
@property (nullable) NSColor *offCurveNodeLineColor;
@property (nullable) NSColor *boundingBoxColor;
@property (nullable) NSColor *selectedCornerNodeStrokeColor;
@property (nullable) NSColor *selectedSmoothNodeStrokeColor;

- (void)setDrawingContext;

- (void)setScale:(CGFloat)scaleFactor keepCentered:(BOOL)center;
- (void)loadTimeline:(nullable LWTimeline *)aTimeline forLayer:(nullable GSLayer *)aGSLayer;
- (BOOL)isPlaying;
- (void)togglePlay:(BOOL)play;
- (void)play;
- (void)pause;
- (void)movePlayheadTo:(double)position;
- (void)abortPlayback;
- (void)makeCurrentFrameANewLayer;
- (void)makeCurrentFrameBackgroundLayer;
- (void)enqueueFrameForDisplay:(NSUInteger)frameIndex withoutDelay:(BOOL)withoutDelay;
@end
