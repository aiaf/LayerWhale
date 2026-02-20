//
//  LWTimelinePalette.m
//  LWTimelinePalette
//
//  Created by Abdullah Arif on 6/21/18.
//  Copyright © 2018 Abdullah Arif. All rights reserved.
//

#import "LWTimelinePalette.h"
#import "LWLayerObserver.h"
#import <GLyphsCore/GSWindowControllerProtocol.h>
#import <CoreImage/CoreImage.h>


//@class GSCollectionViewItemView;
// GSCollectionViewItemView is the cell that contains the glyph in the glyph list

static void * LWTimelinePaletteContext = &LWTimelinePaletteContext;

/*
 * GSDocument and GSApplication have no visible interfaces
 * but they are present
*/

@interface NSApplication (LWGSKnownInterface)
- (NSDocument*)currentFontDocument;
@end

@interface NSDocument (LWGSKnownInterface)
- (GSFont*)font;
@end

@interface NSBundle (NibLoading)
+ (NSArray *)loadNibNamed:(NSString *)nibName owner:(id)owner error:(NSError **)error;
@end

CIFilter *LWRecordButtonOnCIFilter() {
    static CIFilter *filter = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        filter = [CIFilter filterWithName:@"CIFalseColor"];
        [filter setDefaults];
        [filter setValue:[CIColor colorWithRed:0.905 green:0.1 blue:0.06 alpha:1.0] forKey:@"inputColor0"]; // dark red
        [filter setValue:[CIColor colorWithRed:1.0 green:0.897 blue:0.878 alpha:1.0] forKey:@"inputColor1"]; // light red
//        [filter setValue:[CIColor colorWithRed:1.0 green:0.964 blue:0.708 alpha:1.0] forKey:@"inputColor1"]; // yellow
        [filter setValue:nil forKey:kCIInputImageKey];
    });

    return filter;
}

CIFilter *LWRecordButtonOnCIFilterDarkAppearance() {
    static CIFilter *filterDark = nil;
    static dispatch_once_t tokenDark;
    dispatch_once(&tokenDark, ^{
        filterDark = [CIFilter filterWithName:@"CIWhitePointAdjust"];
        [filterDark setDefaults];
        [filterDark setValue:[CIColor colorWithRed:0.765 green:0.260 blue:0.272 alpha:1.0] forKey:kCIInputColorKey]; // dark red
        [filterDark setValue:nil forKey:kCIInputImageKey];
    });

    return filterDark;
}

@implementation LWTimelinePalette

@synthesize windowController;

/*
 * TODO fix this for multiple docs. should a single init? should provide context?
 */

- (id)init {
	self = [super init];

	if ( self ) {
        _activeTimeline = nil;
        _layerObservers = [[NSMutableArray alloc] init];
        _cleanToken = 0;
        _selectedLayersCount = 0;
        
	    // Preferences watcher singleton will remain in memory for the lifetime of the application.
        [LWPreferences sharedPreferences];

        [self performPluginMigrations];
        [self performFileMigrations];

        [NSBundle loadNibNamed:@"LWTimelinePalette" owner:self error:nil];

        /*
		 * This observer and preference watcher singletons will remain in memory for the lifetime of the application.
         * They are destroyed only when the application exits.
		 * Instantiate them as soon as the plugin is first loaded.
		 */		
        LWLayerObserver* layerObserver = [LWLayerObserver perpetualObserver];
		
		if ( [LWPreferences sharedPreferences].highResolutionRecording ) {
			[layerObserver activate];
		} else {
			[layerObserver deactivate];
		}

        // Todo: sometimes after a crash, the same glyph document is opened twice and there would
        // two instances shown. need to figrue out a way to register for only a unique font
        GSFont *currentFont = [[NSApp currentFontDocument] font];
        [self observerLayerChangesOnGlyphs:currentFont.glyphs];

        // if palette is loaded twice consecutively for the same font, the interfaceDidUpdate from the 1st palette will
        // get invoked for the second set of glyphs that are still not primed and prepared
        // hence things like .lw_timeline will crash
        // GSUpdateInterface can come from GSFont and GSWindowController
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(documentDidClose:) name:@"GSDocumentCloseNotification" object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(interfaceDidUpdate:) name:@"GSUpdateInterface" object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(interfaceDidUpdate:) name:@"GSDocumentActivateNotification" object:nil];

		[self addObserver:self forKeyPath:@"activeTimeline.recording" options:NSKeyValueObservingOptionNew context:&LWTimelinePaletteContext];
		[self addObserver:self forKeyPath:@"activeTimeline.lastChange" options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew context:&LWTimelinePaletteContext];

		[self.optionsButton setMenu:self.optionsMenu forSegment:0];
    }

    return self;
}

