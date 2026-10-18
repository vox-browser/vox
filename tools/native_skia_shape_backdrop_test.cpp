// Native shape replay against an earlier bridge, or against an uncached draw
// with a harmless distant clip-out that keeps the full backdrop dependency.
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <iostream>

int main()
{
    auto reference = &ladybird_v_skia_draw_rounded_rect;
    auto reference_mode = &ladybird_v_skia_set_chromium_painting;
    auto reference_clips = &ladybird_v_skia_set_rect_clip_outs;
    auto reference_tiles = &ladybird_v_skia_set_msaa_tiles;
    if (auto path = std::getenv("VOX_SKIA_REFERENCE_LIBRARY")) {
        auto library = dlopen(path, RTLD_NOW | RTLD_LOCAL);
        assert(library);
        reference = reinterpret_cast<decltype(reference)>(dlsym(library, "ladybird_v_skia_draw_rounded_rect"));
        reference_mode = reinterpret_cast<decltype(reference_mode)>(dlsym(library, "ladybird_v_skia_set_chromium_painting"));
        reference_clips = reinterpret_cast<decltype(reference_clips)>(dlsym(library, "ladybird_v_skia_set_rect_clip_outs"));
        reference_tiles = reinterpret_cast<decltype(reference_tiles)>(dlsym(library, "ladybird_v_skia_set_msaa_tiles"));
        assert(reference && reference_mode && reference_clips && reference_tiles);
    }
    assert(graphite_shape_draw()); // Exercise the GPU path, including its readback.
    int comparisons = 0;
    for (int scale : {1, 2}) for (int clip : {0, 1, 2}) for (int radius : {0, 1, 2})
    for (int msaa : {0, 1, 2}) for (int fill : {0, 1}) for (int transform : {0, 1}) {
        int width = 160 * scale, height = 120 * scale, pitch = width * 4 + 16;
        std::vector<uint8_t> expected(size_t(pitch) * height), actual(expected.size());
        auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        auto make_context = [&](std::vector<uint8_t>& pixels) {
            auto context = CGBitmapContextCreate(pixels.data(), width, height, 8, pitch, color,
                static_cast<CGBitmapInfo>(kCGImageAlphaPremultipliedLast) | static_cast<CGBitmapInfo>(kCGBitmapByteOrder32Big));
            assert(context);
            CGContextScaleCTM(context, scale, scale);
            if (clip == 1) CGContextClipToRect(context, CGRectMake(20.25, 17.5, 111.75, 53.25));
            if (clip == 2) {
                CGContextAddEllipseInRect(context, CGRectMake(20.25, 17.5, 111.75, 53.25));
                CGContextClip(context);
            }
            return context;
        };
        auto before = make_context(expected), after = make_context(actual);
        CGColorSpaceRelease(color);
        for (int mutation = 0; mutation < 4; ++mutation) {
            for (size_t i = 0; i < expected.size(); ++i) {
                uint8_t a = (i / 4 * 13 + mutation * 31) % 256;
                expected[i] = i % 4 == 3 ? a : a / (i % 4 + 1);
            }
            actual = expected;
            auto draw = [&](CGContextRef context, decltype(reference) function, bool control) {
                int tiles[] {0, 2};
                float distant_clip[] {1000000, 1000000, 1000001, 1000001};
                auto mode = control ? reference_mode : &ladybird_v_skia_set_chromium_painting;
                auto clips = control ? reference_clips : &ladybird_v_skia_set_rect_clip_outs;
                auto set_tiles = control ? reference_tiles : &ladybird_v_skia_set_msaa_tiles;
                mode(1);
                clips(distant_clip, control && function == &ladybird_v_skia_draw_rounded_rect ? 1 : 0);
                set_tiles(tiles, msaa == 0 ? 0 : msaa == 1 ? 1 : 2, msaa == 1 ? 512 : 82);
                float r = radius ? 6.5f : 0;
                int result = function(context, 7.375, -13.25, 139.5, 118.75,
                    r, r, radius == 2 ? 19.25 : r, r, r, r, r, radius == 2 ? 17.5 : r,
                    1, transform ? .125 : 0, transform ? -.0625 : 0, 1, 0, 0,
                    0, 0, mutation * 7, 160, 120, 197, 37, 83,
                    mutation == 3 ? 128 : 255, fill, 2.25, 1, 1);
                clips(nullptr, 0);
                return result;
            };
            assert(draw(before, reference, true));
            assert(draw(after, &ladybird_v_skia_draw_rounded_rect, false));
            CGContextFlush(before); CGContextFlush(after);
            if (expected != actual) {
                std::cerr << "Shape backdrop mismatch scale=" << scale << " clip=" << clip
                    << " radius=" << radius << " msaa=" << msaa << " fill=" << fill
                    << " transform=" << transform << " mutation=" << mutation << '\n';
                return 1;
            }
            ++comparisons;
        }
        CGContextRelease(before); CGContextRelease(after);
    }
    ladybird_v_skia_set_chromium_painting(0);
    std::cout << "Native shape backdrop: " << comparisons << " exact GPU comparisons passed\n";
}
