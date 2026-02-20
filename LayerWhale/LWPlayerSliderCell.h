//
//  LWPlayerSliderCell.h
//  LayerWhale
//
//  Created by Abdullah Arif on 10/25/18.
//  Copyright © 2018 Abdullah Arif. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface LWPlayerSliderCell : NSSliderCell

@property NSMutableArray<NSNumber *> *checkpoints;

- (void)snapToClosestTickMark:(double)position;

@end