- (void)observeValueForKeyPath:(nullable NSString *)keyPath ofObject:(nullable id)object change:(nullable NSDictionary<NSKeyValueChangeKey, id> *)change context:(nullable void *)context {
	if ( context == LWTimelinePaletteContext ) {
		if ( [keyPath isEqualToString:@"activeTimeline.recording"] ) {
			BOOL isRecording =  ![change[NSKeyValueChangeNewKey] isEqual:[NSNull null]] && [change[NSKeyValueChangeNewKey] boolValue];
			
			if ( isRecording ) {
			    self.recordButton.state = NSControlStateValueOn;
				if ( ![self.recordButton.contentFilters count] ) {
					if (@available(macOS 10.14, *)) {
						if ( self.theView.effectiveAppearance.name == NSAppearanceNameDarkAqua ) {
							[self.recordButton setContentFilters:@[LWRecordButtonOnCIFilterDarkAppearance()]];
						} else {
							[self.recordButton setContentFilters:@[LWRecordButtonOnCIFilter()]];
						}
					} else {
						[self.recordButton setContentFilters:@[LWRecordButtonOnCIFilter()]];
					}
				}
			} else {
                self.recordButton.state = NSControlStateValueOff;
				if ( [self.recordButton.contentFilters count] ) {
					[self.recordButton setContentFilters:@[]];
				}
			}
		} else if ( [keyPath isEqualToString:@"activeTimeline.lastChange"]  ) {
		    [self updateLastChangeString:change[NSKeyValueChangeNewKey]];
        }
	}
}

- (void)updateLastChangeString:(id)value {
	if ( _statusTimer && _statusTimer.isValid ) {
		return;
	}
	
    NSString *reflectedString = @"";
    if ( ![value isEqual:[NSNull null]] ) {
        NSTimeInterval lastChange = [value doubleValue];

        if ( lastChange != 0 ) {
            NSDate *lastChangeDate = [NSDate dateWithTimeIntervalSince1970:lastChange];
            reflectedString = [self.lastChangeFormatter stringFromDate:lastChangeDate];
        }
    }

    [self.statusField setStringValue:reflectedString];
}

- (void)interfaceDidUpdate:(NSNotification *)userInfo {
    //NSLog(@"interfaceDidUpdate %@ glyph %@ layer %@", userInfo, self.windowController.activeLayer.glyph.name, self.windowController.activeLayer.layerId);

    NSUInteger selectedLayerCountNewCount = [[self.windowController selectedLayers] count];

    // We do not wish to trigger redundant KVO, because this method gets called a lot
    if ( selectedLayerCountNewCount != self.selectedLayersCount ) {
        self.selectedLayersCount = selectedLayerCountNewCount;
    }

    /*
     * If multiple layers/none selected i.e. -activeLayer returns nil,
     * then there should be no active timeline
     */
	GSLayer *activeLayer = [self.windowController activeLayer];
    LWTimeline *timeline = nil;

    if ( activeLayer && [activeLayer lw_hasTimeline] ) {
        timeline = [activeLayer lw_timeline];

        /*
         * When a layer & its timeline get copied, they don't automatically register for undo changes
         * So this partially fixes that. todo: investigate properly. What if multiple layers selected?
         */
        if ( timeline.isRecording ) {
            if ( ![activeLayer lw_observed] ) {
                [self observerUndoManagerNotificationsForLayer:activeLayer];
            }
        }
    }
    
    if ( self.activeTimeline != timeline ) {
        self.activeTimeline = timeline;
    }
}

