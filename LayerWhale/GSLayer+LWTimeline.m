//
// Created by Abdullah Arif on 6/27/18.
// Copyright (c) 2018 Abdullah Arif. All rights reserved.
//

#import "GSLayer+LWTimeline.h"
#import "GSGuideLine+LWEquality.h"
#import "GSAnchor+LWEquality.h"
#import <GlyphsCore/NSBezierPath-OAExtensions.h>
#import <objc/Object.h>


NSString* const LWUserDataKeyTimeline = @"LWTimeline";
NSString* const LWUserDataKeyEditTime = @"LWTime";
NSString* const LWUserDataKeyDirtyState = @"LWDirtyState";
NSString* const LWUserDataKeyCGPaths = @"LWCGPaths";
NSString* const LWUserDataKeyCheckpoint = @"LWCheckpoint";


@implementation GSLayer (LWTimeline)

@dynamic lw_observed;

- (void)setLw_observed:(BOOL)isObserved {
    objc_setAssociatedObject(self, @selector(lw_observed), @(isObserved), OBJC_ASSOCIATION_RETAIN) ;
}

- (BOOL)lw_observed {
    return [objc_getAssociatedObject(self, @selector(lw_observed)) boolValue];
}

/*
 * GSLayers with components need sit in the font->glyph->layer stack to retrieve proper paths for the components.
 * The inner machinery of GSComponent needs to know that parent GSLayer.
 * We need to allow for parent referencing from component->layer->glyph->font without having these
 * layers appear in the app's UI
 */
- (void)lw_setGlyph:(GSGlyph*)aGlyph {
    _glyph = aGlyph;
}

- (void)lw_setTimeline:(LWTimeline *)timeline {
    [self setUserData:timeline forKey:LWUserDataKeyTimeline];
}

- (BOOL)lw_hasTimeline {
    return [self userDataForKey:LWUserDataKeyTimeline] != nil;
}

- (LWTimeline *)lw_timeline {
    id timelineObject = [self userDataForKey:LWUserDataKeyTimeline];

    if ( [timelineObject isKindOfClass:[LWTimeline class]] ) {
        return timelineObject;
    }

    LWTimeline* timeline;

    if ( [timelineObject isKindOfClass:[NSString class]] ) {
        timeline = [LWTimeline timelineWithBase64EncodedGzippedJSONString:timelineObject parentLayer:self];
    }

    // [GSLayer setUserData:forKey:] triggers dirty state and undoManager on layer
    // so let's modify the NSMutableDictionary directly
	[self lw_rawSetUserData:timeline forKey:LWUserDataKeyTimeline];

	return timeline;
}

/*
 * This will return 0.0 if the edit key doesn't exist (doubleValue of nil is 0.0)
 */
- (NSTimeInterval)lw_editTime {
    return [(NSNumber *)[self userDataForKey:LWUserDataKeyEditTime] doubleValue];
}

/*
 * Note 1:Comparing draw*Path is ideal because it contains component paths in addition to the layer's own
 * So if a component is edited or transformed, we'll know.
 * Equality is checked using NSBezierPath-OAExtensions's isEqual: implementation
 */

/*
 * Note 2: Comparing selections doesn't work right now because recording is not triggered
 * for selection changes. Note for the future: selection comparison can be triggered from GSUpdateInterface
 * thereafter we must compare current selection with a shallow copy of the previous selection
 *
 * Note 3: future optimization. Store the node index at which the bezier equality failed, then when checking subsequent layers
 * start checking on that index, then spread up/down the element list.
 */

// to do compare vertwidth, hints, still issues with single-node open paths
- (BOOL)lw_isEqualToLayer:(GSLayer *)otherLayer {
    if ( ![self.drawBezierPath isEqual:otherLayer.drawBezierPath] ) {
        return NO;
    }

    if ( ![self.drawOpenBezierPath isEqual:otherLayer.drawOpenBezierPath] ) {
        return NO;
    }
        
    /*
     * This handle single-node open paths (check this statement)
     * We check for nil, because isEqual: checks class membership
     * and if both nil, it evaluates to false which is INCORRECT
     * todo: this might bite us again in the future, check if other bezier
     * equalities above are super correct
     */
    if ( self.openBezierPath || otherLayer.openBezierPath ) {
        if ( ![self.openBezierPath isEqual:otherLayer.openBezierPath] ) {
            return NO;
        }
    }

    if ( self.width != otherLayer.width ) {
        return NO;
    }

    NSInteger numAnchors = [self countOfAnchors];

    if ( numAnchors != [otherLayer countOfAnchors] ) {
        return NO;
    } else {
        for ( NSString *anchorName in self.anchors ) {
            GSAnchor *otherAnchor = [otherLayer anchorForName:anchorName];

            if ( otherAnchor || ![self.anchors[ anchorName ] lw_isEqualToAnchor:otherAnchor] ) {
                return NO;
            }
        }
    }

    NSUInteger numGuideLines = [self guideLineCount];

    if ( numGuideLines != [otherLayer guideLineCount] ) {
        return NO;
    } else {
        for (NSUInteger i = 0; i < numGuideLines; i++) {
            if (![self.guideLines[i] lw_isEqualToGuideLine:otherLayer.guideLines[i]]) {
                return NO;
            }
        }
    }

    return YES;
}

- (void)lw_triggerDirtyState {
    [self setUserData:@(arc4random()%1000) forKey:LWUserDataKeyDirtyState];
    [self removeUserDataForKey:LWUserDataKeyDirtyState];
}

- (NSArray<LWCGPathContainer *>*)lw_CGPaths {
    id CGPaths = [self tempDataForKey:LWUserDataKeyCGPaths];
    
    if ( CGPaths ) {
        return CGPaths;
    }

    [self lw_calculateCGPaths];

    return [self tempDataForKey:LWUserDataKeyCGPaths];
}

- (void)lw_calculateCGPaths {
    if ( [self tempDataForKey:LWUserDataKeyCGPaths] ) {
        return;
    }

    NSMutableArray *cgPaths = [[NSMutableArray alloc] init];

    for ( GSPath *path in self.paths ) {
        LWCGPathContainer *container = [[LWCGPathContainer alloc] init];
        CGPathRef pathRef = [[path bezierPath] newCGPath];
        [container setCGPath:pathRef];
        [container setBounds:CGPathGetPathBoundingBox(pathRef)];
        [cgPaths addObject:container];
    }

    [self setTempData:cgPaths forKey:LWUserDataKeyCGPaths];
}

- (NSString *)lw_masterName {
    return [(id)[self associatedFontMaster] performSelector:NSSelectorFromString(@"name")];
}

- (NSString*)lw_displayName:(BOOL)addGlyphName {
    NSString *masterName = [self lw_masterName];
    NSString* layerDisplayName = [self.name isEqualToString:masterName] ? [NSString stringWithFormat:@"[%@]", self.name] : [NSString stringWithFormat:@"[%@] %@", masterName, self.name];

    if ( addGlyphName ) {
        return [NSString stringWithFormat:@"%@ %@", self.glyph.name, layerDisplayName];
    }

    return layerDisplayName;
}

/*
 * _userData defaults to nil now so we must check before sending it
 * any message. Otherwise we'd be sending to nil, which does nothing.
 * This method will not trigger undo/dirty state.
 */
- (void)lw_rawSetUserData:(id)newData forKey:(NSString*)key {
	if ( !self.userData ) {
		self.userData = [@{} mutableCopy];
	}
	
	[self.userData setValue:newData forKey:key];
}

- (void)lw_rawRemoveUserDataForKey:(NSString*)key {
	[self.userData removeObjectForKey:key];
}

@end
