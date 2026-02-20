//
// Created by Abdullah Arif on 7/6/18.
// Copyright (c) 2018 Abdullah Arif. All rights reserved.
//

#import "LWPlayer.h"
#import "GSLayer+LWTimeline.h"
#import <GlyphsCore/GSGuideLine.h>
#import <GlyphsCore/GSComponent.h>
#import <GlyphsCore/GSAnchor.h>
#import "LWPlayerController.h"
#import "NSColor+LWUtility.h"
#import "LWPlayerSliderCell.h"

static const CGFloat LWBoundingBoxPattern[2] = {2.0, 4.0};
static const CGFloat LWGlyphPaddingWidth = 200.0;
static const CGFloat LWGlyphPaddingHeight = 200.0;
static const CGFloat LWPlayerControlsHeight = 54.0;
static const NSTimeInterval LWTimerFrameInterval = 0.034; // approx 30fps
static NSString *LWElapsedTimeFormat = @"%lu:%02.01f"; // 1:02.5 = 1 minute and 2.5 seconds


@implementation LWPlayer

- (nullable instancetype)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];
	
    if ( self ) {
        _prefs = [LWPreferences sharedPreferences];
        _spacePressed = NO;
        _playing = NO;
        _playheadPosition = 0.0;
        _currentFrame = 0;
        _prevFrameTime = 0.0;
        _elapsedTime = 0.0;
        _duration = LWPlaybackMinDuration;
        _elapsedTimeString = @"0:00.0";
        _scaleFactor = 1.0;
        _playbackTimer = nil;
        _transform = [NSAffineTransform transform];
        _inverseTransform = [NSAffineTransform transform];
        _parentGSLayer = nil;
        _contextGSLayer = nil;
        _maxRect = NSZeroRect;
		_frameTimeString = @"";
		_frameTimeFormatter = [[NSDateFormatter alloc] init];
		[_frameTimeFormatter setDateFormat:@"MMM d, ’YY HH:mm:ss"]; // Jun 8, ’18 16:31:13
        _playbackSpeed = 1.0;

        [self setDrawingContext];
    }

    return self;
}

- (void)loadTimeline:(LWTimeline *)aTimeline forLayer:(GSLayer *)aGSLayer {
    if ( aTimeline != self.timeline ) {
        [self abortPlayback];
        self.parentGSLayer = aGSLayer;
        [aTimeline prepareTimelineForPlaybackInParentLayer:self.parentGSLayer];
        self.maxRect = [aTimeline maxGlyphExtents];
        GSLayer* firstFrame = [aTimeline firstFrame];
        GSGlyphMetrics metrics = firstFrame ? firstFrame.glyphMetrics : self.parentGSLayer.glyphMetrics;
        [self fitGlyphMetrics:metrics];
        [self centerGlyphMetrics:metrics];
    }

    self.timeline = aTimeline;
}

#pragma mark - Drawing & Layout 🎨
#pragma mark -

- (void)setDrawingContext {
    BOOL inverted = self.prefs.invertedColors;

    _handleSize = 5.0 + self.prefs.handleSize * 2.5;
    _openNodeLineRadius = 8.0;

    CGColorRelease(_backgroundCGColor);
    self.backgroundColor = [self.prefs.backgroundColor lw_inverted:inverted];
    _backgroundCGColor = CGColorRetain(self.backgroundColor.CGColor);

    CGColorRelease(_foregroundStrokeCGColor);
    self.foregroundStrokeColor = [[self.prefs.foregroundStrokeColor colorWithAlphaComponent:0.6] lw_inverted:inverted];
    _foregroundStrokeCGColor = CGColorRetain(self.foregroundStrokeColor.CGColor);

    CGColorRelease(_foregroundFillCGColor);
    self.foregroundFillColor = [self.prefs.foregroundStrokeColor lw_inverted:inverted];
    _foregroundFillCGColor = CGColorRetain(self.foregroundFillColor.CGColor);

    CGColorRelease(_metricsCGColor);
    self.metricsColor = [self.prefs.zonesColor lw_inverted:inverted];
    _metricsCGColor = CGColorRetain(self.metricsColor.CGColor);

    CGColorRelease(_guideLinesCGColor);
    self.guideLinesColor = [[NSColor colorWithCalibratedRed:0.788 green:0.812 blue:0.953 alpha:1.00] lw_inverted:inverted];
    _guideLinesCGColor = CGColorRetain(self.guideLinesColor.CGColor);

    CGColorRelease(_componentsCGolor);
    self.componentsColor = [[NSColor colorWithCalibratedRed:0 green:0 blue:0 alpha:0.4] lw_inverted:inverted];
    _componentsCGolor = CGColorRetain(self.componentsColor.CGColor);

    CGColorRelease(_selectedComponentsCGColor);
    self.selectedComponentsColor = [self.componentsColor colorWithAlphaComponent:0.6];
    _selectedComponentsCGColor = CGColorRetain(self.selectedComponentsColor.CGColor);

    CGColorRelease(_selectionCGColor);
    self.selectionColor = [[self.prefs.cornerNodeColor colorWithAlphaComponent:0.6] lw_inverted:inverted];
    _selectionCGColor = CGColorRetain(self.selectionColor.CGColor);

    CGColorRelease(_offCurveNodeHandleCGColor);
    self.offCurveNodeHandleColor = [[NSColor colorWithCalibratedRed:0.043 green:0.043 blue:0.043 alpha:0.60] lw_inverted:inverted];
    _offCurveNodeHandleCGColor = CGColorRetain(self.offCurveNodeHandleColor.CGColor);

    CGColorRelease(_offCurveNodeLineCGColor);
    self.offCurveNodeLineColor = [[NSColor colorWithCalibratedRed:0.573 green:0.573 blue:0.573 alpha:1.00] lw_inverted:inverted];
    _offCurveNodeLineCGColor = CGColorRetain(self.offCurveNodeLineColor.CGColor);

    CGColorRelease(_boundingBoxCGColor);
    self.boundingBoxColor = [[NSColor colorWithCalibratedRed:0.643 green:0.643 blue:0.643 alpha:1.00] lw_inverted:inverted];
	_boundingBoxCGColor = CGColorRetain(self.boundingBoxColor.CGColor);

    CGColorRelease(_cornerNodeCGColor);
    self.cornerNodeColor = [self.prefs.cornerNodeColor lw_inverted:inverted];
    _cornerNodeCGColor = CGColorRetain(self.cornerNodeColor.CGColor);

    CGColorRelease(_selectedCornerNodeStrokeCGColor);
    self.selectedCornerNodeStrokeColor = [[self.prefs.cornerNodeColor shadowWithLevel:0.2] lw_inverted:inverted];
    _selectedCornerNodeStrokeCGColor = CGColorRetain(self.selectedCornerNodeStrokeColor.CGColor);

    CGColorRelease(_smoothNodeCGColor);
    self.smoothNodeColor = [self.prefs.smoothNodeColor lw_inverted:inverted];
    _smoothNodeCGColor = CGColorRetain(self.smoothNodeColor.CGColor);

    CGColorRelease(_selectedSmoothNodeStrokeCGColor);
    self.selectedSmoothNodeStrokeColor = [[self.prefs.smoothNodeColor shadowWithLevel:0.2] lw_inverted:inverted];
    _selectedSmoothNodeStrokeCGColor = CGColorRetain(self.selectedSmoothNodeStrokeColor.CGColor);

    CGColorRelease(_hintsCGColor);
    self.hintsColor = [[[NSColor yellowColor] colorWithAlphaComponent:0.6] lw_inverted:inverted];
    _hintsCGColor = CGColorRetain(self.hintsColor.CGColor);

    CGColorRelease(_anchorsCGColor);
    self.anchorsColor = [[NSColor colorWithDeviceRed:0.76 green:0.53 blue:0.45 alpha:1.0] lw_inverted:inverted];
    _anchorsCGColor = CGColorRetain(self.anchorsColor.CGColor);
}