- (void)documentDidClose:(NSNotification *)userInfo {
    //NSLog(@"documentClose %@", userInfo);
	if ( !userInfo || !self.windowController || self.windowController == userInfo.object ) {
        [self _cleanup];
    }
}

- (void)observerLayerChangesOnGlyphs:(NSArray<GSGlyph *> *)glyphs {
    for ( GSGlyph *glyph in glyphs ) {
        for ( NSString* layerId in glyph.layers ) {
            GSLayer* layer = glyph.layers[ layerId ];

            if ( ![layer lw_hasTimeline] ) {
                continue;
            }

            if ( ![layer lw_timeline].isRecording ) {
                continue;
            }

            [self observerUndoManagerNotificationsForLayer:layer];
        }
    }
}

/*
 * The NSUndoManager is unique to each glyph, not to each layer
 * So we need to know for which layer the observer is created by
 * capturing the value of the layer at the time the closure is created.
 *
 * Maintain a weak reference to the layer to avoid retain cycles
 * We shouldn't own the layer
 * If it gets deleted and the observer is invoked, we check for nil.
 *
 * NSUndoManagerCheckpointNotification will give us correct notifications on any change that happens to the layer
 * e.g. componenets/anchors/guidelines, as opposed to layer callbacks which only pertain to paths.
 *
 * This is triggered before processBezier:.. callbacks, and those do in reality interrupt this call here, since I bel
 *
 */
- (void)observerUndoManagerNotificationsForLayer:(GSLayer *)layer {

    if ( layer.lw_observed ) {
        return;
    }

    [layer setLw_observed:YES];

    __block GSLayer * __weak weakLayer = layer;

    id observer = [NSNotificationCenter.defaultCenter addObserverForName:NSUndoManagerWillCloseUndoGroupNotification //NSUndoManagerCheckpointNotification
                                                                  object:[layer undoManager]
                                                                   queue:[NSOperationQueue mainQueue]
                                                              usingBlock:^(NSNotification *notification) {
                                                                  //NSLog(@"UNDO CHECKPOINT for %@", weakLayer.glyph.name);
                                                                  if ( weakLayer && [weakLayer lw_hasTimeline] ) {
                                                                      LWTimeline *timeline = [weakLayer lw_timeline];
                                                                      if ( timeline.isRecording ) {
                                                                          //NSLog(@"UNDO isRecording and will do");
                                                                          NSTimeInterval editTime = [[NSDate date] timeIntervalSince1970];
                                                                          dispatch_async(dispatch_get_main_queue(), ^{
                                                                              [timeline recordLayer:weakLayer atTime:editTime];
                                                                          });
                                                                      }
                                                                  }
                                                              }
    ];

    [self.layerObservers addObject:observer];
}


#pragma mark Binding helpers
#pragma mark -

+ (NSSet<NSString *> *)keyPathsForValuesAffectingDeleteButtonVisible {
    return [NSSet setWithArray:@[@"selectedLayersCount", @"activeTimeline"]];
}

/*
 * This bound to the delete button's .hidden property in IB
 */
- (BOOL)deleteButtonVisible {
    if ( self.selectedLayersCount > 1 ) {
        NSArray *selectedLayers = [self.windowController selectedLayers];

        for ( GSLayer *layer in selectedLayers ) {
            if ([layer lw_hasTimeline] ) {
                return YES;
            }
        }

        return NO;
    }

    return self.activeTimeline != nil;
}

#pragma mark Actions
#pragma mark -

