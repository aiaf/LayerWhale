//
//  GSAnchor+LWEquality.h
//  LayerWhale
//
//  Created by Abdullah Arif on 10/30/18.
//  Copyright © 2018 Abdullah Arif. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GlyphsCore/GSAnchor.h>

@interface GSAnchor (LWEquality)
- (BOOL)lw_isEqualToAnchor:(GSAnchor *)otherAnchor;
@end
