//
// Created by Abdullah Arif on 7/8/18.
// Copyright (c) 2018 Abdullah Arif. All rights reserved.
//

#import "LWPreferences.h"

NSNotificationName const LWGSPreferencesDidChangeNotification = @"LWGSPreferencesDidChangeNotification";
NSString* const LWPreferencesPanelIdentifier = @"Layer Whale";

static void * LWPreferencesContext = &LWPreferencesContext;

@implementation LWPreferences

/*
 * Colors are stored in NSUserDefaults for com.GeorgSeifert.Glyphs2
 * GSColorBackground
   GSColorBackgroundStroke
   GSColorForegroundStroke
   GSColorKerningNegative
   GSColorKerningPositive
   GSColorNodeCorner
   GSColorNodeSmooth
   GSColorOtherLayersStroke
   GSColorZones

   Following methods need to change if observing anything other than NSColor
   observeValueForKeyPath:..
   setDefaultValue:...
 */

// dict: prefKey -> [propName, defaultValue]
NSDictionary *LWObservedGSColors()
{
    static NSDictionary *colorKeys = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        colorKeys = @{
                @"GSColorBackground": @[@"backgroundColor", [NSColor colorWithCalibratedRed:1 green:1 blue:1 alpha:1.0]],
                @"GSColorBackgroundStroke": @[@"backgroundStrokeColor", [NSColor colorWithCalibratedRed:0.4 green:0.05 blue:0.05 alpha:0.55]],
                @"GSColorForegroundStroke": @[@"foregroundStrokeColor", [NSColor colorWithCalibratedRed:0 green:0 blue:0 alpha:1.0]],
                @"GSColorNodeCorner": @[@"cornerNodeColor", [NSColor colorWithCalibratedRed:0.239 green:0.43 blue:0.75 alpha:1.0]],
                @"GSColorNodeSmooth": @[@"smoothNodeColor", [NSColor colorWithCalibratedRed:0.239 green:0.68 blue:0.4 alpha:1.0]],
                @"GSColorOtherLayersStroke": @[@"otherLayersStrokeColor", [NSColor colorWithCalibratedRed:0.699 green:0.699 blue:0.699 alpha:1.0]],
                @"GSColorZones": @[@"zonesColor", [NSColor colorWithCalibratedRed:0.946 green:0.830 blue:0.763 alpha:0.9]]
        };
    });
    return colorKeys;
}

/*
 * If the keys are edited here, edit/add/delete the corresponding @property
 */
NSDictionary *LWObservedBoolPreferences()
{
    static NSDictionary *prefKeys = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        prefKeys = @{
                @"LWShowNodes": @(YES),
                @"LWShowMetrics": @(YES),
                @"LWShowHints": @(YES),
                @"LWShowInfo": @(YES),
                @"LWShowBackground": @(YES),
                @"LWShowImage": @(YES),
                @"LWShowGuideLines": @(YES),
                @"LWShowAnnotations": @(YES),
                @"LWShowBoundingBox": @(NO),
                @"LWFillOutline": @(NO),
                @"LWShowSelection": @(YES),
                @"LWScaleStrokes": @(YES),
                @"LWInvertedColors": @(NO),
                @"LWHighResolutionRecording": @(NO),
        };
    });
    return prefKeys;
}

NSDictionary *LWObservedStringPreferences()
{
    static NSDictionary *prefKeys = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        prefKeys = @{
                @"LWFirstVersion": @"0",
                @"LWLastVersion": @"0",
        };
    });
    return prefKeys;
}


+ (void)initialize {
    [NSUserDefaults.standardUserDefaults registerDefaults:LWObservedBoolPreferences()];
    [NSUserDefaults.standardUserDefaults registerDefaults:LWObservedStringPreferences()];
    [NSUserDefaults.standardUserDefaults registerDefaults:@{
            @"LWPlayerAspectRatio": @(0)
    }];
}

+ (instancetype)sharedPreferences
{
    static LWPreferences *sharedPreferences = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        sharedPreferences = [[LWPreferences alloc] init];
    });

    return sharedPreferences;
}

