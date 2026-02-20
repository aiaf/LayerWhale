//
// Created by Abdullah Arif on 6/27/18.
// Copyright (c) 2018 Abdullah Arif. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GlyphsCore/GSLayer.h>
#import "LWTimeline.h"
#import <GlyphsCore/GSPath.h>
#import "LWCGPathContainer.h"
#import "NSBezierPath+CGPathGeneration.h"

FOUNDATION_EXPORT NSString* const LWUserDataKeyTimeline;
FOUNDATION_EXPORT NSString* const LWUserDataKeyEditTime;
FOUNDATION_EXPORT NSString* const LWUserDataKeyDirtyState;
FOUNDATION_EXPORT NSString* const LWUserDataKeyCGPaths;
FOUNDATION_EXPORT NSString* const LWUserDataKeyCheckpoint;

@interface GSLayer (LWTimeline)

@property BOOL lw_observed;

- (void)lw_setGlyph:(GSGlyph*)aGlyph;
- (void)lw_setTimeline:(LWTimeline *)timeline;
- (BOOL)lw_hasTimeline;
- (LWTimeline *)lw_timeline;
- (NSTimeInterval)lw_editTime;
- (BOOL)lw_isEqualToLayer:(GSLayer *)otherLayer;
- (void)lw_triggerDirtyState;
- (void)lw_calculateCGPaths;
- (NSArray<LWCGPathContainer *>*)lw_CGPaths;
- (NSString *)lw_masterName;
- (NSString*)lw_displayName:(BOOL)addGlyphName;
- (void)lw_rawSetUserData:(id)newData forKey:(NSString*)key;
- (void)lw_rawRemoveUserDataForKey:(NSString*)key;

@end
