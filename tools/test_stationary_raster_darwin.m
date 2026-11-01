#import <Cocoa/Cocoa.h>
#include <assert.h>
#include "../native_stationary_raster_darwin.h"

static CGContextRef bitmap(int width, int height, int scale) {
    CGColorSpaceRef color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(NULL, width * scale, height * scale,
        8, width * scale * 4, color, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(color);
    assert(context);
    CGContextScaleCTM(context, scale, scale);
    return context;
}
static int begin(int owner, int revision, int generation, double scroll,
    double top, double zoom, double opacity) {
    return native_begin_stationary_raster(owner, revision, generation, scroll, top, zoom, opacity, 1);
}
static void fill(CGContextRef context, int seed) {
    size_t pitch = CGBitmapContextGetBytesPerRow(context), h = CGBitmapContextGetHeight(context);
    uint8_t *pixels = CGBitmapContextGetData(context);
    for (size_t i = 0; i < pitch * h; ++i) pixels[i] = (uint8_t)(i * 13 + i / pitch + seed);
}
int main(void) {
    @autoreleasepool {
        for (int scale = 1; scale <= 2; ++scale) {
            native_discard_stationary_raster();
            CGContextRef context = bitmap(32, 24, scale);
            NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithCGContext:context flipped:NO];
            assert(!begin(1, 2, 3, 0.5, 7, 1, .4));
            fill(context, 17);
            size_t bytes = CGBitmapContextGetBytesPerRow(context) * CGBitmapContextGetHeight(context);
            uint8_t *expected = malloc(bytes);
            memcpy(expected, CGBitmapContextGetData(context), bytes);
            native_end_stationary_raster();
            // Every use starts with a fresh destination, including subpixel
            // scroll offsets. The copied document is byte-identical.
            for (int frame = 0; frame < 3; ++frame) {
                fill(context, 91);
                assert(begin(1, 2, 3, .5, 7, 1, .4));
                assert(!memcmp(expected, CGBitmapContextGetData(context), bytes));
            }
            assert(!begin(2, 2, 3, .5, 7, 1, .4)); native_end_stationary_raster();
            assert(!begin(2, 3, 3, .5, 7, 1, .4)); native_end_stationary_raster();
            assert(!begin(2, 3, 4, .5, 7, 1, .4)); native_end_stationary_raster();
            assert(!begin(2, 3, 4, .75, 7, 1, .4)); native_end_stationary_raster();
            assert(!begin(2, 3, 4, .75, 8, 1, .4)); native_end_stationary_raster();
            assert(!begin(2, 3, 4, .75, 8, 1.25, .4)); native_end_stationary_raster();
            assert(!begin(2, 3, 4, .75, 8, 1.25, .5)); native_end_stationary_raster();
            assert(begin(2, 3, 4, .75, 8, 1.25, .5));
            // Timelines outside DOM invalidation never publish a retained still.
            assert(!begin(2, 4, 4, .75, 8, 1.25, .5));
            native_stationary_raster_independent_content(); native_end_stationary_raster();
            assert(!begin(2, 4, 4, .75, 8, 1.25, .5)); native_end_stationary_raster();
            CGContextSaveGState(context);
            CGContextClipToRect(context, CGRectMake(0, 0, 10, 10));
            assert(!begin(2, 4, 4, .75, 8, 1.25, .5));
            CGContextRestoreGState(context);
            assert(!native_stationary_raster.valid);
            assert(!native_begin_stationary_raster(2, 4, 4, .75, 8, 1.25, .5, 0));
            assert(!begin(2, 4, 4, NAN, 8, 1.25, .5));
            assert(!begin(2, 4, 4, .75, 8, 1.25, .5));
            fill(context, 17);
            native_end_stationary_raster();
            // AppKit creates a new bitmap for each publication. Reuse must
            // work across context identities, but never across dimensions.
            CGContextRef fresh = bitmap(32, 24, scale);
            NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithCGContext:fresh flipped:NO];
            assert(begin(2, 4, 4, .75, 8, 1.25, .5));
            assert(!memcmp(expected, CGBitmapContextGetData(fresh), bytes));
            CGContextRef resized = bitmap(33, 24, scale);
            NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithCGContext:resized flipped:NO];
            assert(!begin(2, 4, 4, .75, 8, 1.25, .5));
            native_end_stationary_raster();
            assert(begin(2, 4, 4, .75, 8, 1.25, .5));
            free(expected);
            NSGraphicsContext.currentContext = nil;
            CGContextRelease(fresh);
            CGContextRelease(resized);
            CGContextRelease(context);
        }
        native_discard_stationary_raster();
    }
    puts("stationary raster: exact copies, all input invalidations, dynamic content and clip guards passed");
    return 0;
}