/*
 * Use this to set _scaleFactor because it adjusts the frame and center accordingly
 */
- (void)setScale:(CGFloat)aScaleFactor keepCentered:(BOOL)center {
    _scaleFactor = fmin(fmax(0.02, aScaleFactor), 80.0); // min 2.0%, max 8,000%

    NSRect unscaledVisibleRect = [self enclosingScrollView].documentVisibleRect; //if larger than docRect must account
    CGFloat unscaledWidth = self.widthConstraint.constant;
    CGFloat unscaledHeight = self.heightConstraint.constant;

    [self setSizeWithScale:_scaleFactor];

    /* Maintain center point */
    if ( !center ) {
        return;
    }

    CGFloat deltaX = (self.widthConstraint.constant - unscaledWidth) * 0.5;
    CGFloat deltaY = (self.heightConstraint.constant - unscaledHeight) * 0.5;

    // NSClipView bounds start at top-left, and this sets the bounds to the point, not sure
    [self scrollPoint:NSMakePoint(unscaledVisibleRect.origin.x + deltaX, unscaledVisibleRect.origin.y - deltaY)];
}

- (void)setSizeWithScale:(CGFloat)aScale {
    NSSize scaledCanvasSize = NSMakeSize(
            (self.maxRect.size.width + LWGlyphPaddingWidth*2.0)*aScale,
            (self.maxRect.size.height + LWGlyphPaddingHeight*2.0)*aScale
    );

    /*
     * A glyph's coordinate system is defined by a Cartesian plane where 0,0 defines the baseline
     * All drawing is relative to that point.
     * But glyphs have a descender, and to render it on NSView we must
     * offset vertically by the max +descender value.
     * We also want to center vertically and horizontally the glyph box within the player's viewport.
     */
    CGFloat dX = (-self.maxRect.origin.x + LWGlyphPaddingWidth) * aScale;
    CGFloat dY = (-self.maxRect.origin.y + LWGlyphPaddingHeight) * aScale;

    // This transform will be applied every single time we draw
    self.transform = [NSAffineTransform transform];
    [self.transform translateXBy:dX yBy:dY];
    [self.transform scaleBy:aScale];

    // For dirtyRect calculations
    self.inverseTransform = [self.transform copy];
    [self.inverseTransform invert];

    // Drawing line widths
    CGFloat relativeHalf = 0.5/self.scaleFactor;
    _relativeOneWidth = 1.0/self.scaleFactor;
    _clampedLineWidth = !self.prefs.scaleStrokes ? _relativeOneWidth : self.scaleFactor <= 0.25 ? relativeHalf : fmax(_relativeOneWidth, fmin(ceil(self.scaleFactor * 100.0) / 100.0, 10.0));
    _clampedNodeLineWidth =  !self.prefs.scaleStrokes ? _relativeOneWidth : self.scaleFactor <= 0.25 ? relativeHalf: _clampedLineWidth > 3.0 ? _clampedLineWidth * 0.25 : _clampedLineWidth;
    _clampedNodeLineWidth = fmax(_clampedNodeLineWidth, relativeHalf);
    _clampedOffCurveLineWidth = _clampedLineWidth > 3.0 ? _clampedNodeLineWidth*0.5 : _relativeOneWidth;
    _clampedOffCurveLineWidth = fmax(_clampedOffCurveLineWidth, relativeHalf) * 0.75;
    
    [self.widthConstraint setConstant:scaledCanvasSize.width];
    [self.heightConstraint setConstant:scaledCanvasSize.height];
    [self setNeedsUpdateConstraints:YES];
    [self setNeedsDisplay:YES];
}

