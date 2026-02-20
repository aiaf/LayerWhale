//
// Created by Abdullah Arif on 6/23/18.
// Copyright (c) 2018 Abdullah Arif. All rights reserved.
//

#import "LWTimeline.h"
#import "GSLayer+LWTimeline.h"
#import "LWLayerObserver.h"
#import <GlyphsCore/GSAnchor.h>
#import <GlyphsCore/GSComponent.h>
#import <GlyphsCore/GSGuideLine.h>
#import <GlyphsCore/GSHint.h>
#import "NSData+GZIP.h"

const NSTimeInterval LWPlaybackCutoffInterval = 1.0;
const NSTimeInterval LWPlaybackMaxInterval = 0.4;
const NSTimeInterval LWPlaybackMinInterval = 0.07;
const NSTimeInterval LWPlaybackMinDuration = 0.1; // to prevent nan/computation/formatting issues
const NSTimeInterval LWPlaybackAvgFrameComputationDelay = 0.016;

GSLayer *LWGSLayerFromDict(NSDictionary *dict, NSString *associatedMasterId, GSGlyph *glyph) {
    NSMutableDictionary *mutableDict = [dict mutableCopy];

    mutableDict[@"associatedMasterId"] = associatedMasterId;

    /*
     * initWithLayerDict successfully loads:
     * .paths, .guideLines, .hints, .anchors, .components
     * But .selection must be manually re-created
     */
    GSLayer *layer = [[GSLayer alloc] initWithLayerDict:mutableDict];

    if ( !layer ) {
        NSLog(@"Layer Whale: Could not read GSLayer dictionary %@", dict);
        return nil;
    }

    /*
     * Recreate selection
     * We use "lw_sel" instead of "selection" so that we don't conflict with Glyphs
     * in case they start supporting selection serialization in the future.
     */
    for ( NSArray *nodeInfo in mutableDict[@"lw_sel"] ) {
        NSUInteger nodeType = [nodeInfo[0] unsignedIntegerValue];

        if ( nodeType == LWGSNode ) {
            [layer addSelection:[layer nodeAtIndexPath:[NSIndexPath indexPathForItem:[nodeInfo[1] integerValue] inSection:[nodeInfo[2] integerValue]]]];
        } else if ( nodeType == LWGSGuideline ) {
            [layer addSelection:[layer guideLineAtIndex:[nodeInfo[1] unsignedIntegerValue]]];
        } else if ( nodeType == LWGSComponent ) {
            [layer addSelection:[layer componentAtIndex:[nodeInfo[1] unsignedIntegerValue]]];
        } else if ( nodeType == LWGSAnchor ) {
            [layer addSelection:[layer anchorForName:[nodeInfo[1] stringValue]]];
        } else if ( nodeType == LWGSHint ) {
            [layer addSelection:[layer hintAtIndex:[nodeInfo[1] unsignedIntegerValue]]];
        }
    }

    // this should be final step to avoid undo and dirty state on the GSLayer object
    [layer lw_setGlyph:glyph];

    return layer;
}

@interface LWTimeline ()
@property NSUInteger frameCount;
@end

@implementation LWTimeline