- (IBAction)toggleRecordingOnSelectedLayers:(id)sender {
    NSArray* targetLayers = [self.windowController selectedLayers];
    NSUInteger layerCount = [targetLayers count];

    if ( !layerCount ) {
        return;
    }

	BOOL doRecord = [(NSButton*)sender state] == NSControlStateValueOn;
    BOOL doToggle = NO;

    if ( layerCount > 1) {
        NSUInteger numRecording = 0;
        NSUInteger numNotRecording = 0;

        for ( GSLayer *layer in targetLayers ) {
            if ([layer lw_hasTimeline] && [layer lw_timeline].isRecording ) {
                numRecording++;
            } else {
                numNotRecording++;
            }
        }

        NSAlert *alert = [[NSAlert alloc] init];

        if ( numRecording == 0 ) {
            [alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to turn on recording for %lu layers?", nil), numNotRecording]];
            [alert addButtonWithTitle:NSLocalizedString(@"Turn on", nil)];
            [alert addButtonWithTitle:NSLocalizedString(@"Nevermind", nil)];
            if ( [alert runModal] == NSAlertFirstButtonReturn ) {
                doRecord = YES;
            } else {
                return;
            }
        } else if ( numNotRecording == 0 ) {
            [alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to turn off recording for %lu layers?", nil), numRecording]];
            [alert addButtonWithTitle:NSLocalizedString(@"Turn off recording", nil)];
            [alert addButtonWithTitle:NSLocalizedString(@"Nevermind", nil)];
            if ( [alert runModal] == NSAlertFirstButtonReturn ) {
                doRecord = NO;
            } else {
                return;
            }
        } else {
            [alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"%lu layers selected. How do you want to record?", nil), layerCount]];
            [alert addButtonWithTitle:NSLocalizedString(@"All ON", nil)];
            [alert addButtonWithTitle:NSLocalizedString(@"All OFF", nil)];
            [alert addButtonWithTitle:NSLocalizedString(@"Toggle", nil)];
            [alert addButtonWithTitle:NSLocalizedString(@"Nevermind", nil)];

            NSModalResponse response = [alert runModal];

            if ( response == NSAlertFirstButtonReturn ) {
                doRecord = YES;
            } else if ( response == NSAlertSecondButtonReturn ) {
                doRecord = NO;
            } else if ( response == NSAlertThirdButtonReturn ) {
                doToggle = YES;
            } else {
                return;
            }
        }
    }

    GSLayer *firstLayer = targetLayers[0];

    for ( GSLayer* layer in targetLayers ) {
        LWTimeline *timeline;
        
        if ( ![layer lw_hasTimeline] ) {
            if ( doRecord || doToggle ) {
                //NSLog(@"new timeline: this.Layer glyph %@ id %@", layer.glyph.name, layer.layerId);

               // [[layer undoManager] beginUndoGrouping];
                timeline = [[LWTimeline alloc] init];
                [layer lw_setTimeline:timeline];
                //[[layer undoManager] endUndoGrouping];
                [self observerUndoManagerNotificationsForLayer:layer];
            }
        } else {
            timeline = [layer lw_timeline];
        }

        if ( !timeline ) {
            continue;
        }
        
        if ( layerCount == 1 && layer == firstLayer ) {
            self.activeTimeline = timeline; 
        }

        [timeline toggleRecording:doToggle ? !timeline.isRecording : doRecord inLayer:layer];
    }
}


- (IBAction)playActiveLayerTimeline:(id)sender
{
    // If multiple selected players, play the first one
    GSLayer *activeLayer = [self.windowController.selectedLayers firstObject];
    
    if ( !activeLayer ) {
        return;
    }

    [self showPlayerWindow];

    if ([activeLayer lw_hasTimeline] ) {
        LWPlayer *player = self.playerController.player;
        
        /*
         * if we toggle immediately, it might feel as though the button is stuck--
         * togglePlay: is heavy (calculates extents and duration)
         * So delay the heavy lifting until the player is visible
         * (i.e. all other threads have finished executing)
         */
        [player setNeedsDisplay:YES];
        dispatch_async(dispatch_get_main_queue(), ^{
            [player loadTimeline:[activeLayer lw_timeline] forLayer:activeLayer];
            [player togglePlay:YES];
        });
    }
}