- (void)fitGlyphMetrics:(GSGlyphMetrics)metrics {
    /*
     * The fit rect is only used to determine the minimum document size
     * The actual document will be much bigger, accounting for maxRect & additional padding.
     * This is a box which is slightly wider & taller than the glyph box.
     */
    NSRect fitThisRect = NSMakeRect(0.0, 0.0, metrics.width + LWGlyphPaddingWidth*2, (-metrics.descender + metrics.ascender)*1.3);
    CGFloat defaultScaleRatio = 1.0;
    NSRect contentRect = [self enclosingScrollView].frame;

    if ( !NSContainsRect(contentRect, fitThisRect) ) {
        defaultScaleRatio = contentRect.size.height / fitThisRect.size.height;
    }

    [self setScale:defaultScaleRatio keepCentered:NO];
}

- (void)centerGlyphMetrics:(GSGlyphMetrics)metrics {
    CGFloat scaledGlyphWidth = metrics.width * _scaleFactor;
    CGFloat scaledLeftPadding = (-self.maxRect.origin.x + LWGlyphPaddingWidth) * _scaleFactor;
    CGFloat scaledBottomPadding = (-self.maxRect.origin.y + LWGlyphPaddingHeight) * _scaleFactor;
    CGFloat availableVisibleMarginAroundGlyph = [self enclosingScrollView].frame.size.width-scaledGlyphWidth;
    NSRect scrollRect = NSMakeRect(
            scaledLeftPadding - (availableVisibleMarginAroundGlyph < 0 ? 0 : availableVisibleMarginAroundGlyph) * 0.5,
            scaledBottomPadding - LWPlayerControlsHeight*1.5,
            scaledGlyphWidth + availableVisibleMarginAroundGlyph,
            10.0
    );

    dispatch_async(dispatch_get_main_queue(), ^{
        [self scrollRectToVisible:scrollRect];
    });
}