- (instancetype)init {
    self = [super init];

    if ( self ) {
        _recording = NO;
        _frames = [[NSMutableArray alloc] init];
        _serializedFrames = [[NSMutableArray alloc] init];
        _frameCount = 0;
        _recordBuffer = [[NSMutableArray alloc] init];
        _numFramesShouldUnserialize = 0;
        _numFramesToSkipInSerialize = 0;
        _dirty = YES;
        _cachedDescription = nil;
        _latestLayerState = nil;
        _indexForLastCalculatedExtent = -1;
        _cachedGlyphExtents = NSZeroRect;
        _checkpointResisted = NSTimeIntervalSince1970;
        _lastChange = 0;
    }

    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    self = [super init];

    if ( self ) {
        _recording = [decoder decodeBoolForKey:@"recording"];
        _frames = [decoder decodeObjectForKey:@"frames"];
        _serializedFrames = [decoder decodeObjectForKey:@"serializedFrames"];
        _frameCount = (NSUInteger)[decoder decodeIntegerForKey:@"frameCount"];
        _recordBuffer = [decoder decodeObjectForKey:@"recordBuffer"];
        _numFramesShouldUnserialize = [decoder decodeIntegerForKey:@"numFramesShouldUnserialize"];
        _numFramesToSkipInSerialize = [decoder decodeIntegerForKey:@"numFramesToSkipInSerialize"];
        _dirty = [decoder decodeBoolForKey:@"dirty"];
        _cachedDescription = [decoder decodeObjectForKey:@"cachedDescription"];
        _latestLayerState = [decoder decodeObjectForKey:@"latestLayerState"];
        _indexForLastCalculatedExtent = [decoder decodeIntegerForKey:@"indexForLastCalculatedExtent"];
        _cachedGlyphExtents = [decoder decodeRectForKey:@"cachedGlyphExtents"];
        _checkpointResisted = [decoder decodeDoubleForKey:@"checkpointResisted"];
        _lastChange = [decoder decodeDoubleForKey:@"lastChange"];
    }

    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeBool:self.recording forKey:@"recording"];
    [encoder encodeObject:self.frames forKey:@"frames"];
    [encoder encodeObject:_serializedFrames forKey:@"serializedFrames"];
    [encoder encodeInteger:self.frameCount forKey:@"frameCount"];
    [encoder encodeObject:_recordBuffer forKey:@"recordBuffer"];
    [encoder encodeInteger:_numFramesShouldUnserialize forKey:@"numFramesShouldUnserialize"];
    [encoder encodeInteger:_numFramesToSkipInSerialize forKey:@"numFramesToSkipInSerialize"];
    [encoder encodeBool:_dirty forKey:@"dirty"];
    [encoder encodeObject:_cachedDescription forKey:@"cachedDescription"];
    [encoder encodeObject:_latestLayerState forKey:@"latestLayerState"];
    [encoder encodeInteger:_indexForLastCalculatedExtent forKey:@"indexForLastCalculatedExtent"];
    [encoder encodeRect:_cachedGlyphExtents forKey:@"cachedGlyphExtents"];
    [encoder encodeDouble:_checkpointResisted forKey:@"checkpointResisted"];
    [encoder encodeDouble:_lastChange forKey:@"lastChange"];
}

// todo: fix when copied and recording is set to time-lapse, the layer is not added to the layer observers
- (id)copyWithZone:(NSZone *)zone {
    LWTimeline *copy = (LWTimeline *)[[[self class] allocWithZone:zone] init];

    if ( copy ) {
        copy.recording = self.recording;
        copy.frames = [self.frames mutableCopyWithZone:zone];
        copy.frameCount = self.frameCount;
        copy.checkpointResisted = self.checkpointResisted;
        copy.lastChange = self.lastChange;
        copy->_serializedFrames = [_serializedFrames mutableCopyWithZone:zone];
        copy->_recordBuffer = [_recordBuffer mutableCopyWithZone:zone];
        copy->_numFramesShouldUnserialize = _numFramesShouldUnserialize;
        copy->_numFramesToSkipInSerialize = _numFramesToSkipInSerialize;
        copy->_dirty = YES;
        copy->_cachedDescription = nil;
        copy->_latestLayerState = nil;
        copy->_indexForLastCalculatedExtent = -1;
        copy->_cachedGlyphExtents = NSZeroRect;
    }

    return copy;
}

+ (instancetype)timelineWithJSON:(NSString *)jsonString parentLayer:(GSLayer *)parentLayer {
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];

    LWTimeline *timeline = [self.class timelineWithDictionary:jsonDict parentLayer:parentLayer];
    timeline->_dirty = NO;
    timeline->_cachedDescription = jsonString;

    return timeline;
}

+ (instancetype)timelineWithBase64EncodedGzippedJSONString:(NSString *)encodedString parentLayer:(GSLayer *)parentLayer {
    NSData* decoded = [[NSData alloc] initWithBase64EncodedString:encodedString options:0];

    if ( !decoded ) {
        NSLog(@"Layer Whale: timeline data corrupted");
        return [[LWTimeline alloc] init];
    }
    
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:[decoded gunzippedData] options:0 error:nil];
    LWTimeline *timeline = [self.class timelineWithDictionary:json parentLayer:parentLayer];
    timeline->_dirty = NO;
    timeline->_cachedDescription = encodedString;

    return timeline;

}

