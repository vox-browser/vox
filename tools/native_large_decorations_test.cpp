#define VOX_TEST_DEFERRED_DECORATIONS
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <iostream>

static std::vector<uint8_t> render(bool optimized, int scale, float scroll, int alpha, bool msaa)
{
    constexpr int lw = 1024, lh = 768;
    int width = lw * scale, height = lh * scale, pitch = width * 4 + 16;
    std::vector<uint8_t> pixels(size_t(pitch) * height, 0xa5);
    for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x) {
        auto* p = pixels.data() + size_t(y) * pitch + x * 4;
        p[0] = 31 + x % 97; p[1] = 43 + y % 83; p[2] = 71; p[3] = 255;
    }
    auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = CGBitmapContextCreate(pixels.data(), width, height, 8, pitch, space,
        CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space); assert(context); CGContextScaleCTM(context, scale, scale);
    if (optimized) {
        unsetenv("VOX_DISABLE_LARGE_DECORATION_BATCH");
        unsetenv("VOX_DISABLE_SHARED_DECORATION_PIXELS");
    } else {
        setenv("VOX_DISABLE_LARGE_DECORATION_BATCH", "1", 1);
        setenv("VOX_DISABLE_SHARED_DECORATION_PIXELS", "1", 1);
    }
    ladybird_v_skia_set_chromium_painting(1);
    ladybird_v_skia_set_raster_layer(0, 0, 1);
    ladybird_v_skia_set_raster_layer_size(lw, 2048);
    ladybird_v_skia_set_root_raster_scroll_y(scroll);
    int cells[] {0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20};
    ladybird_v_skia_set_msaa_grid(cells, msaa ? 11 : 0, 544, 256, scale * 2);
    ladybird_v_skia_set_shared_recording(0, lw, lh);
    assert(ladybird_v_skia_begin_deferred_inset_decorations(context, 0, 0, lw, lh, lw, lh, 0, 0));
    for (int fill : {1, 0}) {
        assert(ladybird_v_skia_draw_rounded_rect(context, 16.25, 32.5, 991.5, 1450.75,
            13, 13, 17, 17, 19, 19, 23, 23, 1, 0, 0, 1, 0, -scroll,
            0, 0, 0, lw, lh, 71, 113, 197, alpha, fill, 1.5, 1, 1));
    }
    assert(ladybird_v_skia_end_deferred_inset_decorations(context));
    CGContextFlush(context); CGContextRelease(context);
    ladybird_v_skia_set_msaa_grid(nullptr, 0, 0, 0, 0);
    ladybird_v_skia_set_chromium_painting(0);
    for (int y = 0; y < height; ++y) for (int x = width * 4; x < pitch; ++x)
        assert(pixels[size_t(y) * pitch + x] == 0xa5);
    assert(!s_shared_picture_pixels.live_bytes());
    return pixels;
}
int main()
{
    unsigned checks = 0;
    for (int scale : {1, 2}) for (float scroll : {0.f, 37.5f, 240.f})
    for (int alpha : {128, 255}) for (bool msaa : {false, true}) {
        auto expected = render(false, scale, scroll, alpha, msaa);
        auto actual = render(true, scale, scroll, alpha, msaa);
        assert(expected == actual); ++checks;
    }
    std::cout << checks << " large decoration scenes preserve all pixels, row padding, mixed MSAA, scroll phase and lease cleanup\n";
}
