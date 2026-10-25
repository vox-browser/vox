// Compare the bridge's single-pass solid fallback with the previous bridge's
// two MSAA passes, including translucent backdrops and non-rectangular clips.
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <iostream>

int main()
{
    auto path = std::getenv("VOX_SKIA_REFERENCE_LIBRARY");
    assert(path);
    auto library = dlopen(path, RTLD_NOW | RTLD_LOCAL);
    assert(library);
    auto reference = reinterpret_cast<decltype(&ladybird_v_skia_draw_rounded_rect)>(
        dlsym(library, "ladybird_v_skia_draw_rounded_rect"));
    auto mode = reinterpret_cast<decltype(&ladybird_v_skia_set_chromium_painting)>(
        dlsym(library, "ladybird_v_skia_set_chromium_painting"));
    auto grid = reinterpret_cast<decltype(&ladybird_v_skia_set_msaa_grid)>(
        dlsym(library, "ladybird_v_skia_set_msaa_grid"));
    auto color = reinterpret_cast<decltype(&ladybird_v_skia_set_unrounded_paint_color)>(
        dlsym(library, "ladybird_v_skia_set_unrounded_paint_color"));
    assert(reference && mode && grid && color && graphite_shape_draw());
    int comparisons = 0;
    for (int scale : {1, 2}) for (int clip : {0, 1, 2})
    for (int background : {0, 1}) for (int fill : {0, 1})
    for (float offset : {0.f, .25f, .5f, -32.f})
    for (float scroll : {0.f, .25f})
    for (int float_color : {0, 1, 2}) for (int alpha : {128, 255})
    for (int radius : {0, 4}) {
        int width = 160 * scale, height = 120 * scale, pitch = width * 4 + 16;
        std::vector<uint8_t> expected(size_t(pitch) * height);
        for (size_t i = 0; i < expected.size(); ++i)
            expected[i] = i % 4 == 3 ? 127 : uint8_t(i * 17 % 128);
        auto actual = expected;
        auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        auto context = [&](auto& pixels) {
            auto result = CGBitmapContextCreate(pixels.data(), width, height, 8, pitch, space,
                CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
            assert(result);
            CGContextScaleCTM(result, scale, scale);
            if (clip == 1) CGContextClipToRect(result, CGRectMake(12.25, 24.5, 94.75, 67.25));
            if (clip == 2) {
                CGContextAddEllipseInRect(result, CGRectMake(5.25, 9.5, 129.75, 89.25));
                CGContextClip(result);
            }
            return result;
        };
        auto before = context(expected), after = context(actual);
        CGColorSpaceRelease(space);
        int tiles[] {0, 2, 4, 8};
        auto byte_color = SkColor4f::FromColor(SkColorSetARGB(alpha, 197, 37, 83));
        float rgba[4]; std::copy_n(byte_color.vec(), 4, rgba);
        if (float_color == 2) rgba[0] = std::nextafter(rgba[0], 0.f);
        auto draw = [&](CGContextRef destination, bool control) {
            (control ? mode : &ladybird_v_skia_set_chromium_painting)(1);
            (control ? grid : &ladybird_v_skia_set_msaa_grid)(tiles, 4, 66 * scale, 50 * scale, 3);
            (control ? color : &ladybird_v_skia_set_unrounded_paint_color)(float_color ? rgba : nullptr);
            // Unreadable/transparent backdrops cannot use root-tile replay.
            // Integer fills and half-pixel strokes exercise the solid path;
            // fractional edges, rounded corners and float colors keep their
            // original coverage and blending behavior.
            float edge = fill ? 8.f : 8.5f;
            return (control ? reference : &ladybird_v_skia_draw_rounded_rect)(destination,
                edge + offset, edge + offset, 120, 96,
                radius, radius, radius, radius, radius, radius, radius, radius,
                1, 0, 0, 1, 0, 0, 0, 0, scroll, 160, 120,
                197, 37, 83, alpha, fill, 1, 1, background);
        };
        assert(draw(before, true) && draw(after, false));
        CGContextFlush(before); CGContextFlush(after);
        if (expected != actual) {
            std::cerr << "Solid replay mismatch scale=" << scale << " clip=" << clip
                << " background=" << background << " fill=" << fill << " offset=" << offset
                << " scroll=" << scroll << " float_color=" << float_color << " alpha=" << alpha << " radius=" << radius << '\n';
            return 1;
        }
        ++comparisons;
        CGContextRelease(before); CGContextRelease(after);
    }
    ladybird_v_skia_set_chromium_painting(0);
    mode(0);
    std::cout << "Solid replay: " << comparisons << " exact GPU comparisons passed\n";
}