+ (instancetype)timelineWithDictionary:(NSDictionary *)dict parentLayer:(GSLayer *)parentLayer {
    LWTimeline *instance = [[LWTimeline alloc] init];

    if ( dict ) {
        NSUInteger numSerializedFrames = [dict[@"frames"] count];

        instance.recording = [dict[@"recording"] boolValue];
        instance.frames = [[NSMutableArray alloc] init];
        instance.frameCount = numSerializedFrames;
        instance->_serializedFrames = [dict[@"frames"] mutableCopy];
        instance->_numFramesShouldUnserialize = numSerializedFrames;
        instance->_numFramesToSkipInSerialize = 0;
        instance->_latestLayerState = numSerializedFrames > 0 ? LWGSLayerFromDict([instance->_serializedFrames lastObject], parentLayer.associatedMasterId, parentLayer.glyph) : nil;
        instance.lastChange = dict[@"lastChange"] ? [dict[@"lastChange"] doubleValue] : instance->_latestLayerState ? [instance->_latestLayerState lw_editTime] : 0;
    }

    return instance;
}

#pragma mark - Serialization
#pragma mark -

- (void)prepareTimelineForPlaybackInParentLayer:(GSLayer *)layer {
    [self unserializeFramesInLayer:layer];
    [self readBuffer];
    [self calculateCGPaths];
}

/*
 * Unserialize should only happen once in the lifetime of a timeline
 * We only have frames to unserialize after we've instantiated from a layer's userData.
 * Thence the frames are in an encoded state (gzip+base64), and need to be transformed to their GSLayer form
 * at the appropriate time e.g. when playing the timeline.
 */
- (void)unserializeFramesInLayer:(GSLayer *)parentLayer {

    if ( _numFramesShouldUnserialize <= 0 ) {
        return;
    }

    NSString *associatedMasterId = [[parentLayer associatedMasterId] copy];
    GSGlyph *glyph = parentLayer.glyph;

    __block NSUInteger numNewlyUnserializedFrames = 0;
    __block NSUInteger insertionIndex = 0;

    // Prepend only serialized frames that were not unserialized
    NSInteger idx = -1;
    for ( NSDictionary *frameDict in _serializedFrames ) {
        idx++;

        if ( idx >= _numFramesShouldUnserialize ) {
            break;
        }

        numNewlyUnserializedFrames++;

        GSLayer *layer = LWGSLayerFromDict(frameDict, associatedMasterId, glyph);

        if ( !layer ) {
            continue;
        }

        [self.frames insertObject:layer atIndex:insertionIndex];
        insertionIndex++;
    }

    // Since the once serialized frames are now present in .frames, do not attempt to re-serialize them
    _numFramesToSkipInSerialize += numNewlyUnserializedFrames;
    _numFramesShouldUnserialize = 0;

    self.frameCount = [self.frames count] + [_recordBuffer count];
}

- (void)unserializeLastFrameInLayer:(GSLayer *)parentLayer {
    if ( _numFramesShouldUnserialize < 1 || [_serializedFrames count] < 1 ) {
        return;
    }

    GSLayer *lastFrameLayer = LWGSLayerFromDict([_serializedFrames lastObject], [parentLayer.associatedMasterId copy], parentLayer.glyph);

    if ( !lastFrameLayer ) {
        return;
    }

    // Prepend last serialized frame
    [self.frames insertObject:lastFrameLayer atIndex:0];

    _numFramesShouldUnserialize--;
    [_serializedFrames removeLastObject];
    self.frameCount++;
}


/*
 * Serialization happens frequently: every time the document is saved,
 * at least every ~10 seconds.
 * So needs to be optimized, lazy, and sequential.
 */
