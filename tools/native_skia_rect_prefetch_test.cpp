// Compare ordered replay with speculative GPU cache population, including
// destination mutations that must invalidate a prefetched backdrop.
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <iostream>

int main()
{
    assert(graphite_shape_draw() && graphite_shape_regions_draw());
    auto* backend = dlopen("@rpath/libVoxGraphite.dylib", RTLD_NOW | RTLD_LOCAL);
    assert(backend);
    auto clear = reinterpret_cast<decltype(&vox_graphite_release_unused_graphics_memory)>(
        dlsym(backend, "vox_graphite_release_unused_graphics_memory"));
    assert(clear);
    int comparisons = 0, admitted = 0, declined = 0;
    for (int grid : {0, 1, 2}) for (int scale : {1, 2}) for (float transform_scale : {.5f, 1.f})
    for (int msaa : {0, 1, 2})
    for (int clip : {0, 1, 2}) for (int mutation : {0, 1, 2})
    for (float phase : {0.f, .2f, .5f, .8f}) @autoreleasepool {
        constexpr int width = 320, height = 140;
        int pitch = width * scale * 4 + 16;
        std::vector<uint8_t> expected(size_t(pitch) * height * scale, 255), actual(expected);
        auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        auto make = [&](auto& pixels) {
            auto c = CGBitmapContextCreate(pixels.data(), width * scale, height * scale,
                8, pitch, color, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
            assert(c);
            CGContextScaleCTM(c, scale, scale);
            if (clip == 1) CGContextClipToRect(c, CGRectMake(20.2, 10.5, 275.75, 112.25));
            if (clip == 2) {
                CGContextAddEllipseInRect(c, CGRectMake(5.5, 5.5, 308.25, 127.25));
                CGContextClip(c);
            }
            return c;
        };
        auto before = make(expected), after = make(actual);
        CGColorSpaceRelease(color);
        ladybird_v_skia_set_chromium_painting(1);
        ladybird_v_skia_set_raster_layer(0, 0, 1);
        ladybird_v_skia_set_raster_layer_size(width, 900);
        int tiles[] {0, 1, 3, 5, 7, 9, 11, 13, 15, 17};
        int grid_width = grid == 2 ? 2048 : grid == 1 ? 544 : 128;
        int grid_height = grid == 2 ? 384 : grid == 1 ? 256 : 80;
        ladybird_v_skia_set_msaa_grid(tiles, msaa == 0 ? 0 : msaa == 1 ? 3 : 10,
            grid_width, grid_height, (width * scale + grid_width - 5) / (grid_width - 2));
        ladybird_v_skia_set_root_raster_scroll_y(phase);
        VoxGraphiteShape shapes[12] {};
        for (int i = 0; i < 12; ++i) {
            auto& s = shapes[i];
            s.matrix[0] = s.matrix[4] = transform_scale;
            s.matrix[8] = 1;
            s.matrix[5] = -phase;
            s.rect[0] = (7.375f + (i % 4) * 72.25f) / transform_scale;
            s.rect[1] = (23.f + (i / 4) * 39) / transform_scale;
            s.rect[2] = (i % 2 ? 65.03125f : 65.8125f) / transform_scale;
            s.rect[3] = 1 / transform_scale;
            s.blue = 128; s.alpha = 255; s.fill = s.anti_alias = 1;
            s.has_float_color = i % 2;
            s.float_color[2] = .5f; s.float_color[3] = 1;
        }
        auto replay = [&](CGContextRef c) {
            for (auto const& s : shapes) {
                if (mutation) {
                    CGContextSetRGBFillColor(c, .7, .4, .2, 1);
                    CGContextFillRect(c, CGRectMake(s.rect[0] * transform_scale,
                        height - s.rect[1] * transform_scale + phase - (mutation == 2 ? 1 : -2),
                        s.rect[2] * transform_scale / 2, 2));
                }
                ladybird_v_skia_set_unrounded_paint_color(s.has_float_color ? s.float_color : nullptr);
                assert(ladybird_v_skia_draw_rounded_rect(c, s.rect[0], s.rect[1], s.rect[2], s.rect[3],
                    0, 0, 0, 0, 0, 0, 0, 0, transform_scale, 0, 0, transform_scale, 0, -phase,
                    0, 0, 0, width, height, s.red, s.green, s.blue, s.alpha, 1, 0, 1, 1));
            }
            CGContextFlush(c);
        };
        replay(before);
        // The reference must not warm the candidate's exact backdrop cache.
        // Exercise actual batched GPU misses before ordered replay checks hits.
        clear();
        auto untouched = actual;
        bool prefetched = ladybird_v_skia_prefetch_plain_rects(after, shapes, 12, 0, 0, width, height);
        bool supported_scale = scale * transform_scale == 1 || scale * transform_scale == 2;
        if (prefetched != supported_scale) {
            std::cerr << "Unexpected prefetch admission grid=" << grid << " scale=" << scale
                << " transform=" << transform_scale << " msaa=" << msaa << " clip=" << clip
                << " mutation=" << mutation << " phase=" << phase << '\n';
            return 1;
        }
        if (prefetched) ++admitted; else ++declined;
        CGContextFlush(after);
        assert(actual == untouched);
        replay(after);
        if (actual != expected) {
            std::cerr << "Prefetch mismatch scale=" << scale << " transform=" << transform_scale << " msaa=" << msaa
                << " clip=" << clip << " mutation=" << mutation << " phase=" << phase << '\n';
            return 1;
        }
        assert(!ladybird_v_skia_prefetch_plain_rects(after, shapes, 1, 0, 0, width, height));
        shapes[3].rect[2] = INFINITY;
        untouched = actual;
        assert(!ladybird_v_skia_prefetch_plain_rects(after, shapes, 12, 0, 0, width, height));
        CGContextFlush(after); assert(actual == untouched);
        shapes[3].rect[2] = 65.03125f / transform_scale;
        for (float invalid_scale : {0.f, -1.f, 2.f, INFINITY}) {
            shapes[3].matrix[0] = invalid_scale;
            assert(!ladybird_v_skia_prefetch_plain_rects(after, shapes, 12, 0, 0, width, height));
            CGContextFlush(after); assert(actual == untouched);
        }
        shapes[3].matrix[0] = transform_scale;
        for (auto size : {std::pair{2048, 513}, std::pair{0, 384}, std::pair{2048, -1}}) {
            s_msaa_grid_width = size.first;
            s_msaa_grid_height = size.second;
            assert(!ladybird_v_skia_prefetch_plain_rects(after, shapes, 12, 0, 0, width, height));
            CGContextFlush(after); assert(actual == untouched);
        }
        CGContextRelease(before); CGContextRelease(after);
        ++comparisons;
    }
    assert(admitted == 972 && declined == 324);
    std::cout << comparisons << " ordered native prefetch comparisons passed ("
        << admitted << " admitted, " << declined << " declined)\n";
}
