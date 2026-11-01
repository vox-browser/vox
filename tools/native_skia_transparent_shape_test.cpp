#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <cstdio>

int main()
{
    auto path = std::getenv("VOX_SKIA_REFERENCE_LIBRARY");
    assert(path && *path);
    auto library = dlopen(path, RTLD_NOW | RTLD_LOCAL);
    assert(library && graphite_shape_region_draw());
    auto reference = reinterpret_cast<decltype(&ladybird_v_skia_draw_rounded_rect)>(dlsym(library, "ladybird_v_skia_draw_rounded_rect"));
    auto mode = reinterpret_cast<decltype(&ladybird_v_skia_set_chromium_painting)>(dlsym(library, "ladybird_v_skia_set_chromium_painting"));
    auto grid = reinterpret_cast<decltype(&ladybird_v_skia_set_msaa_grid)>(dlsym(library, "ladybird_v_skia_set_msaa_grid"));
    auto layer = reinterpret_cast<decltype(&ladybird_v_skia_set_raster_layer)>(dlsym(library, "ladybird_v_skia_set_raster_layer"));
    auto size = reinterpret_cast<decltype(&ladybird_v_skia_set_raster_layer_size)>(dlsym(library, "ladybird_v_skia_set_raster_layer_size"));
    assert(reference && mode && grid && layer && size);
    int cases = 0;
    for (int scale : {1, 2}) for (int clip : {0, 1, 2}) for (int msaa : {0, 1, 2})
    for (float fraction : {.1f, .99999f}) for (int origin : {0, 1})
    for (int background : {0, 1}) for (int fill : {0, 1})
    for (int root : {0, 1}) for (float quartz_alpha : {.5f, 1.f})
    for (int underlay : {0, 1}) for (int vertical : {0, 1}) {
        int alpha = 0;
        int width = 320 * scale, height = 240 * scale, pitch = width * 4 + 16;
        std::vector<uint8_t> expected(size_t(pitch) * height);
        for (size_t i = 0; i < expected.size() / 4; ++i) {
            uint8_t alpha = background ? uint8_t(i * 13) : 255;
            expected[i * 4] = alpha / 2; expected[i * 4 + 1] = alpha / 3;
            expected[i * 4 + 2] = alpha / 5; expected[i * 4 + 3] = alpha;
        }
        auto actual = expected;
        auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        auto make = [&](auto& pixels) {
            auto context = CGBitmapContextCreate(pixels.data(), width, height, 8, pitch, space,
                CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
            assert(context); CGContextScaleCTM(context, scale, scale);
            CGContextSetAlpha(context, quartz_alpha);
            if (clip == 1) CGContextClipToRect(context, CGRectMake(17.25, 19.5, 217.75, 153.25));
            if (clip == 2) {
                CGContextAddEllipseInRect(context, CGRectMake(12.5, 8.25, 261.75, 197.5));
                CGContextClip(context);
            }
            return context;
        };
        auto before = make(expected), after = make(actual); CGColorSpaceRelease(space);
        mode(1); ladybird_v_skia_set_chromium_painting(1);
        layer(origin ? .25 : 0, origin ? .75 : 0, root);
        ladybird_v_skia_set_raster_layer(origin ? .25 : 0, origin ? .75 : 0, root);
        size(320, 240); ladybird_v_skia_set_raster_layer_size(320, 240);
        int mixed[] {0, 2, 4, 8}, all[] {0, 1, 2, 3, 4, 5, 6, 7, 8};
        auto tiles = msaa == 2 ? all : mixed;
        int count = msaa == 0 ? 0 : msaa == 1 ? 4 : 9;
        grid(tiles, count, 128 * scale + 2, 96 * scale + 2, 3);
        ladybird_v_skia_set_msaa_grid(tiles, count, 128 * scale + 2, 96 * scale + 2, 3);
        auto draw = [&](auto context, auto function) {
            if (underlay) {
                float rect[] {float((vertical ? 308 : 7) + fraction), float((vertical ? 7 : 214) + fraction),
                    vertical ? 6.125f : 280.25f, vertical ? 180.25f : 6.125f, 3, 3, 3, 3, 3, 3, 3, 3};
                auto set = function == reference
                    ? reinterpret_cast<decltype(&ladybird_v_skia_set_rounded_rect_underlay)>(dlsym(library, "ladybird_v_skia_set_rounded_rect_underlay"))
                    : &ladybird_v_skia_set_rounded_rect_underlay;
                assert(set); set(rect, 71, 97, 131, 173);
            }
            return function(context, (vertical ? 308 : 7) + fraction,
                (vertical ? 7 : 214) + fraction, vertical ? 6.125 : 280.25, vertical ? 180.25 : 6.125,
                3, 3, 3, 3, 3, 3, 3, 3, 1, 0, 0, 1, 0, 0,
                0, 0, 0, 320, 240, 37, 83, 197, alpha, fill, 1.25, 1, 1);
        };
        assert(draw(before, reference));
        assert(draw(after, &ladybird_v_skia_draw_rounded_rect));
        CGContextFlush(before); CGContextFlush(after);
        if (expected != actual) {
            std::fprintf(stderr, "layer shape differs scale=%d clip=%d msaa=%d fraction=%g origin=%d background=%d fill=%d root=%d quartz_alpha=%g underlay=%d vertical=%d\n",
                scale, clip, msaa, fraction, origin, background, fill, root, quartz_alpha, underlay, vertical);
            return 1;
        }
        CGContextRelease(before); CGContextRelease(after);
        ladybird_v_skia_set_chromium_painting(0); mode(0);
        ++cases;
    }
    ladybird_v_skia_set_chromium_painting(0); mode(0);
    std::printf("Transparent shape replay: %d exact native comparisons\n", cases);
}