- (IBAction)deleteTimeline:(id)sender {
    NSArray<GSLayer *>* targetLayers = [self.windowController selectedLayers];

    if ( ![targetLayers count] ) {
        return;
    }

    NSInteger numLayersWithTimeline = 0;

    for ( GSLayer* layer in targetLayers ) {
        if ([layer lw_hasTimeline] ) {
            numLayersWithTimeline++;
        }
    }

    if ( numLayersWithTimeline == 0 ) {
        return;
    }

    NSAlert *alert = [[NSAlert alloc] init];

    if ( numLayersWithTimeline == 1 ) {
		[alert setMessageText:[NSString stringWithFormat:@"Are you sure you want to delete the timeline for %@?", [targetLayers[0] lw_displayName:YES]]];
        [alert setInformativeText:[NSString stringWithFormat:@"%@ frame(s) will be deleted.", [@( [[targetLayers[0] lw_timeline] fastFrameCount] ) descriptionWithLocale:[NSLocale currentLocale]]]];
    } else {
        [alert setMessageText:[NSString stringWithFormat:@"Are you sure you want to delete %lu timelines in the selected layers?", numLayersWithTimeline]];
    }

    [alert addButtonWithTitle:NSLocalizedString(@"Delete", nil)];
    [alert addButtonWithTitle:NSLocalizedString(@"Nevermind", nil)];

    if ( [alert runModal] != NSAlertFirstButtonReturn ) {
        return;
    }

    for ( GSLayer *layer in targetLayers ) {
        if ( ![layer lw_hasTimeline] ) {
            continue;
        }

        /*
         * Why isn't this nil'd for us automagically if set weak? If we don't nil it, KVO on playhead and frameCount crashes
         * This will cleanup everything, we shouldn't keep the player open, it's confusing.
         */

        LWTimeline *timeline = [layer lw_timeline];

        if ( self.playerController && self.playerController.player ) {
            if (self.playerController.player.timeline == timeline) {
                [self.playerController closePlayer:self];
            }
        }

        if ( timeline == self.activeTimeline ) {
            self.activeTimeline = nil;
        }

        /*
         * Using removeUserDataForKey: ensures that user can undo delete
         * and will retain the timeline in the undo stack.
         * Whereas deleting the object from userData directly deallocates the timeline.
         */
        [layer removeUserDataForKey:LWUserDataKeyTimeline];
    }
}

- (IBAction)makeCheckpoint:(id)sender {
    NSArray* targetLayers = [self.windowController selectedLayers];
    NSUInteger layerCount = [targetLayers count];

    if ( !layerCount ) {
        return;
    }

    if ( layerCount > 1 ) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to add checkpoints to %lu timelines?", nil), layerCount]];
        [alert addButtonWithTitle:NSLocalizedString(@"Add", nil)];
        [alert addButtonWithTitle:NSLocalizedString(@"Nevermind", nil)];

        if ( [alert runModal] != NSAlertFirstButtonReturn ) {
            return;
        }
    }

    GSLayer *firstLayer = targetLayers[0];

    for ( GSLayer* layer in targetLayers ) {
        LWTimeline *timeline;

        if ( ![layer lw_hasTimeline] ) {
            timeline = [[LWTimeline alloc] init];
            [layer lw_setTimeline:timeline];
        } else {
            timeline = [layer lw_timeline];
        }

        if ( layerCount == 1 && layer == firstLayer ) {
            self.activeTimeline = timeline;
        }

        [timeline makeCheckpointFromLayer:layer];
    }

    [self setTemporaryStatusMessage:@"Checkpoint added!" time:2.0];
}

