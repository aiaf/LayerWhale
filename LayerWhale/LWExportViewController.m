//
//  LWExportViewController.m
//  LayerTimeline
//
//  Created by Abdullah Arif on 8/19/18.
//  Copyright © 2018 Abdullah Arif. All rights reserved.
//

#import "LWExportViewController.h"
#import "LWPlayer.h"
#import "GSLayer+LWTimeline.h"

@interface LWExportViewController ()

@end

@implementation LWExportViewController

- (void)windowDidLoad {
    [super windowDidLoad];
	self.exportAllTimeline = YES;
}

/*
 * WebP is currently disabled in the interface and the WebP framework is unlinked
 * until I can find a recent framework built for macOS and doesn't produce many warnings.
 */
- (YYImageType)exportFormat {
    switch ( self.formatButton.selectedTag ) {
        case 1:
            return YYImageTypeMP4;
        case 2:
            return YYImageTypeWebP;
        case 3:
            return YYImageTypePNG;
        default:
            return YYImageTypeGIF;

    }
}

- (NSArray<NSString *>*)exportFormatExtensions:(YYImageType)exportFormat {
    switch ( exportFormat ) {
        case YYImageTypeGIF:
            return @[@"gif"];
		case YYImageTypeMP4:
			return @[@"mp4", @"mov"];
        case YYImageTypeWebP:
            return @[@"webp"];
        case YYImageTypePNG:
            return @[@"apng", @"png"];
        default:
            return @[@"gif"];
    }
}

- (NSInteger)FPS {
    return self.fpsButton.selectedTag;
}

- (CGFloat)resolution {
	return self.resolutionButton.selectedTag * 1.0;
}

- (BOOL)drawTransparentBackground {
	return self.transparentBackground.state == NSControlStateValueOn;
}

- (IBAction)handleLengthSelection:(id)sender {
	switch ( [sender tag] ) {
		case 0:
			self.exportAllTimeline = YES;
			[self.startFrameText setEnabled:NO];
			[self.endFrameText setEnabled:NO];
			break;
		default:
			self.exportAllTimeline = NO;
			[self.startFrameText setEnabled:YES];
			[self.endFrameText setEnabled:YES];
			break;
	}
}
- (IBAction)handleFormatSelection:(id)sender {
	BOOL enabled = [self exportFormat] != YYImageTypeMP4;
	[self.transparentBackground setEnabled:enabled];
	[self.transparentBackground setHidden:!enabled];
	[self.loopText setEnabled:enabled];
	[self.loopText setIntegerValue:enabled ? 0 : 1];
}

- (IBAction)cancelExport:(id)sender {
	[self abortExportProcess];
	[self.exportButton setEnabled:YES];
    [self.progress setDoubleValue:0.0];
    [self.progress setHidden:YES];
    [self.progressText setStringValue:@""];
    [self.player.window endSheet:self.window returnCode:NSModalResponseCancel];
}

- (void)abortExportProcess {
	if ( self.exportBlock ) {
		dispatch_block_cancel( self.exportBlock );
	}
}

