//
//  LWPlayerController.m
//  LWTimelinePalette
//
//  Created by Abdullah Arif on 7/6/18.
//  Copyright © 2018 Abdullah Arif. All rights reserved.
//

#import "LWPlayerController.h"
#import "GSLayer+LWTimeline.h"
#import "NSColor+LWUtility.h"
#import "LWPlayerSliderCell.h"
#import <CoreImage/CoreImage.h>

@implementation LWPlayerController

- (void)windowDidLoad {
    [super windowDidLoad];

    [self.window setMovable:YES];
    [self.window setMovableByWindowBackground:YES];
    [self.window setTitlebarAppearsTransparent:YES];
    [self.window setTitleVisibility:NSWindowTitleHidden];
    [self.window setStyleMask:self.window.styleMask | NSWindowStyleMaskFullSizeContentView];
    // If we use NSWindowCollectionBehaviorFullScreenAuxiliary tiling won't be allowed
    [self.window setCollectionBehavior: self.window.collectionBehavior | NSWindowCollectionBehaviorFullScreenPrimary];

    _mouseInPlayerControls = NO;

    [self.player setWidthConstraint:self.playerWidth];
    [self.player setHeightConstraint:self.playerHeight];

    NSScrollView *scrollView = [self.player enclosingScrollView];

    /*
     * Mouse move/enter/exit tracking areas to enable fadeIn/Out of titlebar and player controls
     */
    NSTrackingArea *scrollViewTrackingArea = [[NSTrackingArea alloc] initWithRect:scrollView.frame options:NSTrackingMouseEnteredAndExited|NSTrackingMouseMoved|NSTrackingActiveAlways|NSTrackingInVisibleRect owner:self userInfo:@{@"area":@"scrollView"}];
    [scrollView addTrackingArea:scrollViewTrackingArea];

    NSTrackingArea *controlsTrackingArea = [[NSTrackingArea alloc] initWithRect:self.playerControls.frame options:NSTrackingMouseEnteredAndExited|NSTrackingActiveAlways|NSTrackingInVisibleRect owner:self userInfo:@{@"area":@"playerControls"}];
    [self.playerControls addTrackingArea:controlsTrackingArea];

    [self setPlayerAppearance];
	NSInteger aspectRatioKey = [NSUserDefaults.standardUserDefaults integerForKey:@"LWPlayerAspectRatio"];
    NSSize aspectRatio = [self aspectRatioFromTag:aspectRatioKey];
    [self applyAspectRatio:aspectRatio animate:NO];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(setPlayerAppearance) name:LWGSPreferencesDidChangeNotification object:nil];

    switch ( aspectRatioKey ) {
        case 1:
            self.aspectSquareButton.state =  NSControlStateValueOn;
            break;
        case 2:
            self.aspect43Button.state =  NSControlStateValueOn;
            break;
        case 3:
            self.aspect169Button.state =  NSControlStateValueOn;
            break;
        default:
            self.aspectNoButton.state =  NSControlStateValueOn;
            break;
    }
    
}

- (NSApplicationPresentationOptions)window:(NSWindow *)window willUseFullScreenPresentationOptions:(NSApplicationPresentationOptions)proposedOptions
{
    return NSApplicationPresentationFullScreen |
            NSApplicationPresentationHideDock |
            NSApplicationPresentationAutoHideMenuBar |
            NSApplicationPresentationAutoHideToolbar;
}

- (void)setPlayerAppearance {
    BOOL invertedColors = [LWPreferences sharedPreferences].invertedColors;

    [self.player setDrawingContext];
    self.backgroundColor = [LWPreferences sharedPreferences].backgroundColor;
    [self.player.enclosingScrollView setBackgroundColor:[self.backgroundColor lw_inverted:invertedColors]];
	[self.player.enclosingScrollView setScrollerKnobStyle:invertedColors ? NSScrollerKnobStyleLight : NSScrollerKnobStyleDark];
	
	BOOL isNativeDarkMode = NO;
	
	if ( @available(macOS 10.14, *) ) {
		if ( self.player.effectiveAppearance.name == NSAppearanceNameDarkAqua ) {
			isNativeDarkMode = YES;
		}
	}
	
	if ( !isNativeDarkMode ) {
		[self.optionsPopover setAppearance:[NSAppearance appearanceNamed:invertedColors ? NSAppearanceNameVibrantDark : NSAppearanceNameVibrantLight]];
		[self.aspectRatiosPopover setAppearance:[NSAppearance appearanceNamed:invertedColors ? NSAppearanceNameVibrantDark : NSAppearanceNameVibrantLight]];
	}
	
    [self setToolbarAppearance];
    [self.player setNeedsDisplay:YES];
}

