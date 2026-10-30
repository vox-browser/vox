// Compile the real mask entry points with the production shared clip state.
#import <Cocoa/Cocoa.h>
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <iostream>

#define LADYBIRD_V_HAS_SKIA_TEXT 1
static CGFloat test_scale = 1;
static CGFloat native_svg_mask_backing_scale(void) { return test_scale; }
static void native_begin_tracked_transparency_layer(CGContextRef context, CFDictionaryRef info)
{
    CGContextBeginTransparencyLayer(context, info);
}
static void native_end_tracked_transparency_layer(CGContextRef context)
{
    CGContextEndTransparencyLayer(context);
}
#include "native_background_text_scope_entry_points.inc"

static bool blocked(CGContextRef context)
{
    auto found = s_shared_clips.find(context);
    return found != s_shared_clips.end() && found->second.unsupported;
}

static void scope_case(bool retained, bool parent_blocked, bool empty, bool outer_input = false)
{
    ladybird_v_skia_set_shared_recording(0, 64, 64);
    s_chromium_painting = retained;
    std::vector<uint8_t> pixels(size_t(64 * test_scale) * (64 * test_scale) * 4);
    auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = CGBitmapContextCreate(pixels.data(), 64 * test_scale, 64 * test_scale,
        8, 64 * test_scale * 4, space,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    std::vector<uint8_t> expected(pixels.size());
    auto reference = CGBitmapContextCreate(expected.data(), 64 * test_scale, 64 * test_scale,
        8, 64 * test_scale * 4, space,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    assert(context && reference);
    CGContextScaleCTM(context, test_scale, test_scale);
    CGContextScaleCTM(reference, test_scale, test_scale);
    [NSGraphicsContext setCurrentContext:[NSGraphicsContext
        graphicsContextWithCGContext:context flipped:NO]];
    float rect[] {0, 0, 64, 64, 2, 2, 2, 2, 2, 2, 2, 2};
    float transform[] {1, 0, 0, 1, 0, 0};
    ladybird_v_skia_add_shared_rounded_clip(context, rect, transform);
    native_begin_clip();
    if (parent_blocked) ladybird_v_skia_block_shared_clip(context);
    if (outer_input) assert(ladybird_v_skia_begin_isolated_input(context, 64, 64));
    if (retained) native_prepare_background_text_gradient_input();
    native_begin_background_text_clip(64, 64, 0, 0, empty ? 0 : 64, empty ? 0 : 64);
    // Preparing an offscreen mask does not change the destination's clip.
    assert(blocked(context) == parent_blocked);
    if (outer_input) assert(s_isolated_input_recordings.at(context)->unsupported);
    if (!empty) {
        CGContextSetRGBFillColor(native_background_text_clip_build_context, 0, 0, 0, 1);
        CGContextFillRect(native_background_text_clip_build_context, CGRectMake(8, 8, 16, 16));
        if (retained) {
            auto* canvas = isolated_input_recording_canvas(native_background_text_clip_build_context);
            assert(canvas);
            SkPaint ink;
            ink.setColor(SK_ColorBLACK);
            canvas->drawRect(SkRect::MakeXYWH(8, 40, 16, 16), ink);
        }
    }
    native_finish_background_text_clip();
    assert(blocked(context) == (parent_blocked || native_background_text_clip_active == 1));
    auto target = [[NSGraphicsContext currentContext] CGContext];
    CGContextSetRGBFillColor(target, 1, 0, 0, 1);
    CGContextFillRect(target, CGRectMake(0, 0, 64, 64));
    if (retained && !empty) {
        auto* canvas = isolated_input_recording_canvas(target);
        assert(canvas);
        SkPaint ink;
        ink.setColor(SK_ColorRED);
        canvas->drawRect(SkRect::MakeWH(64, 64), ink);
    }
    native_end_background_text_clip();
    assert([[NSGraphicsContext currentContext] CGContext] == context);
    assert(blocked(context) == parent_blocked);
    assert(s_isolated_input_recordings.size() == (outer_input ? 1 : 0));
    if (outer_input)
        ladybird_v_skia_discard_isolated_input(ladybird_v_skia_take_isolated_input(context));
    auto& state = s_shared_clips.at(context);
    assert(state.clips.size() == 1 && state.saves.size() == 1);
    // A later sibling must be drawable and recordable outside the text mask.
    CGContextSetRGBFillColor(context, 0, 1, 0, 1);
    CGContextFillRect(context, CGRectMake(48, 4, 12, 12));
    CGContextFlush(context);
    CGContextSetRGBFillColor(reference, 0, 1, 0, 1);
    CGContextFillRect(reference, CGRectMake(48, 4, 12, 12));
    CGContextFlush(reference);
    int checked = 0;
    for (size_t offset = 0; offset < pixels.size(); offset += 4) {
        if (expected[offset + 1] != 255) continue;
        assert(std::equal(expected.begin() + offset, expected.begin() + offset + 4,
            pixels.begin() + offset));
        ++checked;
    }
    assert(checked == 12 * 12 * test_scale * test_scale);
    native_end_clip();
    assert(!blocked(context));
    native_end_background_text_clip();
    assert(s_shared_clips.at(context).saves.empty());
    [NSGraphicsContext setCurrentContext:nil];
    ladybird_v_skia_set_shared_recording(0, 0, 0);
    CGContextRelease(context);
    CGContextRelease(reference);
}

int main()
{
    @autoreleasepool {
        assert(shared_picture_draw());
        for (int scale : {1, 2}) {
            test_scale = scale;
            for (bool retained : {false, true})
                for (bool parent : {false, true})
                    for (bool empty : {false, true}) {
                        scope_case(retained, parent, empty);
                        if (retained) scope_case(retained, parent, empty, true);
                    }
        }
        assert(s_shared_clips.empty());
        std::cout << "24 text mask scope, parent recording and sibling pixel cases passed\n";
    }
}
