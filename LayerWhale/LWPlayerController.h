//
//  LWPlayerController.h
//  LWTimelinePalette
//
//  Created by Abdullah Arif on 7/6/18.
//  Copyright © 2018 Abdullah Arif. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <GlyphsCore/GSFont.h>
#import <GlyphsCore/GSLayer.h>
#import "LWPlayer.h"
#import "LWExportViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface LWPlayerController : NSWindowController<NSWindowDelegate, NSFileManagerDelegate, NSUserNotificationCenterDelegate> {
    NSTimer* _overlaysFadeTimer;
    NSTimer* _statusTimer;
}

@property LWExportViewController *exportController;
@property (weak) IBOutlet LWPlayer *player;
@property (weak) IBOutlet NSLayoutConstraint *playerWidth;
@property (weak) IBOutlet NSLayoutConstraint *playerHeight;

/*
 * We need the control constraints strong, because if weak
 * and we deactivate (.active = NO ) any, they get released
 */
@property (weak) IBOutlet NSView *playerControls;
@property (strong) IBOutlet NSLayoutConstraint *controlsLeading;
@property (strong) IBOutlet NSLayoutConstraint *controlsTrailing;
@property (strong) IBOutlet NSLayoutConstraint *controlsMaxWidth;
@property (strong) IBOutlet NSLayoutConstraint *controlsWidth;
@property (weak) IBOutlet NSTextField *playerTitle;
@property (weak) IBOutlet NSTextField *statusField;
@property (weak) IBOutlet NSSlider *playBar;

@property (strong) IBOutlet NSPopover *optionsPopover;
@property (strong) IBOutlet NSPopover *aspectRatiosPopover;
@property (nullable) NSColor* backgroundColor;
@property (weak) IBOutlet NSButton *aspectNoButton;
@property (weak) IBOutlet NSButton *aspectSquareButton;
@property (weak) IBOutlet NSButton *aspect169Button;
@property (weak) IBOutlet NSButton *aspect43Button;

@property BOOL mouseInPlayerControls;

- (IBAction)showViewOptions:(nullable id)sender;
- (IBAction)invertColors:(nullable id)sender;
- (IBAction)exportMedia:(id)sender;

- (IBAction)skipToBeginning:(id)sender;
- (IBAction)togglePlay:(nullable id)sender;
- (IBAction)changePlaybackSpeed:(id)sender;
- (IBAction)skipToEnd:(id)sender;
- (IBAction)movePlayhead:(nullable id)sender;
- (IBAction)exportAsNewLayer:(id)sender;
- (IBAction)exportAsBackgroundLayer:(id)sender;
- (IBAction)zoomIn:(nullable id)sender;
- (IBAction)zoomToFit:(nullable id)sender;
- (IBAction)zoomOut:(nullable id)sender;

- (void)showPlayerForLayer:(GSLayer *)layer;
- (IBAction)closePlayer:(nullable id)sender;
@end

NS_ASSUME_NONNULL_END
