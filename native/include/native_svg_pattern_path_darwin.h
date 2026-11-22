#ifndef VOX_NATIVE_SVG_PATTERN_PATH_DARWIN_H
#define VOX_NATIVE_SVG_PATTERN_PATH_DARWIN_H

#include <CoreGraphics/CoreGraphics.h>
#include <stdbool.h>

typedef struct {
    CGFloat width;
    CGLineCap cap;
    CGLineJoin join;
    CGFloat miter_limit;
    bool non_scaling;
    const CGFloat *dashes;
    size_t dash_count;
    CGFloat dash_offset;
} NativeSVGPatternStroke;

static inline void native_draw_svg_pattern_tile(CGContextRef destination,
    CGPathRef path, bool even_odd, CGAffineTransform to_canvas, CGImageRef image,
    CGRect tile, CGAffineTransform pattern_transform, CGFloat opacity,
    const NativeSVGPatternStroke *stroke) {
    bool host_space = stroke && stroke->non_scaling;
    CGPathRef geometry = path;
    if (host_space) {
        geometry = CGPathCreateCopyByTransformingPath(path, &to_canvas);
        if (!geometry) return;
    }
    CGContextSaveGState(destination);
    if (!host_space) CGContextConcatCTM(destination, to_canvas);
    CGContextAddPath(destination, geometry);
    if (host_space) CGPathRelease(geometry);
    if (stroke) {
        CGContextSetLineWidth(destination, stroke->width);
        CGContextSetLineCap(destination, stroke->cap);
        CGContextSetLineJoin(destination, stroke->join);
        CGContextSetMiterLimit(destination, stroke->miter_limit);
        if (stroke->dash_count > 0) {
            CGContextSetLineDash(destination, stroke->dash_offset, stroke->dashes,
                stroke->dash_count);
        }
        CGContextReplacePathWithStrokedPath(destination);
        CGContextClip(destination);
    } else if (even_odd) {
        CGContextEOClip(destination);
    } else {
        CGContextClip(destination);
    }

    // The stroke may use host coordinates. The tiles always follow the path's
    // original transform and their own pattern transform.
    if (host_space) CGContextConcatCTM(destination, to_canvas);
    CGContextSetAlpha(destination, opacity);
    CGContextSetInterpolationQuality(destination, kCGInterpolationNone);
    CGContextConcatCTM(destination, pattern_transform);
    // Flip the image rows around the cell center to preserve SVG y-down order.
    CGContextTranslateCTM(destination, 0, 2.0f * (float)tile.origin.y + (float)tile.size.height);
    CGContextScaleCTM(destination, 1, -1);
    CGContextDrawTiledImage(destination, tile, image);
    CGContextRestoreGState(destination);
}

#endif
