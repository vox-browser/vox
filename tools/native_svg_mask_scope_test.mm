// Exercise the native mask entry points and the real shared compositor state.
#import <Cocoa/Cocoa.h>
#include "../native_skia_text_darwin.cpp"
#define restrict __restrict
#include "../native_svg_mask_pixels.h"
#undef restrict
#include "../native_svg_mask_layer_darwin.h"
#include <cassert>
#include <iostream>

#define LADYBIRD_V_HAS_SKIA_TEXT 1
static CGFloat test_scale = 1;
static CGFloat native_svg_mask_backing_scale(void) { return test_scale; }
static CGContextRef native_font_compositing_context;
static int native_font_compositing_transparency_depth;
// The production entry points compile as Objective-C, which permits void*
// conversion. Supply the same data with an explicit cast for this C++ fixture.
static uint8_t* mask_bitmap_data(CGContextRef context)
{
    return static_cast<uint8_t*>(CGBitmapContextGetData(context));
}
#define CGBitmapContextGetData mask_bitmap_data
#include "native_svg_mask_scope_entry_points.inc"
#undef CGBitmapContextGetData

static bool blocked(CGContextRef context)
{
    auto found = s_shared_clips.find(context);
    return found != s_shared_clips.end() && found->second.unsupported;
}

static void clear_cache()
{
    assert(!native_svg_clip_build_context);
    for (auto& entry : native_svg_clip_cache) {
        if (entry.image) CGImageRelease(entry.image);
        entry = {};
    }
    native_svg_clip_image = nullptr;
}

static void prepare(unsigned long long key, int kind, bool cached, CGRect ink)
{
    if (kind)
        native_begin_svg_content_mask(key, kind == 2, 64, 64,
            8, 8, 32, 40, 1, 0, 0, 1, 0, 0, 0, 0, 0);
    else
        native_begin_svg_clip_mask(key, 64, 64,
            8, 8, 32, 40, 1, 0, 0, 1, 0, 0, 0, 0, 0);
    assert(bool(native_svg_clip_build_context) != cached);
    if (auto context = native_svg_clip_build_context) {
        if (kind) CGContextSetRGBFillColor(context, 1, 1, 1, 1);
        CGContextFillRect(context, ink);
    }
}

static CGContextRef bitmap(std::vector<uint8_t>& pixels)
{
    int size = 64 * test_scale;
    pixels.resize(size * size * 4);
    auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = CGBitmapContextCreate(pixels.data(), size, size, 8, size * 4,
        space, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    assert(context);
    CGContextScaleCTM(context, test_scale, test_scale);
    CGContextSetRGBFillColor(context, 1, 1, 1, 1);
    CGContextFillRect(context, CGRectMake(0, 0, 64, 64));
    return context;
}

static void paint(CGContextRef context, CGRect rect, bool green = false)
{
    CGContextSetRGBFillColor(context, 0, green ? 1 : 0, green ? 0 : 1, 1);
    CGContextFillRect(context, rect);
}

static void scope_case(int kind, bool cached, bool parent_blocked, bool nested,
    bool missing)
{
    clear_cache();
    ladybird_v_skia_set_shared_recording(0, 64, 64);
    std::vector<uint8_t> actual, expected, independent_pixels;
    auto context = bitmap(actual);
    auto reference = bitmap(expected);
    auto independent = bitmap(independent_pixels);
    auto graphics = [NSGraphicsContext graphicsContextWithCGContext:context flipped:NO];
    [NSGraphicsContext setCurrentContext:graphics];
    native_font_compositing_context = context;
    native_font_compositing_transparency_depth = 0;
    // A pre-existing clip and saved scope must survive cache work and masking.
    float rect[] {0, 0, 64, 64, 2, 2, 2, 2, 2, 2, 2, 2};
    float transform[] {1, 0, 0, 1, 0, 0};
    ladybird_v_skia_add_shared_rounded_clip(context, rect, transform);
    native_begin_clip();
    if (parent_blocked) ladybird_v_skia_block_shared_clip(context);
    CGRect ink = CGRectMake(12, 24, 20, 16);
    if (cached) {
        prepare(123, kind, false, ink);
        assert(blocked(context) == parent_blocked);
        native_finish_svg_mask_cache();
    }
    prepare(123, kind, cached, ink);
    assert(blocked(context) == parent_blocked);
    assert(!blocked(independent));
    if (kind == 0) {
        native_begin_clip();
        native_finish_svg_clip_mask();
        assert(blocked(context));
        paint(context, CGRectMake(0, 0, 64, 64));
        native_end_clip();
    } else {
        native_finish_svg_mask_cache();
        assert(blocked(context) == parent_blocked);
        native_begin_svg_mask_layer();
        assert(blocked(context));
        assert(native_font_compositing_transparency_depth == 1);
        if (nested) {
            ink = CGRectMake(16, 28, 8, 8);
            prepare(456, kind, false, ink);
            native_finish_svg_mask_cache();
            native_begin_svg_mask_layer();
            assert(native_font_compositing_transparency_depth == 2);
        }
        paint(context, CGRectMake(0, 0, 64, 64));
        if (nested) {
            native_end_svg_mask_layer(456, 1, 64, 64, 0, 0, 0);
            assert(blocked(context));
            assert(native_font_compositing_transparency_depth == 1);
        }
        native_end_svg_mask_layer(missing ? 999 : 123, 1, 64, 64, 0, 0, 0);
        assert(native_font_compositing_transparency_depth == 0);
    }
    assert(blocked(context) == parent_blocked);
    auto& state = s_shared_clips.at(context);
    assert(state.clips.size() == 1 && state.saves.size() == 1);
    assert(!blocked(independent));
    // A subsequent sibling must use the full destination again.
    paint(context, CGRectMake(48, 4, 12, 12), true);
    if (!missing) paint(reference, ink);
    paint(reference, CGRectMake(48, 4, 12, 12), true);
    assert(actual == expected);
    native_end_clip();
    assert(!blocked(context));
    assert(s_shared_clips.at(context).clips.size() == 1);
    assert(s_shared_clips.at(context).saves.empty());
    [NSGraphicsContext setCurrentContext:nil];
    native_font_compositing_context = nullptr;
    ladybird_v_skia_set_shared_recording(0, 0, 0);
    CGContextRelease(context);
    CGContextRelease(reference);
    CGContextRelease(independent);
    clear_cache();
}

int main()
{
    @autoreleasepool {
        int cases = 0;
        for (int scale : {1, 2}) {
            test_scale = scale;
            for (int kind : {0, 1, 2})
                for (bool cached : {false, true})
                    for (bool parent : {false, true}) {
                        scope_case(kind, cached, parent, false, false);
                        ++cases;
                        if (kind) {
                            scope_case(kind, cached, parent, true, false);
                            scope_case(kind, cached, parent, false, true);
                            cases += 2;
                        }
                    }
        }
        native_begin_clip();
        native_end_clip();
        native_begin_svg_mask_layer();
        native_end_svg_mask_layer(0, 1, 64, 64, 0, 0, 0);
        assert(s_shared_clips.empty());
        std::cout << cases << " SVG mask scope and pixel cases passed\n";
    }
}
