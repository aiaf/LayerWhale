//
// Created by Abdullah Arif on 6/23/18.
// Copyright (c) 2018 Abdullah Arif. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GlyphsCore/GSLayer.h>
#import <GlyphsCore/GSGlyph.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSTimeInterval const LWPlaybackCutoffInterval;
FOUNDATION_EXPORT NSTimeInterval const LWPlaybackMaxInterval;
FOUNDATION_EXPORT NSTimeInterval const LWPlaybackMinInterval;
FOUNDATION_EXPORT NSTimeInterval const LWPlaybackMinDuration;
FOUNDATION_EXPORT NSTimeInterval const LWPlaybackAvgFrameDelay;

typedef NS_ENUM(NSUInteger, LWGSElementType) {
    LWGSAnchor,
    LWGSAnnotation,
    LWGSBackgroundImage,
    LWGSComponent,
    LWGSGuideline,
    LWGSHint,
    LWGSNode
};

@interface LWTimeline : NSObject <NSCoding, NSCopying> {
    NSMutableArray<GSLayer *>* _recordBuffer;
    NSMutableArray<NSDictionary *>* _serializedFrames;
    NSInteger _numFramesShouldUnserialize;
    NSInteger _numFramesToSkipInSerialize;
    BOOL _dirty;
    NSString* _cachedDescription;
    GSLayer* _latestLayerState;
    NSInteger _indexForLastCalculatedExtent;
    NSRect _cachedGlyphExtents;
}

@property (getter=isRecording) BOOL recording;
@property (nullable) NSMutableArray<GSLayer *>* frames;
@property (readonly) NSUInteger frameCount;
@property NSTimeInterval checkpointResisted;
@property NSTimeInterval lastChange;

+ (instancetype)timelineWithJSON:(NSString *)jsonString parentLayer:(GSLayer *)parentLayer;
+ (instancetype)timelineWithBase64EncodedGzippedJSONString:(NSString *)encodedString parentLayer:(GSLayer *)parentLayer;
+ (instancetype)timelineWithDictionary:(NSDictionary *)dict parentLayer:(GSLayer *)parentLayer;

GSLayer *LWGSLayerFromDict(NSDictionary *dict, NSString *associatedMasterId, GSGlyph *glyph);

- (void)prepareTimelineForPlaybackInParentLayer:(GSLayer *)layer;

- (void)toggleRecording:(BOOL)record inLayer:(GSLayer *)parent;
- (void)startRecording;
- (void)stopRecording;
- (void)recordLayer:(GSLayer *)layer atTime:(NSTimeInterval)editTime;

- (NSMutableArray*)checkpoints;
- (void)makeCheckpointFromLayer:(GSLayer *)layer;
- (NSInteger)frameIndexOfLastCheckpoint:(NSInteger)skipCount;
- (void)resetToFrame:(NSInteger)frameIndex parentLayer:(GSLayer *)parentLayer;

- (GSLayer* _Nullable)firstFrame;
- (GSLayer* _Nullable)lastFrame:(GSLayer *)layer;
- (GSLayer* _Nullable)frameAtIndex:(NSInteger)index parentLayer:(GSLayer *)parentLayer;
- (NSString *)rawDescription;
- (NSTimeInterval)duration;
- (NSRect)maxGlyphExtents;
- (NSUInteger)fastFrameCount;
- (void)calculateCGPaths;

@end

NS_ASSUME_NONNULL_END
