#ifndef VOX_NATIVE_SVG_MASK_PATH_DARWIN_H
#define VOX_NATIVE_SVG_MASK_PATH_DARWIN_H

#include <CoreGraphics/CoreGraphics.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>
#include "native_graphite_bridge.h"

typedef int (*VoxMaskPathRaster)(uint8_t *, int, int, int, int, VoxGraphitePath *);

// Use the GG raster's top-down pixel coordinates. Keep a transparent fringe
// and restrict rebasing to rectangles whose device edges are exactly integral.
static CGRect native_svg_mask_path_raster_bounds(CGPathRef outline, const float *matrix,
    CGRect canvas)
{
    CGRect rect;
    if (matrix[1] != 0 || matrix[3] != 0 || !CGPathIsRect(outline, &rect)) return canvas;
    double x0 = CGRectGetMinX(rect) * matrix[0], x1 = CGRectGetMaxX(rect) * matrix[0];
    double y0 = CGRectGetMinY(rect) * matrix[4], y1 = CGRectGetMaxY(rect) * matrix[4];
    // Match both fused and separate multiply-adds in the device transform.
    if ((float)x0 != x0 || (float)x1 != x1 || (float)y0 != y0 || (float)y1 != y1)
        return canvas;
    double left = fmin(x0, x1) + matrix[2], right = fmax(x0, x1) + matrix[2];
    double top = fmin(y0, y1) + matrix[5], bottom = fmax(y0, y1) + matrix[5];
    if (!(left >= 0 && right <= canvas.size.width && right > left
        && top >= 0 && bottom <= canvas.size.height && bottom > top)
        || left != floor(left) || right != floor(right)
        || top != floor(top) || bottom != floor(bottom)) return canvas;
    CGRect ink = CGRectMake(left, top, right - left, bottom - top);
    CGRect bounds = CGRectIntersection(CGRectInset(ink, -1, -1), canvas);
    double shift_x = (double)matrix[2] - bounds.origin.x;
    double shift_y = (double)matrix[5] - bounds.origin.y;
    if ((float)shift_x != shift_x || (float)shift_y != shift_y) return canvas;
    return bounds;
}

// Mask paths use the same V/GG coverage as document SVGs. Quartz still owns
// the bitmap, its clip and group opacity; publish an uncomposited path image
// through that context rather than bypassing its graphics state.
static int native_raster_svg_mask_path(CGContextRef context,
    const VoxGraphitePath *path, CGPathRef outline, VoxMaskPathRaster raster)
{
    if (!context || !path || !raster || !CGBitmapContextGetData(context)
        || CGBitmapContextGetBitsPerComponent(context) != 8
        || CGBitmapContextGetBitsPerPixel(context) != 32) return 0;
    size_t width = CGBitmapContextGetWidth(context), height = CGBitmapContextGetHeight(context);
    if (!width || !height || width > 16384 || height > 16384
        || width * height > 8u * 1024u * 1024u) return 0;
    CGAffineTransform ctm = CGContextGetCTM(context);
    if (!isfinite(ctm.a) || !isfinite(ctm.b) || !isfinite(ctm.c)
        || !isfinite(ctm.d) || !isfinite(ctm.tx) || !isfinite(ctm.ty)
        || ctm.a * ctm.d == ctm.b * ctm.c) return 0;
    CGColorSpaceRef space = CGBitmapContextGetColorSpace(context);
    if (!space || CGColorSpaceGetModel(space) != kCGColorSpaceModelRGB) return 0;
    CGRect bounds = CGRectMake(0, 0, width, height);
    VoxGraphitePath draw = *path;
    float matrix[9] = {ctm.a, ctm.c, ctm.tx, -ctm.b, -ctm.d, height - ctm.ty, 0, 0, 1};
    if (!path->stroke) bounds = native_svg_mask_path_raster_bounds(outline, matrix, bounds);
    matrix[2] -= bounds.origin.x;
    matrix[5] -= bounds.origin.y;
    memcpy(draw.matrix, matrix, sizeof(matrix));
    size_t raster_width = (size_t)bounds.size.width, raster_height = (size_t)bounds.size.height;
    CGContextRef staging = CGBitmapContextCreate(NULL, raster_width, raster_height, 8, raster_width * 4,
        space, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    uint8_t *pixels = staging ? CGBitmapContextGetData(staging) : NULL;
    if (!pixels) {
        if (staging) CGContextRelease(staging);
        return 0;
    }
    int drawn = raster(pixels, (int)raster_width, (int)raster_height, (int)(raster_width * 4), 0, &draw);
    CGImageRef image = drawn ? CGBitmapContextCreateImage(staging) : NULL;
    if (image) {
        CGContextSaveGState(context);
        CGContextConcatCTM(context, CGAffineTransformInvert(ctm));
        CGContextSetInterpolationQuality(context, kCGInterpolationNone);
        CGRect device = CGRectMake(bounds.origin.x, height - CGRectGetMaxY(bounds),
            bounds.size.width, bounds.size.height);
        CGContextDrawImage(context, device, image);
        CGContextRestoreGState(context);
        CGImageRelease(image);
    }
    CGContextRelease(staging);
    return image != NULL;
}

#endif
