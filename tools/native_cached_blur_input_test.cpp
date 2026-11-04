#define VOX_TEST_CACHED_BLUR_INPUT
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <iostream>

// vlang.io's `.showcase::before` glow: one radial gradient under blur(30px).
// Once the blurred output is cached for its content identity, the gradient
// leaf records its input but skips rasterizing it into the filter layer. The
// composite stays identical; a failed native blur replays the input instead.
static constexpr int css_width = 400, css_height = 300;

static std::vector<uint8_t> canvas_pixels(float scale, bool opaque)
{
    int width = css_width * scale, height = css_height * scale;
    std::vector<uint8_t> pixels(size_t(width) * height * 4, 0);
    if (opaque) for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x) {
        auto* p = pixels.data() + (size_t(y) * width + x) * 4;
        p[0] = uint8_t(17 + ((x * 3 + y * 5) & 31)); p[1] = uint8_t(23 + (y & 63));
        p[2] = 40; p[3] = 255;
    }
    return pixels;
}

static CGContextRef context_for(std::vector<uint8_t>& pixels, float scale)
{
    auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = CGBitmapContextCreate(pixels.data(), css_width * scale, css_height * scale, 8,
        css_width * scale * 4, color, static_cast<CGBitmapInfo>(kCGImageAlphaPremultipliedLast)
            | static_cast<CGBitmapInfo>(kCGBitmapByteOrder32Big));
    CGColorSpaceRelease(color); assert(context);
    CGContextScaleCTM(context, scale, scale);
    return context;
}

struct Frame { std::vector<uint8_t> output, layer; int deferred, ended; };

static Frame frame(float scale, uint64_t key, bool fail = false)
{
    auto output = canvas_pixels(scale, true), layer = canvas_pixels(scale, false);
    auto destination = context_for(output, scale), offscreen = context_for(layer, scale);
    ladybird_v_skia_set_chromium_painting(1);
    ladybird_v_skia_set_raster_layer(0, 0, 1);
    assert(ladybird_v_skia_begin_isolated_input(offscreen, css_width, css_height));
    ladybird_v_skia_set_isolated_input_key(offscreen, key);
    int deferred = ladybird_v_skia_defer_cached_gradient_blur_input(offscreen);
    float x = 37, y = 61, w = 326, h = 171.5f;
    float path[60] {0, x, y};
    float points[][2] {{x + w, y}, {x + w, y + h}, {x, y + h}};
    for (int i = 0; i < 3; ++i) { path[12 * (i + 1)] = 1; path[12 * (i + 1) + 1] = points[i][0]; path[12 * (i + 1) + 2] = points[i][1]; }
    path[48] = 5;
    float sy = h / w, cx = x + w / 2, cy = y + h / 2;
    float stops[] {0x26 / 255.f, 0x3d / 255.f, 0x5d / 255.f, 0x28 / 255.f, 0,
        0x26 / 255.f, 0x3d / 255.f, 0x5d / 255.f, 0, .68f};
    float clip[12] {x, y, w, h, 0, 0, 0, 0, 0, 0, 0, 0};
    assert(ladybird_v_skia_draw_clipped_svg_radial_gradient_path(offscreen, path, 5, 0,
        1, 0, 0, 1, 0, 0, 0, 0, 0, css_width, css_height, 0, 0, 0, 0, 4,
        cx, cy * sy, 0, cx, cy * sy, w / 2, 1, 0, 0, sy, 0, cy - cy * sy, 4, 0, stops, 2, 1, 1,
        clip, nullptr));
    s_test_fail_gradient_blur_end = fail;
    int ended = ladybird_v_skia_end_css_gradient_blur(offscreen, destination, css_width,
        css_height, scale, 15);
    s_test_fail_gradient_blur_end = false;
    CGContextFlush(destination); CGContextFlush(offscreen);
    CGContextRelease(destination); CGContextRelease(offscreen);
    return {output, layer, deferred, ended};
}

static bool empty(std::vector<uint8_t> const& pixels)
{
    return std::all_of(pixels.begin(), pixels.end(), [](uint8_t value) { return value == 0; });
}

int main()
{
    assert(picture_region_draw());
    unsigned cases = 0;
    for (float scale : {1.f, 2.f}) {
        uint64_t key = 0x5eed0000 + uint64_t(scale);
        auto first = frame(scale, key);
        assert(!first.deferred && first.ended && !empty(first.layer));
        auto cached = frame(scale, key);
        assert(cached.deferred && cached.ended);
        assert(empty(cached.layer));           // No leaf raster into the layer.
        assert(cached.output == first.output); // Identical composite.
        // Without an identity, or for another one, the leaf rasterizes.
        auto plain = frame(scale, 0);
        assert(!plain.deferred && !empty(plain.layer) && plain.output == first.output);
        assert(!frame(scale, key + 99).deferred);
        // A failed blur replays the recorded input into the layer.
        auto failed = frame(scale, key, true);
        assert(failed.deferred && !failed.ended && !empty(failed.layer));
        size_t differing = 0, worst = 0;
        for (size_t i = 0; i < failed.layer.size(); ++i) {
            int difference = std::abs(int(failed.layer[i]) - int(first.layer[i]));
            if (difference) { ++differing; worst = std::max(worst, size_t(difference)); }
        }
        std::cout << "scale " << scale << ": replayed input differs from leaf raster in "
            << differing << " bytes (max " << worst << ")\n";
        assert(worst <= 2);
        cases += 5;
    }
    setenv("VOX_DISABLE_CACHED_BLUR_INPUT_DEFERRAL", "1", 1);
    assert(!frame(2, 0x5eed0002).deferred);
    ++cases;
    std::cout << cases << " cached blur input cases pass\n";
}
