//
//  LWPrefsViewController.m
//  LayerTimeline
//
//  Created by Abdullah Arif on 8/30/18.
//  Copyright © 2018 Abdullah Arif. All rights reserved.
//

#import "LWPrefsViewController.h"
#import "LWLayerObserver.h"
#import "LWPreferences.h"
@interface LWPrefsViewController ()

@end

@implementation LWPrefsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewWillAppear {
}

- (IBAction)handleResolutionChange:(id)sender {
	LWLayerObserver* layerObserver = [LWLayerObserver perpetualObserver];
	switch ( [sender tag] ) {
		case 1:
			// timelapse
			[layerObserver deactivate];
			break;
        default:
            // high resolution
            [layerObserver activate];
            break;
	}
}

- (IBAction)openWebsite:(id)sender {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:[bundle objectForInfoDictionaryKey:@"productPageURL"]]];
}

- (NSString *)identifier {
	return @"LayerWhalePreferences";
}


@end
