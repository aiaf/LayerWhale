//
// Created by Abdullah Arif on 8/21/18.
// Copyright (c) 2018 Abdullah Arif. All rights reserved.
//

#import <AppKit/AppKit.h>

@interface NSColor (LWUtility)
- (BOOL)lw_isDark;
- (NSColor *)lw_inverted:(BOOL)invert;
@end