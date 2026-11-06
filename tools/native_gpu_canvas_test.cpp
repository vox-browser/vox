// The experimental GPU canvas draws approved leaves of a reused scroll frame
// on GPU surfaces and reads them back once. Compare it with the ordinary
// per-leaf replay of the same leaves over the same backdrop: repainted pixels
// match within blending rounding, pixels outside the repainted strip are never
// touched, and a CPU draw of an unapproved command keeps its paint order.
#import <Cocoa/Cocoa.h>
#include "../native_skia_text_darwin.cpp"
#include "../native_scroll_raster_darwin.h"
#include "../native_layer_presentation_darwin.h"
#include "../native_opacity_canvas_pool_darwin.h"
#include "../native_bitmap_snapshot_darwin.h"
#include "../native_chromium_screen_blend.h"
#define LADYBIRD_V_HAS_SKIA_TEXT
static CGFloat native_svg_mask_backing_scale() { return 2; }
static CGContextRef native_font_compositing_context;
static int native_font_compositing_transparency_depth;
#include "native_video_backdrop_entry_points.inc"
#include <cassert>
#include "../native_chromium_screen_blend.h"
#include "../native_opacity_group_darwin.h"
#include <cstdlib>
#include <iostream>

static constexpr int css_width = 400, css_height = 300, scale = 2;
static constexpr int width = css_width * scale, height = css_height * scale;
// Repainted strip in device pixels: deliberately not on the 8-pixel grid.
static constexpr int strip_top = 203, strip_height = 166;

static std::vector<uint8_t> backdrop()
{
    std::vector<uint8_t> pixels(size_t(width) * height * 4);
    for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x) {
        auto* p = pixels.data() + (size_t(y) * width + x) * 4;
        p[0] = uint8_t(40 + ((x * 3 + y) & 63));
        p[1] = uint8_t(60 + ((x + y * 5) & 31));
        p[2] = uint8_t(90 + (y & 15));
        p[3] = 255;
    }
    return pixels;
}

static void draw_leaves(CGContextRef context, bool canvas)
{
    auto approve = [&](char const* kind) {
        if (canvas) {
            bool expected = !s_gpu_canvas->complete_viewport || gpu_canvas_isolated_shapes_enabled()
                || !std::strcmp(kind, "paint_outer_box_shadow");
            assert(ladybird_v_skia_gpu_canvas_command(kind, int(std::strlen(kind)), 0) == int(expected));
        }
    };
    approve("paint_outer_box_shadow");
    assert(ladybird_v_skia_draw_outer_box_shadow(context, 40, 92, 300, 120, 12, 12, 12, 12, 12, 12, 12, 12,
        40, 80, 300, 120, 12, 12, 12, 12, 12, 12, 12, 12, 1, 0, 0, 1, 0, 0, 0, 0, 0,
        css_width, css_height, 24, 0, 0, 0, 120, 1));
    approve("fill_rounded_rect");
    assert(ladybird_v_skia_draw_rounded_rect(context, 40, 80, 300, 120, 12, 12, 12, 12, 12, 12, 12, 12,
        1, 0, 0, 1, 0, 0, 0, 0, 0, css_width, css_height, 230, 240, 250, 255, 1, 0, 1, 1));
    // An unapproved command reads the GPU results back, then draws on the CPU.
    if (canvas) assert(ladybird_v_skia_gpu_canvas_command("draw_video", 10, 0) == 0);
    CGContextSetRGBFillColor(context, 0.8, 0.1, 0.1, 1);
    CGContextFillRect(context, CGRectMake(100, css_height - 160, 60, 30));
    approve("paint_uniform_border");
    assert(ladybird_v_skia_draw_rounded_rect(context, 60.5, 100.25, 120, 70, 8, 8, 8, 8, 8, 8, 8, 8,
        1, 0, 0, 1, 0, 0, 0, 0, 0, css_width, css_height, 20, 30, 200, 255, 0, 3, 1, 1));
}

// A solid fill through the native fill path: the platform records it, then
// lets the GPU canvas take it or fills it on the CPU canvas.
static void native_fill(CGContextRef context, float x, float y, float w, float h,
    uint8_t r, uint8_t g, uint8_t b, bool canvas)
{
    if (canvas) assert(ladybird_v_skia_gpu_canvas_command("fill_rect", 9, 0) == 1);
    ladybird_v_skia_record_rect(context, x, y, w, h, r, g, b, 255);
    if (ladybird_v_skia_defer_recorded_rect(context, x, y, w, h)) return;
    CGContextSetRGBFillColor(context, r / 255.0, g / 255.0, b / 255.0, 1);
    CGContextFillRect(context, CGRectMake(x, y, w, h));
}

static unsigned s_first_uploads, s_first_cpu_leaves;
static bool s_first_begun;

// Text pages draw mostly solid fills and text, which need no GPU round trip.
// Before any GPU leaf they stay on the CPU canvas, without uploading or even
// acquiring GPU surfaces; after one, they join the canvas to keep paint order.
static void draw_cpu_leaves(CGContextRef context, bool canvas)
{
    native_fill(context, 20, css_height - 150, 200, 40, 30, 160, 60, canvas);
    if (canvas) {
        s_first_uploads = s_gpu_canvas->uploads;
        s_first_cpu_leaves = s_gpu_canvas->cpu_leaves;
        s_first_begun = s_gpu_canvas->begun;
        assert(ladybird_v_skia_gpu_canvas_command("fill_rounded_rect", 17, 0) == 1);
    }
    assert(ladybird_v_skia_draw_rounded_rect(context, 40, 80, 300, 120, 12, 12, 12, 12, 12, 12, 12, 12,
        1, 0, 0, 1, 0, 0, 0, 0, 0, css_width, css_height, 230, 240, 250, 255, 1, 0, 1, 1));
    native_fill(context, 120, css_height - 150, 80, 30, 200, 40, 40, canvas);
}

// Inset box shadows join the canvas as pictures of their leaf: vlang.io's
// unblurred 1px highlight, and a blurred shadow over a translucent fill.
static void draw_inset_leaves(CGContextRef context, bool canvas)
{
    float transform[] {1, 0, 0, 1, 0, 0};
    float panel[] {40.25f, 82, 300, 110, 10, 10, 10, 10, 10, 10, 10, 10};
    float highlight[] {40.25f, 83, 300, 110, 10, 10, 10, 10, 10, 10, 10, 10};
    if (canvas) assert(ladybird_v_skia_gpu_canvas_command("paint_inner_box_shadow", 22, 0) == 1);
    assert(ladybird_v_skia_draw_inner_box_shadow(context, panel, highlight, panel, panel, transform,
        0, 0, 0, css_width, css_height, 0, 255, 255, 255, 40, 1));
    if (canvas) assert(ladybird_v_skia_gpu_canvas_command("fill_rounded_rect", 17, 0) == 1);
    assert(ladybird_v_skia_draw_rounded_rect(context, 70, 120, 200, 60, 8, 8, 8, 8, 8, 8, 8, 8,
        1, 0, 0, 1, 0, 0, 0, 0, 0, css_width, css_height, 230, 240, 250, 140, 1, 0, 1, 1));
    float card[] {60.5f, 110, 240, 80, 12, 12, 12, 12, 12, 12, 12, 12};
    float shifted[] {60.5f, 116, 240, 80, 12, 12, 12, 12, 12, 12, 12, 12};
    if (canvas) assert(ladybird_v_skia_gpu_canvas_command("paint_inner_box_shadow", 22, 0) == 1);
    assert(ladybird_v_skia_draw_inner_box_shadow(context, card, shifted, card, card, transform,
        0, 0, 0, css_width, css_height, 18, 0, 0, 0, 170, 1));
}

// Outlines and ellipses draw through the same native rounded-rectangle shape.
// A polygon outline (flag 512) draws CPU lines and stays off the canvas.
static void draw_outline_content(CGContextRef context, bool canvas)
{
    if (canvas) assert(ladybird_v_skia_gpu_canvas_command("stroke_rounded_rect", 19, 0) == 1);
    assert(ladybird_v_skia_draw_rounded_rect(context, 30.5f, 85, 320, 100, 6, 6, 6, 6, 6, 6, 6, 6,
        1, 0, 0, 1, 0, 0, 0, 0, 0, css_width, css_height, 200, 210, 230, 255, 0, 1, 1, 1));
    if (canvas) assert(ladybird_v_skia_gpu_canvas_command("fill_ellipse", 12, 0) == 1);
    assert(ladybird_v_skia_draw_rounded_rect(context, 150, 110, 70, 50, 35, 25, 35, 25, 35, 25, 35, 25,
        1, 0, 0, 1, 0, 0, 0, 0, 0, css_width, css_height, 240, 80, 60, 255, 1, 0, 1, 1));
}

static void draw_outline_leaves(CGContextRef context, bool canvas)
{
    if (canvas) assert(ladybird_v_skia_gpu_canvas_command("stroke_rounded_rect", 19, 512) == 0);
    draw_outline_content(context, canvas);
}

static int s_mixed_fill, s_mixed_alpha;
static float s_mixed_offset;
static void draw_mixed_shape(CGContextRef context, bool canvas)
{
    char const* kind = s_mixed_fill ? "fill_rounded_rect" : "stroke_rounded_rect";
    if (canvas) assert(ladybird_v_skia_gpu_canvas_command(kind, int(std::strlen(kind)), 0)
        == int(!s_gpu_canvas->complete_viewport || gpu_canvas_isolated_shapes_enabled()));
    float rect[] {40.25f + s_mixed_offset, 100.125f, 300.375f, 56.25f, 12, 9, 7, 11, 10, 6, 13, 8};
    if (!s_mixed_fill) ladybird_v_skia_set_rounded_rect_underlay(rect, 38, 63, 94, 255);
    assert(ladybird_v_skia_draw_rounded_rect(context, rect[0], rect[1], rect[2], rect[3],
        rect[4], rect[5], rect[6], rect[7], rect[8], rect[9], rect[10], rect[11],
        1, 0, 0, 1, 0, 0, 0, 0, 0, css_width, css_height, 49, 83, 123, s_mixed_alpha,
        s_mixed_fill, 1.25f, 1, 1));
    ladybird_v_skia_set_rounded_rect_underlay(nullptr, 0, 0, 0, 0);
}

