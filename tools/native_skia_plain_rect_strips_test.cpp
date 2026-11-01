#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <cstdio>

int main()
{
    auto path = std::getenv("VOX_SKIA_REFERENCE_LIBRARY");
    assert(path && *path);
    auto library = dlopen(path, RTLD_NOW | RTLD_LOCAL);
    assert(library && graphite_rounded_parts_draw());
    auto reference = reinterpret_cast<decltype(&ladybird_v_skia_draw_rounded_rect)>(dlsym(library, "ladybird_v_skia_draw_rounded_rect"));
    auto mode = reinterpret_cast<decltype(&ladybird_v_skia_set_chromium_painting)>(dlsym(library, "ladybird_v_skia_set_chromium_painting"));
    auto grid = reinterpret_cast<decltype(&ladybird_v_skia_set_msaa_grid)>(dlsym(library, "ladybird_v_skia_set_msaa_grid"));
    auto layer = reinterpret_cast<decltype(&ladybird_v_skia_set_raster_layer)>(dlsym(library, "ladybird_v_skia_set_raster_layer"));
    auto size = reinterpret_cast<decltype(&ladybird_v_skia_set_raster_layer_size)>(dlsym(library, "ladybird_v_skia_set_raster_layer_size"));
    assert(reference && mode && grid && layer && size);
    int cases = 0;
    for (int scale : {1, 2}) for (int clip : {0, 1, 2}) for (int msaa : {0, 1, 2})
    for (float fraction : {0.f, .1f, .5f, .99999f}) for (int offset : {0, 1})
    for (int background : {0, 1}) for (int fill : {0, 1}) {
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
            if (clip == 1) CGContextClipToRect(context, CGRectMake(17.25, 19.5, 217.75, 153.25));
            if (clip == 2) {
                CGContextAddEllipseInRect(context, CGRectMake(12.5, 8.25, 261.75, 197.5));
                CGContextClip(context);
            }
            return context;
        };
        auto before = make(expected), after = make(actual); CGColorSpaceRelease(space);
        mode(1); ladybird_v_skia_set_chromium_painting(1);
        layer(0, 0, 1); ladybird_v_skia_set_raster_layer(0, 0, 1);
        size(320, 240); ladybird_v_skia_set_raster_layer_size(320, 240);
        int mixed[] {0, 2, 4, 8}, all[] {0, 1, 2, 3, 4, 5, 6, 7, 8};
        auto tiles = msaa == 2 ? all : mixed;
        int count = msaa == 0 ? 0 : msaa == 1 ? 4 : 9;
        grid(tiles, count, 128 * scale + 2, 96 * scale + 2, 3);
        ladybird_v_skia_set_msaa_grid(tiles, count, 128 * scale + 2, 96 * scale + 2, 3);
        auto draw = [&](auto context, auto function) {
            return function(context, (offset ? -13 : 17) + fraction,
                (offset ? -17 : 13) + fraction, 260.25, 210.75,
                0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0,
                0, 0, 0, 320, 240, 197, 37, 83, 255, fill, 2.25, 1, 1);
        };
        assert(draw(before, reference));
        assert(draw(after, &ladybird_v_skia_draw_rounded_rect));
        CGContextFlush(before); CGContextFlush(after);
        if (expected != actual) {
            std::fprintf(stderr, "plain strips differ scale=%d clip=%d msaa=%d fraction=%g offset=%d background=%d fill=%d\n",
                scale, clip, msaa, fraction, offset, background, fill);
            return 1;
        }
        CGContextRelease(before); CGContextRelease(after);
        ladybird_v_skia_set_chromium_painting(0); mode(0);
        ++cases;
    }
    ladybird_v_skia_set_chromium_painting(1);
    ladybird_v_skia_set_raster_layer(0, 0, 1);
    ladybird_v_skia_set_raster_layer_size(320, 240);
    int tile = 0; ladybird_v_skia_set_msaa_grid(&tile, 1, 322, 242, 1);
    std::vector<uint8_t> pixels(320 * 240 * 4, 255);
    auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = CGBitmapContextCreate(pixels.data(), 320, 240, 8, 320 * 4, space,
        CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space); assert(context);
    VoxGraphiteShape shape {.matrix = {1, 0, 0, 0, 1, 0, 0, 0, 1},
        .rect = {17.1f, 13.1f, 260.25f, 210.75f}, .red = 197, .green = 37, .blue = 83,
        .alpha = 255, .fill = 1, .anti_alias = 1};
    assert(!vox_plain_rect_core(shape, 320, 240).empty());
    SkPaint paint; paint.setColor(SkColorSetRGB(197, 37, 83)); paint.setAntiAlias(true);
    assert(draw_chromium_sparse_rounded(context, shape, paint, RasterRegion{0, 0, 320, 240},
        1, 0, 0, 0, 240));
    shape.fill = 0; shape.thickness = 2.25;
    assert(draw_chromium_sparse_rounded(context, shape, paint, RasterRegion{0, 0, 320, 240},
        1, 0, 0, 0, 240));
    shape.alpha = 128;
    assert(vox_plain_rect_core(shape, 320, 240).empty());
    shape.alpha = 255; shape.has_underlay = 1;
    assert(vox_plain_rect_core(shape, 320, 240).empty());
    CGContextRelease(context); ladybird_v_skia_set_chromium_painting(0);
    std::printf("Plain rectangle strips: %d exact native comparisons; fractional path exercised\n", cases);
}
