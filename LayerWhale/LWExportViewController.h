//
//  LWExportViewController.h
//  LayerTimeline
//
//  Created by Abdullah Arif on 8/19/18.
//  Copyright © 2018 Abdullah Arif. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "YYImageCoder.h"

@class LWPlayer;

@interface LWExportViewController : NSWindowController<NSWindowDelegate>

@property LWPlayer* player;
@property (weak) IBOutlet NSPopUpButton *formatButton;
@property (weak) IBOutlet NSButton *transparentBackground;
@property (weak) IBOutlet NSPopUpButton *fpsButton;
@property (weak) IBOutlet NSPopUpButton *resolutionButton;
@property (weak) IBOutlet NSTextField *startFrameText;
@property (weak) IBOutlet NSTextField *endFrameText;
@property (weak) IBOutlet NSTextField *loopText;
@property (weak) IBOutlet NSTextField *pauseText;
@property (weak) IBOutlet NSProgressIndicator *progress;
@property (weak) IBOutlet NSTextField *progressText;
@property (weak) IBOutlet NSButton *exportButton;

@property BOOL exportAllTimeline;
@property NSString* imageFilePath;

@property dispatch_block_t exportBlock;

- (YYImageType)exportFormat;
- (NSArray<NSString *>*)exportFormatExtensions:(YYImageType)exportFormat;
- (NSInteger)FPS;
- (CGFloat)resolution;

- (void)abortExportProcess;
- (IBAction)cancelExport:(id)sender;
- (IBAction)performExport:(id)sender;
@end
