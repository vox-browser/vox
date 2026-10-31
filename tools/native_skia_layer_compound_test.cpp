// Compare the real bridge's fallback with independently assembled GPU tiles.
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <cstdio>

int main()
{
    auto draw = graphite_shape_draw();
    assert(draw);
    void* library = nullptr;
    if (auto path = std::getenv("VOX_SKIA_LAYER_REFERENCE_LIBRARY")) {
        library = dlopen(path, RTLD_NOW | RTLD_LOCAL);
        assert(library);
    }
    auto resolve = [&]<typename T>(char const* name, T implementation) {
        auto result = library ? reinterpret_cast<T>(dlsym(library, name)) : implementation;
        assert(result); return result;
    };
    auto set_chromium_painting = resolve("ladybird_v_skia_set_chromium_painting", &ladybird_v_skia_set_chromium_painting);
    auto set_shared_recording = resolve("ladybird_v_skia_set_shared_recording", &ladybird_v_skia_set_shared_recording);
    auto set_raster_layer = resolve("ladybird_v_skia_set_raster_layer", &ladybird_v_skia_set_raster_layer);
    auto set_raster_layer_size = resolve("ladybird_v_skia_set_raster_layer_size", &ladybird_v_skia_set_raster_layer_size);
    auto set_msaa_grid = resolve("ladybird_v_skia_set_msaa_grid", &ladybird_v_skia_set_msaa_grid);
    auto set_rounded_rect_underlay = resolve("ladybird_v_skia_set_rounded_rect_underlay", &ladybird_v_skia_set_rounded_rect_underlay);
    auto set_unrounded_paint_color = resolve("ladybird_v_skia_set_unrounded_paint_color", &ladybird_v_skia_set_unrounded_paint_color);
    auto draw_rounded_rect = resolve("ladybird_v_skia_draw_rounded_rect", &ladybird_v_skia_draw_rounded_rect);
    int cases = 0;
    for (int scale : {1, 2}) for (int backdrop_alpha : {0, 255})
    for (int underlay_alpha : {127, 255}) for (int mode : {0, 1, 2})
    for (bool paired : {true, false}) for (bool fractional_extent : {false, true}) {
        if (!paired && underlay_alpha != 255) continue;
        constexpr int width = 1024, height = 852, x = 700, y = 80, page_y = 60;
        constexpr int layer_width = 300, layer_height = 1040;
        int pw = width * scale, ph = height * scale, pitch = pw * 4;
        std::vector<uint8_t> actual(size_t(pitch) * ph);
        for (size_t i = 0; i < actual.size(); i += 4) {
            actual[i] = backdrop_alpha ? 250 : 0;
            actual[i + 1] = backdrop_alpha ? 245 : 0;
            actual[i + 2] = backdrop_alpha ? 240 : 0;
            actual[i + 3] = backdrop_alpha;
        }
        auto expected = actual;
        auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        auto make = [&](auto& pixels) {
            auto context = CGBitmapContextCreate(pixels.data(), pw, ph, 8, pitch, color,
                CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
            assert(context); CGContextScaleCTM(context, scale, scale); return context;
        };
        auto destination = make(actual), control = make(expected);
        CGColorSpaceRelease(color);
        int tw = 320 * scale, th = 416 * scale, step = th - 2;
        std::vector<int> msaa = mode == 0 ? std::vector<int>{0}
            : mode == 1 ? std::vector<int>{1} : std::vector<int>{0, 1, 2};
        set_chromium_painting(1);
        set_shared_recording(0, width, height);
        set_raster_layer(x, y, 0);
        set_raster_layer_size(fractional_extent ? 299.9 : layer_width, layer_height);
        set_msaa_grid(msaa.data(), int(msaa.size()), tw, th, 1);
        float rect[] {x + .5f, y + 296.5f, 299, 364, 5.5f, 5.5f, 5.5f, 5.5f,
            5.5f, 5.5f, 5.5f, 5.5f};
        if (!paired) { rect[0] = x + 220; rect[1] = y + 28; rect[2] = 80; rect[3] = 34; }
        if (fractional_extent) rect[0] += 1;
        float rgba[] {.958f, .823133349f, .482f, 1};
        set_rounded_rect_underlay(paired ? rect : nullptr, 253, 247, 231, underlay_alpha);
        set_unrounded_paint_color(rgba);
        assert(draw_rounded_rect(destination, rect[0], rect[1], rect[2], rect[3],
            5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 1, 0, 0, 1, 0, 0,
            0, page_y, 0, width, height, 244, 210, 123, 255, paired ? 0 : 1, 1, 1, 1));

        for (int row = 0; row * step < layer_height * scale; ++row) {
            std::vector<uint32_t> pixels(size_t(tw) * th);
            for (auto& pixel : pixels)
                pixel = backdrop_alpha ? 0xFFFAF5F0U : 0;
            VoxGraphiteShape shape {};
            float matrix[] {float(scale), 0, float(-x * scale), 0, float(scale),
                float(-y * scale - row * step), 0, 0, 1};
            std::copy_n(matrix, 9, shape.matrix);
            std::copy_n(rect, 12, shape.rect);
            std::copy_n(rect, 12, shape.underlay_rect);
            shape.red = 244; shape.green = 210; shape.blue = 123; shape.alpha = 255;
            shape.thickness = 1; shape.anti_alias = 1;
            shape.force_msaa = std::binary_search(msaa.begin(), msaa.end(), row);
            shape.fill = paired ? 0 : 1;
            shape.has_underlay = paired;
            shape.has_float_color = 1;
            std::copy_n(rgba, 4, shape.float_color);
            uint8_t underlay[] {253, 247, 231, uint8_t(underlay_alpha)};
            std::copy_n(underlay, 4, shape.underlay_rgba);
            assert(draw(reinterpret_cast<uint8_t*>(pixels.data()), tw, th, tw * 4, 1, &shape));
            float top = y + page_y + float(row * step) / scale;
            float owned_top = top + (row ? 1.f / scale : 0);
            float bottom = std::min(float(height), top + float(th - 1) / scale);
            if (owned_top >= bottom) continue;
            CGContextSaveGState(control);
            CGContextClipToRect(control, CGRectMake(x, height - bottom,
                fractional_extent ? 301 : layer_width, bottom - owned_top));
            assert(composite_pixels(control, std::move(pixels), tw, th, x,
                height - top - float(th) / scale, float(tw) / scale, float(th) / scale, true));
            CGContextRestoreGState(control);
        }
        CGContextFlush(destination); CGContextFlush(control);
        if (actual != expected) {
            size_t count = 0;
            for (size_t i = 0; i < actual.size(); ++i) if (actual[i] != expected[i]) {
                if (count++ < 8) std::fprintf(stderr, "Mismatch at %zu,%zu channel=%zu actual=%u expected=%u\n",
                    i / 4 % pw, i / 4 / pw, i % 4, actual[i], expected[i]);
            }
            std::fprintf(stderr, "scale=%d backdrop=%d underlay=%d mode=%d paired=%d fractional=%d differing bytes=%zu\n",
                scale, backdrop_alpha, underlay_alpha, mode, paired, fractional_extent, count);
            return 1;
        }
        CGContextRelease(destination); CGContextRelease(control);
        set_chromium_painting(0);
        ++cases;
    }
    std::printf("PASS: %d rounded layer draws match complete GPU tiles at both scales\n", cases);
}
