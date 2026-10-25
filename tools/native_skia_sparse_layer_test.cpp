// Compare non-root sparse rounded rendering with a control native bridge.
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <iostream>

int main() {
    auto path = std::getenv("VOX_SKIA_REFERENCE_LIBRARY");
    if (!path || !*path) {
        std::cerr << "Set VOX_SKIA_REFERENCE_LIBRARY to the control native bridge\n";
        return 2;
    }
    auto library = dlopen(path, RTLD_NOW | RTLD_LOCAL);
    assert(library && graphite_shape_draw());
    auto reference = reinterpret_cast<decltype(&ladybird_v_skia_draw_rounded_rect)>(dlsym(library, "ladybird_v_skia_draw_rounded_rect"));
    auto reference_mode = reinterpret_cast<decltype(&ladybird_v_skia_set_chromium_painting)>(dlsym(library, "ladybird_v_skia_set_chromium_painting"));
    auto reference_grid = reinterpret_cast<decltype(&ladybird_v_skia_set_msaa_grid)>(dlsym(library, "ladybird_v_skia_set_msaa_grid"));
    auto reference_layer = reinterpret_cast<decltype(&ladybird_v_skia_set_raster_layer)>(dlsym(library, "ladybird_v_skia_set_raster_layer"));
    auto reference_size = reinterpret_cast<decltype(&ladybird_v_skia_set_raster_layer_size)>(dlsym(library, "ladybird_v_skia_set_raster_layer_size"));
    assert(reference && reference_mode && reference_grid && reference_layer && reference_size);
    int comparisons = 0;
    for (int scale : {1, 2}) for (int clip : {0, 1, 2})
    for (int mode : {0, 1, 2}) for (int fill : {0, 1})
    for (float fraction : {0.f, .1f, .5f, .99999f})
    for (int placement : {0, 1, 2}) for (int backdrop : {0, 1}) {
        int width = 320 * scale, height = 240 * scale, pitch = width * 4 + 16;
        std::vector<uint8_t> expected(size_t(pitch) * height), actual;
        for (size_t i = 0; i < expected.size() / 4; ++i) {
            uint8_t a = backdrop ? uint8_t(i * 13) : 255;
            expected[i * 4] = a / 2; expected[i * 4 + 1] = a / 3;
            expected[i * 4 + 2] = a / 5; expected[i * 4 + 3] = a;
        }
        actual = expected;
        auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        auto make = [&](auto& pixels) {
            auto c = CGBitmapContextCreate(pixels.data(), width, height, 8, pitch, space,
                CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
            assert(c); CGContextScaleCTM(c, scale, scale);
            if (clip == 1) CGContextClipToRect(c, CGRectMake(17.25, 19.5, 217.75, 153.25));
            if (clip == 2) { CGContextAddEllipseInRect(c, CGRectMake(12.5, 8.25, 261.75, 197.5)); CGContextClip(c); }
            return c;
        };
        auto before = make(expected), after = make(actual); CGColorSpaceRelease(space);
        reference_mode(1); ladybird_v_skia_set_chromium_painting(1);
        reference_layer(7, 9, 0); ladybird_v_skia_set_raster_layer(7, 9, 0);
        reference_size(300, 220); ladybird_v_skia_set_raster_layer_size(300, 220);
        int tiles[] {0, 2, 4, 8};
        int all[] {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19};
        auto selected = mode == 2 ? all : tiles;
        int count = mode == 0 ? 0 : mode == 1 ? 4 : 20;
        reference_grid(selected, count, 96 * scale + 2, 64 * scale + 2, 4);
        ladybird_v_skia_set_msaa_grid(selected, count, 96 * scale + 2, 64 * scale + 2, 4);
        float x = (placement == 1 ? -13 : placement == 2 ? 149 : 17) + fraction;
        float y = (placement == 1 ? -17 : placement == 2 ? 157 : 13) + fraction;
        auto draw = [&](auto c, auto fn) {
            return fn(c, x, y, 210, 170, 6, 7, 9, 5, 7, 4, 3, 8,
                1, 0, 0, 1, 0, 0, 0, 0, 0, 320, 240, 197, 37, 83, 255, fill, 2, 1, 1);
        };
        assert(draw(before, reference));
        assert(draw(after, &ladybird_v_skia_draw_rounded_rect));
        CGContextFlush(before); CGContextFlush(after);
        if (expected != actual) {
            size_t differences = 0;
            for (size_t i = 0; i < expected.size(); ++i) if (expected[i] != actual[i]) {
                if (differences++ < 8) std::cerr << " byte=" << i << " expected=" << int(expected[i]) << " actual=" << int(actual[i]) << '\n';
            }
            std::cerr << "Sparse layer mismatch scale=" << scale << " clip=" << clip << " mode=" << mode
                << " fill=" << fill << " fraction=" << fraction << " placement=" << placement
                << " backdrop=" << backdrop << " differences=" << differences << '\n'; return 1;
        }
        ++comparisons; CGContextRelease(before); CGContextRelease(after);
        ladybird_v_skia_set_chromium_painting(0); reference_mode(0);
    }
    // Check eligibility directly, so identical fallback draws cannot make the
    // comparison suite pass while the optimized implementation stays unused.
    ladybird_v_skia_set_chromium_painting(1);
    ladybird_v_skia_set_raster_layer(7, 9, 0);
    ladybird_v_skia_set_raster_layer_size(300, 220);
    int tiles[] {0, 2, 4, 8};
    ladybird_v_skia_set_msaa_grid(tiles, 4, 98, 66, 4);
    std::vector<uint8_t> pixels(320 * 240 * 4, 255);
    auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = CGBitmapContextCreate(pixels.data(), 320, 240, 8, 320 * 4, space,
        CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    assert(context);
    VoxGraphiteShape shape {
        .matrix = {1, 0, 0, 0, 1, 0, 0, 0, 1},
        .rect = {17, 13, 210, 170, 6, 7, 9, 5, 7, 4, 3, 8},
        .red = 197, .green = 37, .blue = 83, .alpha = 255, .fill = 1
    };
    SkPaint paint;
    paint.setColor(SkColorSetRGB(197, 37, 83));
    assert(draw_chromium_sparse_layer_rounded(context, shape, paint,
        RasterRegion {0, 0, 320, 240}, 1, 0, 0, 0, 240));
    CGContextRelease(context);
    ladybird_v_skia_set_chromium_painting(0);
    std::cout << "Sparse layer: " << comparisons
        << " exact GPU comparisons; direct fast-path eligibility passed\n";
}