// vlang.io's code panels: a translucent CSS linear-gradient background in a
// rounded clip repeats a picture of its generated-image tile.
static void draw_pattern_leaves(CGContextRef context, bool canvas)
{
    float segments[5 * 12] {};
    auto segment = [&](int index, float op, float x, float y) {
        segments[index * 12] = op; segments[index * 12 + 1] = x; segments[index * 12 + 2] = y;
    };
    segment(0, 0, 45, 84); segment(1, 1, 335, 84); segment(2, 1, 335, 196);
    segment(3, 1, 45, 196); segment(4, 5, 0, 0);
    float stops[] {0.07f, 0.11f, 0.16f, 0.56f, 0, 0.06f, 0.08f, 0.12f, 0.56f, 1};
    float clip[] {45, 84, 290, 112, 10, 10, 10, 10, 10, 10, 10, 10};
    float tile[] {45, 84, 290, 112};
    ladybird_v_skia_set_css_gradient_tile_bounds(tile);
    if (canvas) assert(ladybird_v_skia_gpu_canvas_command("fill_gradient", 13, 0) == 1);
    assert(ladybird_v_skia_draw_clipped_svg_linear_gradient_path(context, segments, 5, 0,
        1, 0, 0, 1, 0, 0, 0, 0, 0, css_width, css_height, 0, 0, 0, 0, 4,
        45, 84, 335, 196, 1, 0, 0, 1, 0, 0, 3, 0, stops, 2, 1, 1, clip, nullptr));
    ladybird_v_skia_set_css_gradient_tile_bounds(nullptr);
    if (canvas) assert(ladybird_v_skia_gpu_canvas_command("fill_rounded_rect", 17, 0) == 1);
    assert(ladybird_v_skia_draw_rounded_rect(context, 70, 120, 200, 60, 8, 8, 8, 8, 8, 8, 8, 8,
        1, 0, 0, 1, 0, 0, 0, 0, 0, css_width, css_height, 230, 240, 250, 140, 1, 0, 1, 1));
}

static bool s_video_rounded;
static std::vector<uint8_t> s_video_frame = [] {
    std::vector<uint8_t> pixels(size_t(1426) * 1080 * 4);
    for (int y = 0; y < 1080; ++y) for (int x = 0; x < 1426; ++x) {
        auto* p = pixels.data() + (size_t(y) * 1426 + x) * 4;
        p[0] = uint8_t(x * 5 + y); p[1] = uint8_t(y * 3);
        p[2] = uint8_t(x ^ y); p[3] = 255;
    }
    return pixels;
}();

static void draw_video_leaves(CGContextRef context, bool canvas)
{
    if (canvas) assert(ladybird_v_skia_gpu_canvas_command("draw_video", 10, 0) == int(
        s_gpu_canvas->video_backdrop_callbacks && (std::getenv("VOX_GPU_CANVAS_VIDEO_BACKDROP")
            || (std::getenv("VOX_GPU_CANVAS_DEFER_VIDEO_BARRIERS")
                && s_gpu_canvas->video_cpu_fallback_synchronized))));
    float radii[] {13, 13, 13, 13, 0, 0, 0, 0};
    assert(ladybird_v_skia_draw_rgba_image(context, s_video_frame.data(), 1426, 1080, 1426 * 4,
        52.5f, 81.25f, 238, 180, 0, 0, 1426, 1080, 52.5f, 81.25f, 238, 180,
        1, 0, 0, 1, 0, 0, 0, 0, 0, css_width, css_height, 1, 0,
        2 | VOX_GRAPHITE_IMAGE_VIDEO_FRAME, s_video_rounded ? radii : nullptr));
    if (canvas) assert(ladybird_v_skia_gpu_canvas_command("fill_rounded_rect", 17, 0) == 1);
    assert(ladybird_v_skia_draw_rounded_rect(context, 70, 120, 200, 60, 8, 8, 8, 8, 8, 8, 8, 8,
        1, 0, 0, 1, 0, 0, 0, 0, 0, css_width, css_height, 230, 240, 250, 140, 1, 0, 1, 1));
}

static float s_static_image_offset;
static int s_static_image_nearest;
static bool s_static_image_explicit_clip;
static void draw_static_msaa_image(CGContextRef context, bool canvas)
{
    if (canvas) assert(ladybird_v_skia_gpu_canvas_command("draw_replaced_image", 19, 0));
    float radii[] {13, 13, 13, 13, 0, 0, 0, 0};
    assert(ladybird_v_skia_draw_rgba_image(context, s_video_frame.data(), 1426, 1080, 1426 * 4,
        52.5f + s_static_image_offset, 81.25f, 238, 180, 0, 0, 1426, 1080,
        52.5f + s_static_image_offset, 81.25f, 238, 180,
        1, 0, 0, 1, 0, 0, 0, 0, 0, css_width, css_height, .85f, s_static_image_nearest,
        2 | (s_static_image_explicit_clip ? VOX_GRAPHITE_IMAGE_EXPLICIT_RECT_CLIP : 0),
        s_video_rounded ? radii : nullptr));
}

static unsigned s_draws, s_uploads, s_flushes, s_declined, s_cpu_leaves;
static unsigned s_read_calls, s_successful_reads, s_fail_reads;
static bool s_expect_native_grid;
static decltype(&vox_graphite_canvas_read) s_backend_read;
static decltype(&vox_graphite_canvas_read_direct) s_backend_direct_read;
static unsigned s_direct_reads;
static bool s_fail_direct_read;

static int s_deferred_video_callbacks;
static void draw_deferred_video_leaves(CGContextRef context, bool canvas)
{
    if (canvas) ladybird_v_skia_gpu_canvas_video_backdrop_callbacks(s_deferred_video_callbacks);
    draw_outline_leaves(context, canvas);
    unsigned before = canvas ? s_gpu_canvas->flushes : 0;
    draw_video_leaves(context, canvas);
    if (canvas && s_deferred_video_callbacks >= 2)
        assert(s_gpu_canvas->cpu_stale && s_gpu_canvas->flushes == before);
}

static int counted_direct_read(VoxGraphitePixelRegion const* views, int count)
{
    if (s_fail_direct_read) return 0;
    int result = s_backend_direct_read(views, count);
    s_direct_reads += result != 0;
    s_successful_reads += result != 0;
    return result;
}

static int counted_read(VoxGraphitePixelRegion const* views, int count)
{
    ++s_read_calls;
    if (s_fail_reads) { --s_fail_reads; return 0; }
    int result = s_backend_read(views, count);
    s_successful_reads += result != 0;
    return result;
}

static void direct_read_regions(GpuCanvasApi const* api)
{
    if (!api->read_direct) return; // Compatibility with an older bridge.
    int rectangles[] {0, 0, 13, 11, 0, 0, 13, 11, 32, 24, 17, 9, 32, 24, 17, 9};
    assert(api->begin(rectangles, 2));
    std::vector<uint8_t> source(80 * 12, 0x5a), expected = source, actual = source;
    for (size_t i = 0; i < source.size(); ++i) source[i] = uint8_t(i * 19);
    assert(api->upload(0, source.data(), 80));
    assert(api->upload(1, source.data(), 80));
    // Odd widths, source offsets, disjoint output regions and row padding.
    VoxGraphitePixelRegion staged[] {{1, 2, 11, 7, 80, expected.data() + 4},
        {2, 1, 13, 5, 80, expected.data() + 80 * 7}};
    VoxGraphitePixelRegion direct[] {{1, 2, 11, 7, 80, actual.data() + 4},
        {2, 1, 13, 5, 80, actual.data() + 80 * 7}};
    assert(api->read(staged, 2));
    // An invalid later region must not leave an earlier one partially written.
    direct[1].pitch = 1;
    assert(!api->read_direct(direct, 2));
    assert(std::all_of(actual.begin(), actual.end(), [](uint8_t v) { return v == 0x5a; }));
    direct[1].pitch = 80;
    assert(api->read_direct(direct, 2) && actual == expected);
    api->end();
}

static bool s_compositor, s_present_tiles;

static std::vector<uint8_t> render(bool canvas, bool shared = false,
    void (*leaves)(CGContextRef, bool) = draw_leaves, bool full = false)
{
    auto pixels = backdrop();
    auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = CGBitmapContextCreate(pixels.data(), width, height, 8, width * 4, color,
        static_cast<CGBitmapInfo>(kCGImageAlphaPremultipliedLast)
            | static_cast<CGBitmapInfo>(kCGBitmapByteOrder32Big));
    CGColorSpaceRelease(color);
    assert(context);
    CGContextScaleCTM(context, scale, scale);
    // The scroll raster clips a reused frame to its repainted rectangles.
    CGContextClipToRect(context, full ? CGRectMake(0, 0, css_width, css_height)
        : CGRectMake(0, css_height - (strip_top + strip_height) / float(scale),
            css_width, strip_height / float(scale)));
    ladybird_v_skia_set_chromium_painting(1);
    // Root raster layer: a frame-wide shared recording.
    ladybird_v_skia_set_shared_recording(shared, css_width, css_height);
    if (canvas) {
        int rect[] {0, full ? 0 : strip_top, width, full ? height : strip_height};
        assert(ladybird_v_skia_gpu_canvas_begin(context, rect, 1));
        if (s_compositor) assert(ladybird_v_skia_gpu_canvas_set_compositor(context));
        if(s_expect_native_grid)ladybird_v_skia_gpu_canvas_document_top(0);
    }
    leaves(context, canvas);
    if(canvas && s_expect_native_grid)assert(s_gpu_canvas->native_grid);
    ladybird_v_skia_finish_shared_recording();
    ladybird_v_skia_set_shared_recording(0, 0, 0);
    if (canvas) {
        assert(ladybird_v_skia_bitmap_pixels_are_current(context) == int(!s_gpu_canvas->cpu_stale));
        s_draws = s_gpu_canvas->draws;
        s_uploads = s_gpu_canvas->uploads;
        s_flushes = s_gpu_canvas->flushes;
        s_declined = s_gpu_canvas->declined;
        s_cpu_leaves = s_gpu_canvas->cpu_leaves;
        unsigned expected_reads = s_gpu_canvas->flushes + unsigned(s_gpu_canvas->cpu_stale);
        unsigned before_final_read = s_successful_reads;
        IOSurfaceRef output = nullptr;
        void* completion = nullptr;
        if (s_present_tiles) {
            NSDictionary* properties = @{
                (id)kIOSurfaceWidth:@(width), (id)kIOSurfaceHeight:@(height),
                (id)kIOSurfaceBytesPerElement:@4, (id)kIOSurfacePixelFormat:@(0x52474241u) };
            auto previous = IOSurfaceCreate((CFDictionaryRef)properties);
            output = IOSurfaceCreate((CFDictionaryRef)properties);
            assert(previous && output && !IOSurfaceLock(previous,0,nullptr));
            for (int row=0; row<height; ++row)
                memcpy((uint8_t*)IOSurfaceGetBaseAddress(previous)+row*IOSurfaceGetBytesPerRow(previous),
                    pixels.data()+size_t(row)*width*4,width*4);
            IOSurfaceUnlock(previous,0,nullptr);
            VoxGraphiteCanvasSurfaceRegion region {output,previous,0,0,0,0,width,height};
            assert(ladybird_v_skia_gpu_canvas_can_present(context));
            assert(ladybird_v_skia_gpu_canvas_present(context,&region,1,&completion)==1 && completion);
            CFRelease(previous);
        }
        ladybird_v_skia_gpu_canvas_end();
        assert(!s_gpu_canvas);
        assert(ladybird_v_skia_bitmap_pixels_are_current(context));
        // Every earlier flush succeeded; final publication adds at most one.
        assert(s_successful_reads - before_final_read == (s_present_tiles ? unsigned(std::getenv("VOX_GPU_CANVAS_PRESENT_VERIFY") != nullptr)
            : expected_reads - s_flushes));
        if (output) {
            assert(gpu_canvas_api()->wait_present(completion));
            assert(!IOSurfaceLock(output,kIOSurfaceLockReadOnly,nullptr));
            for (int row=0; row<height; ++row)
                memcpy(pixels.data()+size_t(row)*width*4,
                    (uint8_t*)IOSurfaceGetBaseAddress(output)+row*IOSurfaceGetBytesPerRow(output),width*4);
            IOSurfaceUnlock(output,kIOSurfaceLockReadOnly,nullptr);
            CFRelease(output);
        }
    }
    ladybird_v_skia_set_chromium_painting(0);
    CGContextFlush(context);
    CGContextRelease(context);
    return pixels;
}

