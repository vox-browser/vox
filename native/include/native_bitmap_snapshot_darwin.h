#ifndef VOX_NATIVE_BITMAP_SNAPSHOT_DARWIN_H
#define VOX_NATIVE_BITMAP_SNAPSHOT_DARWIN_H

#include <CoreGraphics/CoreGraphics.h>
#include <dispatch/dispatch.h>
#include <stdint.h>
#include <stdlib.h>
#if defined(__aarch64__)
#include <arm_neon.h>
#endif

typedef struct {
    uint8_t *pixels;
    size_t width, height, pitch, lanes;
} VoxBitmapSwizzle;

static inline void native_bitmap_swizzle_rows(uint8_t *pixels, size_t width,
    size_t pitch, size_t first, size_t end) {
#if defined(__aarch64__)
    const uint8_t indices[] = {2, 1, 0, 3, 6, 5, 4, 7, 10, 9, 8, 11, 14, 13, 12, 15};
    uint8x16_t order = vld1q_u8(indices);
#endif
    for (size_t y = first; y < end; ++y) {
        uint8_t *row = pixels + y * pitch;
        size_t x = 0;
#if defined(__aarch64__)
        for (; width - x >= 4; x += 4)
            vst1q_u8(row + x * 4, vqtbl1q_u8(vld1q_u8(row + x * 4), order));
#endif
        for (; x < width; ++x) {
            uint8_t red = row[x * 4];
            row[x * 4] = row[x * 4 + 2];
            row[x * 4 + 2] = red;
        }
    }
}

static void native_bitmap_swizzle_band(void *context, size_t lane) {
    const VoxBitmapSwizzle *job = (const VoxBitmapSwizzle *)context;
    size_t rows = job->height / job->lanes;
    size_t extra = job->height % job->lanes;
    size_t first = rows * lane + (lane < extra ? lane : extra);
    native_bitmap_swizzle_rows(job->pixels, job->width, job->pitch,
        first, first + rows + (lane < extra));
}

static CGBitmapInfo native_bitmap_match_destination(uint8_t *pixels, size_t width,
    size_t height, size_t pitch, CGBitmapInfo info, CGContextRef destination)
{
    if (destination == NULL
        || (info & kCGBitmapAlphaInfoMask) != kCGImageAlphaPremultipliedLast
        || (info & kCGBitmapByteOrderMask) != kCGBitmapByteOrder32Big
        || CGBitmapContextGetBitsPerComponent(destination) != 8
        || CGBitmapContextGetBitsPerPixel(destination) != 32
        || CGBitmapContextGetAlphaInfo(destination) != kCGImageAlphaPremultipliedFirst
        || (CGBitmapContextGetBitmapInfo(destination) & kCGBitmapByteOrderMask) != kCGBitmapByteOrder32Little)
        return info;
    // The consuming context owns the pixels exclusively until provider creation.
    // Workers touch disjoint rows and finish before Quartz can retain the bytes.
    size_t lanes = width * height / (512u * 1024u);
    if (lanes > height) lanes = height;
    if (lanes > 4) lanes = 4;
    if (lanes > 1 && !getenv("VOX_SERIAL_BITMAP_SWIZZLE")) {
        VoxBitmapSwizzle job = {pixels, width, height, pitch, lanes};
        dispatch_apply_f(lanes, dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0),
            &job, native_bitmap_swizzle_band);
    } else native_bitmap_swizzle_rows(pixels, width, pitch, 0, height);
    return (info & ~(kCGBitmapAlphaInfoMask | kCGBitmapByteOrderMask))
        | kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little;
}

static void native_bitmap_image_release_context(void *context, const void *data, size_t size)
{
    (void)data;
    (void)size;
    CGContextRelease((CGContextRef)context);
}

// Consume a completed bitmap context. The caller must never paint into it
// again. Keep its allocation with the image provider, including when Quartz
// defers drawing the image, instead of making a protected bitmap snapshot.
static CGImageRef native_take_bitmap_image_for_destination(CGContextRef context, CGContextRef destination)
{
    if (context == NULL) return NULL;
    CGContextFlush(context);
    size_t width = CGBitmapContextGetWidth(context);
    size_t height = CGBitmapContextGetHeight(context);
    size_t pitch = CGBitmapContextGetBytesPerRow(context);
    CGBitmapInfo info = CGBitmapContextGetBitmapInfo(context);
    CGImageAlphaInfo alpha = CGBitmapContextGetAlphaInfo(context);
    CGBitmapInfo order = info & kCGBitmapByteOrderMask;
    CGColorSpaceRef color_space = CGBitmapContextGetColorSpace(context);
    if (width > 0 && height > 0 && pitch > 0 && pitch <= SIZE_MAX / height
        && CGBitmapContextGetBitsPerComponent(context) == 8
        && CGBitmapContextGetBitsPerPixel(context) == 32
        && color_space != NULL && CGColorSpaceGetModel(color_space) == kCGColorSpaceModelRGB
        && (alpha == kCGImageAlphaPremultipliedFirst || alpha == kCGImageAlphaPremultipliedLast)
        && (order == kCGBitmapByteOrder32Big || order == kCGBitmapByteOrder32Little)) {
        void *pixels = CGBitmapContextGetData(context);
        if (pixels != NULL) {
            info = native_bitmap_match_destination((uint8_t *)pixels, width, height, pitch, info, destination);
            CGDataProviderRef provider = CGDataProviderCreateWithData(context, pixels,
                pitch * height, native_bitmap_image_release_context);
            if (provider == NULL) {
                CGContextRelease(context);
                return NULL;
            }
            // Match CGBitmapContextCreateImage's interpolation preference.
            CGImageRef image = CGImageCreate(width, height, 8, 32, pitch, color_space,
                info, provider, NULL, true, kCGRenderingIntentDefault);
            CGDataProviderRelease(provider);
            return image;
        }
    }
    // Preserve the existing snapshot contract for other bitmap formats.
    CGImageRef image = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    return image;
}

static CGImageRef native_take_bitmap_image(CGContextRef context)
{
    return native_take_bitmap_image_for_destination(context, NULL);
}

#endif
