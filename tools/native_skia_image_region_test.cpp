// Root-grid image crops must match full-tile replay, including tile seams,
// fractional scrolling, Retina rendering and destination clips.
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <cstdio>

int main()
{
    auto path = std::getenv("VOX_SKIA_REFERENCE_LIBRARY");
    assert(path);
    auto library = dlopen(path, RTLD_NOW | RTLD_LOCAL);
    assert(library);
    auto reference = reinterpret_cast<decltype(&ladybird_v_skia_draw_rgba_image)>(
        dlsym(library, "ladybird_v_skia_draw_rgba_image"));
    auto mode = reinterpret_cast<decltype(&ladybird_v_skia_set_chromium_painting)>(
        dlsym(library, "ladybird_v_skia_set_chromium_painting"));
    auto grid = reinterpret_cast<decltype(&ladybird_v_skia_set_msaa_grid)>(
        dlsym(library, "ladybird_v_skia_set_msaa_grid"));
    auto layer = reinterpret_cast<decltype(&ladybird_v_skia_set_raster_layer)>(
        dlsym(library, "ladybird_v_skia_set_raster_layer"));
    auto size = reinterpret_cast<decltype(&ladybird_v_skia_set_raster_layer_size)>(
        dlsym(library, "ladybird_v_skia_set_raster_layer_size"));
    auto root_scroll = reinterpret_cast<decltype(&ladybird_v_skia_set_root_raster_scroll_y)>(
        dlsym(library, "ladybird_v_skia_set_root_raster_scroll_y"));
    assert(reference && mode && grid && layer && size && root_scroll && graphite_image_region_draw());
    int comparisons = 0;
    for (int scale : {1, 2}) for (int clip : {0, 1, 2})
    for (int backdrop : {0, 2}) for (int root : {0, 1})
    for (float offset : {0.f, .375f, -32.f})
    for (float scroll : {0.f, 3.75f}) for (int nearest : {0, 1}) {
        int width = 160 * scale, height = 120 * scale, pitch = width * 4 + 16;
        std::vector<uint8_t> expected(size_t(pitch) * height);
        for (size_t i = 0; i < expected.size(); ++i)
            expected[i] = i % 4 == 3 ? 255 : uint8_t(i * 17);
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
        std::vector<uint8_t> source(37 * 29 * 4);
        for (size_t i = 0; i < source.size(); ++i) source[i] = uint8_t(i * 37 + i / 11);
        int tiles[] {0, 2, 4, 8};
        float radii[] {4, 4, 7, 7, 3, 3, 0, 0};
        for (int pass : {0, 1, 2}) {
            if (pass == 2) source.back() ^= 1;
            auto draw = [&](CGContextRef destination, bool control) {
                (control ? mode : &ladybird_v_skia_set_chromium_painting)(1);
                (control ? grid : &ladybird_v_skia_set_msaa_grid)(tiles, 4, 66 * scale, 50 * scale, 3);
                (control ? layer : &ladybird_v_skia_set_raster_layer)(0, 0, root);
                (control ? size : &ladybird_v_skia_set_raster_layer_size)(160, 120);
                (control ? root_scroll : &ladybird_v_skia_set_root_raster_scroll_y)(scroll);
                return (control ? reference : &ladybird_v_skia_draw_rgba_image)(destination,
                    source.data(), 37, 29, 37 * 4, 8 + offset, 8 + offset, 120, 96,
                    2, 3, 31, 23, 8 + offset, 8 + offset, 120, 96,
                    1, 0, 0, 1, 0, 0, 0, 0, scroll, 160, 120,
                    .8f, nearest, backdrop, clip == 2 ? radii : nullptr);
            };
            assert(draw(before, true) && draw(after, false));
            CGContextFlush(before); CGContextFlush(after);
            if (expected != actual) {
                std::fprintf(stderr, "Image grid mismatch scale=%d clip=%d backdrop=%d root=%d offset=%g scroll=%g nearest=%d pass=%d\n",
                    scale, clip, backdrop, root, offset, scroll, nearest, pass);
                return 1;
            }
            ++comparisons;
        }
        CGContextRelease(before); CGContextRelease(after);
    }
    ladybird_v_skia_set_chromium_painting(0); mode(0);
    std::printf("Image grid: %d exact native comparisons passed\n", comparisons);
}