// TODO: also apply when system switches to appearance mode while the player is running
// perhaps by providing dark/light assets
- (void)setToolbarAppearance {
	
	BOOL isNativeDarkMode = NO;
	
	if ( @available(macOS 10.14, *) ) {
		if ( self.player.effectiveAppearance.name == NSAppearanceNameDarkAqua ) {
			isNativeDarkMode = YES;
		}
	}
	
	BOOL isPlayerDark = [self.player.enclosingScrollView.backgroundColor lw_isDark];
	BOOL areToolbarItemsNativelyInverted = isNativeDarkMode;
	
	CIFilter *colorInvert = [CIFilter filterWithName:@"CIColorInvert"];
	[colorInvert setDefaults];
	[colorInvert setValue:nil forKey:kCIInputImageKey];
	
	if ( areToolbarItemsNativelyInverted ) {
		if ( isPlayerDark ) {
			for ( __kindof NSToolbarItem *item in self.window.toolbar.items ) {
				[item.view setContentFilters:@[]];
			}
		} else {
			for ( __kindof NSToolbarItem *item in self.window.toolbar.items ) {
				[item.view setContentFilters:@[colorInvert]];
			}
		}
	} else {
		if ( isPlayerDark ) {
			for ( __kindof NSToolbarItem *item in self.window.toolbar.items ) {
				[item.view setContentFilters:@[colorInvert]];
			}
		} else {
			for ( __kindof NSToolbarItem *item in self.window.toolbar.items ) {
				[item.view setContentFilters:@[]];
			}
		}
	}
}

#pragma mark Overlays

- (void)showOverlays {
    NSView *titleView = [self.window standardWindowButton:NSWindowCloseButton].superview;

    if ( titleView.alphaValue < 1.0 ) {
        [titleView animator].alphaValue = 1;
    }

    if ( [self.playerControls animator].alphaValue < 1 ) {
        [self.playerControls animator].alphaValue = 1;
    }
}

- (void)hideOverlays {
    NSView *titleView = [self.window standardWindowButton:NSWindowCloseButton].superview;
    [titleView animator].alphaValue = 0;
    [self.playerControls animator].alphaValue = 0;
}

- (void)hidePlayerControls {
    [self.playerControls animator].alphaValue = 0;
}

- (void)mouseMoved:(NSEvent *)event {
    if ( _overlaysFadeTimer ) {
        [_overlaysFadeTimer invalidate];
    }

    [self showOverlays];

    if ( _mouseInPlayerControls ) {
        return;
    }

    _overlaysFadeTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                  target:self
                                                selector:self.window.styleMask & NSWindowStyleMaskFullScreen ? @selector(hidePlayerControls) : @selector(hideOverlays)
                                                userInfo:nil
                                                 repeats:NO];
}

- (void)mouseExited:(NSEvent *)event {
    NSTrackingArea *area = event.trackingArea;

    if ( area ) {
		id areaName = area.userInfo[@"area"];

		if ( areaName && [areaName isEqualToString:@"playerControls"] ) {
			_mouseInPlayerControls = NO;
		}
	}
	
	if ( _overlaysFadeTimer ) {
		[_overlaysFadeTimer invalidate];
	}
	
	if ( self.window.styleMask&NSWindowStyleMaskFullScreen ) {
		[self hidePlayerControls];
    } else {
        [self hideOverlays];
    }
}

- (void)mouseEntered:(NSEvent *)event {
    NSTrackingArea *area = event.trackingArea;

    if ( !area ) {
        return;
    }

    id areaName = area.userInfo[@"area"];

    if ( !areaName || ![areaName isEqualToString:@"playerControls"] ) {
        return;
    }
	
   _mouseInPlayerControls = YES;

    if ( _overlaysFadeTimer ) {
        [_overlaysFadeTimer invalidate];
    }

    [self showOverlays];
}

#pragma mark Toolbar

