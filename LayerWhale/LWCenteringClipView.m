//
// Created by Abdullah Arif on 7/9/18.
// Copyright (c) 2018 Abdullah Arif. All rights reserved.
//
// Translated from https://developer.apple.com/library/archive/samplecode/Exhibition/Listings/Exhibition_CenteringClipView_swift.html
//

#import "LWCenteringClipView.h"

@implementation LWCenteringClipView

- (NSRect)constrainBoundsRect:(NSRect)proposedBounds {

    NSRect newClipBoundsRect = [super constrainBoundsRect:proposedBounds];

    if ( !self.documentView )  {
        return newClipBoundsRect;
    }

    // Get the `contentInsets` scaled to the future bounds size.
    NSEdgeInsets insets = [self convertedContentInsetsToProposedBoundsSize:newClipBoundsRect.size];

    // Get the insets in terms of the view geometry edges, accounting for flippedness.
    CGFloat minYInset = self.isFlipped ? insets.top : insets.bottom;
    CGFloat maxYInset = self.isFlipped ? insets.bottom : insets.top;
    CGFloat minXInset = insets.left;
    CGFloat maxXInset = insets.right;

    /*
        Get and outset the `documentView`'s frame by the scaled contentInsets.
        The outset frame is used to align and constrain the `newClipBoundsRect`.
    */
    NSRect documentFrame = self.documentView.frame;
    NSRect outsetDocumentFrame = NSMakeRect(
            NSMinX(documentFrame) - minXInset,
            NSMinY(documentFrame) - minYInset,
            (documentFrame.size.width + (minXInset + maxXInset)),
            documentFrame.size.height + (minYInset + maxYInset)
    );

    if (newClipBoundsRect.size.width > outsetDocumentFrame.size.width) {
        /*
            If the clip bounds width is larger than the document, center the
            bounds around the document.
        */
        newClipBoundsRect.origin.x = NSMinX(outsetDocumentFrame) - (newClipBoundsRect.size.width - outsetDocumentFrame.size.width) / 2.0;
    }
    else if (newClipBoundsRect.size.width < outsetDocumentFrame.size.width) {
        /*
            Otherwise, the document is wider than the clip rect. Make sure that
            the clip rect stays within the document frame.
        */
        if (NSMaxX(newClipBoundsRect) > NSMaxX(outsetDocumentFrame)) {
            // The clip rect is outside the maxX edge of the document, bring it in.
            newClipBoundsRect.origin.x = NSMaxX(outsetDocumentFrame) - newClipBoundsRect.size.width;
        }
        else if (NSMinX(newClipBoundsRect) < NSMinX(outsetDocumentFrame)) {
            // The clip rect is outside the minX edge of the document, bring it in.
            newClipBoundsRect.origin.x = NSMinX(outsetDocumentFrame);
        }
    }

    if (newClipBoundsRect.size.height > outsetDocumentFrame.size.height) {
        /*
            If the clip bounds height is larger than the document, center the
            bounds around the document.
        */
        newClipBoundsRect.origin.y = NSMinY(outsetDocumentFrame) - (newClipBoundsRect.size.height - outsetDocumentFrame.size.height) / 2.0;
    }
    else if (newClipBoundsRect.size.height < outsetDocumentFrame.size.height) {
        /*
            Otherwise, the document is taller than the clip rect. Make sure
            that the clip rect stays within the document frame.
        */
        if (NSMaxY(newClipBoundsRect) > NSMaxY(outsetDocumentFrame)) {
            // The clip rect is outside the maxY edge of the document, bring it in.
            newClipBoundsRect.origin.y = NSMaxY(outsetDocumentFrame) - newClipBoundsRect.size.height;
        }
        else if (NSMinY(newClipBoundsRect) < NSMinY(outsetDocumentFrame)) {
            // The clip rect is outside the minY edge of the document, bring it in.
            newClipBoundsRect.origin.y = NSMinY(outsetDocumentFrame);
        }
    }

    return [self backingAlignedRect:newClipBoundsRect options: NSAlignAllEdgesNearest];
}

- (NSEdgeInsets)convertedContentInsetsToProposedBoundsSize:(NSSize)proposedBoundsSize {
    // Base the scale factor on the width scale factor to the new proposedBounds.
    CGFloat fromBoundsToProposedBoundsFactor = self.bounds.size.width > 0 ? (proposedBoundsSize.width / self.bounds.size.width) : 1.0;

    // Scale the set `contentInsets` by the width scale factor.
    NSEdgeInsets newContentInsets = self.contentInsets;
    newContentInsets.top *= fromBoundsToProposedBoundsFactor;
    newContentInsets.left *= fromBoundsToProposedBoundsFactor;
    newContentInsets.bottom *= fromBoundsToProposedBoundsFactor;
    newContentInsets.right *= fromBoundsToProposedBoundsFactor;

    return newContentInsets;
}

- (BOOL)mouseDownCanMoveWindow {
    return YES;
}

@end