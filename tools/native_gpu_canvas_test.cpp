// The experimental GPU canvas draws approved leaves of a reused scroll frame
// on GPU surfaces and reads them back once. Compare it with the ordinary
// per-leaf replay of the same leaves over the same backdrop: repainted pixels
// match within blending rounding, pixels outside the repainted strip are never
// touched, and a CPU draw of an unapproved command keeps its paint order.
#include "../native_skia_text_darwin.cpp"
#include <cassert>
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
            bool expected = !s_gpu_canvas->complete_viewport || !std::strcmp(kind, "paint_outer_box_shadow");
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
static void draw_outline_leaves(CGContextRef context, bool canvas)
{
    if (canvas) assert(ladybird_v_skia_gpu_canvas_command("stroke_rounded_rect", 19, 512) == 0);
    if (canvas) assert(ladybird_v_skia_gpu_canvas_command("stroke_rounded_rect", 19, 0) == 1);
    assert(ladybird_v_skia_draw_rounded_rect(context, 30.5f, 85, 320, 100, 6, 6, 6, 6, 6, 6, 6, 6,
        1, 0, 0, 1, 0, 0, 0, 0, 0, css_width, css_height, 200, 210, 230, 255, 0, 1, 1, 1));
    if (canvas) assert(ladybird_v_skia_gpu_canvas_command("fill_ellipse", 12, 0) == 1);
    assert(ladybird_v_skia_draw_rounded_rect(context, 150, 110, 70, 50, 35, 25, 35, 25, 35, 25, 35, 25,
        1, 0, 0, 1, 0, 0, 0, 0, 0, css_width, css_height, 240, 80, 60, 255, 1, 0, 1, 1));
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
    // Keep the CPU backdrop barrier before the video. Its image opts back in
    // after that barrier rather than approving the complete draw_video command.
    if (canvas) assert(ladybird_v_skia_gpu_canvas_command("draw_video", 10, 0) == 0);
    float radii[] {13, 13, 13, 13, 0, 0, 0, 0};
    assert(ladybird_v_skia_draw_rgba_image(context, s_video_frame.data(), 1426, 1080, 1426 * 4,
        52.5f, 81.25f, 238, 180, 0, 0, 1426, 1080, 52.5f, 81.25f, 238, 180,
        1, 0, 0, 1, 0, 0, 0, 0, 0, css_width, css_height, 1, 0,
        2 | VOX_GRAPHITE_IMAGE_VIDEO_FRAME, s_video_rounded ? radii : nullptr));
    if (canvas) assert(ladybird_v_skia_gpu_canvas_command("fill_rounded_rect", 17, 0) == 1);
    assert(ladybird_v_skia_draw_rounded_rect(context, 70, 120, 200, 60, 8, 8, 8, 8, 8, 8, 8, 8,
        1, 0, 0, 1, 0, 0, 0, 0, 0, css_width, css_height, 230, 240, 250, 140, 1, 0, 1, 1));
}

static unsigned s_draws, s_uploads, s_flushes, s_declined, s_cpu_leaves;
static unsigned s_read_calls, s_successful_reads, s_fail_reads;
static decltype(&vox_graphite_canvas_read) s_backend_read;
static decltype(&vox_graphite_canvas_read_direct) s_backend_direct_read;
static unsigned s_direct_reads;
static bool s_fail_direct_read;

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
    }
    leaves(context, canvas);
    ladybird_v_skia_finish_shared_recording();
    ladybird_v_skia_set_shared_recording(0, 0, 0);
    if (canvas) {
        s_draws = s_gpu_canvas->draws;
        s_uploads = s_gpu_canvas->uploads;
        s_flushes = s_gpu_canvas->flushes;
        s_declined = s_gpu_canvas->declined;
        s_cpu_leaves = s_gpu_canvas->cpu_leaves;
        unsigned expected_reads = s_gpu_canvas->flushes + unsigned(s_gpu_canvas->cpu_stale);
        unsigned before_final_read = s_successful_reads;
        ladybird_v_skia_gpu_canvas_end();
        assert(!s_gpu_canvas);
        // Every earlier flush succeeded; final publication adds at most one.
        assert(s_successful_reads - before_final_read == expected_reads - s_flushes);
    }
    ladybird_v_skia_set_chromium_painting(0);
    CGContextFlush(context);
    CGContextRelease(context);
    return pixels;
}

int main()
{
    // On by default; only VOX_DISABLE_GPU_CANVAS turns the native canvas off.
    unsetenv("VOX_DISABLE_GPU_CANVAS");
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
    std::cout << "GPU canvas matches per-leaf replay within " << max_error << " levels ("
        << differing << " channels differ), inset shadows within " << inset_error
        << " (" << msaa_error << " in MSAA tiles, where plain replay differs by " << msaa_shift
        << "), outlines and ellipses within " << outline_error
        << ", CSS gradient tiles within " << pattern_error
        << ", video frames within " << video_error
        << ", isolated mixed-MSAA fills/strokes within " << isolated_shape_error << " (fallback exact)"
        << "; outside pixels, CPU paint order, CPU leaves and shared recordings preserved\n";
}