- (IBAction)exportMedia:(id)sender {
    [self.player togglePlay:NO];
    self.statusField.stringValue = @"Exporting timeline...";

    if ( !self.exportController ) {
        self.exportController = [[LWExportViewController alloc] initWithWindowNibName:@"LWExportViewController"];
    }

    [self.exportController setPlayer:self.player];
    [self.exportController.startFrameText setIntegerValue:self.player.currentFrame];
    [self.exportController.endFrameText setIntegerValue:[self.player.timeline.frames count]];

    [self.player.window beginSheet:self.exportController.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSModalResponseOK) {
            [self performSelectorOnMainThread:@selector(saveExportedMedia) withObject:nil waitUntilDone:NO];
        }

        self.statusField.stringValue = @"";
        self.exportController.player = nil;
    }];
}

- (void)saveExportedMedia {
    if ( !self.exportController.imageFilePath ) {
        self.statusField.stringValue = @"Failed to export: nothing to save";
        return;
    }

    GSLayer *parentLayer = self.player.parentGSLayer;
	CGFloat resolution = [self.exportController resolution];
	NSInteger fps = [self.exportController FPS];

	NSSavePanel *save = [NSSavePanel savePanel];
	save.title = @"Save Timeline Animation";
	save.nameFieldStringValue = [NSString stringWithFormat:@"%@ Timeline%@%@", [parentLayer lw_displayName:YES], fps == 0 ? @"" : [NSString stringWithFormat:@" %luFPS", fps], resolution == 2.0 ? @"@2x" : @""];
	save.allowedFileTypes = [self.exportController exportFormatExtensions:[self.exportController exportFormat]];

	if ( [save runModal] == NSModalResponseOK ) {
		NSFileManager *fileManager = [NSFileManager defaultManager];
        [fileManager setDelegate:self];
        NSError *error;

        NSUserNotification *notification = [[NSUserNotification alloc] init];
        notification.identifier = [[NSUUID UUID] UUIDString];
        NSUserNotificationCenter *notificationCenter = [NSUserNotificationCenter defaultUserNotificationCenter];
        [notificationCenter setDelegate:self];

        if ( [fileManager moveItemAtURL:[NSURL fileURLWithPath:self.exportController.imageFilePath] toURL:[save URL] error:&error] ) {
            self.exportController.imageFilePath = nil;
            
            notification.title = @"Typelapse Export Succeeded";
            notification.subtitle = [parentLayer lw_displayName:YES];
            notification.soundName = NSUserNotificationDefaultSoundName;
            notification.hasActionButton = YES;
            notification.otherButtonTitle = @"";
            notification.actionButtonTitle = @"Show";
            [notification setValue:@YES forKey:@"_showsButtons"];
            notification.userInfo = @{@"URL": [[save URL] absoluteString]};
        } else {
            NSLog(@"Layer Whale: failed to save exported timeline media %@", error);
            notification.title = @"Typelapse Export Failed";
            notification.subtitle = [parentLayer lw_displayName:YES];
            notification.informativeText = [error localizedDescription];
            notification.hasActionButton = NO;
        }

        [notificationCenter deliverNotification:notification];

        [fileManager setDelegate:nil];
	}
}

- (BOOL)fileManager:(NSFileManager *)fileManager shouldProceedAfterError:(NSError *)error movingItemAtURL:(NSURL *)srcURL toURL:(NSURL *)dstURL {
    return error.code == NSFileWriteFileExistsError;
}

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification {
    if ( notification.userInfo[@"URL"] ) {
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[[NSURL URLWithString:notification.userInfo[@"URL"]]]];
    }
}

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification {
    return YES;
}

- (IBAction)showViewOptions:(id)sender {
    NSButton* item = (NSButton *)sender;
    
    // Show popover
    [self.optionsPopover showRelativeToRect:item.bounds
                              ofView:item
                       preferredEdge:NSMaxYEdge];
}

- (IBAction)invertColors:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:![LWPreferences sharedPreferences].invertedColors forKey:@"LWInvertedColors"];
    [self setPlayerAppearance];
}

#pragma mark Player Controls

- (IBAction)zoomIn:(id)sender {
    [self.player setScale:self.player.scaleFactor * 1.2 keepCentered:YES];
    [self setTemporaryStatusMessage:[NSString stringWithFormat:@"Zoom %.f%%", round(self.player.scaleFactor * 100.0)] time:1.0];
}

- (IBAction)zoomOut:(id)sender {
    [self.player setScale:self.player.scaleFactor * 0.8 keepCentered:YES];
    [self setTemporaryStatusMessage:[NSString stringWithFormat:@"Zoom %.f%%", round(self.player.scaleFactor * 100.0)] time:1.0];
}