- (void)drawRect:(NSRect)dirtyRect {
    if ( !self.contextGSLayer ) {
        [[NSGraphicsContext currentContext] saveGraphicsState];
        [self.transform concat];
        NSDictionary *attribs = @{
                NSForegroundColorAttributeName : self.foregroundStrokeColor,
                NSFontAttributeName: [NSFont systemFontOfSize:19.0 weight:NSFontWeightLight]
        };
        NSString *loading = @"Loading 🐳";
        NSSize loadingSize = [loading sizeWithAttributes:attribs];
        [loading drawAtPoint:NSMakePoint(self.widthConstraint.constant*0.5-loadingSize.width*0.5,self.heightConstraint.constant*0.5-loadingSize.height*0.5) withAttributes:attribs];
        [[NSGraphicsContext currentContext] restoreGraphicsState];
        return;
    }

	BOOL fillOutline = self.prefs.fillOutline != self.spacePressed;  // xor

    NSRect glyphSpaceDirtyRect;
    glyphSpaceDirtyRect.origin = [self.inverseTransform transformPoint:dirtyRect.origin];
    glyphSpaceDirtyRect.size = [self.inverseTransform transformSize:dirtyRect.size];


    NSGraphicsContext *ctx = [NSGraphicsContext currentContext];
    CGContextRef ctxRef = ctx.CGContext;
    CGContextSaveGState(ctxRef);
    [self.transform concat];

    //CFTimeInterval startOthersTime = CACurrentMediaTime();
    
    /*
     * METRICS
     * Glyphs draw metric lines with a transparency.
     */

    CGFloat glyphWidth = self.contextGSLayer.width;

    if ( self.prefs.showMetrics ) {
        GSGlyphMetrics metrics = self.parentGSLayer.glyphMetrics;
        CGContextBeginPath(ctxRef);

        // Body
        CGContextMoveToPoint(ctxRef, 0, metrics.descender);
        CGContextAddLineToPoint(ctxRef, glyphWidth, metrics.descender);
        CGContextAddLineToPoint(ctxRef, glyphWidth, metrics.ascender);
        CGContextAddLineToPoint(ctxRef, 0, metrics.ascender);
        CGContextAddLineToPoint(ctxRef, 0, metrics.descender);

        // Baseline
        CGContextMoveToPoint(ctxRef, 0, 0);
        CGContextAddLineToPoint(ctxRef, glyphWidth, 0);

        // xHeight
        CGContextMoveToPoint(ctxRef, 0, metrics.xHeight);
        CGContextAddLineToPoint(ctxRef, glyphWidth, metrics.xHeight);

        // capHeight
        CGContextMoveToPoint(ctxRef, 0, metrics.capHeight);
        CGContextAddLineToPoint(ctxRef, glyphWidth, metrics.capHeight);

        CGContextSetStrokeColorWithColor(ctxRef, _metricsCGColor);
        CGContextSetLineWidth(ctxRef, _relativeOneWidth);
        CGContextStrokePath(ctxRef);
    }

     /*
      * GUIDELINES
      * y = mx + b
      * we have x, y, angle
      * the slope, m = tan(angle) only if angle is not multiples of 90
      * if angle / 90 is odd, line is vertical
      * if angle / 90 is even, line is horizontal
      */
     if ( self.prefs.showGuideLines ) {
         CGContextBeginPath(ctxRef);
         
         for ( GSGuideLine *guideline in self.contextGSLayer.guideLines ) {
             NSPoint beginPoint = [guideline beginPointForLayerWidth:glyphWidth];
             NSPoint endPoint = [guideline endPointForLayerWidth:glyphWidth];

             NSRect guideLineBounds = NSMakeRect(
                     fmin(beginPoint.x, endPoint.x),
                     fmin(beginPoint.y, endPoint.y),
                     fmax(_relativeOneWidth, fabs(beginPoint.x - endPoint.x)),
                     fmax(_relativeOneWidth, fabs(beginPoint.y - endPoint.y))
             );

             if ( NSIntersectsRect(guideLineBounds, glyphSpaceDirtyRect) ) {
                 CGContextMoveToPoint(ctxRef, beginPoint.x, beginPoint.y);
                 CGContextAddLineToPoint(ctxRef, endPoint.x, endPoint.y);
             }
         }

         CGContextSetStrokeColorWithColor(ctxRef, _guideLinesCGColor);
         CGContextSetLineWidth(ctxRef, _relativeOneWidth);
         CGContextStrokePath(ctxRef);
     }

    /*
     * COMPONENTS
     * Components are drawn with the latest information from the corresponding master layer.
     * todo: make CGContext
     */
    if ( [self.contextGSLayer countOfComponents] ) {
        [self.componentsColor set];
        for (GSComponent *component in self.contextGSLayer.components) {
            NSBezierPath *compBezierPath = [component bezierPath];
            if (compBezierPath && ![compBezierPath isEmpty]) {
                NSRect bezBounds = [compBezierPath bounds];
                if (!NSEqualRects(bezBounds, NSZeroRect) && NSIntersectsRect(bezBounds, glyphSpaceDirtyRect)) {
                    [compBezierPath fill];
                }
            }

            NSBezierPath *compOpenBezierPath = [component openBezierPath];
            if (compOpenBezierPath && ![compOpenBezierPath isEmpty]) {
                NSRect openBounds = [compOpenBezierPath bounds];
                if (!NSEqualRects(openBounds, NSZeroRect) && NSIntersectsRect(openBounds, glyphSpaceDirtyRect)) {
                    [compOpenBezierPath setLineWidth:_clampedLineWidth];
                    [compOpenBezierPath setLineJoinStyle:NSRoundLineJoinStyle];
                    [compOpenBezierPath stroke];
                }
            }
        }
    }

    NSArray <GSPath *> *paths = self.contextGSLayer.paths;
    NSArray <LWCGPathContainer *> *CGPaths = [self.contextGSLayer lw_CGPaths];

    NSUInteger pathIndex = 0;
    CGMutablePathRef openPath = CGPathCreateMutable();
    CGMutablePathRef closedPath = CGPathCreateMutable();

	// todo check if visiblerect encompasses glyph bounds and render in one shot instead
    // Collect ought-to-be rendered glyph paths
    for ( GSPath* path in paths ) {
        LWCGPathContainer *pathContainer = CGPaths[pathIndex];
        NSRect bounds = pathContainer.bounds;
        NSRect strokeAdjustedBounds = NSMakeRect(
                bounds.origin.x - _clampedLineWidth*0.5,
                bounds.origin.y - _clampedLineWidth*0.5,
                bounds.size.width + _clampedLineWidth,
                bounds.size.height + _clampedLineWidth
        );

        if ( !NSIntersectsRect(strokeAdjustedBounds, glyphSpaceDirtyRect) ) {
            pathIndex++;
            continue;
        }

        CGPathAddPath(path.closed ? closedPath : openPath, NULL, pathContainer.CGPath);
        pathIndex++;
    }

    CGContextSetLineJoin(ctxRef, kCGLineJoinRound);

    CGContextBeginPath(ctxRef);
    CGContextAddPath(ctxRef, closedPath);
    if ( fillOutline ) {
        CGContextSetFillColorWithColor(ctxRef, _foregroundFillCGColor);
        CGContextFillPath(ctxRef);
    } else {
        CGContextSetLineWidth(ctxRef, _clampedLineWidth);
        CGContextSetStrokeColorWithColor(ctxRef, _foregroundStrokeCGColor);
        CGContextStrokePath(ctxRef);
    }
    CGPathRelease(closedPath);

    // openBezierPath
    CGContextBeginPath(ctxRef);
    CGContextAddPath(ctxRef, openPath);
    CGContextSetLineWidth(ctxRef, _clampedLineWidth);
    CGContextSetStrokeColorWithColor(ctxRef, _foregroundStrokeCGColor);
    CGContextStrokePath(ctxRef);
    CGPathRelease(openPath);
    
    CGContextSetLineJoin(ctxRef, kCGLineJoinMiter);

    /*
     * SELECTION PATH
     * todo: move this into the path drawing section
     */
    if ( self.prefs.showSelection ) {
        NSBezierPath *selectionPath = self.contextGSLayer.selectionPath;

        if ( selectionPath && ![selectionPath isEmpty] ) {
            CGFloat selectionLineWidth = _clampedLineWidth*2.0;
            NSRect selectionBounds = [selectionPath bounds];
            NSRect strokeAdjustedSelectionBounds = NSMakeRect(
                    selectionBounds.origin.x - selectionLineWidth*0.5,
                    selectionBounds.origin.y - selectionLineWidth*0.5,
                    selectionBounds.size.width + selectionLineWidth,
                    selectionBounds.size.height + selectionLineWidth
            );

            if ( NSIntersectsRect(strokeAdjustedSelectionBounds, glyphSpaceDirtyRect) ) {
                [self.selectionColor setStroke];
                [selectionPath setLineWidth:selectionLineWidth];
                [selectionPath setLineJoinStyle:NSRoundLineJoinStyle];
                [selectionPath stroke];
            }
        }
    }

    //CFTimeInterval endOthersTime = CACurrentMediaTime();
    //NSLog(@"others time %f", endOthersTime - startOthersTime);

    /*
     * NODES
     */
    if ( self.prefs.showNodes && !self.spacePressed ) {
        //CFTimeInterval startNodeTime = CACurrentMediaTime();
        CGMutablePathRef offCurveNodes = CGPathCreateMutable();
        CGMutablePathRef selectedOffCurveNodes = CGPathCreateMutable();
        CGMutablePathRef offCurveNodeLinePath = CGPathCreateMutable();
        CGMutablePathRef openNodes = CGPathCreateMutable();
        CGMutablePathRef selectedOpenNodes = CGPathCreateMutable();
        CGMutablePathRef cornerNodes = CGPathCreateMutable();
        CGMutablePathRef selectedCornerNodes = CGPathCreateMutable();
        CGMutablePathRef smoothNodes = CGPathCreateMutable();
        CGMutablePathRef selectedSmoothNodes = CGPathCreateMutable();
        CGMutablePathRef anchorsPaths = CGPathCreateMutable();

        if ( [self.contextGSLayer countOfAnchors] ) {
            NSDictionary<NSString *, GSAnchor *> *anchors = self.contextGSLayer.anchors;
            for ( NSString *anchorName in anchors ) {
                GSAnchor *anchor =  anchors[ anchorName ];
                NSRect anchorBounds = NSMakeRect(
                        anchor.position.x - _handleSize*0.5,
                        anchor.position.y - _handleSize*0.5,
                        _handleSize,
                        _handleSize
                );

                if ( !NSIntersectsRect(anchorBounds, glyphSpaceDirtyRect) ) {
                    continue;
                }

                CGPathAddEllipseInRect(anchorsPaths, NULL, anchorBounds);
            }
        }


        // todo: in the future could pre-render all nodes into an array of cgpaths
        for (GSPath *path in paths) {
            GSNode *openStartNode, *openEndNode;

            /*
             * Collect open path handles (TANGENTS) at once for every open path
             */
            if (!path.closed) {
                openStartNode = [path startNode];
                openEndNode = [path endNode];
                // todo draw path direction for open paths
                if (openStartNode != openEndNode) {
                    for (GSNode *oNode in @[openStartNode, openEndNode]) {
                        NSRect openNodeLineBounds = NSMakeRect(
                                oNode.position.x -_openNodeLineRadius,
                                oNode.position.y - _openNodeLineRadius,
                                _openNodeLineRadius * 2.0,
                                _openNodeLineRadius * 2.0
                        );
                        if ( !NSIntersectsRect(openNodeLineBounds, glyphSpaceDirtyRect) ) {
                            continue;
                        }

                        CGFloat tangentAngle = [path tangentAngleAtNode:oNode direction:oNode == openStartNode ? 1 : -1];
                        BOOL selectedOpenNode = self.prefs.showSelection && [self.contextGSLayer.selection containsObject:oNode];

                        CGPathMoveToPoint(selectedOpenNode ? selectedOpenNodes : openNodes, NULL,
                                oNode.position.x + (cos((tangentAngle + 90.0) / 180 * M_PI) * _openNodeLineRadius),
                                oNode.position.y + (sin((tangentAngle + 90.0) / 180 * M_PI) * _openNodeLineRadius)
                        );
                        CGPathAddLineToPoint(selectedOpenNode ? selectedOpenNodes : openNodes, NULL,
                                oNode.position.x + (cos((tangentAngle - 90.0) / 180 * M_PI) * _openNodeLineRadius),
                                oNode.position.y + (sin((tangentAngle - 90.0) / 180 * M_PI) * _openNodeLineRadius)
                        );
                    }
                }
            }

            GSNode *actualStartNode = [path findStartNode];
            BOOL hasQuadraticCurves = [path hasTrueTypeCurve];
            NSInteger nodeIndex = -1;
            for (GSNode *node in path.nodes) {
                nodeIndex++;
                NSPoint nodePosition = node.position;
                GSNode *nextNode = [path nodeAtIndex:nodeIndex + 1];
                NSPoint nextNodePosition = nextNode.position;
                GSNodeType nodeType = node.type;

                /*
                 * Collect lines connecting OFFCURVE nodes
                 */
                if (nextNode) {
                    if ((nodeType != OFFCURVE && nextNode.type == OFFCURVE) ||
                            (nodeType == OFFCURVE && nextNode.type != OFFCURVE) ||
                            (hasQuadraticCurves && nextNode.type == OFFCURVE)) {

                        NSRect offCurveNodeLineBounds = NSMakeRect(
                                fmin(nodePosition.x, nextNodePosition.x),
                                fmin(nodePosition.y, nextNodePosition.y),
                                fmax(_clampedOffCurveLineWidth, fabs(nodePosition.x - nextNodePosition.x)),
                                fmax(_clampedOffCurveLineWidth, fabs(nodePosition.y - nextNodePosition.y))
                        );

                        if (NSIntersectsRect(offCurveNodeLineBounds, glyphSpaceDirtyRect)) {
                            CGPathMoveToPoint(offCurveNodeLinePath, NULL, nodePosition.x, nodePosition.y);
                            CGPathAddLineToPoint(offCurveNodeLinePath, NULL, nextNodePosition.x, nextNodePosition.y);
                        }
                    }
                }

                // We've handled these before, skip
                if ((node == openStartNode || node == openEndNode) && openStartNode != openEndNode) {
                    continue;
                }

                // Maximum possible nodeRect, enlarged as if selected & stroked
                NSRect nodeBounds = NSMakeRect(
                        nodePosition.x - _handleSize - _clampedNodeLineWidth * 0.5,
                        nodePosition.y - _handleSize - _clampedNodeLineWidth * 0.5,
                        _handleSize * 1.75 + _clampedNodeLineWidth,
                        _handleSize * 1.75 + _clampedNodeLineWidth);

                /*
                 * nodeBounds is biggest possible nodeRect, which is bigger than handleRect
                 * So this one hit test is sufficient to tell us whether the node should be rendered
                 */
                if (!NSIntersectsRect(nodeBounds, glyphSpaceDirtyRect)) {
                    continue;
                }

                CGFloat scaleCorrectedHandleSize = _handleSize + _clampedLineWidth;
                BOOL nodeIsSelected = NO;
                if (self.prefs.showSelection && [self.contextGSLayer.selection containsObject:node]) {
                    nodeIsSelected = YES;
                    scaleCorrectedHandleSize *= 1.75;
                }

                if (nodeType == OFFCURVE) {
                    CGFloat controlPointSize = scaleCorrectedHandleSize - _clampedNodeLineWidth * 2.0;
                    NSRect handleRect = NSMakeRect(nodePosition.x - controlPointSize * 0.5, nodePosition.y - controlPointSize * 0.5, controlPointSize, controlPointSize);
                    CGPathAddEllipseInRect(nodeIsSelected ? selectedOffCurveNodes : offCurveNodes, NULL, handleRect);
                    continue;
                }

                NSRect nodeRect = NSMakeRect(nodePosition.x - scaleCorrectedHandleSize * 0.5, nodePosition.y - scaleCorrectedHandleSize * 0.5, scaleCorrectedHandleSize, scaleCorrectedHandleSize);
                GSNodeType nodeConnection = node.connection;

                /*
                 * Collect SMOOTH and SHARP nodes
                 */
                if (node == actualStartNode && nextNode) {
                    // Draw right triangle in rect & then orient towards next node
                    CGMutablePathRef startNodePath = CGPathCreateMutable();
                    CGPathMoveToPoint(startNodePath, NULL, NSMinX(nodeRect), NSMinY(nodeRect)); // bl
                    CGPathAddLineToPoint(startNodePath, NULL, NSMinX(nodeRect), NSMaxY(nodeRect)); // tl
                    CGPathAddLineToPoint(startNodePath, NULL, NSMaxX(nodeRect) + nodeRect.size.width / 3.0, NSMidY(nodeRect)); // triangle head
                    CGPathAddLineToPoint(startNodePath, NULL, NSMinX(nodeRect), NSMinY(nodeRect));  // back to bl
                    CGPathCloseSubpath(startNodePath);

                    CGAffineTransform orient = CGAffineTransformTranslate(CGAffineTransformIdentity, nodePosition.x, nodePosition.y);
                    orient = CGAffineTransformRotate(orient, (M_PI * [path tangentAngleAtNode:node direction:1]) / 180);
                    orient = CGAffineTransformTranslate(orient, -nodePosition.x, -nodePosition.y);

                    if (nodeConnection == SMOOTH) {
                        CGPathAddPath(nodeIsSelected ? selectedSmoothNodes : smoothNodes, &orient, startNodePath);
                    } else if (nodeConnection == SHARP) {
                        CGPathAddPath(nodeIsSelected ? selectedCornerNodes : cornerNodes, &orient, startNodePath);
                    }

                    CGPathRelease(startNodePath);
                } else {
                    if (nodeConnection == SMOOTH) {
                        CGPathAddEllipseInRect(nodeIsSelected ? selectedSmoothNodes : smoothNodes, NULL, nodeRect);
                    } else if (nodeConnection == SHARP) {
                        CGPathAddRect(nodeIsSelected ? selectedCornerNodes : cornerNodes, NULL, nodeRect);
                    }
                }
            }
        }

        CGContextSetLineWidth(ctxRef, _clampedOffCurveLineWidth);
        CGContextSetLineCap(ctxRef, kCGLineCapRound);
        // OFFCURVE LINES
        CGContextBeginPath(ctxRef);
        CGContextAddPath(ctxRef, offCurveNodeLinePath);
        CGContextSetStrokeColorWithColor(ctxRef, _offCurveNodeLineCGColor);
        CGContextStrokePath(ctxRef);
        CGPathRelease(offCurveNodeLinePath);

        CGContextSetLineCap(ctxRef, kCGLineCapButt);

        // OFFCURVE (selected)
        CGContextBeginPath(ctxRef);
        CGContextAddPath(ctxRef, selectedOffCurveNodes);
        CGContextSetFillColorWithColor(ctxRef, _offCurveNodeHandleCGColor);
        CGContextFillPath(ctxRef);
        CGPathRelease(selectedOffCurveNodes);

        // OFFCURVE
        CGContextBeginPath(ctxRef);
        CGContextAddPath(ctxRef, offCurveNodes);
        CGContextSetStrokeColorWithColor(ctxRef, _offCurveNodeHandleCGColor);
        CGContextStrokePath(ctxRef);
        CGPathRelease(offCurveNodes);

        CGContextSetStrokeColorWithColor(ctxRef, _cornerNodeCGColor);
        // OPEN NODES
        CGContextBeginPath(ctxRef);
        CGContextAddPath(ctxRef, openNodes);
        CGContextSetLineWidth(ctxRef, _clampedNodeLineWidth * 1.5);
        CGContextStrokePath(ctxRef);
        CGPathRelease(openNodes);

        // OPEN NODES (selected)
        CGContextBeginPath(ctxRef);
        CGContextAddPath(ctxRef, selectedOpenNodes);
        CGContextSetLineWidth(ctxRef, _clampedNodeLineWidth * 3.0);
        CGContextStrokePath(ctxRef);
        CGPathRelease(selectedOpenNodes);

        CGContextSetLineWidth(ctxRef, _clampedNodeLineWidth);
        CGContextSetLineJoin(ctxRef, kCGLineJoinRound);

        // CORNER (selected)
        CGContextBeginPath(ctxRef);
        CGContextAddPath(ctxRef, selectedCornerNodes);
        CGContextSetFillColorWithColor(ctxRef, _cornerNodeCGColor);
        CGContextSetStrokeColorWithColor(ctxRef, _selectedCornerNodeStrokeCGColor);
        CGContextDrawPath(ctxRef, kCGPathFillStroke);
        CGPathRelease(selectedCornerNodes);

        // CORNER
        CGContextBeginPath(ctxRef);
        CGContextAddPath(ctxRef, cornerNodes);
        CGContextSetStrokeColorWithColor(ctxRef, _cornerNodeCGColor);
        CGContextStrokePath(ctxRef);
        CGPathRelease(cornerNodes);

        // SMOOTH (selected)
        CGContextBeginPath(ctxRef);
        CGContextAddPath(ctxRef, selectedSmoothNodes);
        CGContextSetFillColorWithColor(ctxRef, _smoothNodeCGColor);
        CGContextSetStrokeColorWithColor(ctxRef, _selectedSmoothNodeStrokeCGColor);
        CGContextDrawPath(ctxRef, kCGPathFillStroke);
        CGPathRelease(selectedSmoothNodes);

        // SMOOTH
        CGContextBeginPath(ctxRef);
        CGContextAddPath(ctxRef, smoothNodes);
        CGContextSetStrokeColorWithColor(ctxRef, _smoothNodeCGColor);
        CGContextStrokePath(ctxRef);
        CGPathRelease(smoothNodes);

        // ANCHORS
        CGContextBeginPath(ctxRef);
        CGContextAddPath(ctxRef, anchorsPaths);
        CGContextSetFillColorWithColor(ctxRef, _anchorsCGColor);
        CGContextFillPath(ctxRef);
        CGPathRelease(anchorsPaths);

        //CFTimeInterval endNodeTime = CACurrentMediaTime();
        //NSLog(@"node render time %f", endNodeTime - startNodeTime);
    }

    /*
     * BOUNDING BOX
     */
    if ( self.prefs.showBoundingBox ) {
        NSRect allSelectionBounds = [self.contextGSLayer boundsOfSelection];

        // todo proper intersections e.g. individual sides(maybe too expensive)
        if ( !NSEqualRects(allSelectionBounds, NSZeroRect) && NSIntersectsRect(allSelectionBounds, glyphSpaceDirtyRect) ) {
            CGContextSaveGState(ctxRef);
            CGContextSetStrokeColorWithColor(ctxRef, _boundingBoxCGColor);
            CGContextSetLineDash(ctxRef, 0.0, LWBoundingBoxPattern, 2);
            CGContextSetLineJoin(ctxRef, kCGLineJoinBevel);
            CGContextSetLineWidth(ctxRef, _relativeOneWidth);
            CGContextStrokeRect(ctxRef, allSelectionBounds);
            CGContextRestoreGState(ctxRef);
        }
    }

    CGContextRestoreGState(ctxRef);
}

