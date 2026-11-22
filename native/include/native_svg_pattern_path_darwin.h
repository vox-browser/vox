#ifndef VOX_NATIVE_SVG_PATTERN_PATH_DARWIN_H
#define VOX_NATIVE_SVG_PATTERN_PATH_DARWIN_H

#include <CoreGraphics/CoreGraphics.h>
#include <math.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

static inline CGImageRef native_copy_svg_pattern_rgba(const uint8_t *pixels, uint64_t length,
    int32_t width, int32_t height) {
    if (!pixels || width <= 0 || height <= 0 || width > 8191 || height > 8191) return NULL;
    size_t pitch = (size_t)width * 4;
    if (length != pitch * (size_t)height) return NULL;
    // The paint buffer belongs to a V frame arena. Keep an owned copy for
    // deferred Quartz draws and for subsequent cache hits.
    CFDataRef data = CFDataCreate(kCFAllocatorDefault, pixels, (CFIndex)length);
    if (!data) return NULL;
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    CFRelease(data);
    if (!provider) return NULL;
    CGColorSpaceRef color_space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGImageRef image = color_space ? CGImageCreate(width, height, 8, 32, pitch, color_space,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big,
        provider, NULL, false, kCGRenderingIntentDefault) : NULL;
    if (color_space) CGColorSpaceRelease(color_space);
    CGDataProviderRelease(provider);
    return image;
}

static inline void native_set_svg_resource_dashes(CGContextRef context,
    const float *dashes, int count, float offset) {
    if (!dashes || count <= 0) return;
    CGFloat local[16];
    CGFloat *lengths = count <= 16 ? local : malloc((size_t)count * sizeof(*lengths));
    if (!lengths) return;
    for (int index = 0; index < count; ++index) lengths[index] = dashes[index];
    CGContextSetLineDash(context, offset, lengths, (size_t)count);
    if (lengths != local) free(lengths);
}

static inline void native_set_svg_resource_stroke(CGContextRef context, CGFloat width,
    int cap, int join, CGFloat miter, const float *dashes, int count, float offset) {
    CGContextSetLineWidth(context, width > 0 ? width : 0);
    CGContextSetLineCap(context, cap == 1 ? kCGLineCapRound
        : cap == 2 ? kCGLineCapSquare : kCGLineCapButt);
    CGContextSetLineJoin(context, join == 1 ? kCGLineJoinRound
        : join == 2 ? kCGLineJoinBevel : kCGLineJoinMiter);
    CGContextSetMiterLimit(context, miter > 1 ? miter : 1);
    native_set_svg_resource_dashes(context, dashes, count, offset);
}

static inline CGFloat native_svg_mask_device_scale(CGContextRef context) {
    // Mask bitmaps and their opacity children share this uniform backing scale.
    CGFloat scale = CGContextGetCTM(context).a;
    return isfinite(scale) && scale > 0 ? scale : 1;
}

// The caller saves graphics state. Build the centerline in backing pixels,
// where both the line width and the dash lengths will be applied.
static inline bool native_add_svg_host_stroke_path(CGContextRef context,
    CGPathRef path, CGAffineTransform to_canvas, CGFloat scale) {
    CGAffineTransform to_pixels = CGAffineTransformConcat(to_canvas,
        CGAffineTransformMakeScale(scale, scale));
    CGPathRef geometry = CGPathCreateCopyByTransformingPath(path, &to_pixels);
    if (!geometry) return false;
    if (scale != 1) CGContextScaleCTM(context, 1 / scale, 1 / scale);
    CGContextAddPath(context, geometry);
    CGPathRelease(geometry);
    return true;
}

typedef struct {
    CGFloat width;
    CGLineCap cap;
    CGLineJoin join;
    CGFloat miter_limit;
    bool non_scaling;
    const CGFloat *dashes;
    size_t dash_count;
    CGFloat dash_offset;
    CGFloat backing_scale;
} NativeSVGPatternStroke;

static inline void native_draw_svg_pattern_tile(CGContextRef destination,
    CGPathRef path, bool even_odd, CGAffineTransform to_canvas, CGImageRef image,
    CGRect tile, CGAffineTransform pattern_transform, CGFloat opacity,
    const NativeSVGPatternStroke *stroke) {
    bool host_space = stroke && stroke->non_scaling;
    CGContextSaveGState(destination);
    CGFloat scale = 1;
    if (host_space) {
        if (stroke->backing_scale > 0) scale = stroke->backing_scale;
        if (!native_add_svg_host_stroke_path(destination, path, to_canvas, scale)) {
            CGContextRestoreGState(destination);
            return;
        }
    } else {
        CGContextConcatCTM(destination, to_canvas);
        CGContextAddPath(destination, path);
    }
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
    if (host_space) {
        if (scale != 1) CGContextScaleCTM(destination, scale, scale);
        CGContextConcatCTM(destination, to_canvas);
    }
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