- (IBAction)zoomToFit:(id)sender {

}

- (IBAction)skipToEnd:(id)sender {
    [self.player pause];
	[self.playBar setDoubleValue:100.0];
	[self.player movePlayheadTo:100.0];
}

- (IBAction)skipToBeginning:(id)sender {
    [self.player pause];
    [self.playBar setDoubleValue:0.0];
    [self.player movePlayheadTo:0.0];
}

- (IBAction)changePlaybackSpeed:(id)sender {
	CGFloat nextPlaybackSpeed = [(NSPopUpButton *)sender selectedTag];
	nextPlaybackSpeed = nextPlaybackSpeed > 10 ? nextPlaybackSpeed / 100.0 : nextPlaybackSpeed;
	
    BOOL wasPlaying = self.player.isPlaying;

    if ( wasPlaying ) {
        [self.player pause];
    }

    [self.player setPlaybackSpeed:nextPlaybackSpeed];

    if ( wasPlaying ) {
    	[self.player play];
	}
}

- (IBAction)togglePlay:(id)sender {
	[self.player togglePlay:[(NSButton*)sender state] == NSControlStateValueOn];
}

// todo: fix if within 1 frame of checkpoint, and use tries to move 1 frame away, shouldn't snap
- (IBAction)movePlayhead:(id)sender {
    double position = [(NSSlider *)sender doubleValue];
    [self.player movePlayheadTo:position];
    [(LWPlayerSliderCell *)self.playBar.cell snapToClosestTickMark:position];
}

- (IBAction)exportAsNewLayer:(id)sender {
	[self.player makeCurrentFrameANewLayer];
	[self setTemporaryStatusMessage:@"Frame exported as new layer!" time:3.0];
}

- (IBAction)exportAsBackgroundLayer:(id)sender {
	[self.player makeCurrentFrameBackgroundLayer];
	[self setTemporaryStatusMessage:@"Frame set as background layer!" time:3.0];
}


- (IBAction)closePlayer:(id)sender {
    [self.window close];
}

- (IBAction)triggerPlayerRedraw:(id)sender {
    [self.player setNeedsDisplay:YES];
}

- (IBAction)rescaleDocument:(id)sender {
    [self.player setScale:self.player.scaleFactor keepCentered:NO];
    [self.player setNeedsDisplay:YES];
}

- (IBAction)showAspectRatioOptions:(id)sender {
    NSButton* item = (NSButton *)sender;

    // Show popover
    [self.aspectRatiosPopover showRelativeToRect:item.bounds
                                     ofView:item
                              preferredEdge:NSMaxYEdge];
}

- (IBAction)handleAspectRatioChange:(id)sender {
    NSInteger aspectRatioTag = [sender tag];
    [NSUserDefaults.standardUserDefaults setInteger:aspectRatioTag forKey:@"LWPlayerAspectRatio"];
    [self applyAspectRatio:[self aspectRatioFromTag:aspectRatioTag] animate:YES];
}

- (NSSize)aspectRatioFromTag:(NSInteger)tag {
    switch (tag) {
        case 0:
            return NSMakeSize(0, 0);
        case 1: // 1:1
            return NSMakeSize(10, 10);
        case 2: // 4:3
            return NSMakeSize(960, 720);
        case 3: // 16:9
            return NSMakeSize(1280, 720);
        default:
            return NSMakeSize(0, 0);
    }
}

- (void)applyAspectRatio:(NSSize)newAspectRatio animate:(BOOL)doAnimate {
    if ( newAspectRatio.height == 0 ) {
        self.window.resizeIncrements = NSMakeSize(1.0, 1.0); // this disables aspect ratio constraints
    }  else {
        CGFloat newWidth = self.window.frame.size.width;
        CGFloat newHeight = self.window.frame.size.height;
        CGFloat aspectRatioNumber = newAspectRatio.width / newAspectRatio.height;
        if ( newWidth > newHeight ) {
            newHeight = newWidth / aspectRatioNumber;
        } else {
            newWidth = newHeight * aspectRatioNumber;
        }

        // Calculate new frame size based on height and new aspect
        NSRect newFrame = NSMakeRect(self.window.frame.origin.x, self.window.frame.origin.y, newWidth, newHeight);
        [self.window setAspectRatio:newAspectRatio];
        [self.window setFrame:newFrame display:YES animate:doAnimate];
    }
}