static bool s_fail_backdrop_copy;
static int s_backdrop_verify_error;
static decltype(&vox_graphite_canvas_copy_pixels) s_real_backdrop_copy;

static void draw_native_image_cpu_fallback(CGContextRef context, bool canvas)
{
    draw_outline_leaves(context, canvas);
    native_prepare_image_cpu_fallback(context);
    if (canvas) assert(!s_gpu_canvas->cpu_stale && !s_gpu_canvas->gpu_valid);
    CGContextSetRGBFillColor(context, .1, .7, .4, .6);
    CGContextFillRect(context, CGRectMake(35, css_height-157, 90, 70));
    if (canvas) assert(ladybird_v_skia_gpu_canvas_command("fill_rounded_rect",17,0));
    assert(ladybird_v_skia_draw_rounded_rect(context,70,120,200,60,8,8,8,8,8,8,8,8,
        1,0,0,1,0,0,0,0,0,css_width,css_height,230,240,250,140,1,0,1,1));
}
static int maybe_fail_backdrop_copy(uint8_t const* pixels, int w, int h, int pitch, int x, int y)
{
    return s_fail_backdrop_copy ? 0 : s_real_backdrop_copy(pixels, w, h, pitch, x, y);
}

static std::vector<uint8_t> render_video_backdrop(bool canvas, bool callbacks, int alpha, bool fail)
{ @autoreleasepool {
    auto pixels = backdrop();
    auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = CGBitmapContextCreate(pixels.data(), width, height, 8, width * 4, color,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(color); assert(context);
    CGContextScaleCTM(context, scale, scale);
    CGContextClipToRect(context, CGRectMake(0, css_height - (strip_top + strip_height) / float(scale),
        css_width, strip_height / float(scale)));
    NSGraphicsContext* saved = NSGraphicsContext.currentContext;
    NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithCGContext:context flipped:NO];
    native_discard_scroll_raster();
    native_scroll_raster = {.width=width, .height=height, .canvas_width=width, .canvas_height=height,
        .scale=scale, .scroll=100, .owner=7, .active=1, .reused=1, .damage_optimized=1, .context=context};
    native_scroll_repainted_count = 1;
    long painted[] {0, strip_top, width, strip_top + strip_height};
    std::copy_n(painted, 4, native_scroll_repainted[0]);
    ladybird_v_skia_set_chromium_painting(1);
    ladybird_v_skia_set_shared_recording(0, css_width, css_height);
    if (canvas) {
        assert(native_gpu_canvas_begin()); // Actual host wrapper registers the callbacks.
        assert(s_gpu_canvas->video_backdrop_callbacks);
        if (!callbacks) ladybird_v_skia_gpu_canvas_video_backdrop_callbacks(0);
    }
    draw_outline_leaves(context, canvas);
    unsigned before_capture = canvas ? s_gpu_canvas->flushes : 0;
    unsigned before_upload = canvas ? s_gpu_canvas->uploads : 0;
    if (canvas) ladybird_v_skia_gpu_canvas_command("draw_video", 10, 0);
    native_capture_video_backdrop(40, 210, 100.5, 51.5);
    if (canvas) assert(!s_gpu_canvas->cpu_stale && s_gpu_canvas->flushes == before_capture + 1);
    bool retained_capture = canvas && callbacks && std::getenv("VOX_GPU_CANVAS_READONLY_VIDEO_CAPTURE")
        && (std::getenv("VOX_GPU_CANVAS_VIDEO_BACKDROP") || std::getenv("VOX_GPU_CANVAS_DEFER_VIDEO_BARRIERS"));
    if (canvas) assert(s_gpu_canvas->gpu_valid == retained_capture);
    long geometry[] {80, 420, 201, 103};
    auto* source = native_video_backdrop_find(&native_scroll_raster, geometry, 0); assert(source);
    for (int y = 0; y < 103; ++y) {
        assert(source->valid[y]);
        for (int x = 0; x < 201; ++x) {
            auto* p = source->pixels + (y * 201 + x) * 4;
            p[0] = (x * 7 + y) % (alpha + 1); p[1] = (x + y * 3) % (alpha + 1);
            p[2] = (x * 11 + y * 5) % (alpha + 1); p[3] = alpha;
        }
    }
    // No CPU polygon follows this read. Keep that command-decline probe in
    // draw_outline_leaves, and check the real GPU leaves can reuse the copy.
    draw_outline_content(context, canvas);
    if (retained_capture) assert(s_gpu_canvas->uploads == before_upload);
    unsigned before_restore = canvas ? s_gpu_canvas->flushes : 0;
    auto cpu_before = pixels;
    if (canvas) assert(ladybird_v_skia_gpu_canvas_command("draw_video", 10, 0) == int(callbacks
        && (std::getenv("VOX_GPU_CANVAS_VIDEO_BACKDROP") || (std::getenv("VOX_GPU_CANVAS_DEFER_VIDEO_BARRIERS")
            && s_gpu_canvas->video_cpu_fallback_synchronized))));
    s_fail_backdrop_copy = fail;
    native_restore_video_backdrop(40, 210, 100.5, 51.5);
    s_fail_backdrop_copy = false;
    if (canvas && callbacks && !fail && !gpu_canvas_verify()
        && std::getenv("VOX_GPU_CANVAS_VIDEO_BACKDROP")) {
        assert(s_gpu_canvas->cpu_stale && s_gpu_canvas->flushes == before_restore);
        assert(pixels == cpu_before); // The successful GPU restore never writes stale CPU rows.
    } else if (canvas) assert(s_gpu_canvas->flushes == before_restore + 1);
    // The queued GPU copy owns its source before native cache eviction.
    native_discard_video_backdrops();
    for (size_t at = 3; at < s_video_frame.size(); at += 4) s_video_frame[at] = alpha;
    draw_video_leaves(context, canvas);
    if (canvas) {
        if (gpu_canvas_verify()) {
            ladybird_v_skia_gpu_canvas_cpu_access();
            s_backdrop_verify_error = std::max(s_backdrop_verify_error, s_gpu_canvas->max_error);
        }
        ladybird_v_skia_gpu_canvas_end();
    }
    ladybird_v_skia_set_chromium_painting(0);
    ladybird_v_skia_set_shared_recording(0, 0, 0);
    native_discard_scroll_raster();
    NSGraphicsContext.currentContext = saved;
    CGContextFlush(context); CGContextRelease(context);
    return pixels;
} }

@interface MyView2 : NSView
@end
@implementation MyView2
@end
static bool s_surface_legacy_host, s_surface_decline;
static unsigned s_surface_calls;
static decltype(&vox_graphite_canvas_read_iosurface) s_surface_read;
static int test_surface_read(void* surface, int w, int h)
{
    ++s_surface_calls;
    return s_surface_decline ? 0 : s_surface_read(surface,w,h);
}
static void paint_shared_frame(id, SEL, NSRect)
{
    auto context=NSGraphicsContext.currentContext.CGContext;
    auto original=backdrop();
    auto* pixels=static_cast<uint8_t*>(CGBitmapContextGetData(context));
    size_t pitch=CGBitmapContextGetBytesPerRow(context);
    for(int y=0;y<height;++y) std::memcpy(pixels+y*pitch,original.data()+y*width*4,width*4);
    CGContextClipToRect(context,CGRectMake(0,css_height-(strip_top+strip_height)/float(scale),
        css_width,strip_height/float(scale)));
    native_scroll_raster={.width=width,.height=height,.canvas_width=width,.canvas_height=height,
        .scale=scale,.active=1,.reused=1,.damage_optimized=1,.context=context};
    native_scroll_repainted_count=1;
    long painted[]={0,strip_top,width,strip_top+strip_height};
    std::copy_n(painted,4,native_scroll_repainted[0]);
    ladybird_v_skia_set_chromium_painting(1);
    ladybird_v_skia_set_shared_recording(0,css_width,css_height);
    ladybird_v_skia_begin_deferred_layer_frame(0);
    if(s_surface_legacy_host) {
        int rect[]={0,strip_top,width,strip_height};
        assert(ladybird_v_skia_gpu_canvas_begin(context,rect,1));
        assert(!s_gpu_canvas->frame_surface);
    } else {
        assert(native_gpu_canvas_begin());
        assert(s_gpu_canvas->frame_surface==native_layer_frame_surface(context));
        assert(s_gpu_canvas->frame_surface);
    }
    draw_leaves(context,true);
    ladybird_v_skia_gpu_canvas_end();
    assert(ladybird_v_skia_finish_deferred_layer_frame());
    native_scroll_raster={};
    ladybird_v_skia_set_chromium_painting(0);
}

static std::vector<uint8_t> shared_frame_pixels(NSView* view)
{
    auto image=native_layer_raster_frame(view,scale,(IMP)paint_shared_frame); assert(image);
    auto data=CGDataProviderCopyData(CGImageGetDataProvider(image)); assert(data);
    auto* source=CFDataGetBytePtr(data);
    size_t pitch=CGImageGetBytesPerRow(image);
    std::vector<uint8_t> output(size_t(width)*height*4);
    for(int y=0;y<height;++y) std::memcpy(output.data()+y*width*4,source+y*pitch,width*4);
    CFRelease(data); CGImageRelease(image);
    return output;
}

