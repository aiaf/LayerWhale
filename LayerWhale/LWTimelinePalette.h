//
//  LWTimelinePalette.h
//  LWTimelinePalette
//
//  Created by Abdullah Arif on 6/21/18.
//Copyright © 2018 Abdullah Arif. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <GlyphsCore/GSGlyphViewControllerProtocol.h>
#import <GlyphsCore/GlyphsPaletteProtocol.h>
#import <GlyphsCore/GSLayer.h>
#import "GSLayer+LWTimeline.h"
#import "LWTimeline.h"
#import "LWPlayerController.h"

@interface LWTimelinePalette : NSObject <GlyphsPalette> {
	int _cleanToken;
    NSTimer* _statusTimer;
}

@property (nullable, nonatomic) IBOutlet NSView *theView;
@property (nullable, weak) IBOutlet NSButton *recordButton;

@property (nullable) LWTimeline *activeTimeline;
@property (nullable) NSMutableArray *layerObservers;
@property (nullable) LWPlayerController *playerController;
@property NSUInteger selectedLayersCount;
@property (weak) IBOutlet NSSegmentedControl *optionsButton;
@property (strong) IBOutlet NSMenu *optionsMenu;
@property (weak) IBOutlet NSTextField *statusField;
@property (strong) IBOutlet NSDateFormatter *lastChangeFormatter;

- (IBAction)toggleRecordingOnSelectedLayers:(id)sender;
- (IBAction)playActiveLayerTimeline:(nullable id)sender;

- (NSString *)pluginVersion;
- (NSString *)pluginBuildNumber;

@end
