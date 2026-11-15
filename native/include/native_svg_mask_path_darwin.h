#ifndef VOX_NATIVE_SVG_MASK_PATH_DARWIN_H
#define VOX_NATIVE_SVG_MASK_PATH_DARWIN_H

#include <CoreGraphics/CoreGraphics.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>
#include "native_graphite_bridge.h"

typedef int (*VoxMaskPathRaster)(uint8_t *, int, int, int, int, VoxGraphitePath *);

// Mask paths use the same V/GG coverage as document SVGs. Quartz still owns
// the bitmap, its clip and group opacity; publish an uncomposited path image
// through that context rather than bypassing its graphics state.
static int native_raster_svg_mask_path(CGContextRef context,
    const VoxGraphitePath *path, VoxMaskPathRaster raster)
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
    CGContextRef staging = CGBitmapContextCreate(NULL, width, height, 8, width * 4,
        space, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    uint8_t *pixels = staging ? CGBitmapContextGetData(staging) : NULL;
    if (!pixels) {
        if (staging) CGContextRelease(staging);
        return 0;
    }
    VoxGraphitePath draw = *path;
    float matrix[9] = {ctm.a, ctm.c, ctm.tx, -ctm.b, -ctm.d, height - ctm.ty, 0, 0, 1};
    memcpy(draw.matrix, matrix, sizeof(matrix));
    int drawn = raster(pixels, (int)width, (int)height, (int)(width * 4), 0, &draw);
    CGImageRef image = drawn ? CGBitmapContextCreateImage(staging) : NULL;
    if (image) {
        CGContextSaveGState(context);
        CGContextConcatCTM(context, CGAffineTransformInvert(ctm));
        CGContextSetInterpolationQuality(context, kCGInterpolationNone);
        CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
        CGContextRestoreGState(context);
        CGImageRelease(image);
    }
    CGContextRelease(staging);
    return image != NULL;
}

#endif