- (IBAction)revertToLastCheckpoint:(id)sender {
    GSLayer *activeLayer = [self.windowController.selectedLayers firstObject];

    if ( !activeLayer || ![activeLayer lw_hasTimeline] ) {
        return;
    }

    // First determine if there's anything to reset to before doing heavy lifting
    LWTimeline *currentTimeline = [activeLayer lw_timeline];
    NSInteger lastCheckpointIndex = [currentTimeline frameIndexOfLastCheckpoint:0];

    // No checkpoint was found, abort
    if ( lastCheckpointIndex == -1 ) {
        [self setTemporaryStatusMessage:@"No checkpoints to revert to" time:2.0];
        return;
    }

    BOOL reloadTimeline = NO;

    // Abort playback if our timeline is playing
    if ( self.playerController && self.playerController.player && self.playerController.player.timeline == currentTimeline ) {
        [self.playerController.player abortPlayback];
        reloadTimeline = YES;
    }

    /*
     * Now make a copy of the timeline,
     * reset it to the checkpoint,
     * then replace the current layer with the checkpoint layer
     * then assign the amended timeline to the checkpoint layer
     */
    BOOL checkpointIsLastFrame = lastCheckpointIndex == [currentTimeline fastFrameCount]-1;
    NSInteger checkpointIndex = lastCheckpointIndex;
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];

    /*
     * Sometimes a user wants to breakthrough a checkpoint to the one preceding it
     * This logic looks for that behaviour
     */
    if ( checkpointIsLastFrame ) {
        if ( now - currentTimeline.checkpointResisted < 2.0 ) {
            NSInteger penultimateCheckpointIndex = [currentTimeline frameIndexOfLastCheckpoint:1];
            if ( penultimateCheckpointIndex != -1 ) {
                checkpointIndex = penultimateCheckpointIndex;
            }
        } else {
            currentTimeline.checkpointResisted = now;
        }
    }

    LWTimeline *resetTimeline = [currentTimeline copy];
    [resetTimeline resetToFrame:checkpointIndex parentLayer:activeLayer];

    GSLayer *layerAtCheckpoint = [resetTimeline frameAtIndex:checkpointIndex parentLayer:activeLayer];
    [layerAtCheckpoint lw_rawRemoveUserDataForKey:LWUserDataKeyCheckpoint];
	[layerAtCheckpoint lw_rawSetUserData:resetTimeline forKey:LWUserDataKeyTimeline];

    [activeLayer.glyph setLayer:layerAtCheckpoint forKey:activeLayer.layerId];
    
    if ( resetTimeline.isRecording ) {
        [self observerUndoManagerNotificationsForLayer:layerAtCheckpoint];
    }

    NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"MMM d YY, HH:mm:ss"]; // Jun 8 18, 16:31:13
    NSDate* checkpointDate = [NSDate dateWithTimeIntervalSince1970:[layerAtCheckpoint lw_editTime]];

    [self setTemporaryStatusMessage:[NSString stringWithFormat:@"Reset to %@", [dateFormatter stringFromDate:checkpointDate]] time:2.0];

    if ( reloadTimeline ) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.playerController.player loadTimeline:[layerAtCheckpoint lw_timeline] forLayer:layerAtCheckpoint];
        });
    }
}

- (IBAction)showPluginPreferences:(id)sender {
    SEL prefSel = NSSelectorFromString(@"showMainPreferencesWithIdentifier:");
    
    if ( [NSApp.delegate respondsToSelector:prefSel] ) {
        [NSApp.delegate performSelector:prefSel withObject:LWPreferencesPanelIdentifier];
    }
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
    if ( _statusTimer && _statusTimer.isValid ) {
        [_statusTimer invalidate];
    }

    [self.statusField setStringValue:@""];
    
	if ( self.activeTimeline ) {
        [self updateLastChangeString:@(self.activeTimeline.lastChange)];
    }
}

#pragma mark -

