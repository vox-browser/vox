// Preserve ordered pixels while predicting text-dependent rectangle backdrops.
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
    char const* path = "/System/Library/Fonts/Supplemental/Arial.ttf";
    auto* face = select_typeface(path, 0, 400, 0);
    assert(face);
    uint16_t glyphs[] {face->unicharToGlyph('A'), face->unicharToGlyph('g')};
    assert(glyphs[0] && glyphs[1]);
    int comparisons = 0, admitted = 0, predicted = 0;
    bool checked_lifecycle = false;
    for (int scale : {1, 2}) for (float transform_scale : {.5f, 1.f})
    for (int grid : {0, 1, 2}) for (int clip : {0, 1, 2})
    for (bool overlap : {false, true}) for (float phase : {.2f, .5f})
    for (bool patterned : {false, true}) @autoreleasepool {
        constexpr int width = 240, height = 110;
        size_t pitch = width * scale * 4 + 16;
        std::vector<uint8_t> expected(pitch * height * scale, 255);
        if (patterned) for (size_t i = 0; i < expected.size(); i += 4) {
            expected[i] = uint8_t((i * 13) % 256);
            expected[i + 1] = uint8_t((i * 7) % 256);
            expected[i + 2] = uint8_t((i * 3) % 256);
        }
        auto actual = expected;
        auto color_space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        auto make = [&](auto& pixels) {
            auto context = CGBitmapContextCreate(pixels.data(), width * scale, height * scale,
                8, pitch, color_space, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
            assert(context);
            CGContextScaleCTM(context, scale, scale);
            if (clip == 1) CGContextClipToRect(context, CGRectMake(12.25, 8.5, 195.5, 88.25));
            if (clip == 2) {
                CGContextAddEllipseInRect(context, CGRectMake(5.5, 5.5, 223.25, 97.25));
                CGContextClip(context);
            }
            return context;
        };
        auto before = make(expected), after = make(actual);
        CGColorSpaceRelease(color_space);
        ladybird_v_skia_set_chromium_painting(1);
        ladybird_v_skia_set_raster_layer(0, 0, 1);
        ladybird_v_skia_set_raster_layer_size(width, 900);
        int tiles[] {0, 1, 3, 5, 7, 9, 11, 13, 15, 17};
        int grid_width = grid == 2 ? 2048 : grid == 1 ? 544 : 128;
        int grid_height = grid == 2 ? 384 : grid == 1 ? 256 : 80;
        ladybird_v_skia_set_msaa_grid(tiles, grid == 0 ? 0 : 10,
            grid_width, grid_height, (width * scale + grid_width - 5) / (grid_width - 2));
        ladybird_v_skia_set_root_raster_scroll_y(phase);
        VoxGraphiteShape shapes[6] {};
        for (int i = 0; i < 6; ++i) {
            auto& shape = shapes[i];
            shape.matrix[0] = shape.matrix[4] = transform_scale;
            shape.matrix[8] = 1;
            shape.matrix[5] = -phase;
            shape.rect[0] = (9.375f + (i % 3) * (overlap ? 18 : 66)) / transform_scale;
            shape.rect[1] = (27.f + (i / 3) * 39) / transform_scale;
            shape.rect[2] = 53.03125f / transform_scale;
            shape.rect[3] = 1 / transform_scale;
            shape.blue = 128; shape.alpha = 255; shape.fill = shape.anti_alias = 1;
            shape.has_float_color = i % 2;
            shape.float_color[2] = .5f; shape.float_color[3] = 1;
        }
        double positions[] {0, 0, 9.25 / transform_scale, 0};
        auto text = [&](CGContextRef context, int index) {
            auto const& next = shapes[(index + 1) % 6];
            assert(draw_retained_glyph_run(context, path, 0, glyphs, positions, 2,
                14 / transform_scale, 400, 0, next.rect[0] + 1 / transform_scale,
                next.rect[1] + 2 / transform_scale, transform_scale, 0, 0, transform_scale,
                0, -phase, 0, 0, 0, width, height, 100, 42, 17, 255, 2 | 16 | 32, 0));
            CGContextSetRGBFillColor(context, .15, .65, .25, .6);
            CGContextFillRect(context, CGRectMake(next.rect[0] * transform_scale + 19,
                height - next.rect[1] * transform_scale + phase - 1, 7.25, 2));
        };
        std::vector<PlainRectPrefetchJob> reference_jobs;
        auto replay = [&](CGContextRef context, bool capture) {
            for (int i = 0; i < 6; ++i) {
                if (capture) {
                    s_plain_rect_prefetch = &reference_jobs;
                    collect_plain_rect_prefetch(context, shapes[i], 0, 0, width, height);
                    s_plain_rect_prefetch = nullptr;
                }
                collect_plain_rect_prefetch(context, shapes[i], 0, 0, width, height);
                text(context, i);
            }
            CGContextFlush(context);
        };
        replay(before, true);
        clear();
        auto untouched = actual;
        auto scratch = ladybird_v_skia_begin_rect_prefetch_scratch(after, shapes, 6, 0, 0, width, height);
        bool supported = scale * transform_scale == 1 || scale * transform_scale == 2;
        assert(bool(scratch) == supported);
        if (scratch) {
            ++admitted;
            assert(!ladybird_v_skia_begin_rect_prefetch_scratch(after, shapes, 6, 0, 0, width, height));
            for (int i = 0; i < 6; ++i) {
                assert(ladybird_v_skia_append_rect_prefetch_scratch(i));
                text(scratch, i);
            }
            if (!overlap && !clip) {
                auto const& jobs = s_plain_rect_scratch->jobs;
                assert(jobs.size() == reference_jobs.size());
                for (size_t i = 0; i < jobs.size(); ++i) {
                    assert(jobs[i].pixels == reference_jobs[i].pixels);
                    assert(!std::memcmp(jobs[i].shape.matrix, reference_jobs[i].shape.matrix, sizeof(jobs[i].shape.matrix)));
                    ++predicted;
                }
            }
            assert(ladybird_v_skia_finish_rect_prefetch_scratch(1));
            assert(!ladybird_v_skia_finish_rect_prefetch_scratch(1));
        }
        CGContextFlush(after);
        assert(actual == untouched);
        replay(after, false);
        if (actual != expected) {
            std::cerr << "Scratch prefetch mismatch scale=" << scale << " transform=" << transform_scale
                << " grid=" << grid << " clip=" << clip << " overlap=" << overlap
                << " phase=" << phase << " patterned=" << patterned << '\n';
            return 1;
        }
        if (scratch && !checked_lifecycle) {
            checked_lifecycle = true;
            assert(ladybird_v_skia_begin_rect_prefetch_scratch(after, shapes, 6, 0, 0, width, height));
            assert(ladybird_v_skia_append_rect_prefetch_scratch(0));
            assert(!ladybird_v_skia_append_rect_prefetch_scratch(0));
            assert(!ladybird_v_skia_finish_rect_prefetch_scratch(1));
            assert(ladybird_v_skia_begin_rect_prefetch_scratch(after, shapes, 6, 0, 0, width, height));
            assert(!ladybird_v_skia_finish_rect_prefetch_scratch(1));
            assert(ladybird_v_skia_begin_rect_prefetch_scratch(after, shapes, 6, 0, 0, width, height));
            assert(!ladybird_v_skia_finish_rect_prefetch_scratch(0));
            assert(!ladybird_v_skia_begin_rect_prefetch_scratch(after, shapes, 1, 0, 0, width, height));
            assert(!ladybird_v_skia_begin_rect_prefetch_scratch(after, shapes, 6, 0, NAN, width, height));
            assert(!ladybird_v_skia_begin_rect_prefetch_scratch(after, shapes, 6, 0, 0, INFINITY, height));
            shapes[0].rect[0] = 1e20;
            assert(!ladybird_v_skia_begin_rect_prefetch_scratch(after, shapes, 6, 0, 0, width, height));
            CGContextFlush(after);
            assert(actual == expected);
        }
        CGContextRelease(before); CGContextRelease(after);
        ++comparisons;
    }
    assert(comparisons == 288 && admitted == 216 && predicted > 0 && checked_lifecycle);
    std::cout << comparisons << " exact ordered scratch comparisons (" << admitted
        << " admitted, " << predicted << " exact text-dependent backdrop predictions)\n";
}
