#ifndef VOX_NATIVE_SVG_MASK_OPACITY_DARWIN_H
#define VOX_NATIVE_SVG_MASK_OPACITY_DARWIN_H

#include "native_opacity_group_darwin.h"
#include "native_opacity_canvas_pool_darwin.h"
#include "native_bitmap_snapshot_darwin.h"

typedef struct {
    VoxOpacityCanvas canvas;
    CGContextRef parent;
    float opacity;
} VoxSVGMaskOpacityBitmap;

#define VOX_SVG_MASK_OPACITY_BITMAP_DEPTH 64

static int native_begin_svg_mask_bitmap_opacity(VoxSVGMaskOpacityBitmap *group,
    CGContextRef parent, float opacity)
{
    if (!parent || !CGBitmapContextGetData(parent)
        || CGBitmapContextGetBitsPerComponent(parent) != 8
        || CGBitmapContextGetBitsPerPixel(parent) != 32
        || CGBitmapContextGetAlphaInfo(parent) != kCGImageAlphaPremultipliedLast
        || (CGBitmapContextGetBitmapInfo(parent) & kCGBitmapByteOrderMask) != kCGBitmapByteOrder32Big)
        return 0;
    CGAffineTransform ctm = CGContextGetCTM(parent);
    if (!(ctm.a > 0 && ctm.d > 0) || ctm.b != 0 || ctm.c != 0
        || !isfinite(ctm.a) || !isfinite(ctm.d) || !isfinite(ctm.tx) || !isfinite(ctm.ty)
        || CGRectIsEmpty(CGContextGetClipBoundingBox(parent))) return 0;
    size_t width = CGBitmapContextGetWidth(parent), height = CGBitmapContextGetHeight(parent);
    if (!width || !height || width > 16384 || height > 16384
        || width * height > 8u * 1024u * 1024u) return 0;
    CGColorSpaceRef space = CGBitmapContextGetColorSpace(parent);
    if (!space || CGColorSpaceGetModel(space) != kCGColorSpaceModelRGB) return 0;
    VoxOpacityCanvas canvas = native_acquire_opacity_canvas(width, height, space);
    if (!canvas.context) return 0;
    CGContextConcatCTM(canvas.context, ctm);
    CGContextSetShouldAntialias(canvas.context, true);
    CGContextSetInterpolationQuality(canvas.context, CGContextGetInterpolationQuality(parent));
    // Apply the parent's clip once when publishing the completed group.
    *group = (VoxSVGMaskOpacityBitmap){canvas, parent, fminf(fmaxf(opacity, 0), 1)};
    return 1;
}

static void native_end_svg_mask_bitmap_opacity(VoxSVGMaskOpacityBitmap *group)
{
    CGContextRef parent = group->parent, context = group->canvas.context;
    CGContextFlush(context);
    CGContextFlush(parent);
    size_t width = CGBitmapContextGetWidth(context), height = CGBitmapContextGetHeight(context);
    size_t pitch = CGBitmapContextGetBytesPerRow(context);
    size_t parent_pitch = CGBitmapContextGetBytesPerRow(parent);
    const uint8_t *backdrop = (const uint8_t *)CGBitmapContextGetData(parent);
    int left, top, right, bottom;
    if (group->opacity > 0 && native_opacity_layer_ink_bounds(group->canvas.pixels, pitch,
            0, 0, (int)width, (int)height, &left, &top, &right, &bottom)) {
        size_t ink_width = (size_t)(right - left), ink_height = (size_t)(bottom - top);
        CGContextRef result = CGBitmapContextCreate(NULL, ink_width, ink_height, 8,
            ink_width * 4, CGBitmapContextGetColorSpace(parent),
            kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
        uint8_t *pixels = result ? (uint8_t *)CGBitmapContextGetData(result) : NULL;
        CGImageRef image = NULL;
        CGRect device = CGRectMake(left, top, ink_width, ink_height);
        int copied = 0;
        if (pixels) {
            for (size_t row = 0; row < ink_height; ++row)
                native_composite_opacity_pixels(
                    group->canvas.pixels + (top + row) * pitch + (size_t)left * 4,
                    backdrop + (top + row) * parent_pitch + (size_t)left * 4,
                    pixels + row * ink_width * 4, ink_width, group->opacity);
            image = native_take_bitmap_image_for_destination(result, parent);
            copied = image != NULL;
        } else if (result) CGContextRelease(result);
        if (!image) {
            // Preserve the ordinary Quartz composite if staging allocation fails.
            image = CGBitmapContextCreateImage(context);
            device = CGRectMake(0, 0, width, height);
        }
        if (image) {
            CGContextSaveGState(parent);
            if (copied) CGContextSetBlendMode(parent, kCGBlendModeCopy);
            else CGContextSetAlpha(parent, group->opacity);
            CGContextSetInterpolationQuality(parent, kCGInterpolationNone);
            CGContextDrawImage(parent, CGContextConvertRectToUserSpace(parent, device), image);
            CGContextRestoreGState(parent);
            CGContextFlush(parent);
            CGImageRelease(image);
        }
    }
    native_release_opacity_canvas(group->canvas, 0, 0, width, height);
    *group = (VoxSVGMaskOpacityBitmap){0};
}

#endif
