//
// Created by Abdullah Arif on 7/3/18.
// Copyright (c) 2018 Abdullah Arif. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GlyphsCore/GSGlyph.h>
#import <GlyphsCore/GSLayer.h>
#import <GlyphsCore/GSPath.h>


@interface LWLayerObserver : NSObject

@property BOOL activated;

+ (LWLayerObserver *)perpetualObserver;
- (void)activate;
- (void)deactivate;

@end
