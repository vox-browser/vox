// Exercise the native mask entry points and the real shared compositor state.
#import <Cocoa/Cocoa.h>
#include "../native_skia_text_darwin.cpp"
#define restrict __restrict
#include "../native_svg_mask_pixels.h"
#undef restrict
#include "../native_svg_mask_layer_darwin.h"
#include "../native_svg_mask_opacity_darwin.h"
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
        assert(native_svg_clip_build_opacity_depth == 0);
        native_begin_svg_mask_opacity(.5);
        native_begin_svg_mask_opacity(.75);
        assert(native_svg_clip_build_opacity_depth == 2);
        native_end_svg_mask_opacity();
        assert(native_svg_clip_build_opacity_depth == 1);
        native_end_svg_mask_opacity();
        assert(native_svg_clip_build_opacity_depth == 0);
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

static void opacity_case(float opacity, bool nested)
{
    clear_cache();
    std::vector<uint8_t> page_pixels;
    auto page = bitmap(page_pixels);
    native_font_compositing_context = page;
    native_begin_svg_content_mask(987, 1, 64, 64, 8, 8, 32, 40,
        1, 0, 0, 1, 0, 0, 0, 0, 0);
    auto parent = native_svg_clip_build_context;
    assert(parent);
    auto ctm = CGContextGetCTM(parent);
    auto clip = CGContextGetClipBoundingBox(parent);
    CGContextSetRGBFillColor(parent, 1, 1, 1, 1);
    CGContextFillRect(parent, clip);
    CGContextFlush(parent);
    int width = CGBitmapContextGetWidth(parent), height = CGBitmapContextGetHeight(parent);
    int pitch = CGBitmapContextGetBytesPerRow(parent);
    auto info = SkImageInfo::Make(width, height, kRGBA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto background = SkImages::RasterFromPixmapCopy(
        SkPixmap(info, CGBitmapContextGetData(parent), pitch));
    assert(background);
    SkPictureRecorder recorder;
    auto* canvas = recorder.beginRecording(SkRect::MakeWH(width, height));
    canvas->drawImage(background, 0, 0);
    canvas->translate(ctm.tx, height - 64 * test_scale - ctm.ty);
    canvas->scale(test_scale, test_scale);
    // Model the compositor's float texture modulation with a color filter;
    // keep the picture paint's own alpha at one.
    auto group_paint = [](float value) {
        float matrix[] {1, 0, 0, 0, 0, 0, 1, 0, 0, 0,
            0, 0, 1, 0, 0, 0, 0, 0, value, 0};
        SkPaint result; result.setColorFilter(SkColorFilters::Matrix(matrix)); return result;
    };
    SkPaint alpha = group_paint(opacity);
    canvas->saveLayer(nullptr, &alpha);
    SkPaint paint; paint.setColor(SK_ColorBLACK);
    canvas->drawRect(SkRect::MakeXYWH(12, 12, 16, 16), paint);
    if (nested) {
        alpha = group_paint(.625);
        canvas->saveLayer(nullptr, &alpha);
        paint.setColor(SK_ColorWHITE);
        canvas->drawRect(SkRect::MakeXYWH(16, 16, 16, 16), paint);
        canvas->restore();
    }
    canvas->restore();
    SkSerialProcs procs; procs.fImageProc = serialize_shared_picture_image;
    auto bytes = recorder.finishRecordingAsPicture()->serialize(&procs);
    std::vector<uint32_t> expected(size_t(width) * height);
    float identity[] {1, 0, 0, 0, 1, 0, 0, 0, 1};
    assert(bytes && shared_picture_draw()(reinterpret_cast<uint8_t*>(expected.data()),
        width, height, width * 4, bytes->data(), bytes->size(), identity));

    native_begin_svg_mask_opacity(opacity);
    CGContextSetRGBFillColor(native_svg_clip_build_context, 0, 0, 0, 1);
    CGContextFillRect(native_svg_clip_build_context, CGRectMake(12, 64 - 12 - 16, 16, 16));
    if (nested) {
        native_begin_svg_mask_opacity(.625);
        CGContextSetRGBFillColor(native_svg_clip_build_context, 1, 1, 1, 1);
        CGContextFillRect(native_svg_clip_build_context, CGRectMake(16, 64 - 16 - 16, 16, 16));
        native_end_svg_mask_opacity();
    }
    native_end_svg_mask_opacity();
    assert(native_svg_clip_build_opacity_depth == 0);
    assert(native_svg_clip_build_context == parent);
    assert(CGAffineTransformEqualToTransform(ctm, CGContextGetCTM(parent)));
    assert(CGRectEqualToRect(clip, CGContextGetClipBoundingBox(parent)));
    CGContextFlush(parent);
    auto* actual = static_cast<uint8_t*>(CGBitmapContextGetData(parent));
    auto* reference = reinterpret_cast<uint8_t*>(expected.data());
    int differences = 0;
    for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x)
        for (int c = 0; c < 4; ++c) {
            int bgra = c == 0 ? 2 : c == 2 ? 0 : c;
            if (actual[y * pitch + x * 4 + c] != reference[(y * width + x) * 4 + bgra]) ++differences;
        }
    if (differences) std::cerr << "Mask opacity mismatch: scale=" << test_scale
        << " opacity=" << opacity << " nested=" << nested << " bytes=" << differences << '\n';
    assert(differences == 0);
    native_finish_svg_mask_cache();
    native_font_compositing_context = nullptr;
    CGContextRelease(page);
    clear_cache();
}