#pragma mark - Controls  🎮
#pragma mark -

- (void)togglePlay:(BOOL)play {
	if ( play ) {
		[self play];
	} else {
		[self pause];
	}
}

- (void)play {
	LWPlayerController *controller = (LWPlayerController *)self.window.windowController;
	[controller.statusField setStringValue:@""];
	self.playing = YES;
    [self.timeline prepareTimelineForPlaybackInParentLayer:self.parentGSLayer];
	self.duration = [self.timeline duration];
	NSRect extents = [self.timeline maxGlyphExtents];

	// Alt-option click on the play bar will increment/decrement by 1 frame
    NSSlider *slider = controller.playBar;
    [slider setAltIncrementValue:slider.maxValue / ([self.timeline frameCount] * 1.0)];

	if ( !NSEqualRects(extents, self.maxRect) ) {
	    self.maxRect = extents;
        [self setSizeWithScale:self.scaleFactor];
    }
	
	// Populate checkpoints
	NSMutableArray *checkpoints = [self.timeline checkpoints];
	LWPlayerSliderCell *sliderCell = (LWPlayerSliderCell *)[slider cell];
	NSInteger numCheckpoints = [checkpoints count];
	[sliderCell setNumberOfTickMarks:numCheckpoints < 1 ? 1 : numCheckpoints]; // force at least 1 to maintain slider knob styling
	[sliderCell setTickMarkPosition:NSTickMarkPositionAbove];
	[sliderCell setAllowsTickMarkValuesOnly:NO];
    [sliderCell setCheckpoints:checkpoints];



    // If we're at end of playback, restart at 0.
	NSUInteger nextFrame = self.currentFrame >= [self.timeline.frames count] - 1 ? 0 : self.currentFrame;
	
	[self enqueueFrameForDisplay:nextFrame withoutDelay:YES];
}

