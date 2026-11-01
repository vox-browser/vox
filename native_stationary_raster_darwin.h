#ifndef VOX_NATIVE_STATIONARY_RASTER_DARWIN_H
#define VOX_NATIVE_STATIONARY_RASTER_DARWIN_H
#import <Cocoa/Cocoa.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// A single bounded viewport. Engine preparation still runs on every frame;
// this cache only replaces replay of the same committed document pixels.
typedef struct {
    uint64_t owner, revision, generation;
    double scroll, page_top, zoom, scrollbar_opacity;
} VoxStationaryRasterKey;
typedef struct {
    uint8_t *pixels;
    size_t bytes, width, height, pitch;
    CGAffineTransform transform;
    VoxStationaryRasterKey key;
    CGContextRef context;
    int valid, active, independent;
} VoxStationaryRaster;
static VoxStationaryRaster native_stationary_raster;

static void native_discard_stationary_raster(void) {
    free(native_stationary_raster.pixels);
    native_stationary_raster = (VoxStationaryRaster){0};
}
static void native_stationary_raster_independent_content(void) {
    if (native_stationary_raster.active) native_stationary_raster.independent = 1;
}
static int native_stationary_raster_same_key(VoxStationaryRasterKey a,
    VoxStationaryRasterKey b) {
    return a.owner == b.owner && a.revision == b.revision && a.generation == b.generation
        && a.scroll == b.scroll && a.page_top == b.page_top && a.zoom == b.zoom
        && a.scrollbar_opacity == b.scrollbar_opacity;
}
static int native_begin_stationary_raster(uint64_t owner, uint64_t revision,
    uint64_t generation, double scroll, double page_top, double zoom,
    double scrollbar_opacity, int eligible) {
    VoxStationaryRaster *cache = &native_stationary_raster;
    CGContextRef context = NSGraphicsContext.currentContext.CGContext;
    if (!eligible || getenv("VOX_DISABLE_STATIONARY_RASTER_REUSE") || !context
        || !owner || !isfinite(scroll) || !isfinite(page_top)
        || !isfinite(zoom) || zoom <= 0 || !isfinite(scrollbar_opacity)) {
        native_discard_stationary_raster();
        return 0;
    }
    size_t width = CGBitmapContextGetWidth(context), height = CGBitmapContextGetHeight(context);
    size_t pitch = CGBitmapContextGetBytesPerRow(context);
    uint8_t *pixels = CGBitmapContextGetData(context);
    CGRect clip = CGContextConvertRectToDeviceSpace(context, CGContextGetClipBoundingBox(context));
    CGColorSpaceRef srgb = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGColorSpaceRef color = CGBitmapContextGetColorSpace(context);
    int same_color = srgb && color && CFEqual(srgb, color);
    if (srgb) CGColorSpaceRelease(srgb);
    if (!pixels || !width || !height || width > SIZE_MAX / 4 || pitch < width * 4
        || height > 64 * 1024 * 1024 / pitch || !same_color
        || !CGRectEqualToRect(clip, CGRectMake(0, 0, width, height))
        || CGBitmapContextGetBitsPerComponent(context) != 8
        || CGBitmapContextGetBitsPerPixel(context) != 32
        || CGBitmapContextGetBitmapInfo(context)
            != (kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big)) {
        native_discard_stationary_raster();
        return 0;
    }
    CGAffineTransform transform = CGContextGetCTM(context);
    VoxStationaryRasterKey key = {owner, revision, generation, scroll, page_top, zoom,
        scrollbar_opacity};
    size_t bytes = pitch * height;
    int reuse = cache->valid && native_stationary_raster_same_key(cache->key, key)
        && cache->width == width && cache->height == height && cache->pitch == pitch
        && CGAffineTransformEqualToTransform(cache->transform, transform);
    if (cache->bytes != bytes) {
        uint8_t *replacement = realloc(cache->pixels, bytes);
        if (!replacement) { native_discard_stationary_raster(); return 0; }
        cache->pixels = replacement;
        cache->bytes = bytes;
        reuse = 0;
    }
    cache->key = key;
    cache->width = width; cache->height = height; cache->pitch = pitch;
    cache->transform = transform;
    cache->context = context;
    cache->active = !reuse;
    cache->independent = 0;
    cache->valid = reuse;
    if (reuse) {
        CGContextFlush(context);
        memcpy(pixels, cache->pixels, bytes);
        if (getenv("VOX_STATIONARY_RASTER_DIAGNOSTICS"))
            fprintf(stderr, "Vox stationary raster: reused\n");
    }
    return reuse;
}
static void native_end_stationary_raster(void) {
    VoxStationaryRaster *cache = &native_stationary_raster;
    if (!cache->active) return;
    CGContextRef context = cache->context;
    if (!cache->independent && context == NSGraphicsContext.currentContext.CGContext) {
        CGContextFlush(context);
        uint8_t *pixels = CGBitmapContextGetData(context);
        if (pixels) { memcpy(cache->pixels, pixels, cache->bytes); cache->valid = 1; }
    }
    cache->active = 0;
    cache->context = NULL;
}
#endif