- (void)serializeFrames {
    [self readBuffer];

    if ( ![self.frames count] ) {
        return;
    }

    NSUInteger numNewlySerializedFrames = 0;
    NSInteger frameIndex = -1;

    for ( GSLayer *frame in self.frames ) {
        frameIndex++;

        if ( frameIndex < _numFramesToSkipInSerialize ) {
            continue;
        }

        numNewlySerializedFrames++;

        /*
         * -layerDict encodes: paths, components, hints, anchor, guideLines, width, userData
         * Does not encode or maintain: selection,
         */
        NSMutableDictionary *layerDict = [[frame layerDict] mutableCopy];

        if ( !layerDict ) {
            NSLog(@"Layer Whale: nothing to serialize in frame index %lu", frameIndex);
            continue;
        }

        // Remove repetitive, problematic data
        [layerDict removeObjectForKey:@"layerId"]; // keeping the Id will confuse things when the original layer is copied
        [layerDict removeObjectForKey:@"associatedMasterId"]; // this is repetitive; we know the masterId from the parent glyph

        // todo: vertWidth and metricKeys (they are glyph-specific and not returned by layerDict

        /*
         * SERIALIZE SELECTION
         * This is not taken care of by -layerDict, so we need to improvise
         */
        NSMutableArray* selection = [[NSMutableArray alloc] init];

        /*
         * Storing .elementString is redundant and faulty
         * because we need to reference the actual nodes when re-creating the selection
         * and cannot rely on .position to create a GSNode because multiple nodes can have the same position
         * and the newly created node won't be equal to anything found in .paths
         *
         * Selection element support:
         * - Supported: GSNode, GSGuideLine, GSAnchor, GSComponent, GSHint
         * - Unsupported: GSBackgroundImage, GSAnnotation
         */
        for ( __kindof GSElement *element in frame.selection ) {
            if ( [element isKindOfClass:[GSNode class] ] ) {
                /*
                 * indexPathOfNode is always 2-dimensional
                 * .section points to the GSPath inside .paths
                 * .item points to the GSNode inside the GSPath referenced by .section
                 **/
                NSIndexPath *nodeIndex = [frame indexPathOfNode:element];
                [selection addObject:@[@(LWGSNode), @(nodeIndex.item), @(nodeIndex.section)]];
            } else if ( [element isKindOfClass:[GSGuideLine class]] ) {
                [selection addObject:@[@(LWGSGuideline), @([frame.guideLines indexOfObject:element])]];
            } else if ( [element isKindOfClass:[GSAnchor class]] ) {
                [selection addObject:@[@(LWGSAnchor), [(GSAnchor *)element name]]];
            } else if ( [element isKindOfClass:[GSComponent class]] ) {
                [selection addObject:@[@(LWGSComponent), @([frame.components indexOfObject:element])]];
            } else if ( [element isKindOfClass:[GSHint class]] ) {
                [selection addObject:@[@(LWGSHint), @([frame.hints indexOfObject:element])]];
            }
        }

        layerDict[@"lw_sel"] = selection;

        [_serializedFrames addObject:layerDict];
    }

    _numFramesToSkipInSerialize += numNewlySerializedFrames;
}


- (void)resetSerialization {
    if ( _numFramesShouldUnserialize == 0 ) {
        if ( [_serializedFrames count] > 0 ) {
            [_serializedFrames removeAllObjects];
        }

        _numFramesToSkipInSerialize = 0;
    }
}

// CFPropertyListWriter_vintage.h writePropertyListToFileNoEscape crashes if this method returns more than 5MB!!!
- (NSString *)description {
    if ( !_dirty && _cachedDescription ) {
        return _cachedDescription;
    }

    [self serializeFrames];

    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:@{
            @"recording": @(self.isRecording),
            @"lastChange": @(self.lastChange),
            @"frames": _serializedFrames,
    } options:0 error:nil];

    if ( !jsonData ) {
        NSLog(@"Layer Whale: failed to convert timeline to JSON");
        return _cachedDescription;
    }

    _cachedDescription = [[jsonData gzippedDataWithCompressionLevel:0.4] base64EncodedStringWithOptions:0];
    //_cachedDescription =  [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

    _dirty = NO;

    return _cachedDescription;
}

- (NSString *)rawDescription {
    [self serializeFrames];
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:@{
            @"recording": @(self.isRecording),
            @"lastChange": @(self.lastChange),
            @"frames": _serializedFrames,
    } options:NSJSONWritingPrettyPrinted error:nil];

    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

#pragma mark - Recording  ⏺
#pragma mark -

- (void)toggleRecording:(BOOL)record inLayer:(GSLayer *)parent {

    if ( record != self.isRecording ) {
        NSUndoManager *undoManager = [parent undoManager];
        [undoManager beginUndoGrouping];
        [[undoManager prepareWithInvocationTarget:self] toggleRecording:self.isRecording inLayer:parent];
        [undoManager setActionName:NSLocalizedString(@"Toggle Recording", nil)];
        // Tell Glyphs that our layer is edited & needs to be saved
        [parent lw_triggerDirtyState];
        [undoManager endUndoGrouping];
        _dirty = YES;
    }

    if ( record ) {
        [self startRecording];
    } else {
        [self stopRecording];
    }
}

