//
//  GSAnchor+LWEquality.m
//  LayerWhale
//
//  Created by Abdullah Arif on 10/30/18.
//  Copyright © 2018 Abdullah Arif. All rights reserved.
//

#import "GSAnchor+LWEquality.h"

@implementation GSAnchor (LWEquality)
- (BOOL)lw_isEqualToAnchor:(GSAnchor *)otherAnchor {
	if ( !otherAnchor ) {
		return NO;
	}
	
	if ( [self isEqualTo:otherAnchor] ) {
		return YES;
	}
	
	if ( !NSEqualPoints(self.position, otherAnchor.position) ) {
		return NO;
	}
	
	if ( self.type != otherAnchor.type ) {
		return NO;
	}
	
	return [self.name isEqualToString:otherAnchor.name];
}
@end
