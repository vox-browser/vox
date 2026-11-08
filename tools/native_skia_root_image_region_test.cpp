// Root image readback keeps full-tile interpolation and MSAA while transferring
// only the native clip. Compare complete published buffers with full replay.
#include "include/private/base/SkASAN.h"
#undef SK_SANITIZE_ADDRESS
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <iostream>

int main()
{
    assert(graphite_image_region_draw());
    int comparisons = 0;
    for (int scale : {1, 2}) for (float zoom : {1.f, 1.25f, 1.75f})
    for (bool nearest : {false, true}) for (bool msaa : {false, true})
    for (int clip : {0, 1, 2, 3}) for (float scroll : {0.f, 4.5f, 39.f})
    for (int format : {0, 1, 4, 12, 28, 12 | VOX_GRAPHITE_IMAGE_YUV422}) {
        constexpr int cw = 180, ch = 160, iw = 41, ih = 29;
        int w = cw * scale, h = ch * scale, pitch = w * 4 + 16;
        std::vector<uint8_t> source((iw * 4 + 8) * ih);
        for (size_t i = 0; i < source.size(); ++i) source[i] = uint8_t(i * 37 + i / 11);
        if (format & 1) for (int y = 0; y < ih; ++y) for (int x = 0; x < iw; ++x) {
            auto* p = source.data() + size_t(y) * (iw * 4 + 8) + x * 4;
            for (int c = 0; c < 3; ++c) p[c] = p[c] * p[3] / 255;
        }
        std::vector<uint8_t> expected(size_t(pitch) * h), actual(expected.size());
        for (size_t i = 0; i < expected.size(); ++i)
            expected[i] = i % 4 == 3 ? 255 : uint8_t(i * 17);
        actual = expected;
        auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        auto make_context = [&](auto& bytes) {
            auto c = CGBitmapContextCreate(bytes.data(), w, h, 8, pitch, space,
                CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
            assert(c);
            CGContextScaleCTM(c, scale, scale);
            if (clip == 1) CGContextClipToRect(c, CGRectMake(0, ch - 83, cw, 3));
            if (clip == 2) CGContextClipToRect(c, CGRectMake(23.25, ch - 92.75, 81.5, 14.25));
            if (clip == 3) {
                CGContextAddEllipseInRect(c, CGRectMake(9.25, ch - 107, 140.5, 75.25));
                CGContextClip(c);
            }
            return c;
        };
        auto before = make_context(expected), after = make_context(actual);
        CGColorSpaceRelease(space);
        ladybird_v_skia_set_chromium_painting(1);
        ladybird_v_skia_set_shared_recording(0, cw, ch);
        ladybird_v_skia_set_raster_layer(0, 0, 1);
        ladybird_v_skia_set_msaa_grid(nullptr, 0, 0, 0, 0);
        ladybird_v_skia_set_root_raster_scroll_y(scroll);
        int selected[] {0, 2, 4, 6};
        ladybird_v_skia_set_msaa_tiles(selected, msaa ? 4 : 0, 64 * scale);
        auto draw = [&](CGContextRef c) {
            assert(ladybird_v_skia_draw_rgba_image(c, source.data(), iw, ih, iw * 4 + 8,
                8.25, 20.5, 123.5, 111.25, 0, 0, iw, ih,
                8.25, 20.5, 123.5, 111.25, zoom, 0, 0, zoom, 0, -scroll,
                0, 0, 0, cw, ch, .8, nearest, format | 2, nullptr));
            CGContextFlush(c);
        };
        setenv("VOX_DISABLE_ROOT_IMAGE_REGION", "1", 1);
        draw(before);
        unsetenv("VOX_DISABLE_ROOT_IMAGE_REGION");
        draw(after);
        if (expected != actual) {
            std::cerr << "Root image region mismatch scale=" << scale << " zoom=" << zoom
                << " nearest=" << nearest << " msaa=" << msaa << " clip=" << clip
                << " scroll=" << scroll << '\n';
            return 1;
        }
        CGContextRelease(before); CGContextRelease(after);
        ++comparisons;
    }
    std::cout << "Root image regions: " << comparisons << " exact complete-buffer comparisons passed\n";
}