- (void)showPlayerForLayer:(GSLayer *)layer {
    [self abortExport];
    [self.window makeKeyAndOrderFront:self];
    NSString *layerDisplayName = [layer lw_displayName:YES];

    [self.window setTitle:[NSString stringWithFormat:@"%@ Timeline", layerDisplayName]];
	[self.playerTitle setStringValue:layerDisplayName];
	[self.statusField setStringValue:@"Loading frames..."];
}

- (void)setTemporaryStatusMessage:(NSString *)message time:(CGFloat)seconds {
	if ( _statusTimer ) {
		[_statusTimer invalidate];
	}
	
	[self.statusField setStringValue:message];
	
	_statusTimer = [NSTimer scheduledTimerWithTimeInterval:seconds
														  target:self
														selector:@selector(hideStatus)
														userInfo:nil
														 repeats:NO];
}

- (void)hideStatus {
	[self.statusField setStringValue:@""];
}

- (void)abortExport {
    if ( self.exportController ) {
        [self.exportController abortExportProcess];
        if ( self.exportController.window.sheetParent ) {
            [self.exportController.window.sheetParent endSheet:self.exportController.window returnCode:NSModalResponseCancel];
        }
    }
}

#pragma mark - NSWindowDelegate

- (void)windowDidBecomeKey:(NSNotification *)notification {
    [self.window makeFirstResponder:self];
}

- (void)windowWillClose:(NSNotification *)notification {
    [self abortExport];
    [self.player abortPlayback];
    self.player.timeline = nil;
    self.player.parentGSLayer = nil;

    if ( _overlaysFadeTimer ) {
        [_overlaysFadeTimer invalidate];
    }
    _overlaysFadeTimer = nil;
	
	if ( _statusTimer ) {
		[_statusTimer invalidate];
	}
	_statusTimer = nil;
}

- (void)windowWillEnterFullScreen:(NSNotification *)notification {
	[self disableMaxWidthConstraints];
    // Otherwise, the animation looks messed up with artifacts
}

/*
 * Center player controls & set width to maxWidth if window dimensions exceed maxWidth + margins
 * Otherwise make sure it stickies to window leading/trailing edges
 */
- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)frameSize {
	if ( frameSize.width >= ( self.controlsMaxWidth.constant + self.controlsLeading.constant + self.controlsTrailing.constant ) ) {
	    if ( self.controlsMaxWidth.active ) {
			[self disableMaxWidthConstraints];
        }
	} else if ( self.controlsWidth.active ) {
		[self enableMaxWidthConstraints];
	}

	return frameSize;
}

- (void)windowDidResize:(NSNotification *)notification {
    NSRect windowRect = NSIntegralRect(self.window.frame);
    [self setTemporaryStatusMessage:[NSString stringWithFormat:@"Resized %lux%lu", (NSInteger)windowRect.size.width, (NSInteger)windowRect.size.height] time:1.5];
}

- (void)disableMaxWidthConstraints {
	[self.controlsWidth setActive:YES];
	[self.controlsMaxWidth setActive:NO];
	[self.controlsLeading setActive:NO];
	[self.controlsTrailing setActive:NO];
}

- (void)enableMaxWidthConstraints {
	[self.controlsWidth setActive:NO];
	[self.controlsLeading setActive:YES];
	[self.controlsTrailing setActive:YES];
	[self.controlsMaxWidth setActive:YES];
}

// Hitting ESC should close preview
- (void)keyDown:(NSEvent *)event {
//    if (([event modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask) == NSEventModifierFlagCommand) {
//        if ( [event keyCode] == 0x0F ) { // R key
//        } else {
//            [super keyDown:event];
//        }
//    } else {
        //NSPasteboard *pasteBoard = [NSPasteboard generalPasteboard];
        switch ([event keyCode]) {
            case 53: // ESC
                [self closePlayer:self];
                break;
            case 49: // Space
                [self.player setSpacePressed:YES];
                [self.player setNeedsDisplay:YES];
				//[pasteBoard declareTypes:@[NSStringPboardType] owner:nil];
				//[pasteBoard setString:[self.player.timeline rawDescription] forType:NSStringPboardType];
                break;
            default:
                [super keyDown:event];
                break;
        }
    //}
}

- (void)keyUp:(NSEvent *)event {
    if ([event keyCode] == 49) { // Space
        self.player.spacePressed = NO;
        [self.player setNeedsDisplay:YES];
    } else {
        [super keyDown:event];
    }
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

@end