- (void)startRecording {
    self.recording = YES;
}

- (void)stopRecording {
    self.recording = NO;
}

- (void)recordLayer:(GSLayer *)layer atTime:(NSTimeInterval)editTime {
	// Retrieve the last recorded layer for this timeline
    if ( !_latestLayerState ) {
        _latestLayerState = [_recordBuffer lastObject];

        if ( !_latestLayerState ) {
            if ( [self.frames count] > 0 ) {
                _latestLayerState = [self.frames lastObject];
            } else if ( [_serializedFrames count] > 0 ) {
                _latestLayerState = LWGSLayerFromDict([_serializedFrames lastObject], [layer.associatedMasterId copy], layer.glyph);
            }
        }
    }

    // Only proceed if buffer is completely empty or layer isn't the same as previously recorded
    if ( _latestLayerState && [layer lw_isEqualToLayer:_latestLayerState] ) {
        return;
    }

    /*
     * Passing YES to copyThin: clears the selection (even if selection:YES)
     * copyThin:NO selection:YES gives us proper:
     * paths, components (without parent glyph) guideLines,
     * selection, anchors, hints
     *
     * We do not want to copy the timeline! Too much data.
     * So pop it, copy, then push it back into the original layer.
     */
	id timeline = [layer userDataForKey:LWUserDataKeyTimeline];
	[layer lw_rawRemoveUserDataForKey:LWUserDataKeyTimeline];
    GSLayer *layerCopy = [layer copyThin:NO selection:YES];
	[layer lw_rawSetUserData:timeline forKey:LWUserDataKeyTimeline];

    /*
     * This will allow us to determine the delay between each frame.
     */
	[layerCopy lw_rawSetUserData:@(editTime) forKey:LWUserDataKeyEditTime];
	
	/*
     * When any method is directly invoked on a GSLayer e.g. setUserDataForKey, setLayerId, etc
     * ...anything which triggers dirty state, the inner machinery will check of the GSGlyph's undoManager
     * and it will register undo's in it. So hitting cmd+z in the app will silently try to change this layer copy's state
     * via undoManager, which causes internal inconsistencies. In any case, we should change the layer discretely via ivars
     * and only attach the glyph after we've done all our changes.
     *
     * We need to set the glyph to get accurate drawBezierPath for comparison purposes.
     * Without a glyph, the components won't be there.
     */
    [layerCopy lw_setGlyph:layer.glyph];
    [_recordBuffer addObject:layerCopy];
    _latestLayerState = layerCopy;
    _dirty = YES;
    self.lastChange = editTime;
    self.frameCount += 1;
}

- (void)readBuffer {
    if ( ![_recordBuffer count] ) {
        return;
    }

    [self.frames addObjectsFromArray:_recordBuffer];
    [_recordBuffer removeAllObjects];
    self.frameCount = [self.frames count] + _numFramesShouldUnserialize;

}

#pragma mark - Checkpoints 🏁
#pragma mark -

/*
 * This returns an ordered array containing the
 * relative position of the checkpoint within the list of frames.
 * e.g. checkpoint at frame 50 of 100 then -checkpoints = [0.50]
 * todo: cache and optimize
 */
- (NSMutableArray *)checkpoints {
    NSMutableArray* output = [@[] mutableCopy];
    NSUInteger frameCount = [self.frames count];
    CGFloat frameDenom = frameCount == 1 ? 1.0 : (frameCount-1.0)*1.0;

    NSInteger idx = 0;
    for ( GSLayer* frame in self.frames ) {
        if ( [frame userDataForKey:LWUserDataKeyCheckpoint] ) {
            [output addObject:@( idx / frameDenom )];
        }
        idx++;
    }

    return output;
}

