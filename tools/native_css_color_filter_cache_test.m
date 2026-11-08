#import <Cocoa/Cocoa.h>
#import <CoreImage/CoreImage.h>
#include <assert.h>
#include "native/include/native_layer_presentation_darwin.h"
#include "native/include/native_bitmap_snapshot_darwin.h"
typedef struct { uint8_t r,g,b,a; } gg__Color;
typedef struct { int unused; } gg__Image;
static CGContextRef native_font_compositing_context;
static int native_font_compositing_transparency_depth;
static CGFloat native_svg_mask_backing_scale(void) { return 2; }
#include "native_document_canvas_entry_points.inc"

static NSData *packed(CGImageRef image) {
    CFDataRef data = CGDataProviderCopyData(CGImageGetDataProvider(image));
    assert(data);
    size_t width = CGImageGetWidth(image), height = CGImageGetHeight(image);
    size_t pitch = CGImageGetBytesPerRow(image);
    NSMutableData *result = [NSMutableData dataWithLength:width * height * 4];
    for (size_t row = 0; row < height; ++row)
        memcpy((uint8_t *)result.mutableBytes + row * width * 4,
            CFDataGetBytePtr(data) + row * pitch, width * 4);
    CFRelease(data);
    return result;
}

static CGImageRef source(int bgra, int wide, int seed, int size) {
    size_t pitch = size * 4 + 32;
    NSMutableData *data = [NSMutableData dataWithLength:pitch * size];
    for (int y = 0; y < size; ++y) for (int x = 0; x < size; ++x) {
        uint8_t *p = (uint8_t *)data.mutableBytes + y * pitch + x * 4;
        int alpha = (x * 17 + y * 23 + seed) & 255;
        p[bgra ? 2 : 0] = (x * 37 + seed) % (alpha + 1);
        p[1] = (y * 71 + seed) % (alpha + 1);
        p[bgra ? 0 : 2] = (x * 11 + y * 7) % (alpha + 1);
        p[3] = alpha;
    }
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    CGColorSpaceRef color = CGColorSpaceCreateWithName(wide ? kCGColorSpaceDisplayP3 : kCGColorSpaceSRGB);
    CGImageRef image = CGImageCreate(size, size, 8, 32, pitch, color,
        bgra ? kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little
             : kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big,
        provider, NULL, true, kCGRenderingIntentDefault);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(color);
    assert(image);
    return image;
}

static CGImageRef selected;
static int offset;
static void paint(id view, SEL selector, NSRect rect) {
    CGContextRef frame = NSGraphicsContext.currentContext.CGContext;
    CGContextSetRGBFillColor(frame, .1, .3, .6, 1);
    CGContextFillRect(frame, rect);
    native_begin_css_filter_layer(128, 128);
    CGContextDrawImage(NSGraphicsContext.currentContext.CGContext,
        CGRectMake(12 + offset, 19 + offset, 37, 37), selected);
    native_add_css_filter_operation(2, .65, 2, 0, (gg__Color){0});
    native_add_css_filter_operation(3, 33, 0, 0, (gg__Color){0});
    native_end_css_filter_layer();
}

