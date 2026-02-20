//
// Created by Abdullah Arif on 7/8/18.
// Copyright (c) 2018 Abdullah Arif. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "LWPrefsViewController.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSNotificationName const LWGSPreferencesDidChangeNotification;
FOUNDATION_EXPORT NSString* const LWPreferencesPanelIdentifier;

@interface LWPreferences : NSObject

@property LWPrefsViewController *prefsView;

@property (readonly, nullable) NSColor *backgroundColor;
@property (readonly, nullable) NSColor *backgroundStrokeColor;
@property (readonly, nullable) NSColor *otherLayersStrokeColor;
@property (readonly, nullable) NSColor *foregroundStrokeColor;
@property (readonly, nullable) NSColor *cornerNodeColor;
@property (readonly, nullable) NSColor *smoothNodeColor;
@property (readonly, nullable) NSColor *zonesColor;

@property NSInteger handleSize;
@property NSInteger playerAspectRatio;

@property BOOL showNodes;
@property BOOL showMetrics;
@property BOOL showHints; /* not implemented */
@property BOOL showInfo;  /* not implemented */
@property BOOL showBackground; /* not implemented */
@property BOOL showImage; /* not implemented */
@property BOOL showGuideLines;
@property BOOL showAnnotations; /* not implemented */
@property BOOL showBoundingBox;
@property BOOL fillOutline;
@property BOOL showSelection;
@property BOOL scaleStrokes;
@property BOOL invertedColors;
@property BOOL highResolutionRecording;

+ (nullable instancetype)sharedPreferences;

@end

NS_ASSUME_NONNULL_END