// TODO refactor to use a userData entry which stores all checkpoints
// Easier to retrieve, search, and undo/redo
- (void)makeCheckpointFromLayer:(GSLayer *)layer {
    /*
     * First record current layer state as new frame
     * This might succeed or fail depending whether the current state
     * matches the last recorded frame or not
     */
    NSTimeInterval checkpointTime = [[NSDate date] timeIntervalSince1970];

    [self recordLayer:layer atTime:checkpointTime];

    /*
     * Now grab the last frame in the timeline
     * This could be the one we just recorded, or
     * a previously recorded frame
     */
    GSLayer *lastFrame = [self lastFrame:layer];

    if ( !lastFrame ) {
        return;
    }

    /*
     * Sometimes all frames would be deserialized and the serializer
     * would be instructed to not re-seralize even if some frames have newly changed data
     * such as when adding checkpoints, this reset prevents that caching issue
     */
    [self resetSerialization];
    self.lastChange = checkpointTime;
    _dirty = YES;

	// This invokes the undoManager and triggers dirty state on the layer
	[lastFrame setUserData:@(checkpointTime) forKey:LWUserDataKeyCheckpoint];
}

- (NSInteger)frameIndexOfLastCheckpoint:(NSInteger)skipCount {
    [self serializeFrames];

    __block BOOL foundCheckpoint = NO;
    __block NSUInteger lastCheckpointIdx = 0;
    __block NSInteger numToSkip = skipCount;

    [_serializedFrames enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSDictionary *frameDict, NSUInteger idx, BOOL *stop) {
        if ( frameDict[@"userData"] && frameDict[@"userData"][ LWUserDataKeyCheckpoint ] ) {
            if ( numToSkip == 0 ) {
                foundCheckpoint = YES;
                lastCheckpointIdx = idx;
                *stop = YES;
            } else {
                numToSkip--;
            }
        }
    }];

    if ( foundCheckpoint ) {
        return lastCheckpointIdx;
    }

    return -1;
}

- (void)resetToFrame:(NSInteger)frameIndex parentLayer:(GSLayer *)parentLayer {
    if ( frameIndex < 0 ) {
        return;
    }

    NSInteger frameCount = [_serializedFrames count];

    if ( frameCount == 0 || frameIndex >= frameCount ) {
        return;
    }

    // Bookmark is last frame, nothing to delete
    if ( frameIndex == frameCount - 1 ) {
        return;
    }

    // If timeline consists of a single frame, delete everything
    if ( frameCount == 1 ) {
        [_serializedFrames removeAllObjects];
    } else {
        NSUInteger location = (NSUInteger)frameIndex + 1;
        [_serializedFrames removeObjectsInRange:NSMakeRange(location, frameCount - location)];
    }

    _dirty = YES;
    self.frames = [@[] mutableCopy];
    self.frameCount = [_serializedFrames count];
    self.lastChange = [[NSDate date] timeIntervalSince1970];
    _numFramesToSkipInSerialize = 0;
    _numFramesShouldUnserialize = self.frameCount;
    _latestLayerState = self.frameCount > 0 ? LWGSLayerFromDict([_serializedFrames lastObject], parentLayer.associatedMasterId, parentLayer.glyph) : nil;
}


#pragma mark - Computed properties ⏰
#pragma mark -

// This guarantees the first frame only if we've unserialized everything first
- (GSLayer *_Nullable)firstFrame {
    if ( [self.frames count] > 0 ) {
        return [self.frames firstObject];
    }

    return nil;
}

// This guarantees that we get the absolute last frame in the timeline
// todo: alt approach. serialize all first, then convert last object in serialzed frames
- (GSLayer *_Nullable)lastFrame:(GSLayer *)layer {
    [self unserializeLastFrameInLayer:layer];
    [self readBuffer];

    if ( [self.frames count] > 0 ) {
        return [self.frames lastObject];
    }

    return nil;
}

- (GSLayer *_Nullable)frameAtIndex:(NSInteger)index parentLayer:(GSLayer *)parentLayer {
    [self serializeFrames];

    if ( index >= [_serializedFrames count] ) {
        return nil;
    }

    return LWGSLayerFromDict(_serializedFrames[index], [parentLayer.associatedMasterId copy], [parentLayer glyph]);
}

/*
 * -performSelector:afterDelay: adds an average of 16ms to execution time
 * So when we're calling up a frame to be rendered, the delay is actually 16ms later (on average)
 * We need to account for this when calculating duration, otherwise the playback time and actual slider movement
 * will be out of sync.
 * The delay is unaffected by what happens in drawRect:
 * dispatch_after's delay is even greater than performSelector:... but perhaps more consistent?
 * Needs more testing.
 * See http://atastypixel.com/blog/experiments-with-precise-timing-in-ios/
 */
