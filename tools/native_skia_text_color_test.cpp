// Fractional glyph colors must survive both cold rasterization and cache hits.
#include "../native_skia_text_darwin.cpp"
#include <array>
#include <cassert>
#include <iostream>

int main()
{
    constexpr int width = 128, height = 96, pitch = width * 4;
    auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    std::vector<uint8_t> expected(pitch * height), actual(expected.size());
    auto make = [&](std::vector<uint8_t>& pixels) {
        auto context = CGBitmapContextCreate(pixels.data(), width, height, 8, pitch, space,
            static_cast<CGBitmapInfo>(kCGImageAlphaPremultipliedLast)
                | static_cast<CGBitmapInfo>(kCGBitmapByteOrder32Big));
        assert(context);
        return context;
    };
    auto control = make(expected), candidate = make(actual);
    CGColorSpaceRelease(space);
    uint16_t glyphs[] {36, 37, 38, 39, 40, 41};
    double positions[] {0, 0, 11.5, 0, 22, 0, 34.25, 0, 46, 0, 57.5, 0};
    auto draw = [&](CGContextRef context, std::vector<uint8_t>& pixels, float const* color, int policy) {
        for (size_t i = 0; i < pixels.size(); i += 4) {
            pixels[i] = pixels[i + 1] = pixels[i + 2] = 254;
            pixels[i + 3] = 255;
        }
        ladybird_v_skia_set_unrounded_paint_color(color);
        assert(ladybird_v_skia_draw_glyph_run(context, "/System/Library/Fonts/HelveticaNeue.ttc",
            0, glyphs, positions, 6, 16, 400, 0, 15.375, 46.25,
            1, 0, 0, 1, 0, 0, 0, 0, 0, width, height, 0, 0, 0, 150, policy));
        assert(!s_has_unrounded_paint_color);
        CGContextFlush(context);
    };
    std::array<float, 4> colors[] {{0, 0, 0, .5883f}, {0, 0, 0, .5901f},
        {10.5f / 255, 20.25f / 255, 30.75f / 255, .59f}};
    GlyphRasterCache warm;
    int comparisons = 0;
    std::vector<uint8_t> first;
    // Policy 48 exercises Chromium's GPU path when present; 32 keeps the
    // float CPU fallback covered independently, including a populated cache.
    for (int policy : {48, 32}) {
        for (auto const& color : colors) {
            for (int repeat = 0; repeat < 2; ++repeat) {
                s_glyph_raster_cache.clear();
                draw(control, expected, color.data(), policy);
                std::swap(s_glyph_raster_cache, warm);
                draw(candidate, actual, color.data(), policy);
                std::swap(s_glyph_raster_cache, warm);
                assert(expected == actual);
                if (comparisons % 7 == 0) first = expected;
                if (comparisons % 7 == 2) assert(first != expected);
                ++comparisons;
            }
        }
        s_glyph_raster_cache.clear();
        draw(control, expected, nullptr, policy);
        std::swap(s_glyph_raster_cache, warm);
        draw(candidate, actual, nullptr, policy);
        std::swap(s_glyph_raster_cache, warm);
        assert(expected == actual);
        ++comparisons;
    }
    CGContextRelease(control);
    CGContextRelease(candidate);
    std::cout << comparisons << " GPU/CPU fractional/byte glyph cache comparisons passed\n";
}