- (void)pause {
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	
	if ( self.playbackTimer.isValid ) {
		[self.playbackTimer invalidate];
	}
	
	self.playbackTimer = nil;
	self.playing = NO;
	self.prevFrameTime = 0.0;
}

- (void)movePlayheadTo:(double)position {
	if ( self.isPlaying ) {
		[NSObject cancelPreviousPerformRequestsWithTarget:self];
	}

    [self.timeline prepareTimelineForPlaybackInParentLayer:self.parentGSLayer];
	[self enqueueFrameForDisplay:[self frameNumberFromPlayheadPosition:position] withoutDelay:YES];
}

- (void)makeCurrentFrameANewLayer {

    GSLayer* currentLayerCopy = [self currentFrameAsLayer];

    if ( !currentLayerCopy ) {
        return;
    }

    [self.parentGSLayer.glyph setLayer:currentLayerCopy forKey:currentLayerCopy.layerId];
}

- (void)makeCurrentFrameBackgroundLayer {

    GSLayer* currentLayerCopy = [self currentFrameAsLayer];

    if ( !currentLayerCopy ) {
        return;
    }

    [self.parentGSLayer setBackground:currentLayerCopy];
}

- (GSLayer *)currentFrameAsLayer {
    if ( !self.parentGSLayer || !self.contextGSLayer ) {
        return nil;
    }

    [[self.parentGSLayer undoManager] disableUndoRegistration];

    GSLayer *currentLayerCopy = [self.contextGSLayer copy];

    NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"MMM d YY, HH:mm:ss"]; // Jun 8 18, 16:31:13

    NSDate* frameDate = [NSDate dateWithTimeIntervalSince1970:[(NSNumber *)[currentLayerCopy userDataForKey:LWUserDataKeyEditTime] doubleValue]];

    [currentLayerCopy setLayerId:[[NSUUID UUID] UUIDString]];
    [currentLayerCopy setName:[dateFormatter stringFromDate:frameDate]];
    [currentLayerCopy clearSelection];

    [[self.parentGSLayer undoManager] enableUndoRegistration];

    return currentLayerCopy;
}