- (void)showPlayerWindow {
    if ( self.playerController == nil ) {
        self.playerController = [[LWPlayerController alloc] initWithWindowNibName:@"LWPlayer"];
    }

    [self.playerController showPlayerForLayer:self.windowController.activeLayer];
}

#pragma mark NSObject Lifecycle
#pragma mark -

- (void)dealloc {
    [self _cleanup];
}

/*
 * We may only invoke this method once, either on document close, or palette dealloc
 * whichever comes first.
 * Otherwise app will crash if attempting to remove non-existent observers.
 */
- (void)_cleanup {

    if ( _cleanToken == 1 ) {
        return;
    }

    [self removeObserver:self forKeyPath:@"activeTimeline.recording" context:&LWTimelinePaletteContext];
    [self removeObserver:self forKeyPath:@"activeTimeline.lastChange" context:&LWTimelinePaletteContext];

    [NSNotificationCenter.defaultCenter removeObserver:self];

    for ( id observer in self.layerObservers ) {
        [NSNotificationCenter.defaultCenter removeObserver:observer];
    }

    [self.layerObservers removeAllObjects];

    self.activeTimeline = nil;
    self.selectedLayersCount = 0;

    if ( self.playerController ) {
        [self.playerController closePlayer:nil];
    }
	
	if ( _statusTimer ) {
		[_statusTimer invalidate];
	}
	_statusTimer = nil;

    _cleanToken = 1;
}

#pragma mark - Migrations

- (NSString *)pluginVersion {
    return [[NSBundle bundleForClass:[self class]] infoDictionary][@"CFBundleShortVersionString"];
}

- (NSString *)pluginBuildNumber {
    return [[NSBundle bundleForClass:[self class]] infoDictionary][@"CFBundleVersion"];
}

- (void)performPluginMigrations
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    //NSString *lastInstalledAppVersion = [defaults stringForKey:@"LWLastVersion"];

    // do migrations if updating from 1005
    //if ([lastInstalledAppVersion isEqualToString:@"1005"]) { }

    if ( [[defaults stringForKey:@"LWFirstVersion"] isEqualToString:@"0"] ) {
        [defaults setObject:[self pluginBuildNumber] forKey:@"LWFirstVersion"];
    }

    [defaults setObject:[self pluginBuildNumber] forKey:@"LWLastVersion"];
}

- (void)performFileMigrations {
    static NSString *pluginVersionKey = @"LWPluginVersion";
    GSFont *currentFont = [[NSApp currentFontDocument] font];

    NSString *currentVersion = [self pluginBuildNumber]; // or convert to NSUInteger
    BOOL didMigrate = NO;

    //    NSString *fontPreviouslySavedWith = [currentFont userDataForKey:pluginVersionKey];
//    // do file migrations for fonts saved with xxxx
//    if ([fontPreviouslySavedWith isEqualToString:@"1001"]) {
//        // do file migrations for 1.0.0
//        didMigrate = YES;
//        // set newly savedwith version and trigger dirty state/undo
//        [currentFont setUserData:currentVersion forKey:pluginVersionKey];
//    }

    // If no migrations, lazily set the plugin version with the next document save if any
    if ( !didMigrate ) {
        [currentFont.undoManager disableUndoRegistration];
        [currentFont setUserData:currentVersion forKey:pluginVersionKey];
        [currentFont.undoManager enableUndoRegistration];
    }
}

#pragma mark GlyphsPalette Protocol
#pragma mark -

- (NSUInteger)interfaceVersion {
	// Distinguishes the API version the plugin was built for. Return 1.
	return 2;
}

- (NSString*)title {
	// Return the name of the tool as it will appear in the menu.
	return @"Layer Timeline";
}

- (NSInteger)maxHeight {
	return 265;
}

- (NSInteger)minHeight {
	return 60;
}

- (NSUInteger)currentHeight {
	return 60;
}

- (NSUInteger)sortID {
    return 40;
}
@end
