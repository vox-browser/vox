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
        if (canvas) assert(ladybird_v_skia_gpu_canvas_command(kind, int(std::strlen(kind)), 0) == 1);
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

static unsigned s_draws, s_uploads, s_flushes, s_declined;

static std::vector<uint8_t> render(bool canvas, bool shared = false)
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
    CGContextClipToRect(context, CGRectMake(0, css_height - (strip_top + strip_height) / float(scale),
        css_width, strip_height / float(scale)));
    ladybird_v_skia_set_chromium_painting(1);
    // Root raster layer: a frame-wide shared recording.
    ladybird_v_skia_set_shared_recording(shared, css_width, css_height);
    if (canvas) {
        int rect[] {0, strip_top, width, strip_height};
        assert(ladybird_v_skia_gpu_canvas_begin(context, rect, 1));
    }
    draw_leaves(context, canvas);
    ladybird_v_skia_finish_shared_recording();
    ladybird_v_skia_set_shared_recording(0, 0, 0);
    if (canvas) {
        s_draws = s_gpu_canvas->draws;
        s_uploads = s_gpu_canvas->uploads;
        s_flushes = s_gpu_canvas->flushes;
        s_declined = s_gpu_canvas->declined;
        ladybird_v_skia_gpu_canvas_end();
        assert(!s_gpu_canvas);
    }
    ladybird_v_skia_set_chromium_painting(0);
    CGContextFlush(context);
    CGContextRelease(context);
    return pixels;
}

int main()
{
    setenv("VOX_EXPERIMENT_GPU_CANVAS", "1", 1);
    assert(gpu_canvas_api());
    auto reference = render(false);
    auto candidate = render(true);
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
    std::cout << "GPU canvas matches per-leaf replay within " << max_error << " levels ("
        << differing << " channels differ); outside pixels, CPU paint order and shared recordings preserved\n";
}
