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
    size_t row_origin, dirty_first, dirty_rows;
    double scale, scroll;
    uint64_t owner, revision;
    int valid, active, reused, independent_content, damage_optimized;
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

// Rows form a ring: advancing the origin keeps the overlapping document pixels
// in place. Only the exposed rows need writing back after replay. Contiguous
// canvases need at most two copies even when the ring wraps.
static void native_scroll_raster_copy_rows(VoxScrollRaster *cache,
    uint8_t *canvas, size_t pitch, size_t first, size_t count, int store) {
    size_t row_bytes = cache->width * 4;
    while (count) {
        size_t ring_row = (cache->row_origin + first) % cache->height;
        size_t run = cache->height - ring_row;
        if (run > count) run = count;
        uint8_t *raster = cache->pixels + ring_row * row_bytes;
        uint8_t *output = canvas + (cache->top + first) * pitch;
        if (pitch == row_bytes) {
            if (store) memcpy(raster, output, run * row_bytes);
            else memcpy(output, raster, run * row_bytes);
        } else {
            for (size_t row = 0; row < run; ++row) {
                if (store) memcpy(raster + row * row_bytes, output + row * pitch, row_bytes);
                else memcpy(output + row * pitch, raster + row * row_bytes, row_bytes);
            }
        }
        first += run;
        count -= run;
    }
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
    const char *disable_damage = getenv("VOX_DISABLE_SCROLL_RASTER_DAMAGE_OPTIMIZATIONS");
    int damage_optimized = !(disable_damage && *disable_damage);
    double delta = (scroll - cache->scroll) * scale;
    int reuse = cache->valid && cache->owner == owner && cache->revision == revision
        && cache->width == w && cache->height == h && cache->top == top
        && cache->canvas_width == canvas_width && cache->canvas_height == canvas_height
        && cache->scale == scale && isfinite(delta) && fabs(delta) < h
        && cache->damage_optimized == damage_optimized
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
    cache->damage_optimized = damage_optimized;
    cache->dirty_first = 0;
    cache->dirty_rows = h;
    if (!reuse) {
        cache->row_origin = 0;
        return 0;
    }
    CGContextFlush(context);
    long rows = lround(delta);
    if (damage_optimized) {
        cache->row_origin = (cache->row_origin + h + rows) % h;
        cache->dirty_rows = (size_t)labs(rows);
        cache->dirty_first = rows < 0 ? 0 : h - cache->dirty_rows;
        native_scroll_raster_copy_rows(cache, pixels, pitch,
            rows < 0 ? cache->dirty_rows : 0, h - cache->dirty_rows, 0);
        // The caller clears under the damage clip after begin. Preserve the
        // original white canvas outside the cached document as well, without
        // clearing document pixels that were just restored from the ring.
        CGContextSaveGState(context);
        CGContextSetRGBFillColor(context, 1, 1, 1, 1);
        double canvas_w = canvas_width / scale, canvas_h = canvas_height / scale;
        double page_bottom = canvas_h - page_top - height;
        CGContextFillRect(context, CGRectMake(0, canvas_h - page_top, canvas_w, page_top));
        CGContextFillRect(context, CGRectMake(0, 0, canvas_w, page_bottom));
        if (canvas_w > width)
            CGContextFillRect(context, CGRectMake(width, page_bottom, canvas_w - width, height));
        CGContextRestoreGState(context);
    } else {
        for (size_t y = 0; y < h; ++y) {
            long source_y = (long)y + rows;
            if (source_y >= 0 && source_y < (long)h)
                memcpy(pixels + (top + y) * pitch,
                    cache->pixels + (size_t)source_y * w * 4, w * 4);
        }
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
    uint8_t *pixels = CGBitmapContextGetData(context);
    size_t pitch = CGBitmapContextGetBytesPerRow(context);
    if (pixels) {
        if (cache->damage_optimized) {
            native_scroll_raster_copy_rows(cache, pixels, pitch,
                cache->dirty_first, cache->dirty_rows, 1);
        } else {
            for (size_t y = 0; y < cache->height; ++y)
                memcpy(cache->pixels + y * cache->width * 4,
                    pixels + (cache->top + y) * pitch, cache->width * 4);
        }
        cache->valid = !cache->independent_content;
    }
    cache->active = 0;
    cache->context = NULL;
}
#endif
