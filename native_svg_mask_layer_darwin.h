#ifndef VOX_NATIVE_SVG_MASK_LAYER_DARWIN_H
#define VOX_NATIVE_SVG_MASK_LAYER_DARWIN_H

#include <CoreGraphics/CoreGraphics.h>

static void native_begin_svg_mask_layer_in_context(CGContextRef context, CGRect mask_rect)
{
    CGContextSaveGState(context);
    // Pixels outside the final mask's raster bounds cannot survive masking.
    // Restrict the layer before drawing its subtree: SVG sprites otherwise
    // composite window-sized transparency layers for each tiny background tile.
    // Filter inputs use their independent offscreen contexts and remain intact.
    // Keep a fringe around fractional mask edges. Clipping the image's exact
    // rectangle would apply coverage twice at nested antialiased boundaries.
    CGRect bounds = CGRectIsEmpty(mask_rect) ? CGRectZero
        : CGRectInset(mask_rect, -2.0, -2.0);
    CGContextClipToRect(context, bounds);
    CGContextBeginTransparencyLayer(context, NULL);
}

#endif