static int s_overlay_stroke_antialias;
static std::vector<uint8_t> render_overlay_batch(bool batch,int alpha,bool horizontal,float phase)
{
    auto pixels=backdrop();auto color=CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context=CGBitmapContextCreate(pixels.data(),width,height,8,width*4,color,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(color);assert(context);CGContextScaleCTM(context,scale,scale);
    auto saved=NSGraphicsContext.currentContext;
    NSGraphicsContext.currentContext=[NSGraphicsContext graphicsContextWithCGContext:context flipped:NO];
    ladybird_v_skia_set_chromium_painting(1);
    ladybird_v_skia_set_shared_recording(0,css_width,css_height);
    float rects[]={384,7,16,154,24,282,134,18};
    if(batch) assert(native_gpu_canvas_begin_rects(rects,horizontal?2:1));
    for(int axis=0;axis<(horizontal?2:1);++axis) for(int fill:{1,0}) {
        if(batch) assert(ladybird_v_skia_gpu_canvas_command(fill?"fill_rounded_rect":"stroke_rounded_rect",fill?17:19,4));
        assert(ladybird_v_skia_draw_rounded_rect(context,axis?30:390+phase,axis?290:13+phase,
            axis?120:7,axis?6:140,3.5,3.5,3.5,3.5,3.5,3.5,3.5,3.5,
            1,0,0,1,0,0,0,0,0,css_width,css_height,fill?50:60,fill?50:60,fill?50:60,alpha,fill,1,0,fill?0:s_overlay_stroke_antialias));
    }
    if(batch)ladybird_v_skia_gpu_canvas_end();
    ladybird_v_skia_set_chromium_painting(0);NSGraphicsContext.currentContext=saved;
    CGContextFlush(context);CGContextRelease(context);return pixels;
}

static std::vector<uint8_t> render_filter_image(bool canvas, bool bgra, int alpha, bool full, int fallback)
{
    auto pixels = backdrop();
    auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = CGBitmapContextCreate(pixels.data(), width, height, 8, width * 4, color,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    assert(context);
    CGContextScaleCTM(context, scale, scale);
    if (!full) CGContextClipToRect(context, CGRectMake(0,
        css_height - (strip_top + strip_height) / float(scale), css_width, strip_height / float(scale)));
    native_font_compositing_context = context;
    ladybird_v_skia_set_chromium_painting(1);
    ladybird_v_skia_set_shared_recording(0, css_width, css_height);
    s_raster_layer_is_root = false;
    ladybird_v_skia_set_msaa_grid(nullptr, 0, 0, 0, 0);
    if (canvas) {
        int rect[] {0, full ? 0 : strip_top, width, full ? height : strip_height};
        assert(ladybird_v_skia_gpu_canvas_begin(context, rect, 1));
        assert(ladybird_v_skia_gpu_canvas_command("fill_rounded_rect", 17, 0));
    }
    assert(ladybird_v_skia_draw_rounded_rect(context, 30, 90, 80, 40, 0,0,0,0,0,0,0,0,
        1,0,0,1,0,0,0,0,0,css_width,css_height,73,101,139,255,1,0,1,0));
    if (canvas) {
        assert(ladybird_v_skia_gpu_canvas_command("begin_css_filter_layer", 22, 0));
        assert(ladybird_v_skia_gpu_canvas_defer_filters() && s_gpu_canvas->cpu_stale && !s_gpu_canvas->flushes);
    }
    constexpr int w = 23, h = 17, pitch = w * 4 + 16;
    std::vector<uint8_t> source(pitch * h);
    for (int y = 0; y < h; ++y) for (int x = 0; x < w; ++x) {
        auto* p = source.data() + y * pitch + x * 4;
        p[bgra ? 2 : 0] = (x * 13) % (alpha + 1);
        p[1] = (y * 17) % (alpha + 1);
        p[bgra ? 0 : 2] = (x * 11 + y * 7) % (alpha + 1);
        p[3] = alpha;
    }
    auto provider = CGDataProviderCreateWithData(nullptr, source.data(), source.size(), nullptr);
    auto image = CGImageCreate(w, h, 8, 32, pitch, color,
        bgra ? kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little
             : kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big,
        provider, nullptr, true, kCGRenderingIntentDefault);
    assert(image);
    CGColorSpaceRelease(color);
    CGDataProviderRelease(provider);
    CGRect target = CGRectMake(38.5 + (fallback == 1 ? .125 : 0), css_height - 103.5 - h / 2., w / 2., h / 2.);
    int result = 0;
    if (canvas) {
        assert(ladybird_v_skia_gpu_canvas_command("end_css_filter_layer", 20, 0));
        native_font_compositing_transparency_depth = fallback == 2;
        result = native_try_gpu_css_filter_image(context, image, target, css_height);
        native_font_compositing_transparency_depth = 0;
        assert(result == (fallback ? 0 : gpu_canvas_verify() ? 2 : 1));
    }
    if (result != 1) {
        if (canvas && !result) ladybird_v_skia_gpu_canvas_cpu_access();
        native_layer_draw_document_image(context, target, image, 0);
    }
    CGImageRelease(image);
    std::fill(source.begin(), source.end(), 0xdd);
    source.clear(); source.shrink_to_fit();
    if (canvas) {
        if (!fallback && !gpu_canvas_verify())
            assert(s_gpu_canvas->draws == 2 && s_gpu_canvas->uploads == 1 && s_gpu_canvas->flushes == 0);
        ladybird_v_skia_gpu_canvas_end();
    }
    ladybird_v_skia_set_chromium_painting(0);
    native_font_compositing_context = nullptr;
    CGContextFlush(context); CGContextRelease(context);
    return pixels;
}

static std::vector<uint8_t> render_layer_pixels(bool gpu, int blend, float opacity, bool full)
{
    auto pixels = backdrop();
    auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = CGBitmapContextCreate(pixels.data(), width, height, 8, width * 4, color,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    auto other = CGBitmapContextCreate(nullptr, 16, 16, 8, 64, color,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    assert(context && other); CGColorSpaceRelease(color);
    CGContextScaleCTM(context, scale, scale);
    ladybird_v_skia_set_shared_recording(0, css_width, css_height);
    if (gpu) {
        int rect[] {0, full ? 0 : strip_top, width, full ? height : strip_height};
        assert(ladybird_v_skia_gpu_canvas_begin(context, rect, 1));
        assert(ladybird_v_skia_gpu_canvas_command("begin_css_effect_layer", 22, 0));
        assert(ladybird_v_skia_gpu_canvas_defer_layers());
    }
    constexpr int w = 37, h = 29, pitch = w * 4 + 16, x = 80, y = 225;
    std::vector<uint8_t> source(pitch * h);
    for (int row = 0; row < h; ++row) for (int column = 0; column < w; ++column) {
        auto* p = source.data() + row * pitch + column * 4;
        int alpha = (column * 17 + row * 31) % 256;
        p[0] = column * 13 % (alpha + 1); p[1] = row * 11 % (alpha + 1);
        p[2] = (column * 3 + row * 7) % (alpha + 1); p[3] = alpha;
    }
    for (int pass = 0; pass < 2; ++pass) {
        int result = 0;
        if (gpu) {
            assert(ladybird_v_skia_gpu_canvas_command("end_css_effect_layer", 20, 0));
            result = ladybird_v_skia_gpu_canvas_layer_pixels(context, source.data(), w, h, pitch, x, y, opacity, blend);
            assert(result == (gpu_canvas_verify() ? 2 : 1));
        }
        if (result != 1) {
            for (int row = 0; row < h; ++row) {
                auto* destination = pixels.data() + ((y + row) * width + x) * 4;
                if (blend == 3) native_composite_screen_pixels(source.data() + row * pitch,
                    destination, destination, w, opacity);
                else native_composite_opacity_pixels(source.data() + row * pitch,
                    destination, destination, w, opacity);
            }
        }
        if (gpu && !gpu_canvas_verify()) {
            ladybird_v_skia_gpu_canvas_context_access(other);
            assert(s_gpu_canvas->cpu_stale && !s_gpu_canvas->flushes && s_gpu_canvas->uploads == 1);
            assert(!ladybird_v_skia_gpu_canvas_layer_pixels(context, source.data(), w, h, pitch, x, y, opacity, 1));
        }
    }
    std::fill(source.begin(), source.end(), 0xdd); source.clear(); source.shrink_to_fit();
    if (gpu) ladybird_v_skia_gpu_canvas_end();
    CGContextRelease(other); CGContextRelease(context);
    return pixels;
}

static std::vector<uint8_t> render_native_group(bool gpu, bool nested, int blend, float opacity, bool full,
    bool text_transition = false, bool force_barrier = false, bool suffix = false)
{
    auto pixels = backdrop();
    auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = CGBitmapContextCreate(pixels.data(), width, height, 8, width * 4, color,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    assert(context); CGColorSpaceRelease(color);
    CGContextScaleCTM(context, scale, scale);
    if (!full) CGContextClipToRect(context, CGRectMake(0,
        css_height - (strip_top + strip_height) / float(scale), css_width, strip_height / float(scale)));
    auto saved = NSGraphicsContext.currentContext;
    NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithCGContext:context flipped:NO];
    native_font_compositing_context = context;
    ladybird_v_skia_set_chromium_painting(1);
    ladybird_v_skia_set_shared_recording(0, css_width, css_height);
    if (gpu) {
        int rect[] {0, full ? 0 : strip_top, width, full ? height : strip_height};
        assert(ladybird_v_skia_gpu_canvas_begin(context, rect, 1));
        assert(ladybird_v_skia_gpu_canvas_command("fill_rounded_rect", 17, 0));
    }
    assert(ladybird_v_skia_draw_rounded_rect(context, 30, 90, 80, 40, 0,0,0,0,0,0,0,0,
        1,0,0,1,0,0,0,0,0,css_width,css_height,73,101,139,255,1,0,1,0));
    if (gpu) assert(ladybird_v_skia_gpu_canvas_command("begin_css_effect_layer", 22, 0)
        == int(ladybird_v_skia_gpu_canvas_defer_layers()!=0));
    native_begin_css_effect_layer(opacity, blend);
    assert(NSGraphicsContext.currentContext.CGContext != context);
    if (nested) {
        if (gpu) assert(ladybird_v_skia_gpu_canvas_command("begin_css_effect_layer", 22, 0)
            == int(ladybird_v_skia_gpu_canvas_defer_layers()!=0));
        native_begin_css_effect_layer(.73f, 3);
    }
    auto isolated = NSGraphicsContext.currentContext.CGContext;
    CGContextSetRGBFillColor(isolated, .3, .7, .2, .6);
    CGContextFillRect(isolated, CGRectMake(35.5, css_height - 127.5, 45, 25));
    if (text_transition) { @autoreleasepool {
        auto* text = [[NSAttributedString alloc] initWithString:@"GPU text layer" attributes:@{
            NSFontAttributeName: [NSFont monospacedSystemFontOfSize:13 weight:NSFontWeightRegular],
            NSForegroundColorAttributeName: [NSColor colorWithSRGBRed:.8 green:.4 blue:.2 alpha:.73]}];
        CTLineRef line = CTLineCreateWithAttributedString((CFAttributedStringRef)text);
        CGContextSetTextMatrix(isolated,CGAffineTransformIdentity);
        CGContextSetTextPosition(isolated,45,css_height-123);
        CTLineDraw(line,isolated); CFRelease(line); [text release];
    } }
    if (nested) {
        if (gpu) assert(ladybird_v_skia_gpu_canvas_command("end_css_effect_layer", 20, 0)
            == int(ladybird_v_skia_gpu_canvas_defer_layers()!=0));
        native_end_css_effect_layer();
        if (gpu && !gpu_canvas_verify()) assert(s_gpu_canvas->cpu_stale && !s_gpu_canvas->flushes);
    }
    if (gpu) assert(ladybird_v_skia_gpu_canvas_command("end_css_effect_layer", 20, 0)
        == int(ladybird_v_skia_gpu_canvas_defer_layers()!=0));
    if (gpu && text_transition && (force_barrier || !native_gpu_canvas_can_defer_layers()))
        ladybird_v_skia_gpu_canvas_cpu_access();
    native_end_css_effect_layer();
    assert(NSGraphicsContext.currentContext.CGContext == context);
    if (suffix) {
        if (gpu) assert(ladybird_v_skia_gpu_canvas_command("fill_rounded_rect",17,0));
        assert(ladybird_v_skia_draw_rounded_rect(context,40.25f,110.5f,50,30,3,3,3,3,3,3,3,3,
            1,0,0,1,0,0,0,0,0,css_width,css_height,230,240,250,117,1,0,1,1));
    }
    if (gpu) {
        if (!gpu_canvas_verify()) {
            if (!force_barrier) assert(s_gpu_canvas->cpu_stale && !s_gpu_canvas->flushes
                && s_gpu_canvas->draws == 2+unsigned(suffix) && s_gpu_canvas->uploads == 1);
            else assert(s_gpu_canvas->flushes == 1 && s_gpu_canvas->draws == 1+unsigned(suffix)
                && s_gpu_canvas->uploads == 1+unsigned(suffix));
        }
        ladybird_v_skia_gpu_canvas_end();
    }
    assert(!native_opacity_group_depth);
    ladybird_v_skia_set_chromium_painting(0);
    native_font_compositing_context = nullptr;
    NSGraphicsContext.currentContext = saved;
    CGContextFlush(context); CGContextRelease(context);
    return pixels;
}

static void test_bitmap_inspection_pending_inputs()
{
    auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = CGBitmapContextCreate(nullptr, 32, 32, 8, 128, color,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(color); assert(context);
    assert(!ladybird_v_skia_bitmap_pixels_are_current(nullptr));
    assert(ladybird_v_skia_bitmap_pixels_are_current(context));
    s_isolated_input_recordings[context] = std::make_unique<IsolatedInputRecording>();
    assert(!ladybird_v_skia_bitmap_pixels_are_current(context));
    s_isolated_input_recordings.erase(context);
    s_shared_root_recording = std::make_unique<SharedRootRecording>();
    s_shared_root_recording->destination = context;
    assert(!ladybird_v_skia_bitmap_pixels_are_current(context));
    s_shared_root_recording.reset();
    s_deferred_layer_destinations[context] = CGRectMake(0, 0, 32, 32);
    assert(!ladybird_v_skia_bitmap_pixels_are_current(context));
    s_deferred_layer_destinations.erase(context);
    assert(ladybird_v_skia_bitmap_pixels_are_current(context));
    CGContextRelease(context);
}

static void test_text_layer_barrier_eligibility()
{
    auto color=CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context=CGBitmapContextCreate(nullptr,32,32,8,128,color,
        kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(color); assert(context);
    auto saved=NSGraphicsContext.currentContext;
    NSGraphicsContext.currentContext=[NSGraphicsContext graphicsContextWithCGContext:context flipped:NO];
    native_font_compositing_context=context;
    ladybird_v_skia_set_chromium_painting(1);
    ladybird_v_skia_set_shared_recording(0,32,32);
    int rect[]={0,0,32,32};
    assert(ladybird_v_skia_gpu_canvas_begin(context,rect,1));
    assert(ladybird_v_skia_gpu_canvas_defer_layers());
    assert(!native_gpu_canvas_can_defer_layers());
    s_raster_layer_is_root=false;
    ladybird_v_skia_set_layer_shared_recording(1);
    native_begin_css_effect_layer(1,0);
    assert(native_opacity_groups[0].passthrough);
    assert(!native_gpu_canvas_can_defer_layers());
    assert(ladybird_v_skia_gpu_canvas_command("draw_text",9,0));
    if (!native_gpu_canvas_can_defer_layers()) ladybird_v_skia_gpu_canvas_cpu_access();
    assert(!s_gpu_canvas->in_gpu_command);
    native_end_css_effect_layer();
    ladybird_v_skia_set_layer_shared_recording(0);
    s_raster_layer_is_root=true;
    native_begin_css_effect_layer(.7f,0);
    assert(native_gpu_canvas_can_defer_layers());
    native_opacity_group_overflow_depth=1;
    assert(!native_gpu_canvas_can_defer_layers());
    native_opacity_group_overflow_depth=0;
    native_end_css_effect_layer();
    assert(!native_gpu_canvas_can_defer_layers());
    ladybird_v_skia_gpu_canvas_end();
    ladybird_v_skia_set_chromium_painting(0);
    native_font_compositing_context=nullptr;
    NSGraphicsContext.currentContext=saved;
    CGContextRelease(context);
}

static double s_resident_scroll;
static void draw_resident_scene(CGContextRef context, bool canvas) {
    CGContextSetRGBFillColor(context,1,1,1,1);
    CGContextFillRect(context,CGRectMake(0,0,css_width,css_height));
    for (int n=0; n<16; ++n) {
        float y=n*77+12-s_resident_scroll;
        if (canvas) assert(ladybird_v_skia_gpu_canvas_command("fill_rounded_rect",17,0));
        assert(ladybird_v_skia_draw_rounded_rect(context,20,y,320,53,9,9,9,9,9,9,9,9,
            1,0,0,1,0,0,0,0,0,css_width,css_height,
            (n*47)%255,(n*83)%255,(n*103)%255,213,1,0,1,1));
    }
    // The fixed overlay participates in the root and repaints vacated ink.
    if (canvas) assert(ladybird_v_skia_gpu_canvas_command("fill_rounded_rect",17,4));
    assert(ladybird_v_skia_draw_rounded_rect(context,380,71,9,67,4,4,4,4,4,4,4,4,
        1,0,0,1,0,0,0,0,0,css_width,css_height,20,40,60,117,1,0,1,1));
}
static void resident_ring_draw(id self, SEL selector, NSRect bounds) {
    vox_browser_frame_prepared();
    auto context=NSGraphicsContext.currentContext.CGContext;
    static double previous;
    double movement=s_resident_scroll-previous, delta=0;
    double first=floor(std::min(68.,68.-movement));
    double last=ceil(std::max(141.,141.-movement));
    double damage[]={377,first,15,last-first};
    native_scroll_tile_compositor_enabled(1);
    native_begin_scroll_raster(7,1,s_resident_scroll,0,css_width,css_height,1,
        &delta,damage,1,1,1);
    assert(native_scroll_raster.gpu_tiled);
    bool canvas=native_gpu_canvas_begin();
    assert(canvas && native_gpu_canvas_can_present());
    draw_resident_scene(context,canvas);
    native_gpu_canvas_end(); native_end_scroll_raster();
    assert(native_scroll_raster.valid && !native_scroll_gpu_tile_frame_failed);
    previous=s_resident_scroll;
    vox_browser_frame_completed();
}

int main(int argc, char** argv)
{
    test_bitmap_inspection_pending_inputs();
    if (argc==2 && !std::strcmp(argv[1],"--resident-ring")) { @autoreleasepool {
        [NSApplication sharedApplication];
        assert(ladybird_v_skia_gpu_canvas_compositor_available());
        auto* api=const_cast<GpuCanvasApi*>(gpu_canvas_api());
        s_backend_read=api->read; api->read=counted_read;
        native_set_opaque_browser_frames(1);
        setenv("VOX_GPU_TILE_COMPOSITOR","1",1); native_scroll_gpu_tile_capability=YES;
        auto view=[[MyView2 alloc] initWithFrame:NSMakeRect(0,0,css_width,css_height)];
        view.wantsLayer=YES;
        int error=0; unsigned reused=0;
        for (double scroll : {0.,8.,16.,120.,128.,136.,128.,120.,16.,8.,0.}) { @autoreleasepool {
            s_resident_scroll=scroll;
            auto reference=render(true,false,draw_resident_scene,true);
            native_layer_present_frame(view,scale,(IMP)resident_ring_draw);
            reused += native_scroll_raster.reused;
            auto image=native_layer_frame_image(view); assert(image);
            auto data=CGDataProviderCopyData(CGImageGetDataProvider(image)); assert(data);
            for (int y=0; y<height; ++y) for (int x=0; x<width*4; ++x)
                error=std::max(error,std::abs(int(reference[size_t(y)*width*4+x])
                    -int(CFDataGetBytePtr(data)[y*CGImageGetBytesPerRow(image)+x])));
            CFRelease(data);
            if (error>3) { std::cerr<<"Resident ring scroll="<<scroll<<" max error="<<error<<"\n"; return 1; }
        } }
        assert(reused>=8); native_discard_scroll_raster(); [view release];
        std::cout<<"Resident native GPU ring: max error "<<error
            <<"; actual bridge export, wrap/reverse, fixed alpha overlay, lazy capture, "<<reused<<" reused frames\n";
        return 0;
    } }
    if (argc==2 && !std::strcmp(argv[1],"--present-tiles")) {
        auto* api=const_cast<GpuCanvasApi*>(gpu_canvas_api());
        assert(ladybird_v_skia_gpu_canvas_compositor_available());
        s_backend_read=api->read; api->read=counted_read;
        s_compositor=true;
        unsigned cases=0;
        for (auto draw : {draw_leaves,draw_cpu_leaves,draw_inset_leaves,draw_outline_leaves,
                draw_pattern_leaves,draw_video_leaves,draw_native_image_cpu_fallback})
        for (bool full : {false,true}) for (bool shared : {false,true}) {
            s_present_tiles=false;
            auto reference=render(true,shared,draw,full);
            s_present_tiles=true;
            auto candidate=render(true,shared,draw,full);
            assert(reference==candidate); ++cases;
        }
        std::cout << "Retained GPU publication: " << cases
            << " exact full/strip/shared/CPU-barrier frames; no final CPU readback\n";
        return 0;
    }
    if (argc == 2 && !std::strcmp(argv[1], "--text-layer-composite")) {
        setenv("VOX_GPU_CANVAS_OFFSCREEN_LAYERS","1",1);
        test_text_layer_barrier_eligibility();
        auto* api=const_cast<GpuCanvasApi*>(gpu_canvas_api()); assert(api && api->draw_layer_pixels);
        int error=0; unsigned cases=0;
        for (bool full : {false,true}) for (bool nested : {false,true}) for (bool suffix : {false,true}) {
            auto reference=render_native_group(false,nested,0,1,full,true);
            auto control=render_native_group(true,nested,0,1,full,true,true,suffix);
            auto candidate=render_native_group(true,nested,0,1,full,true,false,suffix);
            // Reference includes the same following root leaf.
            if (suffix) reference=render_native_group(false,nested,0,1,full,true,false,true);
            for (size_t at=0; at<reference.size(); ++at) {
                error=std::max(error,std::abs(int(reference[at])-int(candidate[at])));
                error=std::max(error,std::abs(int(control[at])-int(candidate[at])));
            }
            assert(error<=3); ++cases;
        }
        auto layer_pixels=api->draw_layer_pixels;
        api->draw_layer_pixels=nullptr;
        for (bool full : {false,true}) {
            auto reference=render_native_group(false,false,0,1,full,true,false,true);
            auto fallback=render_native_group(true,false,0,1,full,true,true,true);
            for (size_t at=0; at<reference.size(); ++at)
                error=std::max(error,std::abs(int(reference[at])-int(fallback[at])));
            assert(error<=3); ++cases;
        }
        api->draw_layer_pixels=layer_pixels;
        std::cout << "Text layer composites: " << cases << " CPU/barrier/batched frames, max error "
            << error << "; actual glyphs, nested screen groups, strip/full paint, following root leaves and capability fallback\n";
        return 0;
    }
    if (argc == 2 && !std::strcmp(argv[1], "--deferred-video-barriers")) {
        setenv("VOX_GPU_CANVAS_DEFER_VIDEO_BARRIERS", "1", 1);
        unsetenv("VOX_GPU_CANVAS_VIDEO_BACKDROP");
        unsetenv("VOX_GPU_CANVAS_DISABLE_ISOLATED_SHAPES");
        auto* api = const_cast<GpuCanvasApi*>(gpu_canvas_api());
        assert(api && api->draw_image_msaa && api->copy_pixels);
        s_backend_read = api->read; api->read = counted_read;
        int tiles[] {0, 1, 2, 3, 4, 5, 6, 7};
        int error = 0; unsigned cases = 0;
        for (bool full : {false, true}) for (int coverage : {0, 1, 2})
        for (bool rounded : {false, true}) for (int alpha : {128, 255})
        for (int callbacks : {0, 1, 2}) {
            s_video_rounded = rounded; s_deferred_video_callbacks = callbacks;
            for (size_t at=3; at<s_video_frame.size(); at+=4) s_video_frame[at]=alpha;
            s_raster_layer_height=css_height;
            ladybird_v_skia_set_msaa_grid(coverage ? tiles : nullptr,
                coverage == 1 ? 8 : coverage == 2 ? 1 : 0, 512, 256, 2);
            auto reference=render(false,false,draw_deferred_video_leaves,full);
            auto candidate=render(true,false,draw_deferred_video_leaves,full);
            for (size_t at=0; at<reference.size(); ++at)
                error=std::max(error,std::abs(int(reference[at])-int(candidate[at])));
            assert(error <= 3); ++cases;
        }
        for (bool full : {false,true}) {
            auto reference=render(false,false,draw_native_image_cpu_fallback,full);
            auto candidate=render(true,false,draw_native_image_cpu_fallback,full);
            for (size_t at=0; at<reference.size(); ++at)
                error=std::max(error,std::abs(int(reference[at])-int(candidate[at])));
            assert(error <= 3); ++cases;
        }
        ladybird_v_skia_set_msaa_grid(nullptr,0,0,0,0);
        s_raster_layer_height=0; s_video_rounded=false;
        s_real_backdrop_copy=api->copy_pixels; api->copy_pixels=maybe_fail_backdrop_copy;
        for (bool read_only : {false,true}) for (bool gpu_restore : {false,true}) {
            if (read_only) setenv("VOX_GPU_CANVAS_READONLY_VIDEO_CAPTURE","1",1);
            else unsetenv("VOX_GPU_CANVAS_READONLY_VIDEO_CAPTURE");
            if (gpu_restore) setenv("VOX_GPU_CANVAS_VIDEO_BACKDROP","1",1);
            else unsetenv("VOX_GPU_CANVAS_VIDEO_BACKDROP");
            for (int alpha : {128,255}) for (bool callbacks : {false,true}) for (bool fail : {false,true}) {
                auto reference=render_video_backdrop(false,callbacks,alpha,false);
                auto candidate=render_video_backdrop(true,callbacks,alpha,fail);
                for (size_t at=0; at<reference.size(); ++at)
                    error=std::max(error,std::abs(int(reference[at])-int(candidate[at])));
                assert(error <= 3); ++cases;
            }
        }
        std::cout << "Deferred video barriers: " << cases << " ordinary/canvas frames, max error "
            << error << "; pending prefix, capture, CPU/GPU restore, failed copy and legacy host\n";
        return 0;
    }
    if (argc == 2 && !std::strcmp(argv[1], "--static-msaa-images")) {
        setenv("VOX_GPU_CANVAS_MSAA_IMAGES", "1", 1);
        assert(gpu_canvas_api()->draw_image_msaa);
        auto* api = const_cast<GpuCanvasApi*>(gpu_canvas_api());
        s_backend_read = api->read; api->read = counted_read;
        int tiles[] {0, 1, 2, 3, 4, 5, 6, 7};
        int error = 0; unsigned cases = 0;
        for (bool full : {false, true}) for (int coverage : {1, 2})
        for (bool rounded : {false, true}) for (int alpha : {128, 255})
        for (float offset : {0.f, .375f}) for (int nearest : {0, 1}) for (bool explicit_clip : {false, true}) {
            s_video_rounded=rounded; s_static_image_offset=offset; s_static_image_nearest=nearest;
            s_static_image_explicit_clip=explicit_clip;
            for (size_t at=3; at<s_video_frame.size(); at+=4) s_video_frame[at]=alpha;
            s_raster_layer_height=css_height;
            ladybird_v_skia_set_msaa_grid(coverage ? tiles : nullptr,
                coverage == 1 ? 8 : coverage == 2 ? 1 : 0,512,256,2);
            auto reference=render(false,false,draw_static_msaa_image,full);
            auto candidate=render(true,false,draw_static_msaa_image,full);
            bool admitted=!nearest && !explicit_clip;
            assert(s_draws == unsigned(admitted) && s_declined == unsigned(!admitted)
                && s_uploads == unsigned(admitted));
            for (size_t at=0; at<reference.size(); ++at)
                error=std::max(error,std::abs(int(reference[at])-int(candidate[at])));
            if (error>3) {
                std::cerr << "Static MSAA image full=" << full << " coverage=" << coverage
                    << " rounded=" << rounded << " alpha=" << alpha << " offset=" << offset
                    << " nearest=" << nearest << " max error=" << error << '\n'; return 1;
            }
            ++cases;
        }
        std::cout << "Static MSAA images: " << cases << " ordinary/canvas frames, max error " << error << '\n';
        return 0;
    }
    if (argc == 2 && !std::strcmp(argv[1], "--layer-pixels")) {
        setenv("VOX_GPU_CANVAS_OFFSCREEN_LAYERS", "1", 1);
        assert(gpu_canvas_api()->draw_layer_pixels);
        int error = 0;
        for (int blend : {0, 3}) for (float opacity : {0.f, .01f, .25f, .5f, .85f, .999f, 1.f})
            for (bool full : {false, true}) {
                auto reference = render_layer_pixels(false, blend, opacity, full);
                auto candidate = render_layer_pixels(true, blend, opacity, full);
                for (size_t index = 0; index < reference.size(); ++index)
                    error = std::max(error, std::abs(int(reference[index]) - int(candidate[index])));
            }
        for (bool nested : {false, true}) for (int blend : {0, 3})
            for (float opacity : {.5f, .85f, 1.f}) for (bool full : {false, true}) {
                auto reference = render_native_group(false, nested, blend, opacity, full);
                auto candidate = render_native_group(true, nested, blend, opacity, full);
                for (size_t index = 0; index < reference.size(); ++index)
                    error = std::max(error, std::abs(int(reference[index]) - int(candidate[index])));
            }
        std::cout << "GPU screen/opacity layers: scalar reference, nested CPU access, source lifetime and pending order max error " << error << '\n';
        assert(error <= 3); return 0;
    }
    if (argc == 2 && !std::strcmp(argv[1], "--filter-image")) {
        setenv("VOX_GPU_CANVAS_FILTER_LAYERS", "1", 1);
        int error = 0;
        for (bool bgra : {false, true}) for (int alpha : {0, 73, 128, 255})
            for (bool full : {false, true}) for (int fallback : {0, 1, 2}) {
                auto reference = render_filter_image(false, bgra, alpha, full, fallback);
                auto candidate = render_filter_image(true, bgra, alpha, full, fallback);
                for (size_t index = 0; index < reference.size(); ++index)
                    error = std::max(error, std::abs(int(reference[index]) - int(candidate[index])));
            }
        std::cout << "GPU filter images: RGBA/BGRA, alpha, padding, source lifetime, root order and fallback max error " << error << '\n';
        assert(error <= 3);
        return 0;
    }
    if(argc==2 && !std::strcmp(argv[1],"--native-grid")) {
        auto* api=const_cast<GpuCanvasApi*>(gpu_canvas_api());assert(api && api->begin_native_grid && api->draw_shape_native_grid);
        s_backend_read=api->read;api->read=counted_read;s_expect_native_grid=true;
        setenv("VOX_GPU_CANVAS_NATIVE_GRID","1",1);
        unsetenv("VOX_GPU_CANVAS_DISABLE_ISOLATED_SHAPES");
        s_raster_layer_is_root=true;s_raster_layer_height=css_height+128;
        int max_error=0;
        auto original=backdrop();
        for(double scroll:{0.,13.5,127.5})for(bool full:{false,true})for(int tile:{0,1,2,3})
            for(int fill:{0,1})for(int alpha:{128,255})for(float offset:{0.f,.375f}) {
            s_root_raster_scroll_y=scroll;s_mixed_fill=fill;s_mixed_alpha=alpha;s_mixed_offset=offset;
            ladybird_v_skia_set_msaa_grid(&tile,1,512,256,2);
            auto reference=render(false,false,draw_mixed_shape,full);
            auto candidate=render(true,false,draw_mixed_shape,full);
            assert(s_draws==1 && s_uploads==1 && s_flushes==0);
            for(int y=0;y<height;++y)for(int x=0;x<width*4;++x) {
                size_t index=size_t(y)*width*4+x;
                int error=std::abs(int(reference[index])-int(candidate[index]));
                max_error=std::max(max_error,error);
                if(!full && (y<strip_top || y>=strip_top+strip_height)) assert(candidate[index]==original[index]);
            }
            if(max_error>3) {
                std::cerr<<"Native grid error "<<max_error<<" scroll="<<scroll<<" full="<<full<<" tile="<<tile<<" fill="<<fill<<" alpha="<<alpha<<" offset="<<offset<<'\n';
                return 1;
            }
        }
        std::cout<<"Native GPU grid mixed coverage, negative tile origins and clipping: max error "<<max_error<<'\n';return 0;
    }
    if(argc==2 && !std::strcmp(argv[1],"--overlay-batch")) {
        int error=0;
        for(int aa:{0,1})for(int alpha:{73,128,255})for(bool horizontal:{false,true})for(float phase:{0.f,.25f,.5f,.75f}) {
            s_overlay_stroke_antialias=aa;
            auto reference=render_overlay_batch(false,alpha,horizontal,phase);
            auto candidate=render_overlay_batch(true,alpha,horizontal,phase);
            for(size_t i=0;i<reference.size();++i)error=std::max(error,std::abs(int(reference[i])-int(candidate[i])));
            auto original=backdrop();
            for(int y=0;y<height;++y)for(int x=0;x<width;++x) {
                bool vertical=x>=384*2 && y>=7*2 && y<(7+154)*2;
                bool across=horizontal && x>=24*2 && x<(24+134)*2 && y>=282*2;
                if(!vertical && !across)for(int channel=0;channel<4;++channel)
                    assert(candidate[(y*width+x)*4+channel]==original[(y*width+x)*4+channel]);
            }
        }
        std::cout<<"Late GPU overlay batch: maximum channel error "<<error<<'\n';
        // The established GPU canvas leaf bound is three channel levels.
        assert(error<=3);return 0;
    }
    if (argc==2 && !std::strcmp(argv[1],"--partial-readback")) {
        auto* api=const_cast<GpuCanvasApi*>(gpu_canvas_api());assert(api);
        s_backend_read=api->read;api->read=counted_read;
        setenv("VOX_GPU_CANVAS_DISABLE_ISOLATED_SHAPES","1",1);
        for(auto draw:{draw_leaves,draw_cpu_leaves,draw_outline_leaves,draw_inset_leaves,draw_pattern_leaves,draw_video_leaves}) {
            unsetenv("VOX_GPU_CANVAS_PARTIAL_READBACK");auto reference=render(true,false,draw);
            setenv("VOX_GPU_CANVAS_PARTIAL_READBACK","1",1);auto candidate=render(true,false,draw);
            assert(reference==candidate);
        }
        unsetenv("VOX_GPU_CANVAS_PARTIAL_READBACK");auto reference=render(true,false,draw_leaves,true);
        setenv("VOX_GPU_CANVAS_PARTIAL_READBACK","1",1);auto candidate=render(true,false,draw_leaves,true);
        assert(reference==candidate);
        std::cout<<"Partial GPU readback matches full transfers exactly for shapes, CPU barriers, shadows, gradients and video\n";
        return 0;
    }
    if (argc==2 && !std::strcmp(argv[1],"--iosurface-readback")) { @autoreleasepool {
        auto* api=const_cast<GpuCanvasApi*>(gpu_canvas_api()); assert(api && api->read_iosurface);
        s_surface_read=api->read_iosurface; api->read_iosurface=test_surface_read;
        setenv("VOX_GPU_CANVAS_DISABLE_ISOLATED_SHAPES","1",1);
        MyView2* view=[[MyView2 alloc] initWithFrame:NSMakeRect(0,0,css_width,css_height)];
        unsetenv("VOX_GPU_CANVAS_IOSURFACE_READBACK");
        auto reference=shared_frame_pixels(view);
        assert(!s_surface_calls);
        setenv("VOX_GPU_CANVAS_IOSURFACE_READBACK","1",1);
        for(int iteration=0;iteration<6;++iteration) {
            assert(shared_frame_pixels(view)==reference);
            assert(s_surface_calls==(iteration+1)*2);
        }
        s_surface_decline=true;
        assert(shared_frame_pixels(view)==reference && s_surface_calls==14);
        s_surface_decline=false; s_surface_legacy_host=true;
        assert(shared_frame_pixels(view)==reference && s_surface_calls==14);
        [view release];
        std::cout<<"IOSurface GPU readback matches pooled publication exactly, including CPU barriers, reuse, legacy host and unsupported fallback\n";
        return 0;
    } }
    if (argc == 2 && (!std::strcmp(argv[1], "--failed-readback")
        || !std::strcmp(argv[1], "--failed-readonly"))) {
        auto* api = const_cast<GpuCanvasApi*>(gpu_canvas_api()); assert(api);
        s_backend_read = api->read; api->read = counted_read;
        auto pixels = backdrop();
        auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        auto context = CGBitmapContextCreate(pixels.data(), width, height, 8, width * 4, color,
            kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
        CGColorSpaceRelease(color); assert(context);
        CGContextScaleCTM(context, scale, scale);
        ladybird_v_skia_set_chromium_painting(1);
        ladybird_v_skia_set_shared_recording(0,css_width,css_height);
        ladybird_v_skia_begin_deferred_layer_frame(0);
        int rect[] {0,0,width,height};
        assert(ladybird_v_skia_gpu_canvas_begin(context, rect, 1));
        assert(ladybird_v_skia_gpu_canvas_command("fill_rounded_rect",17,0));
        assert(ladybird_v_skia_draw_rounded_rect(context,40,80,300,120,12,12,12,12,12,12,12,12,
            1,0,0,1,0,0,0,0,0,css_width,css_height,230,240,250,255,1,0,1,1));
        assert(s_gpu_canvas->cpu_stale);
        s_fail_reads = 2;
        if (!std::strcmp(argv[1], "--failed-readonly")) {
            assert(!ladybird_v_skia_gpu_canvas_context_read(context));
            assert(!s_gpu_canvas->gpu_valid);
        } else ladybird_v_skia_gpu_canvas_cpu_access();
        assert(s_read_calls == 2 && !s_successful_reads && !s_fail_reads);
        assert(s_gpu_canvas_read_failed && !gpu_canvas_enabled());
        assert(!ladybird_v_skia_gpu_canvas_command("fill_rect",9,0));
        ladybird_v_skia_gpu_canvas_end();
        assert(!ladybird_v_skia_finish_deferred_layer_frame());
        ladybird_v_skia_begin_deferred_layer_frame(0);
        assert(!ladybird_v_skia_gpu_canvas_begin(context,rect,1));
        native_fill(context,10,20,40,30,20,40,60,false);
        assert(ladybird_v_skia_finish_deferred_layer_frame());
        CGContextFlush(context);
        auto* painted = pixels.data()+((height-60)*width+30)*4;
        assert(painted[0]==20 && painted[1]==40 && painted[2]==60 && painted[3]==255);
        CGContextRelease(context);
        std::cout << "Failed GPU readback rejects replay and disables subsequent GPU attempts\n";
        return 0;
    }
    if (argc == 2 && !std::strcmp(argv[1], "--video-backdrop-verify")) {
        assert(gpu_canvas_verify_leaves());
        auto* api = const_cast<GpuCanvasApi*>(gpu_canvas_api()); assert(api && api->copy_pixels);
        s_real_backdrop_copy = api->copy_pixels; api->copy_pixels = maybe_fail_backdrop_copy;
        setenv("VOX_GPU_CANVAS_VIDEO_BACKDROP", "1", 1);
        for (int alpha : {128,255}) for (bool callbacks : {false,true}) for (bool fail : {false,true}) {
            auto reference = render_video_backdrop(false, callbacks, alpha, false);
            auto candidate = render_video_backdrop(true, callbacks, alpha, fail);
            assert(reference == candidate);
        }
        assert(s_backdrop_verify_error <= 3);
        std::cout << "GPU video backdrop per-leaf verification max error " << s_backdrop_verify_error << '\n';
        return 0;
    }
    // On by default; only VOX_DISABLE_GPU_CANVAS turns the native canvas off.
    unsetenv("VOX_DISABLE_GPU_CANVAS");
    unsetenv("VOX_GPU_CANVAS_VIDEO_BACKDROP");
    assert(gpu_canvas_api());
    unsetenv("VOX_GPU_CANVAS_DISABLE_ISOLATED_SHAPES");
    assert(gpu_canvas_isolated_shapes_enabled());
    setenv("VOX_GPU_CANVAS_DISABLE_ISOLATED_SHAPES", "1", 1);
    auto* api = const_cast<GpuCanvasApi*>(gpu_canvas_api());
    direct_read_regions(api);
    s_backend_read = api->read;
    api->read = counted_read;
    auto reference = render(false);
    auto candidate = render(true);
    assert(s_read_calls == 2 && s_successful_reads == 2);
    s_fail_reads = 1;
    auto retry_candidate = render(true);
    assert(s_read_calls == 5 && s_successful_reads == 4 && !s_fail_reads);
    assert(retry_candidate == candidate);
    auto full_reference = render(false, false, draw_leaves, true);
    auto full_candidate = render(true, false, draw_leaves, true);
    int full_error = 0;
    for (size_t i = 0; i < full_reference.size(); ++i)
        full_error = std::max(full_error, std::abs(int(full_reference[i]) - int(full_candidate[i])));
    assert(full_error <= 3);
    if (api->read_direct) {
        s_backend_direct_read = api->read_direct;
        api->read_direct = counted_direct_read;
        setenv("VOX_GPU_CANVAS_DIRECT_READBACK", "1", 1);
        auto direct_candidate = render(true);
        assert(s_direct_reads == 2 && direct_candidate == candidate);
        s_fail_direct_read = true;
        auto fallback_candidate = render(true);
        assert(s_direct_reads == 2 && fallback_candidate == candidate);
        s_fail_direct_read = false;
        unsetenv("VOX_GPU_CANVAS_DIRECT_READBACK");
    }
    // All three approved leaves draw on the GPU; the CPU fill between them
    // forces one readback and a fresh upload before the border. The final
    // readback happens when the frame ends.
    if (s_draws != 3 || s_declined || s_uploads != 2 || s_flushes != 1) {
        std::cerr << "GPU canvas did not take the expected path: draws=" << s_draws << " uploads="
            << s_uploads << " flushes=" << s_flushes << " declined=" << s_declined << '\n';
        return 1;
    }
    auto original = backdrop();
    int max_error = 0;
    size_t differing = 0, painted = 0;
    for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x) {
        size_t at = (size_t(y) * width + x) * 4;
        bool inside = y >= strip_top && y < strip_top + strip_height;
        for (int c = 0; c < 4; ++c) {
            if (!inside && candidate[at + c] != original[at + c]) {
                std::cerr << "GPU canvas wrote outside the repainted strip at " << x << "," << y << '\n';
                return 1;
            }
            if (inside && candidate[at + c] != original[at + c]) ++painted;
            int error = std::abs(int(candidate[at + c]) - int(reference[at + c]));
            if (error) ++differing;
            max_error = std::max(max_error, error);
        }
    }
    if (painted < 100000) {
        std::cerr << "Leaves painted only " << painted << " strip channels\n";
        return 1;
    }
    // The red CPU fill lies inside the strip and must cover the shape below it.
    size_t red = (size_t(150 * scale + 2 + 0) * width + 130 * scale) * 4;
    if (std::abs(int(candidate[red]) - 204) > 1 || candidate[red + 1] > 30) {
        std::cerr << "CPU fill lost its paint order\n";
        return 1;
    }
    if (max_error > 3) {
        std::cerr << "GPU canvas differs from per-leaf replay by " << max_error
            << " (" << differing << " channels)\n";
        return 1;
    }
    // A layer recording its leaves into a shared compositor picture publishes
    // them later; the canvas leaves that layer to the ordinary path entirely.
    auto shared_reference = render(false, true);
    auto shared_candidate = render(true, true);
    if (s_draws != 0 || s_declined == 0 || shared_candidate != shared_reference) {
        std::cerr << "GPU canvas drew during a shared recording: draws=" << s_draws
            << " declined=" << s_declined << '\n';
        return 1;
    }
    // Solid fills before any GPU leaf stay on the CPU canvas; one after the
    // rounded fill joins the GPU canvas above it.
    auto cpu_reference = render(false, false, draw_cpu_leaves);
    auto cpu_candidate = render(true, false, draw_cpu_leaves);
    if (s_first_uploads || s_first_begun || s_first_cpu_leaves != 1 || s_draws != 2
        || s_uploads != 1 || s_flushes || s_cpu_leaves != 1) {
        std::cerr << "CPU leaves took the wrong path: first uploads=" << s_first_uploads
            << " begun=" << s_first_begun << " draws=" << s_draws << " uploads=" << s_uploads
            << " flushes=" << s_flushes << " cpu_leaves=" << s_cpu_leaves << '\n';
        return 1;
    }
    int cpu_error = 0;
    for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x) {
        size_t at = (size_t(y) * width + x) * 4;
        bool inside = y >= strip_top && y < strip_top + strip_height;
        for (int c = 0; c < 4; ++c) {
            if (!inside && cpu_candidate[at + c] != original[at + c]) {
                std::cerr << "CPU-leaf frame wrote outside the strip at " << x << "," << y << '\n';
                return 1;
            }
            cpu_error = std::max(cpu_error, std::abs(int(cpu_candidate[at + c]) - int(cpu_reference[at + c])));
        }
    }
    // The second fill lies above the rounded fill, which covers the first.
    size_t above = (size_t(135 * scale) * width + 160 * scale) * 4;
    size_t below = (size_t(135 * scale) * width + 60 * scale) * 4;
    if (cpu_error > 3 || cpu_candidate[above] != 200 || cpu_candidate[above + 1] != 40
        || cpu_candidate[below] != 230) {
        std::cerr << "CPU-leaf frame differs by " << cpu_error << " or lost paint order\n";
        return 1;
    }
    // Both inset shadows and the fill between them draw in the frame's one
    // GPU pass, read back once when it ends.
    auto inset_reference = render(false, false, draw_inset_leaves);
    auto inset_candidate = render(true, false, draw_inset_leaves);
    if (s_draws != 3 || s_declined || s_uploads != 1 || s_flushes) {
        std::cerr << "Inset shadows took the wrong path: draws=" << s_draws << " uploads=" << s_uploads
            << " flushes=" << s_flushes << " declined=" << s_declined << '\n';
        return 1;
    }
    int inset_error = 0;
    size_t inset_painted = 0;
    for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x) {
        size_t at = (size_t(y) * width + x) * 4;
        bool inside = y >= strip_top && y < strip_top + strip_height;
        for (int c = 0; c < 4; ++c) {
            if (!inside && inset_candidate[at + c] != original[at + c]) {
                std::cerr << "Inset frame wrote outside the strip at " << x << "," << y << '\n';
                return 1;
            }
            if (inside && inset_reference[at + c] != original[at + c]) ++inset_painted;
            inset_error = std::max(inset_error, std::abs(int(inset_candidate[at + c]) - int(inset_reference[at + c])));
        }
    }
    if (inset_painted < 50000 || inset_error > 3) {
        std::cerr << "Inset shadows differ from per-leaf replay by " << inset_error
            << " (" << inset_painted << " painted channels)\n";
        return 1;
    }
    auto outline_reference = render(false, false, draw_outline_leaves);
    auto outline_candidate = render(true, false, draw_outline_leaves);
    int outline_error = 0;
    for (size_t at = 0; at < outline_reference.size(); ++at)
        outline_error = std::max(outline_error, std::abs(int(outline_candidate[at]) - int(outline_reference[at])));
    if (s_draws != 2 || s_declined || s_uploads != 1 || s_flushes || outline_error > 3
        || outline_reference == original) {
        std::cerr << "Outline and ellipse took the wrong path: draws=" << s_draws << " uploads="
            << s_uploads << " flushes=" << s_flushes << " error=" << outline_error << '\n';
        return 1;
    }
    auto pattern_reference = render(false, false, draw_pattern_leaves);
    auto pattern_candidate = render(true, false, draw_pattern_leaves);
    int pattern_error = 0;
    size_t pattern_painted = 0;
    for (size_t at = 0; at < pattern_reference.size(); ++at) {
        pattern_error = std::max(pattern_error, std::abs(int(pattern_candidate[at]) - int(pattern_reference[at])));
        if (pattern_reference[at] != original[at]) ++pattern_painted;
    }
    if (s_draws != 2 || s_declined || s_uploads != 1 || s_flushes || pattern_error > 3
        || pattern_painted < 50000) {
        std::cerr << "Gradient tile took the wrong path: draws=" << s_draws << " uploads=" << s_uploads
            << " flushes=" << s_flushes << " error=" << pattern_error << " painted=" << pattern_painted << '\n';
        return 1;
    }
    // Over Chromium MSAA tiles they draw in a multisampled scratch pass, as
    // their tiled replay multisamples each tile.
    int const msaa_tiles[] {0, 1, 2, 3, 4, 5, 6, 7};
    s_raster_layer_height = css_height;
    ladybird_v_skia_set_msaa_grid(msaa_tiles, 8, 512, 256, 2);
    auto msaa_reference = render(false, false, draw_inset_leaves);
    auto msaa_candidate = render(true, false, draw_inset_leaves);
    ladybird_v_skia_set_msaa_grid(nullptr, 0, 0, 0, 0);
    s_raster_layer_height = 0;
    if (s_draws != 2 || s_declined != 1 || s_uploads != 2 || s_flushes != 1) {
        std::cerr << "MSAA inset shadows took the wrong path: draws=" << s_draws << " uploads="
            << s_uploads << " flushes=" << s_flushes << " declined=" << s_declined << '\n';
        return 1;
    }
    int msaa_error = 0;
    for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x) {
        size_t at = (size_t(y) * width + x) * 4;
        bool inside = y >= strip_top && y < strip_top + strip_height;
        for (int c = 0; c < 4; ++c) {
            if (!inside && msaa_candidate[at + c] != original[at + c]) {
                std::cerr << "MSAA inset frame wrote outside the strip at " << x << "," << y << '\n';
                return 1;
            }
            msaa_error = std::max(msaa_error, std::abs(int(msaa_candidate[at + c]) - int(msaa_reference[at + c])));
        }
    }
    int msaa_shift = 0;
    for (size_t at = 0; at < msaa_reference.size(); ++at)
        msaa_shift = std::max(msaa_shift, std::abs(int(msaa_reference[at]) - int(inset_reference[at])));
    // MSAA tiles are declined unless the canvas multisamples them itself; the
    // counters above show that it did.
    if (msaa_error > 3) {
        std::cerr << "MSAA inset shadows differ from tiled replay by " << msaa_error << '\n';
        return 1;
    }
    assert(gpu_canvas_api()->draw_image_msaa);
    // All four corners can belong to different ordinary/MSAA raster tiles.
    // Fractional compound strokes and opaque sparse fills must retain their
    // exact ordinary coverage in both full and partial viewport repainting.
    int isolated_shape_error = 0;
    if (std::getenv("VOX_TEST_ISOLATED_DIRECT")) setenv("VOX_GPU_CANVAS_DIRECT_READBACK", "1", 1);
    for (bool isolated : {false, true}) {
    if (isolated) unsetenv("VOX_GPU_CANVAS_DISABLE_ISOLATED_SHAPES");
    else setenv("VOX_GPU_CANVAS_DISABLE_ISOLATED_SHAPES", "1", 1);
    for (bool full : {false, true}) for (int tile : {0, 1, 2, 3})
        for (int fill : {0, 1}) for (int alpha : {128, 255}) for (float offset : {0.f, .375f}) {
        s_mixed_fill = fill; s_mixed_alpha = alpha; s_mixed_offset = offset;
        s_raster_layer_height = css_height;
        ladybird_v_skia_set_msaa_grid(&tile, 1, 512, 256, 2);
        auto reference = render(false, false, draw_mixed_shape, full);
        auto candidate = render(true, false, draw_mixed_shape, full);
        assert(s_draws == unsigned(isolated) && s_uploads == unsigned(isolated) && s_flushes == 0);
        int error = 0;
        for (size_t at = 0; at < reference.size(); ++at)
            error = std::max(error, std::abs(int(reference[at]) - int(candidate[at])));
        if (error > (isolated ? 3 : 0)) {
            std::cerr << "Isolated=" << isolated << " full=" << full << " tile=" << tile
                << " fill=" << fill << " alpha=" << alpha << " offset=" << offset << " error=" << error << '\n';
            return 1;
        }
        isolated_shape_error = std::max(isolated_shape_error, error);
    }
    }
    setenv("VOX_GPU_CANVAS_DISABLE_ISOLATED_SHAPES", "1", 1);
    unsetenv("VOX_GPU_CANVAS_DIRECT_READBACK");
    ladybird_v_skia_set_msaa_grid(nullptr, 0, 0, 0, 0);
    s_raster_layer_height = 0;
    int video_error = 0;
    std::vector<uint8_t> previous_video_reference;
    for (int coverage : {0, 1, 2}) for (bool rounded : {false, true}) for (int frame : {0, 1}) {
        s_video_rounded = rounded;
        for (size_t at = 3; at < s_video_frame.size(); at += 4)
            s_video_frame[at] = frame ? 128 : 255;
        s_video_frame[(size_t(400) * 1426 + 50) * 4 + 2] ^= 37;
        s_raster_layer_height = css_height;
        ladybird_v_skia_set_msaa_grid(coverage ? msaa_tiles : nullptr,
            coverage == 1 ? 8 : coverage == 2 ? 1 : 0, 512, 256, 2);
        auto video_reference = render(false, false, draw_video_leaves);
        auto video_candidate = render(true, false, draw_video_leaves);
        if (frame) assert(video_reference != previous_video_reference);
        previous_video_reference = video_reference;
        ladybird_v_skia_set_msaa_grid(nullptr, 0, 0, 0, 0);
        s_raster_layer_height = 0;
        // Preserve mixed MSAA tile ownership without a per-leaf readback.
        assert(s_draws == (coverage ? 1 : 2));
        assert(s_declined == unsigned(coverage != 0));
        assert(s_uploads == 1 && s_flushes == unsigned(coverage != 0));
        for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x) {
            size_t at = (size_t(y) * width + x) * 4;
            for (int c = 0; c < 4; ++c) {
                if (y < strip_top || y >= strip_top + strip_height)
                    assert(video_candidate[at + c] == original[at + c]);
                video_error = std::max(video_error,
                    std::abs(int(video_candidate[at + c]) - int(video_reference[at + c])));
            }
        }
        if (video_error > 3) {
            std::cerr << "Video coverage=" << coverage << " rounded=" << rounded
                << " frame=" << frame << " differs by " << video_error << '\n';
            return 1;
        }
    }
    assert(api->copy_pixels);
    s_real_backdrop_copy = api->copy_pixels;
    api->copy_pixels = maybe_fail_backdrop_copy;
    setenv("VOX_GPU_CANVAS_VIDEO_BACKDROP", "1", 1);
    int backdrop_error = 0;
    for (int alpha : {128, 255}) for (bool callbacks : {false, true}) for (bool fail : {false, true}) {
        auto reference = render_video_backdrop(false, callbacks, alpha, false);
        auto candidate = render_video_backdrop(true, callbacks, alpha, fail);
        for (size_t at = 0; at < reference.size(); ++at)
            backdrop_error = std::max(backdrop_error, std::abs(int(reference[at]) - int(candidate[at])));
        assert(backdrop_error <= 3);
    }
    unsetenv("VOX_GPU_CANVAS_VIDEO_BACKDROP");
    api->copy_pixels = s_real_backdrop_copy;
    std::cout << "GPU canvas matches per-leaf replay within " << max_error << " levels ("
        << differing << " channels differ), inset shadows within " << inset_error
        << " (" << msaa_error << " in MSAA tiles, where plain replay differs by " << msaa_shift
        << "), outlines and ellipses within " << outline_error
        << ", CSS gradient tiles within " << pattern_error
        << ", video frames within " << video_error
        << ", isolated mixed-MSAA fills/strokes within " << isolated_shape_error << " (fallback exact)"
        << ", GPU video backdrop within " << backdrop_error << " (legacy host and failed-copy fallback included)"
        << "; outside pixels, CPU paint order, CPU leaves and shared recordings preserved\n";
}
