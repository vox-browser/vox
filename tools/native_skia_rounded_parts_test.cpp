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
    reference_mode(0);
    // Small controls straddle root tile borders while keeping the original
    // surface origin, dimensions and per-cell MSAA mode. Compare the compact
    // CPU view with a previous bridge's complete-tile replay.
    if (auto path = std::getenv("VOX_SKIA_REFERENCE_LIBRARY")) {
        auto library = dlopen(path, RTLD_NOW | RTLD_LOCAL);
        auto reference_grid = reinterpret_cast<decltype(&ladybird_v_skia_set_msaa_grid)>(
            dlsym(library, "ladybird_v_skia_set_msaa_grid"));
        auto reference_layer = reinterpret_cast<decltype(&ladybird_v_skia_set_raster_layer)>(
            dlsym(library, "ladybird_v_skia_set_raster_layer"));
        auto reference_size = reinterpret_cast<decltype(&ladybird_v_skia_set_raster_layer_size)>(
            dlsym(library, "ladybird_v_skia_set_raster_layer_size"));
        assert(reference_grid && reference_layer && reference_size);
        for (int columns : {1, 3}) for (int scale : {1, 2}) for (int clip : {0, 1, 2})
        for (float x : {11.f, 57.f, 62.375f}) for (float y : {7.f, 41.f, 46.25f})
        for (int fill : {0, 1}) for (int alpha : {97, 255}) for (int radius : {0, 1}) {
            int width = 160 * scale, height = 120 * scale, pitch = width * 4 + 16;
            std::vector<uint8_t> expected(size_t(pitch) * height);
            for (size_t i = 0; i < expected.size(); ++i)
                expected[i] = i % 4 == 3 ? 255 : uint8_t(i * 17);
            auto actual = expected;
            auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
            auto make_context = [&](auto& pixels) {
                auto context = CGBitmapContextCreate(pixels.data(), width, height, 8, pitch, color,
                    static_cast<CGBitmapInfo>(kCGImageAlphaPremultipliedLast)
                    | static_cast<CGBitmapInfo>(kCGBitmapByteOrder32Big));
                assert(context);
                CGContextScaleCTM(context, scale, scale);
                if (clip == 1) CGContextClipToRect(context, CGRectMake(12.25, 24.5, 94.75, 67.25));
                if (clip == 2) {
                    CGContextAddEllipseInRect(context, CGRectMake(5.25, 9.5, 129.75, 89.25));
                    CGContextClip(context);
                }
                return context;
            };
            auto before = make_context(expected), after = make_context(actual);
            CGColorSpaceRelease(color);
            int tiles[] {0, 2, 4, 8};
            auto draw = [&](CGContextRef context, bool control) {
                (control ? reference_mode : &ladybird_v_skia_set_chromium_painting)(1);
                (control ? reference_layer : &ladybird_v_skia_set_raster_layer)(0, 0, 1);
                (control ? reference_size : &ladybird_v_skia_set_raster_layer_size)(160, 120);
                (control ? reference_grid : &ladybird_v_skia_set_msaa_grid)(
                    tiles, 4, 64 * scale + 2, 48 * scale + 2, columns);
                return (control ? reference : &ladybird_v_skia_draw_rounded_rect)(context,
                    x, y, 100, 82, radius * 5, radius * 4, radius * 3, radius * 2,
                    radius * 4, radius * 5, radius * 2, radius * 3,
                    1, 0, 0, 1, 0, 0, 0, 0, 0, 160, 120,
                    197, 37, 83, alpha, fill, 1.25, 1, 1);
            };
            assert(draw(before, true) && draw(after, false));
            CGContextFlush(before); CGContextFlush(after);
            if (expected != actual) {
                std::cerr << "Root shape grid mismatch scale=" << scale << " clip=" << clip
                    << " x=" << x << " y=" << y << " fill=" << fill << " alpha=" << alpha
                    << " radius=" << radius << '\n';
                return 1;
            }
            ++comparisons;
            CGContextRelease(before); CGContextRelease(after);
        }
        // Call the optimized helper directly as well, so a fallback cannot
        // make a passing comparison hide an unexercised fast path.
        int direct_fills = 0;
        for (int scale : {1, 2}) for (int clip : {0, 1, 2})
        for (int color_case : {0, 1, 2, 3}) for (int background : {0, 1, 2, 3}) {
            int width = 160 * scale, height = 120 * scale, pitch = width * 4 + 16;
            std::vector<uint8_t> expected(size_t(pitch) * height);
            for (size_t i = 0; i < expected.size(); ++i) {
                uint8_t alpha = background == 0 ? 255 : background == 1 ? 0
                    : uint8_t((i / 4 * 13 + background * 31) % 256);
                expected[i] = i % 4 == 3 ? alpha : alpha / (i % 4 + 1);
            }
            auto actual = expected;
            auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
            auto make_context = [&](auto& pixels) {
                auto context = CGBitmapContextCreate(pixels.data(), width, height, 8, pitch, space,
                    static_cast<CGBitmapInfo>(kCGImageAlphaPremultipliedLast)
                    | static_cast<CGBitmapInfo>(kCGBitmapByteOrder32Big));
                assert(context); CGContextScaleCTM(context, scale, scale);
                if (clip == 1) CGContextClipToRect(context, CGRectMake(12.25, 24.5, 94.75, 67.25));
                if (clip == 2) {
                    CGContextAddEllipseInRect(context, CGRectMake(5.25, 9.5, 129.75, 89.25));
                    CGContextClip(context);
                }
                return context;
            };
            auto before = make_context(expected), after = make_context(actual);
            CGColorSpaceRelease(space);
            int tiles[] {0, 2, 4, 8};
            reference_mode(1); ladybird_v_skia_set_chromium_painting(1);
            reference_layer(0, 0, 1); ladybird_v_skia_set_raster_layer(0, 0, 1);
            reference_size(160, 120); ladybird_v_skia_set_raster_layer_size(160, 120);
            reference_grid(tiles, 4, 64 * scale + 2, 48 * scale + 2, 3);
            ladybird_v_skia_set_msaa_grid(tiles, 4, 64 * scale + 2, 48 * scale + 2, 3);
            uint8_t red = color_case == 0 ? 0 : color_case == 1 ? 255 : color_case == 2 ? 197 : 113;
            uint8_t green = color_case == 0 ? 0 : color_case == 1 ? 255 : color_case == 2 ? 37 : 211;
            uint8_t blue = color_case == 0 ? 0 : color_case == 1 ? 255 : color_case == 2 ? 83 : 6;
            SkPaint paint; paint.setColor(SkColorSetRGB(red, green, blue)); paint.setAntiAlias(true);
            RasterRegion region {0, 0, 160, 120};
            VoxGraphiteShape shape {};
            shape.matrix[0] = shape.matrix[4] = scale; shape.matrix[8] = 1;
            float data[] {11, 7, 100, 82, 5, 4, 3, 2, 4, 5, 2, 3};
            std::copy_n(data, 12, shape.rect);
            shape.red = red; shape.green = green; shape.blue = blue; shape.alpha = 255;
            shape.fill = 1; shape.anti_alias = 1;
            assert(reference(before, 11, 7, 100, 82, 5, 4, 3, 2, 4, 5, 2, 3,
                1, 0, 0, 1, 0, 0, 0, 0, 0, 160, 120, red, green, blue, 255, 1, 1, 1, 1));
            assert(draw_chromium_sparse_rounded(after, shape, paint, region, scale, 0, 0, 0, 120));
            CGContextFlush(before); CGContextFlush(after);
            if (expected != actual) {
                std::cerr << "Direct rounded parts mismatch scale=" << scale << " clip=" << clip
                    << " color=" << color_case << " background=" << background << '\n';
                int differences = 0;
                for (size_t i = 0; i < expected.size(); ++i) if (expected[i] != actual[i]) {
                    if (differences++ < 24) std::cerr << " byte=" << i << " x=" << (i % pitch) / 4 << " y=" << i / pitch
                        << " channel=" << i % 4 << " expected=" << int(expected[i]) << " actual=" << int(actual[i]) << '\n';
                }
                std::cerr << "differing_bytes=" << differences << '\n';
                return 1;
            }
            // Device edges proved for a uniform raster scale must not be
            // reused by an anisotropic destination, even if it is readable.
            for (double horizontal_scale : {.5, 1.5}) {
                CGContextSaveGState(after);
                CGContextScaleCTM(after, horizontal_scale, 1);
                assert(!draw_chromium_sparse_rounded(after, shape, paint, region, scale, 0, 0, 0, 120));
                CGContextRestoreGState(after);
                CGContextFlush(after);
                assert(expected == actual);
            }
            ++comparisons; ++direct_fills;
            CGContextRelease(before); CGContextRelease(after);
        }
        assert(direct_fills == 96);
        std::cout << "Direct rounded parts: " << direct_fills << " exact comparisons passed\n";
        reference_grid(nullptr, 0, 0, 0, 0);
        ladybird_v_skia_set_msaa_grid(nullptr, 0, 0, 0, 0);
        // The candidate's frame pool was opened inside the reference's pool.
        // Drain in reverse order when both libraries live in this process.
        ladybird_v_skia_set_chromium_painting(0);
        reference_mode(0);
    }
    std::cout << "Native rounded parts: " << comparisons << " exact GPU comparisons passed\n";
}