- (instancetype)init {
    self = [super init];

    if ( self ) {
        NSDictionary* observedColors = LWObservedGSColors();
        for ( NSString* prefKey in observedColors ) {
            [self observePreference:prefKey];
            [self setDefaultColorValue:observedColors[prefKey][1] forKey:observedColors[prefKey][0] tryPreference:prefKey];
        }

        // Do handle size manually for now
        id preferredHandleSize = [NSUserDefaults.standardUserDefaults objectForKey:@"GSHandleSize"];
        [self observePreference:@"GSHandleSize"];
        [self setHandleSize:preferredHandleSize ? [preferredHandleSize integerValue] : 1];

        NSInteger aspectRatioTag = [NSUserDefaults.standardUserDefaults integerForKey:@"LWPlayerAspectRatio"];
        [self setPlayerAspectRatio:aspectRatioTag];

        NSDictionary* observedPrefs = LWObservedBoolPreferences();
        for ( NSString* prefKey in observedPrefs ) {
            [self observePreference:prefKey];
            NSString *propName = [self propertyNameFromPreferenceKey:prefKey];
            [self setDefaultValue:observedPrefs[prefKey] forKey:propName tryPreference:prefKey];
        }
		
		if ( !self.prefsView ) {
		    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
			self.prefsView = [[LWPrefsViewController alloc] initWithNibName:@"LWPrefsViewController" bundle:bundle];
			SEL addViewToPrefsSEL = NSSelectorFromString(@"addViewToPreferences:");
			
            if ([NSApp.delegate respondsToSelector:addViewToPrefsSEL]) {
                // To make the text enabled in the toolbar's overflow menu, the NSToolbarItem's menuFormRepresentation
                // must be set and its validator properly implemented. todo later
                // NSApp.delegate.preferencesController.prefsPanel.tabView.window.toolbar.items
				NSImage *panelIcon = [bundle imageForResource:@"LWIconTemplate"];
				[panelIcon setName:LWPreferencesPanelIdentifier];
				[self.prefsView setTitle:LWPreferencesPanelIdentifier];
				[self.prefsView setRepresentedObject:LWPreferencesPanelIdentifier];
				#pragma clang diagnostic push
				#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                [NSApp.delegate performSelector:addViewToPrefsSEL withObject:self.prefsView];
                #pragma clang diagnostic pop
            }
		}
    }

    return self;
}

- (NSString *)propertyNameFromPreferenceKey:(NSString *)prefKey {
    return [NSString stringWithFormat:@"%@%@", [[prefKey substringWithRange:NSMakeRange(2, 1)] lowercaseString], [prefKey substringFromIndex:3]];

}

- (void)setDefaultValue:(id)value forKey:(NSString *)propertyName tryPreference:(NSString*)preferenceName {
    id preferredValue = [NSUserDefaults.standardUserDefaults valueForKey:preferenceName];

    if ( preferredValue != nil ) {
        [self setValue:@([preferredValue boolValue]) forKey:propertyName];
    } else {
        [self setValue:value forKey:propertyName];
    }
}

- (void)setDefaultColorValue:(id)value forKey:(NSString *)propertyName tryPreference:(NSString*)preferenceName {
    id preferredValue = [NSUserDefaults.standardUserDefaults valueForKey:preferenceName];

    if ( preferredValue ) {
        [self setValue:[self colorFromData:preferredValue] forKey:propertyName];
    } else {
        [self setValue:value forKey:propertyName];
    }

}

- (void)observePreference:(NSString*)prefKey {
    [NSUserDefaults.standardUserDefaults addObserver:self
                                          forKeyPath:prefKey
                                             options:NSKeyValueObservingOptionNew
                                             context:&LWPreferencesContext];
}

- (void)observeValueForKeyPath:(nullable NSString *)keyPath ofObject:(nullable id)object change:(nullable NSDictionary<NSKeyValueChangeKey, id> *)change context:(nullable void *)context {
    if ( context == LWPreferencesContext ) {
        if (LWObservedGSColors()[ keyPath ] ) {
            if ( change[NSKeyValueChangeNewKey] && ![change[NSKeyValueChangeNewKey] isEqual:[NSNull null]] ) { // if color was not unset
                [self setValue:[self colorFromData:change[NSKeyValueChangeNewKey]] forKey:LWObservedGSColors()[keyPath][0]];
            } else {
                [self setValue:LWObservedGSColors()[keyPath][1] forKey:LWObservedGSColors()[keyPath][0]];
            }

            [NSNotificationCenter.defaultCenter postNotificationName:LWGSPreferencesDidChangeNotification object:nil];

        } else if (LWObservedBoolPreferences()[ keyPath ] != nil ) {
            [self setValue:@([change[NSKeyValueChangeNewKey] boolValue]) forKey:[self propertyNameFromPreferenceKey:keyPath]];
        } else if ( [keyPath isEqualToString:@"GSHandleSize"] ) {
            if ( change[NSKeyValueChangeNewKey] && ![change[NSKeyValueChangeNewKey] isEqual:[NSNull null]] ) {
                self.handleSize = [change[NSKeyValueChangeNewKey] integerValue];
            } else {
                self.handleSize = 1;
            }

            [NSNotificationCenter.defaultCenter postNotificationName:LWGSPreferencesDidChangeNotification object:nil];
        }
    }
}

- (NSColor *)colorFromData:(NSData *)data {
    return [NSUnarchiver unarchiveObjectWithData:data];
}

@end
