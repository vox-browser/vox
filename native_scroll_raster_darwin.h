#ifndef VOX_NATIVE_SCROLL_RASTER_DARWIN_H
#define VOX_NATIVE_SCROLL_RASTER_DARWIN_H
#include <CoreGraphics/CoreGraphics.h>
#include <math.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

// One bounded viewport, never a growing document-sized backing store. The
// caller supplies a content revision and excludes non-translating content.
typedef struct {
    uint8_t *pixels;
    size_t bytes, width, height, top, canvas_width, canvas_height;
    double scale, scroll;
    uint64_t owner, revision;
    int valid, active, reused, independent_content;
    CGContextRef context;
} VoxScrollRaster;

static VoxScrollRaster native_scroll_raster;

static void native_discard_scroll_raster(void) {
    free(native_scroll_raster.pixels);
    native_scroll_raster = (VoxScrollRaster){0};
}

static void native_scroll_raster_independent_content(void) {
    if (native_scroll_raster.active)
        native_scroll_raster.independent_content = 1;
}

static int native_scroll_raster_integer(double value) {
    return isfinite(value) && value >= 0 && value <= 16777216
        && fabs(value - round(value)) < 0.0000001;
}

// Called on the fresh, unpainted RGBA document canvas. Bitmap row zero is the
// top of the window; Quartz user coordinates have their origin at the bottom.
// Keep the original canvas dimensions and raster origins for intersecting
// leaves, clipping only their final output to the damaged strips.
static int native_begin_scroll_raster(uint64_t owner, uint64_t revision,
    double scroll, double page_top, double width, double height, int eligible,
    double *scroll_delta) {
    VoxScrollRaster *cache = &native_scroll_raster;
    CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
    if (!eligible || getenv("VOX_DISABLE_SCROLL_RASTER_REUSE") || !context) {
        native_discard_scroll_raster();
        return 0;
    }
    CGAffineTransform ctm = CGContextGetCTM(context);
    double scale = ctm.a;
    size_t canvas_width = CGBitmapContextGetWidth(context);
    size_t canvas_height = CGBitmapContextGetHeight(context);
    size_t pitch = CGBitmapContextGetBytesPerRow(context);
    uint8_t *pixels = CGBitmapContextGetData(context);
    double device_width = width * scale, device_height = height * scale;
    double device_top = page_top * scale;
    if (!pixels || !(scale > 0) || ctm.d != scale || ctm.b != 0 || ctm.c != 0
        || ctm.tx != 0 || ctm.ty != 0 || !isfinite(scroll) || fabs(scroll) > 1000000
        || !native_scroll_raster_integer(device_width)
        || !native_scroll_raster_integer(device_height)
        || !native_scroll_raster_integer(device_top)
        || device_width < 1 || device_height < 1
        || device_width > canvas_width || device_top + device_height > canvas_height
        || CGBitmapContextGetBitsPerComponent(context) != 8
        || CGBitmapContextGetBitsPerPixel(context) != 32
        || CGBitmapContextGetBitmapInfo(context) !=
            (kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big)
        || canvas_width > SIZE_MAX / 4 || pitch < canvas_width * 4
        || device_width * device_height * 4 > 64 * 1024 * 1024) {
        native_discard_scroll_raster();
        return 0;
    }
    size_t w = (size_t)llround(device_width), h = (size_t)llround(device_height);
    size_t top = (size_t)llround(device_top), bytes = w * h * 4;
    double delta = (scroll - cache->scroll) * scale;
    int reuse = cache->valid && cache->owner == owner && cache->revision == revision
        && cache->width == w && cache->height == h && cache->top == top
        && cache->canvas_width == canvas_width && cache->canvas_height == canvas_height
        && cache->scale == scale && isfinite(delta) && fabs(delta) < h
        && fabs(delta - round(delta)) < 0.0000001;
    if (cache->bytes != bytes) {
        uint8_t *replacement = realloc(cache->pixels, bytes);
        if (!replacement) {
            native_discard_scroll_raster();
            return 0;
        }
        cache->pixels = replacement;
        cache->bytes = bytes;
        reuse = 0;
    }
    cache->owner = owner;
    cache->revision = revision;
    cache->scroll = scroll;
    cache->scale = scale;
    cache->width = w;
    cache->height = h;
    cache->top = top;
    cache->canvas_width = canvas_width;
    cache->canvas_height = canvas_height;
    cache->context = context;
    cache->valid = 0;
    cache->active = 1;
    cache->reused = reuse;
    cache->independent_content = 0;
    if (!reuse) return 0;
    CGContextFlush(context);
    long rows = lround(delta);
    for (size_t y = 0; y < h; ++y) {
        long source_y = (long)y + rows;
        if (source_y >= 0 && source_y < (long)h)
            memcpy(pixels + (top + y) * pitch,
                cache->pixels + (size_t)source_y * w * 4, w * 4);
    }
    *scroll_delta = rows / scale;
    CGContextSaveGState(context);
    // Scrollbars are painted after end, so the cache holds only translating
    // document pixels. A single exposed strip keeps leaf raster bounds small.
    double strip = fabs(*scroll_delta);
    double bottom = canvas_height / scale - page_top - height;
    CGContextClipToRect(context, CGRectMake(0,
        *scroll_delta < 0 ? bottom + height - strip : bottom, width, strip));
    return 1;
}

// Finish before the document layer is published or chrome is painted. A new
// invalidation, navigation, scale, resize or fractional device-pixel scroll
// forces the ordinary complete replay on the next begin.
static void native_end_scroll_raster(void) {
    VoxScrollRaster *cache = &native_scroll_raster;
    if (!cache->active) return;
    CGContextRef context = cache->context;
    if (cache->reused) CGContextRestoreGState(context);
    CGContextFlush(context);
    const uint8_t *pixels = CGBitmapContextGetData(context);
    size_t pitch = CGBitmapContextGetBytesPerRow(context);
    if (pixels) {
        for (size_t y = 0; y < cache->height; ++y)
            memcpy(cache->pixels + y * cache->width * 4,
                pixels + (cache->top + y) * pitch, cache->width * 4);
        cache->valid = !cache->independent_content;
    }
    cache->active = 0;
    cache->context = NULL;
}
#endif