static void opacity_fallback_cases()
{
    clear_cache();
    std::vector<uint8_t> page_pixels;
    auto page = bitmap(page_pixels);
    native_font_compositing_context = page;
    native_begin_svg_content_mask(987, 1, 64, 64, 8, 8, 32, 40,
        1, 0, 0, 1, 0, 0, 0, 0, 0);
    auto parent = native_svg_clip_build_context;
    CGContextRef deepest = nullptr;
    for (int depth = 0; depth < VOX_SVG_MASK_OPACITY_BITMAP_DEPTH + 2; ++depth) {
        auto previous = native_svg_clip_build_context;
        native_begin_svg_mask_opacity(.5);
        if (depth < VOX_SVG_MASK_OPACITY_BITMAP_DEPTH)
            assert(native_svg_clip_build_context != previous);
        else assert(native_svg_clip_build_context == deepest);
        deepest = native_svg_clip_build_context;
    }
    for (int depth = 0; depth < VOX_SVG_MASK_OPACITY_BITMAP_DEPTH + 2; ++depth)
        native_end_svg_mask_opacity();
    assert(native_svg_clip_build_context == parent);
    assert(native_svg_clip_build_opacity_depth == 0);
    for (auto const& group : native_svg_clip_opacity_bitmaps) assert(!group.canvas.context);
    // The non-Chromium painter and empty clips retain ordinary Quartz scopes.
    native_font_compositing_context = nullptr;
    native_begin_svg_mask_opacity(.5);
    assert(native_svg_clip_build_context == parent);
    native_end_svg_mask_opacity();
    native_font_compositing_context = page;
    CGContextSaveGState(parent); CGContextClipToRect(parent, CGRectZero);
    native_begin_svg_mask_opacity(.5);
    assert(native_svg_clip_build_context == parent);
    native_end_svg_mask_opacity();
    CGContextRestoreGState(parent);
    assert(native_svg_clip_build_opacity_depth == 0);
    native_finish_svg_mask_cache();
    native_font_compositing_context = nullptr;
    CGContextRelease(page);
    clear_cache();
    native_discard_opacity_canvas_pool();
    assert(native_opacity_canvas_pool_bytes == 0);
}

int main()
{
    @autoreleasepool {
        int cases = 0, opacity_cases = 0;
        for (int scale : {1, 2}) {
            test_scale = scale;
            for (float opacity : {0.f, .25f, .5f, .6f, .75f, 1.f})
                for (bool nested : {false, true}) { opacity_case(opacity, nested); ++opacity_cases; }
            opacity_fallback_cases();
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
        std::cout << cases << " SVG mask scope and pixel cases; " << opacity_cases
            << " float opacity GPU comparisons and both-scale scope fallbacks passed\n";
    }
}
