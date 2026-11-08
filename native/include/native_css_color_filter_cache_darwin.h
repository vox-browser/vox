#pragma once
#include "../../platform/native_state.h"

// Pointwise color filters depend only on their owned input rows, profile and
// operations. Reuse identical small inputs even when scrolling moves them.
// Main-thread document painting owns this bounded cache, like the CIContext.
enum { NATIVE_COLOR_FILTER_CACHE_SLOTS = 16 };
static const size_t native_color_filter_cache_limit = 8 * 1024 * 1024;
typedef struct {
    CFDataRef pixels;
    CGColorSpaceRef color;
    CGImageRef output;
    size_t width, height, pitch, bytes, operation_count;
    CGBitmapInfo info;
    NativeCSSFilterOperation operations[16];
    uint64_t used;
} NativeColorFilterCacheEntry;
VOX_NATIVE_STATE NativeColorFilterCacheEntry native_color_filter_cache[NATIVE_COLOR_FILTER_CACHE_SLOTS];
VOX_NATIVE_STATE size_t native_color_filter_cache_bytes;
VOX_NATIVE_STATE uint64_t native_color_filter_cache_clock, native_color_filter_cache_hits;

static void native_color_filter_cache_remove(size_t index) {
    NativeColorFilterCacheEntry *entry = &native_color_filter_cache[index];
    if (!entry->output) return;
    native_color_filter_cache_bytes -= entry->bytes;
    CFRelease(entry->pixels);
    CGColorSpaceRelease(entry->color);
    CGImageRelease(entry->output);
    memset(entry, 0, sizeof(*entry));
}

static size_t native_color_filter_cache_oldest(void) {
    size_t oldest = SIZE_MAX;
    for (size_t index = 0; index < NATIVE_COLOR_FILTER_CACHE_SLOTS; ++index) {
        if (native_color_filter_cache[index].output && (oldest == SIZE_MAX
            || native_color_filter_cache[index].used < native_color_filter_cache[oldest].used)) oldest = index;
    }
    return oldest;
}

static CGImageRef native_cached_css_color_filter_image(NativeCSSFilterLayer const *layer,
    CGImageRef input) {
    if (!getenv("VOX_CACHE_CSS_COLOR_FILTERS") || getenv("VOX_DISABLE_CSS_COLOR_FILTER_CACHE")
        || !input || !layer->operations || !layer->operation_count || layer->operation_count > 16
        || layer->graph_node_count || CGImageGetBitsPerComponent(input) != 8
        || CGImageGetBitsPerPixel(input) != 32 || CGImageGetDecode(input)) return NULL;
    for (size_t index = 0; index < layer->operation_count; ++index)
        if (layer->operations[index].kind != 2 && layer->operations[index].kind != 3) return NULL;
    size_t width = CGImageGetWidth(input), height = CGImageGetHeight(input);
    size_t pitch = CGImageGetBytesPerRow(input);
    CGColorSpaceRef color = CGImageGetColorSpace(input);
    CGBitmapInfo info = CGImageGetBitmapInfo(input);
    if (!color || !width || !height || width > SIZE_MAX / 4 || pitch < width * 4
        || pitch > 1024 * 1024 / height) return NULL;
    CFDataRef pixels = CGDataProviderCopyData(CGImageGetDataProvider(input));
    if (!pixels || CFDataGetLength(pixels) != pitch * height) {
        if (pixels) CFRelease(pixels);
        return NULL;
    }
    for (size_t index = 0; index < NATIVE_COLOR_FILTER_CACHE_SLOTS; ++index) {
        NativeColorFilterCacheEntry *entry = &native_color_filter_cache[index];
        if (!entry->output || entry->width != width || entry->height != height || entry->pitch != pitch
            || entry->info != info || entry->operation_count != layer->operation_count
            || !CFEqual(entry->color, color)
            || memcmp(entry->operations, layer->operations, layer->operation_count * sizeof(*layer->operations))
            || !CFEqual(entry->pixels, pixels)) continue;
        entry->used = ++native_color_filter_cache_clock;
        ++native_color_filter_cache_hits;
        CFRelease(pixels);
        if (getenv("VOX_CSS_COLOR_FILTER_CACHE_DIAGNOSTICS"))
            fprintf(stderr, "Vox CSS color filter cache: hit size=%zux%zu bytes=%zu\n", width, height, entry->bytes);
        return CGImageRetain(entry->output);
    }
    CGImageRef output = native_render_css_filter_image(layer, input,
        CGRectMake(0, 0, width, height), YES);
    size_t output_pitch = output ? CGImageGetBytesPerRow(output) : 0;
    if (!output || output_pitch > native_color_filter_cache_limit / height) {
        CFRelease(pixels);
        return output;
    }
    size_t bytes = pitch * height + output_pitch * height;
    CFDataRef owned = bytes <= native_color_filter_cache_limit
        ? CFDataCreate(NULL, CFDataGetBytePtr(pixels), CFDataGetLength(pixels)) : NULL;
    CFRelease(pixels);
    if (!owned) return output;
    while (native_color_filter_cache_bytes + bytes > native_color_filter_cache_limit)
        native_color_filter_cache_remove(native_color_filter_cache_oldest());
    size_t slot = native_color_filter_cache_oldest();
    for (size_t index = 0; index < NATIVE_COLOR_FILTER_CACHE_SLOTS; ++index)
        if (!native_color_filter_cache[index].output) { slot = index; break; }
    native_color_filter_cache_remove(slot);
    NativeColorFilterCacheEntry *entry = &native_color_filter_cache[slot];
    *entry = (NativeColorFilterCacheEntry){.pixels = owned, .color = CGColorSpaceRetain(color),
        .output = CGImageRetain(output), .width = width, .height = height, .pitch = pitch,
        .bytes = bytes, .operation_count = layer->operation_count, .info = info,
        .used = ++native_color_filter_cache_clock};
    memcpy(entry->operations, layer->operations, layer->operation_count * sizeof(*layer->operations));
    native_color_filter_cache_bytes += bytes;
    if (getenv("VOX_CSS_COLOR_FILTER_CACHE_DIAGNOSTICS"))
        fprintf(stderr, "Vox CSS color filter cache: miss size=%zux%zu bytes=%zu total=%zu\n",
            width, height, bytes, native_color_filter_cache_bytes);
    return output;
}
