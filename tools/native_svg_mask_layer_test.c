#include "native/include/native_svg_mask_layer_darwin.h"
#include "native/include/native_svg_mask_cache_key.h"
#include "native/include/native_svg_mask_raster_cache_darwin.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static CGContextRef bitmap(void)
{
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(NULL, 96, 80, 8, 96 * 4, space,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    assert(context != NULL);
    return context;
}

static const NativeSVGMaskRasterCacheEntry *scan_mask_raster_cache(
    const NativeSVGMaskRasterCache *cache)
{
    const NativeSVGMaskRasterCacheEntry *oldest = &cache->entries[0];
    for (int index = 1; index < NATIVE_SVG_MASK_RASTER_CACHE_SIZE; ++index) {
        const NativeSVGMaskRasterCacheEntry *entry = &cache->entries[index];
        if (entry->image == NULL || entry->last_use < oldest->last_use) {
            oldest = entry;
        }
    }
    return oldest;
}

static void check_mask_raster_replacement(void)
{
    NativeSVGMaskRasterCache cache = {0};
    CGContextRef context = bitmap();
    CGImageRef image = CGBitmapContextCreateImage(context);
    assert(image != NULL);
    for (int index = NATIVE_SVG_MASK_RASTER_CACHE_SIZE - 1; index >= 0; --index) {
        assert(native_svg_mask_raster_can_admit(&cache, UINT64_MAX));
        assert(cache.replacement == &cache.entries[index]);
        assert(native_svg_mask_raster_store(&cache,
            (NativeSVGMaskRasterCacheEntry){index + 1, image, UINT64_MAX, UINT64_MAX}) == NULL);
    }

    // Equal timestamps retain the first slot. Its admission age is checked
    // anew even across frame rollover while the cached slot stays valid.
    assert(!native_svg_mask_raster_can_admit(&cache, UINT64_MAX));
    assert(!native_svg_mask_raster_can_admit(&cache, 0));
    assert(native_svg_mask_raster_can_admit(&cache, 1));
    assert(cache.replacement == &cache.entries[0]);
    native_svg_mask_raster_touch(&cache, &cache.entries[0], UINT64_MAX, 1);
    assert(cache.replacement == &cache.entries[0]);
    assert(!native_svg_mask_raster_can_admit(&cache, 1));
    native_svg_mask_raster_touch(&cache, &cache.entries[1], 0, 1);
    assert(cache.replacement == NULL);
    native_svg_mask_raster_touch(&cache, &cache.entries[2], 1, 1);
    assert(native_svg_mask_raster_replacement(&cache) == &cache.entries[1]);
    native_svg_mask_raster_touch(&cache, &cache.entries[2], 2, 1);
    assert(cache.replacement == &cache.entries[1]);
    native_svg_mask_raster_touch(&cache, &cache.entries[1], 3, 1);
    assert(cache.replacement == NULL);
    assert(native_svg_mask_raster_replacement(&cache) == &cache.entries[2]);

    // Compare hits, capacity misses and stores against the original full scan.
    uint32_t sequence = 1;
    for (uint64_t step = 0; step < 4096; ++step) {
        uint64_t frame = 1 + step / 19;
        sequence = sequence * 1664525u + 1013904223u;
        int slot = (sequence >> 16) % NATIVE_SVG_MASK_RASTER_CACHE_SIZE;
        if (sequence % 3 != 0) {
            native_svg_mask_raster_touch(&cache, &cache.entries[slot], 4 + step, frame);
        }
        const NativeSVGMaskRasterCacheEntry *expected = scan_mask_raster_cache(&cache);
        assert(native_svg_mask_raster_can_admit(&cache, frame) == (frame - expected->frame > 1));
        assert(cache.replacement == expected);
        if (frame - expected->frame > 1) {
            assert(native_svg_mask_raster_store(&cache,
                (NativeSVGMaskRasterCacheEntry){100 + step, image, 4 + step, frame}) == image);
            assert(expected->key == 100 + step);
        }
    }
    CGImageRelease(image);
    CGContextRelease(context);
}

static void begin_layer(CGContextRef context, CGRect rect, int optimized)
{
    if (optimized) {
        native_begin_svg_mask_layer_in_context(context, rect);
    } else {
        CGContextSaveGState(context);
        CGContextBeginTransparencyLayer(context, NULL);
    }
}

// Apply the bridge's existing destination-in mask and clear outside its bounds.
static void end_layer(CGContextRef context, CGRect rect)
{
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef mask = CGBitmapContextCreate(NULL, 32, 24, 8, 32 * 4, space,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    assert(mask != NULL);
    CGContextSetRGBFillColor(mask, 1, 1, 1, .75);
    CGContextFillEllipseInRect(mask, CGRectMake(1, 1, 30, 22));
    CGImageRef image = CGBitmapContextCreateImage(mask);
    CGContextSaveGState(context);
    CGContextAddRect(context, CGRectMake(-200, -200, 500, 500));
    CGContextAddRect(context, rect);
    CGContextEOClip(context);
    CGContextSetBlendMode(context, kCGBlendModeClear);
    CGContextFillRect(context, CGRectMake(-200, -200, 500, 500));
    CGContextRestoreGState(context);
    CGContextSaveGState(context);
    CGContextSetBlendMode(context, kCGBlendModeDestinationIn);
    CGContextDrawImage(context, rect, image);
    CGContextRestoreGState(context);
    CGContextEndTransparencyLayer(context);
    CGContextRestoreGState(context);
    CGImageRelease(image);
    CGContextRelease(mask);
}

static CGContextRef scene(int optimized, int nested, int transformed, CGFloat phase)
{
    CGContextRef context = bitmap();
    CGContextSetRGBFillColor(context, .25, .5, .75, 1);
    CGContextFillRect(context, CGRectMake(0, 0, 96, 80));
    if (transformed) {
        CGContextTranslateCTM(context, 3, 5);
        CGContextScaleCTM(context, 1.25, .75);
    }
    CGRect parent_clip = CGRectMake(10 + phase, 12 + phase, 48, 42);
    CGContextClipToRect(context, parent_clip);
    CGRect before = CGContextGetClipBoundingBox(context);
    CGRect outer = CGRectMake(4 + phase, 8 + phase, 64, 48);
    begin_layer(context, outer, optimized);
    CGContextSetRGBFillColor(context, 1, 0, .25, .8);
    CGContextFillRect(context, CGRectMake(0, 0, 96, 80));
    if (nested) {
        // The second scope is outside the embedding clip, as in an SVG sprite.
        for (int index = 0; index < 2; ++index) {
            CGRect inner = CGRectMake((index ? 70 : 18) + phase, 16 + phase, 32, 24);
            begin_layer(context, inner, optimized);
            CGContextSetRGBFillColor(context, 0, 1, .25, .7);
            CGContextFillRect(context, CGRectMake(0, 0, 96, 80));
            end_layer(context, inner);
        }
    }
    end_layer(context, outer);
    assert(CGRectEqualToRect(before, CGContextGetClipBoundingBox(context)));
    return context;
}

static CGContextRef coverage_scene(int srgb, int clip, int full)
{
    CGColorSpaceRef space = srgb ? CGColorSpaceCreateWithName(kCGColorSpaceSRGB)
        : CGColorSpaceCreateDeviceRGB();
    size_t width = full ? 32 : 21;
    size_t height = full ? 24 : 17;
    CGContextRef mask = CGBitmapContextCreate(NULL, width, height, 8, width * 4, space,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    assert(mask != NULL);
    uint8_t *pixels = CGBitmapContextGetData(mask);
    for (size_t y = 0; y < height; ++y) {
        for (size_t x = 0; x < width; ++x) {
            size_t source = full ? y * 32 + x : (y + 3) * 32 + x + 5;
            memset(pixels + (y * width + x) * 4, (uint8_t)(source * 37), 4);
        }
    }
    CGImageRef image = CGBitmapContextCreateImage(mask);
    assert(image != NULL);
    CGContextRelease(mask);
    if (full) {
        CGImageRef cropped = CGImageCreateWithImageInRect(image, CGRectMake(5, 3, 21, 17));
        CGImageRelease(image);
        assert(cropped != NULL);
        image = cropped;
    }

    CGContextRef canvas = bitmap();
    CGRect rect = CGRectMake(7.25, 8.5, 67.5, 53.25);
    if (clip) {
        CGContextClipToMask(canvas, rect, image);
    }
    CGContextSetRGBFillColor(canvas, .25, .5, .75, .8);
    CGContextFillRect(canvas, rect);
    if (!clip) {
        CGContextSetBlendMode(canvas, kCGBlendModeDestinationIn);
        CGContextDrawImage(canvas, rect, image);
    }
    CGImageRelease(image);
    return canvas;
}

int main(void)
{
    check_mask_raster_replacement();
    for (int content = 0; content < 2; ++content) {
        uint64_t standard = native_svg_mask_cache_key(17, content, 1024, 640, 0, 64, 0, 1);
        assert(standard == native_svg_mask_cache_key(17, content, 1024, 640, 0, 64, 0, 1));
        assert(standard != native_svg_mask_cache_key(17, content, 1024, 640, 0, 64, 0, 2));
        assert(standard != native_svg_mask_cache_key(17, content, 1024, 640, 0, 64, 0, 1.5));
    }
    int cases = 0;
    for (int nested = 0; nested < 2; ++nested) {
        for (int transformed = 0; transformed < 2; ++transformed) {
            for (int phase = 0; phase < 4; ++phase) {
                CGContextRef reference = scene(0, nested, transformed, phase / 4.0);
                CGContextRef actual = scene(1, nested, transformed, phase / 4.0);
                if (memcmp(CGBitmapContextGetData(reference), CGBitmapContextGetData(actual),
                    CGBitmapContextGetBytesPerRow(reference) * 80) != 0) {
                    fprintf(stderr, "pixel mismatch nested=%d transformed=%d phase=%d\n", nested, transformed, phase);
                    abort();
                }
                CGContextRelease(reference);
                CGContextRelease(actual);
                ++cases;
            }
        }
    }
    CGContextRef context = bitmap();
    CGContextClipToRect(context, CGRectMake(4, 4, 8, 8));
    CGRect before = CGContextGetClipBoundingBox(context);
    native_begin_svg_mask_layer_in_context(context, CGRectMake(40, 40, 16, 16));
    assert(CGRectIsEmpty(CGContextGetClipBoundingBox(context)));
    CGContextEndTransparencyLayer(context);
    CGContextRestoreGState(context);
    assert(CGRectEqualToRect(before, CGContextGetClipBoundingBox(context)));
    native_begin_svg_mask_layer_in_context(context, CGRectZero);
    assert(CGRectIsEmpty(CGContextGetClipBoundingBox(context)));
    CGContextEndTransparencyLayer(context);
    CGContextRestoreGState(context);
    assert(CGRectEqualToRect(before, CGContextGetClipBoundingBox(context)));
    CGContextRelease(context);
    for (int clip = 0; clip < 2; ++clip) {
        CGContextRef reference = coverage_scene(0, clip, 0);
        CGContextRef shared = coverage_scene(1, clip, 1);
        assert(memcmp(CGBitmapContextGetData(reference), CGBitmapContextGetData(shared),
            CGBitmapContextGetBytesPerRow(reference) * 80) == 0);
        CGContextRelease(reference);
        CGContextRelease(shared);
    }
    printf("SVG mask layers: %d exact scenes, clip restoration, bounds, cache keys and replacement passed\n", cases);
    return 0;
}