#pragma mark -

- (void)magnifyWithEvent:(NSEvent *)event {
    [self setScale:self.scaleFactor * exp(event.magnification) keepCentered:YES];
}

- (void)mouseUp:(NSEvent *)event {
    if ( [event clickCount] == 2 && ![(LWPlayerController *)self.window.windowController mouseInPlayerControls] ) {
        [self.window toggleFullScreen:self];
    }
}

#pragma mark - Playback  ⏯️
#pragma mark -

- (void)didReachEndOfPlayback {
    [self pause];
    self.currentFrame = [self.timeline.frames count] - 1;
	self.playheadPosition = 100.0;
}

- (void)abortPlayback {
    [self pause];
    self.contextGSLayer = nil;
    self.currentFrame = 0;
    self.prevFrameTime = 0.0;
    self.elapsedTime = 0.0;
    self.playheadPosition = 0.0;
	self.duration = LWPlaybackMinDuration;
    self.elapsedTimeString = @"0:00";
    self.frameTimeString = @"";
}

- (NSUInteger)frameNumberFromPlayheadPosition:(double)position {
    if ( position <= 0.00 ) {
        return 0;
    }

    if ( position >= 100.0 ) {
        return [self.timeline.frames count] - 1;
    }

    return (NSUInteger)(position / 100.0 * [@([self.timeline.frames count]-1) doubleValue]);
}