- (NSTimeInterval)duration {
    if ( [self.frames count] < 2 ) {
        return LWPlaybackMinDuration;
    }

    NSTimeInterval lastEditTime = [self.frames[0] lw_editTime];
    NSTimeInterval total = 0.0;

    for ( GSLayer *frame in self.frames ) {
        NSTimeInterval editTime = [frame lw_editTime];
        NSTimeInterval delta = editTime - lastEditTime;

		if ( delta <= 0.0 ) {
			total += LWPlaybackMinInterval;
		} else if ( delta >= LWPlaybackCutoffInterval ) { // greater than 1.0
            total += LWPlaybackMaxInterval;
        } else if ( delta < LWPlaybackMinInterval ) { // less than 0.07 but greater than 0
            total += fmax(0, delta);
        } else { // clamp between 0.07 (min) and 1.0 (max)
            total += LWPlaybackMinInterval;
        }

        total +=  LWPlaybackAvgFrameComputationDelay;

        lastEditTime = editTime;
    }

    return fmax(LWPlaybackMinDuration, total);
}



- (NSRect)maxGlyphExtents {
    if ( ![self.frames count] ) {
        return NSZeroRect;
    }

    LWLayerObserver *layerObserver = [LWLayerObserver perpetualObserver];
    BOOL layerObserverWasActive = layerObserver.activated;
    // This will prevent processBezier:... from unneeded invocation while we calculate metrics
   [layerObserver deactivate];

    GSGlyphMetrics metrics = self.frames[0].glyphMetrics;
    CGFloat minX;
    CGFloat maxX;
    CGFloat minY;
    CGFloat maxY;
    
    if ( NSEqualRects(_cachedGlyphExtents, NSZeroRect) ) {
        minX = 0.0;
        maxX = metrics.width;
        minY = metrics.descender;
        maxY = metrics.ascender;
    } else {
        minX = _cachedGlyphExtents.origin.x;
        maxX = _cachedGlyphExtents.size.width + minX;
        minY = _cachedGlyphExtents.origin.y;
        maxY = _cachedGlyphExtents.size.height + minY;
    }

    // NSEnumerationConcurrent is 6.5 faster than sequential, explore later, maybe not
    //[self.frames enumerateObjectsWithOptions:NSEnumerationConcurrent usingBlock:[^(GSLayer *frame, NSUInteger idx, BOOL *stop) {}];

    NSInteger idx = -1;
    for ( GSLayer *frame in self.frames ) {
        idx++;

        if ( _indexForLastCalculatedExtent >= idx ) {
            continue;
        }

        CGFloat layerMinX = frame.LSB;
        CGFloat layerMaxX = frame.width - frame.RSB;
        CGFloat layerMinY = frame.BSB + metrics.descender;
        CGFloat layerMaxY = metrics.ascender - frame.TSB;


        if ( layerMinX < minX ) {
            minX = layerMinX;
        }

        if ( layerMaxX > maxX ) {
            maxX = layerMaxX;
        }

        if ( layerMinY < minY ) {
            minY = layerMinY;
        }

        if ( layerMaxY > maxY ) {
            maxY = layerMaxY;
        }
    }

    _indexForLastCalculatedExtent = idx;
    _cachedGlyphExtents = NSMakeRect(minX, minY, maxX-minX, maxY-minY);

    if ( layerObserverWasActive ) {
        [layerObserver activate];
    }
    
    return _cachedGlyphExtents;
}

/*
 * Does not modify timeline state e.g. no unserialize, buffer unloading etc
 */
- (NSUInteger)fastFrameCount {
    return [_recordBuffer count] + [self.frames count] + _numFramesShouldUnserialize;
}

- (void)calculateCGPaths {
    LWLayerObserver *layerObserver = [LWLayerObserver perpetualObserver];
    BOOL layerObserverWasActive = layerObserver.activated;
    // This will prevent processBezier:... from unneeded invocation while we calculate metrics
    [layerObserver deactivate];

    for ( GSLayer* frame in self.frames ) {
        [frame lw_calculateCGPaths];
    }

    if ( layerObserverWasActive ) {
        [layerObserver activate];
    }
}



@end