int main(void) { @autoreleasepool {
    setenv("VOX_CACHE_CSS_COLOR_FILTERS", "1", 1);
    unsigned cases = 0;
    for (int bgra = 0; bgra < 2; ++bgra) for (int wide = 0; wide < 2; ++wide)
        for (int kind = 0; kind < 8; ++kind) {
            CGImageRef input = source(bgra, wide, 3, 41);
            NativeCSSFilterOperation operations[] = {
                {.kind = kind == 7 ? 3 : 2, .first = kind == 7 ? 33 : .65, .second = kind},
                {.kind = 2, .first = .75, .second = 3}
            };
            NativeCSSFilterLayer layer = {.operations = operations, .operation_count = 2};
            native_initialize_css_filter_renderer();
            CIImage *filtered = native_apply_css_filter_layer(&layer, input);
            CGImageRef reference = [native_css_filter_ci_context createCGImage:filtered
                fromRect:CGRectMake(0, 0, 41, 41) format:kCIFormatRGBA8 colorSpace:native_css_filter_color_space];
            CGImageRef cold = native_cached_css_color_filter_image(&layer, input);
            assert(cold && [packed(cold) isEqualToData:packed(reference)]);
            uint64_t hits = native_color_filter_cache_hits;
            CGImageRelease(input);
            input = source(bgra, wide, 3, 41); // Equal bytes in a different provider.
            CGImageRef warm = native_cached_css_color_filter_image(&layer, input);
            assert(warm && native_color_filter_cache_hits == hits + 1);
            assert([packed(warm) isEqualToData:packed(reference)]);
            operations[0].first += .125;
            CGImageRef changed = native_cached_css_color_filter_image(&layer, input);
            assert(changed && native_color_filter_cache_hits == hits + 1);
            CGImageRelease(input);
            input = source(bgra, wide, 11, 41);
            CGImageRef changed_pixels = native_cached_css_color_filter_image(&layer, input);
            assert(changed_pixels && native_color_filter_cache_hits == hits + 1);
            CGImageRelease(changed_pixels);
            layer.graph_node_count = 1;
            assert(!native_cached_css_color_filter_image(&layer, input));
            layer.graph_node_count = 0;
            operations[0].kind = 0;
            assert(!native_cached_css_color_filter_image(&layer, input));
            CGImageRelease(changed); CGImageRelease(warm); CGImageRelease(cold);
            CGImageRelease(reference); CGImageRelease(input);
            ++cases;
            if (cases % 8 == 0) [native_css_filter_ci_context clearCaches];
        }
    NativeCSSFilterOperation operation = {.kind = 2, .first = .5, .second = 2};
    NativeCSSFilterLayer layer = {.operations = &operation, .operation_count = 1};
    CGImageRef oversized = source(0, 0, 1, 513);
    assert(!native_cached_css_color_filter_image(&layer, oversized));
    CGImageRelease(oversized);
    CGImageRef held = NULL;
    NSData *held_pixels = nil;
    for (int seed = 0; seed < 25; ++seed) {
        CGImageRef input = source(0, 0, seed, 256);
        CGImageRef output = native_cached_css_color_filter_image(&layer, input);
        assert(output && native_color_filter_cache_bytes <= native_color_filter_cache_limit);
        if (!seed) { held = CGImageRetain(output); held_pixels = packed(held); }
        CGImageRelease(input); CGImageRelease(output);
        if (seed % 4 == 0) [native_css_filter_ci_context clearCaches];
    }
    for (size_t slot = 0; slot < NATIVE_COLOR_FILTER_CACHE_SLOTS; ++slot)
        native_color_filter_cache_remove(slot);
    assert(native_color_filter_cache_bytes == 0 && [packed(held) isEqualToData:held_pixels]);
    CGImageRelease(held);
    NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 128, 128)];
    for (int wide = 0; wide < 2; ++wide) {
        selected = source(0, wide, 13, 37);
        for (offset = 0; offset < 3; ++offset) {
            setenv("VOX_DISABLE_COMPACT_CSS_FILTER_INPUT", "1", 1);
            CGImageRef reference = native_layer_raster_frame(view, 2, (IMP)paint);
            unsetenv("VOX_DISABLE_COMPACT_CSS_FILTER_INPUT");
            CGImageRef cold = native_layer_raster_frame(view, 2, (IMP)paint);
            uint64_t hits = native_color_filter_cache_hits;
            CGImageRef warm = native_layer_raster_frame(view, 2, (IMP)paint);
            assert(reference && cold && warm && native_color_filter_cache_hits == hits + 1);
            assert([packed(cold) isEqualToData:packed(reference)] && [packed(warm) isEqualToData:packed(reference)]);
            CGImageRelease(reference); CGImageRelease(cold); CGImageRelease(warm);
        }
        CGImageRelease(selected);
    }
    printf("CSS color filter cache: %u exact color/profile/format cases, changed inputs, eviction, ownership and translated real frames passed\n", cases);
}}