- (void)updateElapsedTime {
    self.elapsedTime += LWTimerFrameInterval;
	CGFloat apparentElapsedTime = self.elapsedTime * self.playbackSpeed;
	self.playheadPosition = ( apparentElapsedTime  / self.duration ) * 100.0;
	// todo make this run only if the seconds rounded up to 1 decimal place didn't change between elapsed times
	self.elapsedTimeString = [NSString stringWithFormat:LWElapsedTimeFormat, (NSInteger)(apparentElapsedTime/60.0), fmod(apparentElapsedTime, 60.0)];
}

- (void)updateElapsedTimeString {
    self.elapsedTimeString = [NSString stringWithFormat:LWElapsedTimeFormat, (NSInteger)(self.elapsedTime/60.0), fmod(self.elapsedTime, 60.0)];
}

- (void)enqueueFrameForDisplay:(NSUInteger)frameIndex withoutDelay:(BOOL)withoutDelay {

    NSUInteger numFrames = [self.timeline.frames count];

    // We ran out frames and reached end of playback
    if ( frameIndex >= numFrames ) {
        return [self didReachEndOfPlayback];
    }
	
	self.currentFrame = frameIndex;
	
	if ( withoutDelay ) {
		if ( self.playbackTimer.isValid ) {
			[self.playbackTimer invalidate];
		}

		self.playbackTimer = nil;
		self.prevFrameTime = 0.0;
        self.elapsedTime = (frameIndex / (double)numFrames) * self.duration;
		[self updateElapsedTimeString];
		self.elapsedTime = self.elapsedTime / self.playbackSpeed;
		
		if ( self.isPlaying ) {
		    // todo reliable https://stackoverflow.com/questions/8172473/nstimer-reliable-alternatives/8172530
			self.playbackTimer = [NSTimer scheduledTimerWithTimeInterval:LWTimerFrameInterval target:self selector:@selector(updateElapsedTime) userInfo:nil repeats:YES];
		}
		
		[self prepareFrameForImmediateDisplay:@(frameIndex)];
		return;
	}

    /*
     * Determine delay
     */

	NSTimeInterval delay = LWPlaybackMinInterval;
    GSLayer* nextContextLayer = self.timeline.frames[ frameIndex ];
	
	// At some point a certain version of Glyphs stopped recording edit times,
	// So now we have to check if it exists for those edge cases, maybe better idea to migrate the keys in?
	id layerEditTimeValueWrapper = [nextContextLayer userDataForKey:LWUserDataKeyEditTime];
	NSTimeInterval layerEditTime = 0.0;
	
	if ( layerEditTimeValueWrapper ) {
		layerEditTime = [(NSNumber *)layerEditTimeValueWrapper doubleValue];
		
		if ( self.prevFrameTime == 0.0 ) {
			self.prevFrameTime = layerEditTime;
		}
		
		NSTimeInterval editTimeDelta = layerEditTime - self.prevFrameTime;
		
		if ( editTimeDelta >= LWPlaybackCutoffInterval ) {
			delay = LWPlaybackMaxInterval;
		} else if ( editTimeDelta < LWPlaybackMinInterval && editTimeDelta > 0.0 ) {
			delay = editTimeDelta;
		}
	}
	
	self.prevFrameTime = layerEditTime;
    [self performSelector:@selector(prepareFrameForImmediateDisplay:) withObject:@(frameIndex) afterDelay:delay/self.playbackSpeed];
}

- (void)prepareFrameForImmediateDisplay:(NSNumber *)frameIndex  {
    // This is here to prevent delays with playback time?
    if ( self.isPlaying ) {
        [self enqueueFrameForDisplay:self.currentFrame+1 withoutDelay:NO];
    }

    NSUInteger frameIndexInteger = [frameIndex unsignedIntegerValue];

    if ( frameIndexInteger >= [self.timeline.frames count] ) {
        NSLog(@"Layer Whale: attempting to render out bounds layer frame.");
        [self abortPlayback];
    }
	
	
    [self setContextGSLayer:self.timeline.frames[ frameIndexInteger ]];
    [self setNeedsDisplay:YES];
	
	id layerEditTimeWrapper = [self.contextGSLayer userDataForKey:LWUserDataKeyEditTime];
	
	if ( layerEditTimeWrapper ) {
		NSTimeInterval layerEditTime = [(NSNumber *)layerEditTimeWrapper doubleValue];
	
		self.frameTimeString = [NSString stringWithFormat:@"%lu @ %@", self.currentFrame, [self.frameTimeFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:layerEditTime]]];
	} else {
		self.frameTimeString = [NSString stringWithFormat:@"%lu", self.currentFrame];
	}
}

- (BOOL)mouseDownCanMoveWindow {
    return YES;
}

@end
