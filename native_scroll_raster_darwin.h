#ifndef VOX_NATIVE_SCROLL_RASTER_DARWIN_H
#define VOX_NATIVE_SCROLL_RASTER_DARWIN_H
#include <CoreGraphics/CoreGraphics.h>
#include <math.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "native_raster_row_ranges.h"

#define VOX_SCROLL_RASTER_MAX_DAMAGE_RECTS 48

// One bounded viewport, never a growing document-sized backing store. The
// caller supplies a content revision and excludes non-translating content.
typedef struct {
    uint8_t *pixels;
    size_t bytes, width, height, top, canvas_width, canvas_height;
    size_t row_origin, dirty_first, dirty_rows;
    // Rows of in-page damage rectangles, stored back besides the strip.
    size_t damage_rows[VOX_SCROLL_RASTER_MAX_DAMAGE_RECTS][2];
    int damage_row_count;
    double scale, scroll;
    uint64_t owner, revision;
    int valid, active, reused, independent_content, damage_optimized;
    CGContextRef context;
} VoxScrollRaster;

static VoxScrollRaster native_scroll_raster;


// Chromium composites a video as its own layer over the unchanged raster
// beneath it. The single-surface equivalent retains, in document device rows,
// the pixels painted beneath a top-level video immediately before it draws.
// A frame whose only change is the next video frame restores them and draws
// just the video. A row is valid only while it has stayed in the viewport
// since it was captured from freshly painted pixels.
#define VOX_VIDEO_BACKDROPS 4
typedef struct {
    uint8_t *pixels, *valid;
    long x, y, width, height;
    double scale;
    uint64_t owner, stamp;
} VoxVideoBackdrop;

static VoxVideoBackdrop native_video_backdrops[VOX_VIDEO_BACKDROPS];
static uint64_t native_video_backdrop_clock;
// Viewport device rectangles (left, top, right, bottom) repainted by the
// active reused frame; a negative count means the whole viewport.
static long native_scroll_repainted[VOX_SCROLL_RASTER_MAX_DAMAGE_RECTS + 1][4];
static int native_scroll_repainted_count = -1;

static void native_discard_video_backdrops(void) {
    for (int index = 0; index < VOX_VIDEO_BACKDROPS; ++index) {
        free(native_video_backdrops[index].pixels);
        free(native_video_backdrops[index].valid);
        native_video_backdrops[index] = (VoxVideoBackdrop){0};
    }
}

static void native_discard_scroll_raster(void) {
    free(native_scroll_raster.pixels);
    native_scroll_raster = (VoxScrollRaster){0};
    native_scroll_repainted_count = -1;
    native_discard_video_backdrops();
}

static void native_scroll_raster_independent_content(void) {
    if (native_scroll_raster.active)
        native_scroll_raster.independent_content = 1;
}

