#ifndef VOX_NATIVE_OPACITY_CANVAS_POOL_DARWIN_H
#define VOX_NATIVE_OPACITY_CANVAS_POOL_DARWIN_H

#include <CoreGraphics/CoreGraphics.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>

// Main-thread opacity groups keep the original full-canvas device space.
// Reuse only idle canvases; nested groups must own distinct backing stores.
// The clip supplied on release bounds every write to the group. Small buffers
// clear that region; large dedicated mappings discard all payload pages. Both
// leave a transparent canvas for the next, possibly disjoint, clip.
typedef struct {
    CGContextRef context;
    uint8_t *pixels;
} VoxOpacityCanvas;

#define VOX_OPACITY_CANVAS_POOL_SLOTS 2
// Large canvases own page-aligned mappings so idle payload can be discarded
// without changing the CGContext, virtual capacity, or surviving snapshots.
#define VOX_OPACITY_CANVAS_MAPPED_MIN_BYTES (1024u * 1024u)
#define VOX_OPACITY_CANVAS_POOL_BYTES (32u * 1024u * 1024u)
static VoxOpacityCanvas native_opacity_canvas_pool[VOX_OPACITY_CANVAS_POOL_SLOTS];
static size_t native_opacity_canvas_pool_bytes;

static int native_opacity_canvas_pool_disabled(void) {
    const char *value = getenv("VOX_DISABLE_OPACITY_CANVAS_POOL");
    return value && *value;
}

static size_t native_opacity_canvas_bytes(VoxOpacityCanvas canvas) {
    return CGBitmapContextGetHeight(canvas.context) * CGBitmapContextGetBytesPerRow(canvas.context);
}

static void native_destroy_opacity_canvas(VoxOpacityCanvas canvas) {
    size_t bytes = native_opacity_canvas_bytes(canvas);
    CGContextRelease(canvas.context);
    if (bytes >= VOX_OPACITY_CANVAS_MAPPED_MIN_BYTES) munmap(canvas.pixels, bytes);
    else free(canvas.pixels);
}

static void native_discard_opacity_canvas_pool(void) {
    for (size_t i = 0; i < VOX_OPACITY_CANVAS_POOL_SLOTS; ++i) {
        if (native_opacity_canvas_pool[i].context)
            native_destroy_opacity_canvas(native_opacity_canvas_pool[i]);
        native_opacity_canvas_pool[i] = (VoxOpacityCanvas){0};
    }
    native_opacity_canvas_pool_bytes = 0;
}

static VoxOpacityCanvas native_acquire_opacity_canvas(size_t width, size_t height,
    CGColorSpaceRef color_space) {
    VoxOpacityCanvas canvas = {0};
    if (!width || !height || width > SIZE_MAX / 4 || height > SIZE_MAX / (width * 4))
        return canvas;
    if (native_opacity_canvas_pool_disabled()) native_discard_opacity_canvas_pool();
    for (size_t i = 0; i < VOX_OPACITY_CANVAS_POOL_SLOTS; ++i) {
        CGContextRef context = native_opacity_canvas_pool[i].context;
        if (context && CGBitmapContextGetWidth(context) == width
            && CGBitmapContextGetHeight(context) == height
            && CFEqual(CGBitmapContextGetColorSpace(context), color_space)) {
            canvas = native_opacity_canvas_pool[i];
            native_opacity_canvas_pool[i] = (VoxOpacityCanvas){0};
            native_opacity_canvas_pool_bytes -= native_opacity_canvas_bytes(canvas);
            break;
        }
    }
    if (!canvas.context) {
        size_t bytes = height * width * 4;
        if (bytes >= VOX_OPACITY_CANVAS_MAPPED_MIN_BYTES) {
            void *mapping = mmap(NULL, bytes, PROT_READ | PROT_WRITE,
                MAP_PRIVATE | MAP_ANON, -1, 0);
            if (mapping == MAP_FAILED) return canvas;
            canvas.pixels = (uint8_t *)mapping;
        } else {
            canvas.pixels = (uint8_t *)calloc(height, width * 4);
            if (!canvas.pixels) return canvas;
        }
        canvas.context = CGBitmapContextCreate(canvas.pixels, width, height, 8, width * 4,
            color_space, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
        if (!canvas.context) {
            if (bytes >= VOX_OPACITY_CANVAS_MAPPED_MIN_BYTES) munmap(canvas.pixels, bytes);
            else free(canvas.pixels);
            return (VoxOpacityCanvas){0};
        }
    }
    // Restore graphics state, including the CTM and clip, on release.
    // Quartz paths, text geometry and the allows* switches are context state.
    CGContextBeginPath(canvas.context);
    CGContextSetTextMatrix(canvas.context, CGAffineTransformIdentity);
    CGContextSetTextPosition(canvas.context, 0, 0);
    CGContextSetAllowsAntialiasing(canvas.context, true);
    CGContextSetAllowsFontSmoothing(canvas.context, true);
    CGContextSetAllowsFontSubpixelPositioning(canvas.context, true);
    CGContextSetAllowsFontSubpixelQuantization(canvas.context, true);
    CGContextSaveGState(canvas.context);
    return canvas;
}

static void native_release_opacity_canvas(VoxOpacityCanvas canvas, size_t left,
    size_t top, size_t right, size_t bottom) {
    if (!canvas.context) return;
    CGContextFlush(canvas.context);
    CGContextRestoreGState(canvas.context);
    size_t width = CGBitmapContextGetWidth(canvas.context);
    size_t height = CGBitmapContextGetHeight(canvas.context);
    size_t bytes = native_opacity_canvas_bytes(canvas);
    // An invalid clearing region cannot establish transparency for reuse.
    if (left > right || top > bottom || right > width || bottom > height
        || bytes > VOX_OPACITY_CANVAS_POOL_BYTES || native_opacity_canvas_pool_disabled()) {
        native_destroy_opacity_canvas(canvas);
        return;
    }
    // Prefer a recent viewport over stale dimensions/color spaces. At most
    // two idle canvases and 32 MiB of pixels survive between groups.
    size_t slot = 0;
    for (; slot < VOX_OPACITY_CANVAS_POOL_SLOTS; ++slot)
        if (!native_opacity_canvas_pool[slot].context) break;
    if (slot == VOX_OPACITY_CANVAS_POOL_SLOTS
        || native_opacity_canvas_pool_bytes > VOX_OPACITY_CANVAS_POOL_BYTES - bytes) {
        native_discard_opacity_canvas_pool();
        slot = 0;
    }
    size_t pitch = CGBitmapContextGetBytesPerRow(canvas.context);
    if (bytes >= VOX_OPACITY_CANVAS_MAPPED_MIN_BYTES) {
        // Replacing our own mapping releases physical pages and guarantees
        // transparent bytes on reuse. No malloc metadata or live payload is
        // inside this dedicated reservation. Quartz has flushed the group.
        if (mmap(canvas.pixels, bytes, PROT_READ | PROT_WRITE,
                MAP_PRIVATE | MAP_ANON | MAP_FIXED, -1, 0) == MAP_FAILED) {
            native_destroy_opacity_canvas(canvas);
            return;
        }
    } else {
        for (size_t row = top; row < bottom; ++row)
            memset(canvas.pixels + row * pitch + left * 4, 0, (right - left) * 4);
    }
    native_opacity_canvas_pool[slot] = canvas;
    native_opacity_canvas_pool_bytes += bytes;
}

#endif