- (IBAction)performExport:(id)sender {
	self.exportBlock = nil;

	[self.progress setDoubleValue:0.0];
    [self.progress setHidden:NO];
	[self.exportButton setEnabled:NO];
	[self.progressText setStringValue:@"Rendering frames..."];

	// Make a shallow copy of frames to avoid mutation-while-enumerating crashes & other race conditions
	NSArray<GSLayer *>* frames = [self.player.timeline.frames copyWithZone:nil];

	// Calculate & clamp start & end frames
	NSUInteger frameCount = [frames count];
	NSUInteger lastPossibleFrameIdx = frameCount-1;
	NSInteger startFrameIdx = self.exportAllTimeline ? 0 : [self.startFrameText integerValue];
	startFrameIdx = startFrameIdx < 0 ? 0 : startFrameIdx;
	NSInteger lastFrameIdx = self.exportAllTimeline ? lastPossibleFrameIdx : [self.endFrameText integerValue];
	lastFrameIdx = lastFrameIdx < 0 ? 0 : lastFrameIdx;
	lastFrameIdx = lastFrameIdx > lastPossibleFrameIdx ? lastPossibleFrameIdx : lastFrameIdx;
	
	if ( startFrameIdx > lastFrameIdx ) {
		startFrameIdx = lastFrameIdx == 0 ? 0 : lastFrameIdx-1;
	}

	// Export profile
    YYImageType exportFormat = [self exportFormat];
    NSInteger targetFPS = [self FPS];
    CGFloat resolutionFactor = [self resolution];
    NSInteger numLoops = [self.loopText integerValue];
    numLoops = numLoops < 0 ? 0 : numLoops;
    NSTimeInterval endFramePause = fmax(LWPlaybackMinInterval, [self.pauseText doubleValue]);
    BOOL drawBackground = ![self drawTransparentBackground];
	CGFloat playbackSpeed = self.player.playbackSpeed; // GIFs cannot handle a speed of 5.0 ~= 0.07/5 = 0.014s per frame

	// Which portion of the view are we going to export?
	NSRect visibleRect = NSIntegralRect([self.player enclosingScrollView].documentVisibleRect);
	NSInteger integralWidth = (NSInteger)visibleRect.size.width;
	NSInteger integralHeight = (NSInteger)visibleRect.size.height;

	// Ensure proper dimensions for width & height for MP4
	// See https://support.brightcove.com/optimal-video-dimensions
	if ( exportFormat == YYImageTypeMP4 ) {
		integralWidth = integralWidth - (integralWidth % 16); // width must be multiples of 16 to fit properly in an mp4
		integralHeight = integralHeight - (integralHeight % 2); // height must be even for best results
	}

	visibleRect = NSMakeRect(visibleRect.origin.x, visibleRect.origin.y, integralWidth, integralHeight);
	
	CGAffineTransform scrollTransform = CGAffineTransformTranslate(CGAffineTransformIdentity, -visibleRect.origin.x, -visibleRect.origin.y);

    __weak typeof(self) weakSelf = self;

    self.exportBlock = dispatch_block_create(0, ^{
		/*
		 * Collect frame durations and determine frame drop rates as per user preferred max FPS
		 * Speed: fast
		 */
		NSTimeInterval lengthSoFar = 0.0;
		NSMutableArray<NSNumber *>* durations = [[NSMutableArray alloc] init];
		NSMutableArray* dropRates = [[NSMutableArray alloc] init];
		NSUInteger currentRunFPS = 0;

		NSInteger idx = -1;
        for ( GSLayer *frame in frames ) {
            idx++;
			
            if ( idx > lastPossibleFrameIdx ) {
                break;
            }

            NSTimeInterval duration = LWPlaybackMinInterval;

            if ( idx+1 < frameCount ) {
                GSLayer *nextFrame = frames[ (NSUInteger)idx+1 ];
                NSTimeInterval timeDifference = [nextFrame lw_editTime] - [frame lw_editTime];

				if ( timeDifference >= LWPlaybackCutoffInterval ) {
                    duration = LWPlaybackMaxInterval;
                } else if ( timeDifference <= LWPlaybackMinInterval && timeDifference > 0.0) {
                    duration = timeDifference;
                }
            }

            [durations addObject:@(duration)];
            lengthSoFar += duration;
            currentRunFPS++;

            if ( targetFPS > 0 && (lengthSoFar >= 1.0 || idx == lastPossibleFrameIdx ) ) {
                [dropRates addObject:@[@(idx), @((NSUInteger)((currentRunFPS + targetFPS / 2)/targetFPS))]]; // rounding integer division (currentFPS/targetFPS)
                currentRunFPS = 0;
                lengthSoFar = 0.0;
            }
        }

        // A drop rate of <= 1 means no frames are dropped
        if ( ![dropRates count] ) {
            [dropRates addObject:@[@(frameCount-1), @(1)]];
        }
		
		if ( dispatch_block_testcancel(weakSelf.exportBlock) ) {
			weakSelf.exportBlock = nil;
			return;
		}

		YYImageEncoder *encoder = [[YYImageEncoder alloc] initWithType:exportFormat];
		encoder.loopCount = (NSUInteger)numLoops;
		encoder.widthHint = (NSInteger)visibleRect.size.width;
		encoder.heightHint = (NSInteger)visibleRect.size.height;
		encoder.resolution = (NSInteger)resolutionFactor;

        /*
         * Render or drop frames according to calculated drop rates
         * Speed: moderate
         */
        NSUInteger dropIdx = 0;
		idx = -1;
		for ( GSLayer *frame in frames ) {
			idx++;

            if ( idx > lastFrameIdx ) {
                break;
            }

            NSUInteger dropUntilIdx = [dropRates[ dropIdx ][0] unsignedIntegerValue];
            NSUInteger dropRate = [dropRates[ dropIdx ][1] unsignedIntegerValue];

            if ( idx == dropUntilIdx ) {
                dropIdx++;
            }

            if ( dropRate > 1 && idx%dropRate != 0 ) {
                continue;
            }
			
			if ( idx < startFrameIdx ) {
				continue;
			}

			NSBitmapImageRep *pixelCorrectImageRep = [[NSBitmapImageRep alloc]
									 initWithBitmapDataPlanes:NULL
									 pixelsWide:(NSInteger)(visibleRect.size.width * resolutionFactor)
									 pixelsHigh:(NSInteger)(visibleRect.size.height * resolutionFactor)
									 bitsPerSample:8
									 samplesPerPixel:4
									 hasAlpha:YES
									 isPlanar:NO
									 colorSpaceName:NSCalibratedRGBColorSpace
									 bytesPerRow:0
									 bitsPerPixel:0];
			pixelCorrectImageRep.size = visibleRect.size;

			[NSGraphicsContext saveGraphicsState];
			[NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:pixelCorrectImageRep]];
			CGContextRef ctx = [NSGraphicsContext currentContext].CGContext;
			CGContextConcatCTM(ctx, scrollTransform);

			if ( drawBackground ) {
				CGContextSetFillColorWithColor(ctx, weakSelf.player.backgroundColor.CGColor);
				CGContextFillRect(ctx, visibleRect);
			}

			[weakSelf.player setContextGSLayer:frame];
			[weakSelf.player drawRect:visibleRect];
			[NSGraphicsContext restoreGraphicsState];

			NSImage *imageFrame = [[NSImage alloc] initWithSize:visibleRect.size];
			[imageFrame addRepresentation:pixelCorrectImageRep];

			[encoder addImage:imageFrame duration:[durations[ idx ] doubleValue] / playbackSpeed];

            if ( dispatch_block_testcancel(weakSelf.exportBlock) ) {
				weakSelf.exportBlock = nil;
				return;
            }

			if ( idx%10 == 0 ) {
				dispatch_async(dispatch_get_main_queue(), ^(void) {
					[weakSelf.progress setDoubleValue:(idx+1.0)/(double)frameCount*100.0];
				});
			}
		}

		if ( dispatch_block_testcancel(weakSelf.exportBlock) ) {
			weakSelf.exportBlock = nil;
			return;
		}

		/*
		 * Set last frame duration according to user preference
		 */
		if ( [encoder.durations count] ) {
			/*
			 * MP4 works by setting a time on which to display a frame, unlike other types which work by duration
			 * Make it pause with multiples half-second frames for best playback & compression results
			 * This is by trial & error that I figured this out.
			 */
            if ( exportFormat == YYImageTypeMP4 ) {
            	if ( endFramePause <= 0.5 ) {
					encoder.durations[[encoder.durations count] - 1] = @(endFramePause);
					[encoder addImage:encoder.images.lastObject duration:endFramePause];
            	} else {
					NSInteger multiples = (NSInteger)(endFramePause / 0.5 + 0.5); // rounded up
					for (NSInteger i = 0; i < multiples; i++) {
						[encoder addImage:encoder.images.lastObject duration:0.5];
					}
				}
            } else {
				encoder.durations[[encoder.durations count] - 1] = @(endFramePause);
            }
		}

		/*
		 * Encode frames into destination file
		 * Speed: slow
		 */
		dispatch_sync(dispatch_get_main_queue(), ^(void) {
			[weakSelf.progress setDoubleValue:0.0];
			[weakSelf.progressText setStringValue:@"Encoding..."];
		});

		[encoder setProgressHandler:^(NSUInteger itemIdx, NSUInteger itemCount, BOOL *stop) {
			if ( dispatch_block_testcancel(weakSelf.exportBlock) ) {
				*stop = YES;
				return;
			}
			
			if ( itemIdx%10 == 0 ) {
				dispatch_async(dispatch_get_main_queue(), ^(void) {
					[weakSelf.progress setDoubleValue:(itemIdx+1.0)/(double)itemCount*100.0];
				});
			}

			if ( itemIdx == itemCount-1 ) {
				dispatch_async(dispatch_get_main_queue(), ^(void) {
					[weakSelf.progressText setStringValue:@"Finalizing file..."];
				});
			}
		}];

		[encoder setCompletionHandler:^(void){
            if ( dispatch_block_testcancel(weakSelf.exportBlock) ) {
				weakSelf.exportBlock = nil;
                return;
            }

            dispatch_sync(dispatch_get_main_queue(), ^(void) {
                weakSelf.progress.doubleValue = 0.0;
                weakSelf.progress.hidden = YES;
                weakSelf.progressText.stringValue = @"";
                weakSelf.exportButton.enabled = YES;
            });
        }];

        [encoder setSuccessHandler:^(void){
            // We now have the rendered animation stored in a temp file
            dispatch_sync(dispatch_get_main_queue(), ^(void) {
                [weakSelf.player.window endSheet:weakSelf.window returnCode:NSModalResponseOK];
            });
        }];

        [encoder setFailureHandler:^(void){
            dispatch_sync(dispatch_get_main_queue(), ^(void) {
                [weakSelf.progressText setStringValue:@"Export failed, try again"];
            });
        }];

		weakSelf.imageFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];

        [encoder encodeToFile:self.imageFilePath];
	});

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), self.exportBlock);
}

#pragma mark - NSWindowDelegate

- (void)windowWillClose:(NSNotification *)notification {
	[self abortExportProcess];
}

- (void)dealloc {
	self.exportBlock = nil;
	self.player = nil;
}

@end