// Rows leave validity when they leave the viewport: content beneath them can
// change offscreen without producing viewport damage.
static void native_video_backdrops_keep_visible(VoxScrollRaster *cache, int keep) {
    double origin = cache->scroll * cache->scale;
    int aligned = keep && isfinite(origin) && fabs(origin - round(origin)) < 0.0000001;
    long first = aligned ? lround(origin) : 0, end = first + (long)cache->height;
    for (int index = 0; index < VOX_VIDEO_BACKDROPS; ++index) {
        VoxVideoBackdrop *backdrop = &native_video_backdrops[index];
        if (!backdrop->valid) continue;
        if (!aligned || backdrop->owner != cache->owner || backdrop->scale != cache->scale) {
            memset(backdrop->valid, 0, (size_t)backdrop->height);
            continue;
        }
        for (long row = 0; row < backdrop->height; ++row) {
            long document_row = backdrop->y + row;
            if (document_row < first || document_row >= end) backdrop->valid[row] = 0;
        }
    }
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

// Copy only the retained pixels that the caller's opaque damage clear will
// leave visible. Damage edges remain copied: Quartz may cover them partially.
// Sweep at rectangle boundaries, merging x intervals once per horizontal band
// instead of sorting them for every row. Unaffected bands keep the bulk copy.
static size_t native_scroll_raster_restore_visible(VoxScrollRaster *cache,
    uint8_t *canvas, size_t pitch, size_t first, size_t count, int opaque_clear) {
    const char *enabled = opaque_clear && native_scroll_repainted_count > 0
        ? getenv("VOX_SKIP_OVERWRITTEN_SCROLL_COPY") : NULL;
    size_t area = 0, end = first + count, skipped = 0;
    if (enabled && *enabled) {
        for (int index = 0; index < native_scroll_repainted_count; ++index) {
            const long *rect = native_scroll_repainted[index];
            size_t top = (size_t)rect[1] > first ? (size_t)rect[1] : first;
            size_t bottom = (size_t)rect[3] < end ? (size_t)rect[3] : end;
            if (bottom > top) area += (size_t)(rect[2] - rect[0]) * (bottom - top);
        }
    }
    if (!area || area < cache->width * count / 64) {
        native_scroll_raster_copy_rows(cache, canvas, pitch, first, count, 0);
        return 0;
    }
    for (size_t y = first; y < end;) {
        size_t next = end, intervals[VOX_SCROLL_RASTER_MAX_DAMAGE_RECTS + 1][2];
        int interval_count = 0;
        for (int index = 0; index < native_scroll_repainted_count; ++index) {
            const long *rect = native_scroll_repainted[index];
            size_t top = (size_t)rect[1], bottom = (size_t)rect[3];
            if (top > y && top < next) next = top;
            if (bottom > y && bottom < next) next = bottom;
            if (top <= y && bottom > y) {
                int slot = interval_count++;
                while (slot && intervals[slot - 1][0] > (size_t)rect[0]) {
                    intervals[slot][0] = intervals[slot - 1][0];
                    intervals[slot][1] = intervals[slot - 1][1];
                    --slot;
                }
                intervals[slot][0] = (size_t)rect[0];
                intervals[slot][1] = (size_t)rect[2];
            }
        }
        if (!interval_count) {
            native_scroll_raster_copy_rows(cache, canvas, pitch, y, next - y, 0);
        } else {
            size_t spans[VOX_SCROLL_RASTER_MAX_DAMAGE_RECTS + 2][2];
            size_t x = 0, copied_width = 0;
            int span_count = 0;
            for (int index = 0; index < interval_count; ++index) {
                if (intervals[index][0] > x) {
                    spans[span_count][0] = x;
                    spans[span_count++][1] = intervals[index][0];
                }
                if (intervals[index][1] > x) x = intervals[index][1];
            }
            if (x < cache->width) {
                spans[span_count][0] = x;
                spans[span_count++][1] = cache->width;
            }
            for (int index = 0; index < span_count; ++index)
                copied_width += spans[index][1] - spans[index][0];
            skipped += (cache->width - copied_width) * (next - y) * 4;
            for (size_t row = y; row < next; ++row) {
                const uint8_t *source = cache->pixels
                    + ((cache->row_origin + row) % cache->height) * cache->width * 4;
                uint8_t *target = canvas + (cache->top + row) * pitch;
                for (int index = 0; index < span_count; ++index) {
                    size_t offset = spans[index][0] * 4;
                    memcpy(target + offset, source + offset,
                        (spans[index][1] - spans[index][0]) * 4);
                }
            }
        }
        y = next;
    }
    const char *diagnostics = getenv("VOX_SCROLL_COPY_DIAGNOSTICS");
    if (diagnostics && *diagnostics)
        fprintf(stderr, "VOX_SCROLL_COPY skipped_bytes=%zu retained_bytes=%zu rects=%d\n",
            skipped, cache->width * count * 4, native_scroll_repainted_count);
    return skipped;
}

// Different damage rectangles can cover the same device rows, even when the
// rectangles do not overlap horizontally. Each store copies the complete row;
// publish its final canvas bytes to the ring once, including exposed rows.
static void native_scroll_raster_store_rows(VoxScrollRaster *cache, uint8_t *pixels, size_t pitch) {
    const char *enabled = NULL, *disabled = NULL;
    if (cache->damage_row_count > 1 || (cache->damage_row_count && cache->dirty_rows)) {
        // Keep the original default until matched page trials establish a gain.
        enabled = getenv("VOX_ENABLE_SCROLL_RASTER_ROW_UNION");
        if (enabled && *enabled) disabled = getenv("VOX_DISABLE_SCROLL_RASTER_ROW_UNION");
    }
    if (!cache->damage_row_count || (cache->damage_row_count == 1 && !cache->dirty_rows)
        || !enabled || !*enabled || (disabled && *disabled)) {
        native_scroll_raster_copy_rows(cache, pixels, pitch, cache->dirty_first, cache->dirty_rows, 1);
        for (int index = 0; index < cache->damage_row_count; ++index)
            native_scroll_raster_copy_rows(cache, pixels, pitch,
                cache->damage_rows[index][0], cache->damage_rows[index][1], 1);
        return;
    }
    VoxRasterRowRange ranges[VOX_SCROLL_RASTER_MAX_DAMAGE_RECTS + 1];
    size_t count = 0, original_rows = cache->dirty_rows;
    ranges[count++] = (VoxRasterRowRange){cache->dirty_first, cache->dirty_rows};
    for (int index = 0; index < cache->damage_row_count; ++index) {
        ranges[count++] = (VoxRasterRowRange){cache->damage_rows[index][0], cache->damage_rows[index][1]};
        original_rows += cache->damage_rows[index][1];
    }
    size_t merged = vox_union_raster_rows(ranges, count, cache->height), stored_rows = 0;
    for (size_t index = 0; index < merged; ++index) {
        native_scroll_raster_copy_rows(cache, pixels, pitch, ranges[index].first, ranges[index].count, 1);
        stored_rows += ranges[index].count;
    }
    static int reported;
    const char *diagnostics = getenv("VOX_SCROLL_RASTER_ROW_UNION_DIAGNOSTICS");
    if (!reported && diagnostics && *diagnostics && stored_rows < original_rows) {
        reported = 1;
        fprintf(stderr, "Vox scroll raster row union: avoided_rows=%zu ranges=%zu merged=%zu owner=%llu width=%zu height=%zu\n",
            original_rows - stored_rows, count, merged, (unsigned long long)cache->owner,
            cache->width, cache->height);
    }
}

// Called on the fresh, unpainted RGBA document canvas. Bitmap row zero is the
// top of the window; Quartz user coordinates have their origin at the bottom.
// Keep the original canvas dimensions and raster origins for intersecting
// leaves, clipping only their final output to the damaged strips.
//
// `damage` holds `damage_count` viewport-space CSS rectangles (x, top, width,
// height) whose content changed since the retained frame; they are clipped and
// repainted together with the exposed strip. `allow_reuse` means the caller has
// reconciled the retained frame's content into those rectangles (including
// across a changed revision), so the retained pixels outside them are current.
// Without it the frame is painted completely and stored: a revision match
// alone no longer implies reuse, because content that does not translate with
// the viewport is only repainted through that reconciliation. `opaque_clear`
// promises that replay first replaces every damage pixel with an opaque fill;
// without this promise all overlapping retained pixels must be restored.
static int native_begin_scroll_raster(uint64_t owner, uint64_t revision,
    double scroll, double page_top, double width, double height, int eligible,
    double *scroll_delta, const double *damage, int damage_count,
    int allow_reuse, int opaque_clear) {
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
    uint8_t *pixels = (uint8_t *)CGBitmapContextGetData(context);
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
#ifdef VOX_SCROLL_RASTER_DIAGNOSTICS
        fprintf(stderr, "VOX_SCROLL_RASTER_NATIVE_REJECT pixels=%d ctm=%g,%g,%g,%g,%g,%g scroll=%.12g viewport=%g,%g,%g canvas=%zu,%zu pitch=%zu bits=%zu,%zu info=%u\n",
            pixels != NULL, ctm.a, ctm.b, ctm.c, ctm.d, ctm.tx, ctm.ty,
            scroll, device_width, device_height, device_top,
            canvas_width, canvas_height, pitch,
            CGBitmapContextGetBitsPerComponent(context),
            CGBitmapContextGetBitsPerPixel(context),
            (unsigned)CGBitmapContextGetBitmapInfo(context));
#endif
        native_discard_scroll_raster();
        return 0;
    }
    size_t w = (size_t)llround(device_width), h = (size_t)llround(device_height);
    size_t top = (size_t)llround(device_top), bytes = w * h * 4;
    const char *disable_damage = getenv("VOX_DISABLE_SCROLL_RASTER_DAMAGE_OPTIMIZATIONS");
    int damage_optimized = !(disable_damage && *disable_damage);
    double delta = (scroll - cache->scroll) * scale;
    if (damage_count < 0 || damage_count > VOX_SCROLL_RASTER_MAX_DAMAGE_RECTS
        || (damage_count > 0 && !damage))
        allow_reuse = 0, damage_count = 0;
    int reuse = cache->valid && allow_reuse && cache->owner == owner
        && cache->width == w && cache->height == h && cache->top == top
        && cache->canvas_width == canvas_width && cache->canvas_height == canvas_height
        && cache->scale == scale && isfinite(delta) && fabs(delta) < h
        && cache->damage_optimized == damage_optimized
        && fabs(delta - round(delta)) < 0.0000001;
    if (cache->bytes != bytes) {
        uint8_t *replacement = (uint8_t *)realloc(cache->pixels, bytes);
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
    cache->damage_row_count = 0;
    native_video_backdrops_keep_visible(cache, reuse);
    native_scroll_repainted_count = -1;
    if (!reuse) {
        cache->row_origin = 0;
        return 0;
    }
    CGContextFlush(context);
    long rows = lround(delta);
    native_scroll_repainted_count = 0;
    if (rows) {
        long strip_rows = labs(rows) < (long)h ? labs(rows) : (long)h;
        long *strip_rect = native_scroll_repainted[native_scroll_repainted_count++];
        strip_rect[0] = 0;
        strip_rect[1] = rows < 0 ? 0 : (long)h - strip_rows;
        strip_rect[2] = (long)w;
        strip_rect[3] = rows < 0 ? strip_rows : (long)h;
    }
    if (damage_optimized) {
        cache->row_origin = (cache->row_origin + h + rows) % h;
        cache->dirty_rows = (size_t)labs(rows);
        cache->dirty_first = rows < 0 ? 0 : h - cache->dirty_rows;
        // The caller clears under the damage clip after begin. Preserve the
        // original white canvas outside the cached document as well, without
        // clearing document pixels that will be restored from the ring.
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
    CGRect clips[VOX_SCROLL_RASTER_MAX_DAMAGE_RECTS + 1];
    size_t clip_count = 0;
    clips[clip_count++] = CGRectMake(0,
        *scroll_delta < 0 ? bottom + height - strip : bottom, width, strip);
    for (int index = 0; index < damage_count; ++index) {
        const double *rect = damage + index * 4;
        if (!isfinite(rect[0]) || !isfinite(rect[1]) || !isfinite(rect[2]) || !isfinite(rect[3]))
            continue;
        double left = fmax(0, rect[0]), right = fmin(width, rect[0] + rect[2]);
        double top_edge = fmax(0, rect[1]), bottom_edge = fmin(height, rect[1] + rect[3]);
        if (right <= left || bottom_edge <= top_edge) continue;
        // Changed content rewrites rows outside the exposed strip; store
        // those rows back into the ring as well, and only those.
        size_t first_row = (size_t)floor(top_edge * scale + 0.0000001);
        size_t end_row = (size_t)ceil(bottom_edge * scale - 0.0000001);
        if (end_row > h) end_row = h;
        if (end_row > first_row) {
            cache->damage_rows[cache->damage_row_count][0] = first_row;
            cache->damage_rows[cache->damage_row_count][1] = end_row - first_row;
            ++cache->damage_row_count;
        }
        clips[clip_count++] = CGRectMake(left, bottom + height - bottom_edge,
            right - left, bottom_edge - top_edge);
        // Only whole device pixels inside the clip are freshly painted.
        long *repainted = native_scroll_repainted[native_scroll_repainted_count];
        repainted[0] = (long)ceil(left * scale);
        repainted[1] = (long)ceil(top_edge * scale);
        repainted[2] = (long)floor(right * scale);
        repainted[3] = (long)floor(bottom_edge * scale);
        if (repainted[2] > repainted[0] && repainted[3] > repainted[1])
            ++native_scroll_repainted_count;
    }
    if (damage_optimized) {
        CGContextFlush(context);
        native_scroll_raster_restore_visible(cache, pixels, pitch,
            rows < 0 ? cache->dirty_rows : 0, h - cache->dirty_rows, opaque_clear);
    }
    CGContextClipToRects(context, clips, clip_count);
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
    uint8_t *pixels = (uint8_t *)CGBitmapContextGetData(context);
    size_t pitch = CGBitmapContextGetBytesPerRow(context);
    if (pixels) {
        if (cache->damage_optimized) {
            native_scroll_raster_store_rows(cache, pixels, pitch);
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
// A video's retained rectangle, in CSS pixels of the document, as device
// pixels at the ring's density and scroll. Fractional device geometry cannot
// be anchored to the document and is rejected.
static int native_video_backdrop_geometry(const VoxScrollRaster *cache, double scroll,
    double x, double y, double width, double height, long *out, long *origin) {
    double scale = cache->scale;
    double values[5] = {x * scale, y * scale, width * scale, height * scale, scroll * scale};
    for (int index = 0; index < 5; ++index)
        if (!isfinite(values[index]) || fabs(values[index]) > 16777216
            || fabs(values[index] - round(values[index])) > 0.0000001) return 0;
    for (int index = 0; index < 4; ++index) out[index] = lround(values[index]);
    *origin = lround(values[4]);
    return scale > 0 && out[2] > 0 && out[3] > 0 && out[0] >= 0
        && out[0] + out[2] <= (long)cache->width
        && (size_t)out[2] * (size_t)out[3] * 4 <= 32 * 1024 * 1024;
}

static VoxVideoBackdrop *native_video_backdrop_find(const VoxScrollRaster *cache,
    const long *rect, int create) {
    VoxVideoBackdrop *oldest = NULL;
    for (int index = 0; index < VOX_VIDEO_BACKDROPS; ++index) {
        VoxVideoBackdrop *backdrop = &native_video_backdrops[index];
        if (backdrop->pixels && backdrop->owner == cache->owner && backdrop->scale == cache->scale
            && backdrop->x == rect[0] && backdrop->y == rect[1]
            && backdrop->width == rect[2] && backdrop->height == rect[3]) {
            backdrop->stamp = ++native_video_backdrop_clock;
            return backdrop;
        }
        if (!oldest || backdrop->stamp < oldest->stamp) oldest = backdrop;
    }
    if (!create || !oldest) return NULL;
    free(oldest->pixels);
    free(oldest->valid);
    *oldest = (VoxVideoBackdrop){0};
    oldest->pixels = (uint8_t *)malloc((size_t)rect[2] * (size_t)rect[3] * 4);
    oldest->valid = (uint8_t *)calloc((size_t)rect[3], 1);
    if (!oldest->pixels || !oldest->valid) {
        free(oldest->pixels);
        free(oldest->valid);
        *oldest = (VoxVideoBackdrop){0};
        return NULL;
    }
    oldest->x = rect[0]; oldest->y = rect[1];
    oldest->width = rect[2]; oldest->height = rect[3];
    oldest->owner = cache->owner;
    oldest->scale = cache->scale;
    oldest->stamp = ++native_video_backdrop_clock;
    return oldest;
}

// The document rows of the backdrop visible at `origin`, as [first, end).
static int native_video_backdrop_visible(const VoxScrollRaster *cache, const long *rect,
    long origin, long *first, long *end) {
    *first = rect[1] > origin ? rect[1] : origin;
    long viewport_end = origin + (long)cache->height;
    *end = rect[1] + rect[3] < viewport_end ? rect[1] + rect[3] : viewport_end;
    return *end > *first;
}

// Whether the next frame, at `scroll`, can restore every visible row.
static int native_video_backdrop_ready(uint64_t owner, double scroll,
    double x, double y, double width, double height) {
    VoxScrollRaster *cache = &native_scroll_raster;
    long rect[4], origin, first, end;
    if (!cache->valid || cache->active || cache->owner != owner
        || !native_video_backdrop_geometry(cache, scroll, x, y, width, height, rect, &origin)) return 0;
    VoxVideoBackdrop *backdrop = native_video_backdrop_find(cache, rect, 0);
    if (!backdrop || !native_video_backdrop_visible(cache, rect, origin, &first, &end)) return 0;
    for (long row = first; row < end; ++row)
        if (!backdrop->valid[row - rect[1]]) return 0;
    return 1;
}

// Store the freshly painted pixels beneath a video, just before it draws.
static void native_video_backdrop_capture(CGContextRef current,
    double x, double y, double width, double height) {
    VoxScrollRaster *cache = &native_scroll_raster;
    long rect[4], origin, first, end;
    if (!cache->active || !current || current != cache->context
        || !native_video_backdrop_geometry(cache, cache->scroll, x, y, width, height, rect, &origin)
        || !native_video_backdrop_visible(cache, rect, origin, &first, &end)) return;
    VoxVideoBackdrop *backdrop = native_video_backdrop_find(cache, rect, 1);
    uint8_t *canvas = (uint8_t *)CGBitmapContextGetData(current);
    if (!backdrop || !canvas) return;
    CGContextFlush(current);
    size_t pitch = CGBitmapContextGetBytesPerRow(current);
    long whole[4] = {0, 0, (long)cache->width, (long)cache->height};
    int count = native_scroll_repainted_count < 0 ? 1 : native_scroll_repainted_count;
    for (int index = 0; index < count; ++index) {
        const long *painted = native_scroll_repainted_count < 0 ? whole : native_scroll_repainted[index];
        long left = painted[0] > rect[0] ? painted[0] : rect[0];
        long right = painted[2] < rect[0] + rect[2] ? painted[2] : rect[0] + rect[2];
        long top = painted[1] + origin > first ? painted[1] + origin : first;
        long bottom = painted[3] + origin < end ? painted[3] + origin : end;
        if (right <= left || bottom <= top) continue;
        int complete = left == rect[0] && right == rect[0] + rect[2];
        for (long row = top; row < bottom; ++row) {
            long local = row - rect[1];
            memcpy(backdrop->pixels + ((size_t)local * rect[2] + (left - rect[0])) * 4,
                canvas + (cache->top + (size_t)(row - origin)) * pitch + (size_t)left * 4,
                (size_t)(right - left) * 4);
            if (complete) backdrop->valid[local] = 1;
        }
    }
}

// A video replayed without capturing (another video restores in this frame, or
// this one is not eligible) leaves the rows it repainted beneath it stale.
static void native_video_backdrop_invalidate(double x, double y, double width, double height) {
    VoxScrollRaster *cache = &native_scroll_raster;
    long rect[4], origin;
    if (!cache->active
        || !native_video_backdrop_geometry(cache, cache->scroll, x, y, width, height, rect, &origin)) {
        native_discard_video_backdrops();
        return;
    }
    VoxVideoBackdrop *backdrop = native_video_backdrop_find(cache, rect, 0);
    if (!backdrop) return;
    long whole[4] = {0, 0, (long)cache->width, (long)cache->height};
    int count = native_scroll_repainted_count < 0 ? 1 : native_scroll_repainted_count;
    for (int index = 0; index < count; ++index) {
        const long *painted = native_scroll_repainted_count < 0 ? whole : native_scroll_repainted[index];
        if (painted[2] <= rect[0] || painted[0] >= rect[0] + rect[2]) continue;
        for (long row = painted[1] + origin; row < painted[3] + origin; ++row)
            if (row >= rect[1] && row < rect[1] + rect[3]) backdrop->valid[row - rect[1]] = 0;
    }
}

// Replace the visible rectangle with its retained backdrop before the video
// draws. Returns zero, leaving the canvas untouched, unless every row is valid.
typedef int (*VoxVideoBackdropGpuRestore)(CGContextRef, const uint8_t *,
    int, int, int, int, int);

static int native_video_backdrop_restore_with_gpu(CGContextRef current,
    double x, double y, double width, double height, VoxVideoBackdropGpuRestore gpu_restore) {
    VoxScrollRaster *cache = &native_scroll_raster;
    long rect[4], origin, first, end;
    if (!cache->active || !cache->reused || !current || current != cache->context
        || !native_video_backdrop_geometry(cache, cache->scroll, x, y, width, height, rect, &origin)
        || !native_video_backdrop_visible(cache, rect, origin, &first, &end)) return 0;
    VoxVideoBackdrop *backdrop = native_video_backdrop_find(cache, rect, 0);
    uint8_t *canvas = (uint8_t *)CGBitmapContextGetData(current);
    if (!backdrop || !canvas) return 0;
    for (long row = first; row < end; ++row)
        if (!backdrop->valid[row - rect[1]]) return 0;
    if (gpu_restore && gpu_restore(current,
            backdrop->pixels + (size_t)(first - rect[1]) * rect[2] * 4,
            (int)rect[2], (int)(end - first), (int)rect[2] * 4,
            (int)rect[0], (int)(cache->top + first - origin))) return 1;
    CGContextFlush(current);
    size_t pitch = CGBitmapContextGetBytesPerRow(current);
    for (long row = first; row < end; ++row)
        memcpy(canvas + (cache->top + (size_t)(row - origin)) * pitch + (size_t)rect[0] * 4,
            backdrop->pixels + (size_t)(row - rect[1]) * rect[2] * 4, (size_t)rect[2] * 4);
    return 1;
}

static int native_video_backdrop_restore(CGContextRef current,
    double x, double y, double width, double height) {
    return native_video_backdrop_restore_with_gpu(current, x, y, width, height, NULL);
}
#endif
