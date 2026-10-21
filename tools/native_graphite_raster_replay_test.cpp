// Compare cached GPU output with an uncached build of the same renderer.
// Usage: native_graphite_raster_replay_test CONTROL.dylib CANDIDATE.dylib
#include "../native_graphite_bridge.h"
#include <algorithm>
#include <cassert>
#include <cstring>
#include <dlfcn.h>
#include <iostream>
#include <vector>
#include <chrono>
#include <thread>

int main(int argc, char** argv)
{
    assert(argc == 3);
    auto load = [](char const* path) {
        void* library = dlopen(path, RTLD_NOW | RTLD_LOCAL);
        if (!library) std::cerr << dlerror() << '\n';
        assert(library);
        return library;
    };
    void* control = load(argv[1]);
    void* candidate = load(argv[2]);
    auto before = reinterpret_cast<decltype(&vox_graphite_draw_image_pixels)>(dlsym(control,
        "vox_graphite_draw_image_pixels"));
    auto after = reinterpret_cast<decltype(before)>(dlsym(candidate, "vox_graphite_draw_image_pixels"));
    auto clear = reinterpret_cast<decltype(&vox_graphite_release_unused_graphics_memory)>(
        dlsym(candidate, "vox_graphite_release_unused_graphics_memory"));
    assert(before && after && clear);
    auto finish_frame = reinterpret_cast<void (*)()>(dlsym(candidate, "vox_graphite_finish_frame"));
    int comparisons = 0;
    // These Retina-sized photo draws exceed the old 8 MiB entry allowance.
    // Compare first draws, cache hits and changed inputs against the renderer.
    for (int flags : {4 | 8, 4 | 8 | 16}) {
        constexpr int width = 1252, height = 884, pitch = width * 4 + 12;
        std::vector<uint8_t> source(700 * 700 * 3), backdrop(pitch * height, 255), expected, actual;
        for (size_t i = 0; i < source.size(); ++i) source[i] = (i * 37 + i / 11) % 256;
        VoxGraphiteImage photo {};
        photo.matrix[0] = photo.matrix[4] = photo.matrix[8] = 1;
        photo.source[2] = photo.source[3] = photo.width = photo.height = 700;
        photo.destination[2] = photo.destination[3] = width;
        photo.clip[2] = width; photo.clip[3] = height;
        photo.opacity = 1; photo.pitch = 2800; photo.flags = flags;
        photo.pixels = source.data();
        auto compare = [&] {
            expected = actual = backdrop;
            assert(before(expected.data(), width, height, pitch, 1, &photo));
            assert(after(actual.data(), width, height, pitch, 1, &photo));
            assert(expected == actual); ++comparisons;
            if (finish_frame) finish_frame();
        };
        compare(); compare();
        source[700 * 700 - 1] ^= 31; compare(); compare();
        backdrop[(height / 2) * pitch + (width / 2) * 4] ^= 73; compare(); compare();
        photo.matrix[2] = .375f; compare(); compare();
        photo.matrix[0] = .9f; photo.matrix[4] = .95f; compare(); compare();
        for (int i = 4; i < 12; ++i) photo.clip[i] = 5.5f;
        compare(); compare();
        backdrop[(height - 1) * pitch + width * 4 - 1] ^= 31; compare(); compare();
        clear(); compare();
    }
    for (int flags : {0, 1, 4, 4 | 8, 4 | 16, 4 | 8 | 16}) {
        for (int scale : {1, 2}) for (int background : {0, 1}) for (int cropped : {0, 1}) {
            // Odd dimensions exercise the complete final chroma row/column.
            std::vector<uint8_t> source(37 * 29 * 4);
            for (size_t i = 0; i < source.size(); ++i) source[i] = (i * 37 + i / 11) % 256;
            if (flags & 1) for (size_t i = 0; i < source.size(); i += 4)
                for (int c = 0; c < 3; ++c) source[i + c] = source[i + c] * source[i + 3] / 255;
            int width = 27 * scale, height = 31 * scale, pitch = width * 4 + 12;
            std::vector<uint8_t> backdrop(pitch * height), expected, actual;
            for (size_t i = 0; i < backdrop.size(); ++i) backdrop[i] = (i * 19) % 256;
            for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x) {
                auto* p = backdrop.data() + y * pitch + x * 4;
                p[3] = background ? 255 : 0;
            }
            VoxGraphiteImage image {};
            image.matrix[0] = image.matrix[4] = scale;
            image.matrix[8] = 1;
            image.matrix[2] = .375f;
            image.matrix[5] = -.25f;
            image.source[0] = cropped ? 3 : 0;
            image.source[1] = cropped ? 2 : 0;
            image.source[2] = cropped ? 25 : 37;
            image.source[3] = cropped ? 19 : 29;
            image.destination[0] = 1.25f;
            image.destination[1] = 2.5f;
            image.destination[2] = 21.5f;
            image.destination[3] = 25;
            image.clip[0] = 2;
            image.clip[1] = 3;
            image.clip[2] = 20;
            image.clip[3] = 24;
            for (int i = 4; i < 12; ++i) image.clip[i] = 3.5f;
            image.opacity = .75f;
            image.width = 37; image.height = 29; image.pitch = 37 * 4;
            image.flags = flags;
            image.pixels = source.data();
            auto compare = [&] {
                expected = actual = backdrop;
                assert(before(expected.data(), width, height, pitch, background, &image));
                assert(after(actual.data(), width, height, pitch, background, &image));
                assert(expected == actual);
                ++comparisons;
                if (finish_frame) finish_frame();
            };
            compare(); compare(); // Cold followed by a hit.
            source[0] ^= 63; compare(); compare(); // Same buffer, changed content.
            backdrop[0] ^= 31; compare(); compare(); // Changed input backdrop.
            image.opacity = .35f; compare(); compare();
            image.matrix[1] = .125f; compare(); compare();
            image.nearest = 1; compare(); compare();
            if (!(flags & 4)) {
                image.has_color_profile = 1;
                image.color_profile[0] = 1.8f;
                compare(); compare();
                image.color_profile[0] = 2.2f;
                compare(); compare();
            }
            clear(); compare(); // Idle eviction must preserve the next draw.
        }
    }
    auto before_shape = reinterpret_cast<decltype(&vox_graphite_draw_shape_pixels)>(
        dlsym(control, "vox_graphite_draw_shape_pixels"));
    auto after_shape = reinterpret_cast<decltype(before_shape)>(
        dlsym(candidate, "vox_graphite_draw_shape_pixels"));
    assert(before_shape && after_shape);
    for (int scale : {1, 2}) for (int background : {0, 1}) for (int msaa : {0, 1}) {
        VoxGraphiteShape shape {};
        shape.matrix[0] = shape.matrix[4] = scale;
        shape.matrix[8] = 1;
        shape.matrix[2] = -.375f; shape.matrix[5] = .25f;
        shape.rect[0] = 1.25f; shape.rect[1] = 2.5f;
        shape.rect[2] = 23; shape.rect[3] = 26;
        for (int i = 4; i < 12; ++i) shape.rect[i] = 3.5f;
        shape.fill = shape.anti_alias = 1;
        shape.force_msaa = msaa;
        shape.red = 35; shape.green = 167; shape.blue = 79; shape.alpha = 190;
        int width = 27 * scale, height = 31 * scale, pitch = width * 4 + 12;
        std::vector<uint8_t> backdrop(pitch * height, 89), expected, actual;
        auto compare = [&] {
            expected = actual = backdrop;
            assert(before_shape(expected.data(), width, height, pitch, background, &shape));
            assert(after_shape(actual.data(), width, height, pitch, background, &shape));
            assert(expected == actual);
            ++comparisons;
            if (finish_frame) finish_frame();
        };
        compare(); compare();
        shape.fill = 0; shape.thickness = 2.25f; compare(); compare();
        shape.has_underlay = 1;
        std::copy_n(shape.rect, 12, shape.underlay_rect);
        shape.underlay_rgba[0] = 191; shape.underlay_rgba[1] = 125;
        shape.underlay_rgba[2] = 67; shape.underlay_rgba[3] = 180;
        compare(); compare();
        float clips[] {8.25f, 9, 14, 15.75f};
        shape.clip_outs = clips; shape.clip_out_count = 1;
        compare(); compare();
        clips[1] += .5f; compare(); compare();
        backdrop[3] = 255; compare(); compare();
        clear(); compare();
    }
    // Opaque aligned fills must match GPU output, including MSAA, saturated
    // colors, viewport clipping and half-CSS-pixel geometry at Retina density.
    float const rects[][4] {{2, 3, 19, 23}, {-3, -5, 11, 17},
        {0, 0, 41, 35}, {18, 23, 20, 20}, {.5f, 1.5f, 17, 21},
        {-.25f, .25f, 19.5f, 20.5f}, {0, 0, .5f, .5f}, {91, 93, 7, 11}};
    for (int scale : {1, 2}) for (int background : {0, 1}) for (int msaa : {0, 1})
    for (int aa : {0, 1}) for (int channel : {0, 1, 127, 128, 254, 255}) for (auto const& rect : rects) {
        VoxGraphiteShape shape {};
        shape.matrix[0] = shape.matrix[4] = scale; shape.matrix[8] = 1;
        std::copy_n(rect, 4, shape.rect);
        shape.fill = 1; shape.anti_alias = aa; shape.force_msaa = msaa;
        shape.red = channel; shape.green = 255 - channel; shape.blue = channel / 2;
        shape.alpha = 255;
        int width = 31 * scale, height = 37 * scale, pitch = width * 4 + 12;
        std::vector<uint8_t> expected(pitch * height), actual;
        for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x) {
            auto* pixel = expected.data() + y * pitch + x * 4;
            pixel[3] = (x * 17 + y * 13) % 256;
            pixel[0] = pixel[3] / 2; pixel[1] = pixel[3] / 3; pixel[2] = pixel[3];
        }
        actual = expected;
        assert(before_shape(expected.data(), width, height, pitch, background, &shape));
        assert(after_shape(actual.data(), width, height, pitch, background, &shape));
        assert(expected == actual);
        ++comparisons;
        if (finish_frame) finish_frame();
    }
    for (int scale : {1, 2}) for (int background : {0, 1}) for (int fill : {0, 1})
    for (int msaa : {0, 1}) for (int offset : {-280, -13, 0, 53, 290})
    for (float phase : {0.0f, .375f, .6666667f}) {
        VoxGraphiteShape shape {};
        shape.matrix[0] = shape.matrix[4] = scale; shape.matrix[8] = 1;
        shape.matrix[2] = phase;
        shape.matrix[5] = offset * scale + phase;
        shape.rect[0] = phase > .5f ? 100007 : 7; shape.rect[1] = 3;
        if (phase > .5f) shape.matrix[2] -= 100000 * scale;
        shape.rect[2] = 617; shape.rect[3] = 281;
        for (int i = 4; i < 12; ++i) shape.rect[i] = 6.5f;
        shape.fill = fill; shape.thickness = phase == 0 ? 2 : 1;
        shape.anti_alias = 1; shape.force_msaa = msaa;
        shape.red = 171; shape.green = 53; shape.blue = 248;
        shape.alpha = !fill && phase == .375f ? 128 : 255;
        int width = 631 * scale, height = 303 * scale, pitch = width * 4 + 12;
        std::vector<uint8_t> expected(pitch * height), actual;
        for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x) {
            auto* p = expected.data() + y * pitch + x * 4;
            p[3] = (x * 17 + y * 13) % 256;
            p[0] = p[3] / 2; p[1] = p[3] / 3; p[2] = p[3];
        }
        actual = expected;
        assert(before_shape(expected.data(), width, height, pitch, background, &shape));
        assert(after_shape(actual.data(), width, height, pitch, background, &shape));
        if (expected != actual) {
            std::cerr << "Rounded shape mismatch scale=" << scale << " background=" << background
                << " fill=" << fill << " msaa=" << msaa << " offset=" << offset << " phase=" << phase << '\n';
            int count = 0;
            for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x) {
                size_t i = size_t(y) * pitch + x * 4;
                if (std::memcmp(expected.data() + i, actual.data() + i, 4)) {
                    if (count++ < 12) std::cerr << " at " << x << ',' << y << " expected="
                        << int(expected[i]) << ',' << int(expected[i+1]) << ',' << int(expected[i+2]) << ',' << int(expected[i+3])
                        << " actual=" << int(actual[i]) << ',' << int(actual[i+1]) << ',' << int(actual[i+2]) << ',' << int(actual[i+3]) << '\n';
                }
            }
            std::cerr << " differing=" << count << '\n';
            std::abort();
        }
        ++comparisons;
        if (finish_frame) finish_frame();
    }
    for (int scale : {1, 2}) for (int background : {0, 1}) for (int fill : {0, 1}) {
        VoxGraphiteShape shape {};
        shape.matrix[0] = shape.matrix[4] = scale; shape.matrix[8] = 1;
        shape.rect[0] = 7.375f; shape.rect[1] = 3.333333f;
        shape.rect[2] = 617; shape.rect[3] = 281;
        for (int i = 4; i < 12; ++i) shape.rect[i] = 6.5f;
        shape.fill = fill; shape.thickness = 1; shape.anti_alias = shape.force_msaa = 1;
        shape.red = 93; shape.green = 187; shape.blue = 125; shape.alpha = fill ? 255 : 128;
        int width = 631 * scale, height = 303 * scale, pitch = width * 4 + 12;
        std::vector<uint8_t> backdrop(size_t(pitch) * height, 89), expected, actual;
        auto compare = [&] {
            expected = actual = backdrop;
            assert(before_shape(expected.data(), width, height, pitch, background, &shape));
            assert(after_shape(actual.data(), width, height, pitch, background, &shape));
            assert(expected == actual);
            ++comparisons;
            if (finish_frame) finish_frame();
        };
        compare(); compare();
        // A cached stroke must preserve changed pixels in its untouched middle.
        auto center = size_t(height / 2) * pitch + (width / 2) * 4;
        backdrop[center] = 31; backdrop[center + 3] = 192;
        compare();
        // A changed corner backdrop must invalidate the packed border result.
        auto corner = size_t(5 * scale) * pitch + 9 * scale * 4;
        backdrop[corner] = 21; backdrop[corner + 3] = 183;
        compare();
        clear(); compare();
    }
    // Pixel-aligned strokes and narrow rounded comment controls, including
    // corners completely above/below the viewport and fractional fallbacks.
    for (int scale : {1, 2}) for (int background : {0, 1}) for (int msaa : {0, 1})
    for (int kind : {0, 1, 2}) for (float phase : {0.0f, .5f, .375f})
    for (int offset : {-400, -13, 0, 53}) {
        VoxGraphiteShape shape {};
        shape.matrix[0] = shape.matrix[4] = scale; shape.matrix[8] = 1;
        shape.matrix[2] = phase * scale; shape.matrix[5] = offset * scale;
        shape.rect[0] = 2.5f; shape.rect[1] = 3.5f;
        shape.rect[2] = kind == 0 ? 269 : 15;
        shape.rect[3] = kind == 0 ? 23 : (kind == 1 ? 291 : 2080);
        for (int i = 4; i < 12; ++i) shape.rect[i] = kind == 0 ? 0 : 3;
        if (kind == 2) { shape.rect[8] = shape.rect[9] = 0; shape.rect[10] = 1; }
        shape.fill = kind != 0; shape.thickness = 1;
        shape.anti_alias = 1; shape.force_msaa = msaa;
        shape.red = 171; shape.green = 53; shape.blue = 248; shape.alpha = 255;
        int width = (kind == 0 ? 278 : 23) * scale, height = (kind == 0 ? 32 : 303) * scale;
        int pitch = width * 4 + 12;
        std::vector<uint8_t> backdrop(size_t(pitch) * height, 89), expected, actual;
        for (int repeat = 0; repeat < 2; ++repeat) {
            expected = actual = backdrop;
            assert(before_shape(expected.data(), width, height, pitch, background, &shape));
            assert(after_shape(actual.data(), width, height, pitch, background, &shape));
            if (expected != actual) {
                std::cerr << "Narrow/stroke mismatch kind=" << kind << " scale=" << scale
                    << " phase=" << phase << " offset=" << offset << " msaa=" << msaa << '\n';
                return 1;
            }
            ++comparisons;
            if (finish_frame) finish_frame();
        }
    }
    auto before_path = reinterpret_cast<decltype(&vox_graphite_draw_path_pixels)>(
        dlsym(control, "vox_graphite_draw_path_pixels"));
    auto after_path = reinterpret_cast<decltype(before_path)>(
        dlsym(candidate, "vox_graphite_draw_path_pixels"));
    assert(before_path && after_path);
    for (int alpha : {128, 255}) for (bool noise : {false, true}) {
        constexpr int width = 1260, height = 888, pitch = width * 4 + 12;
        float segments[] {
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            1, 700, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            1, 700, 490, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            1, 0, 490, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
        VoxGraphitePath path {};
        path.segments = segments; path.segment_count = 6;
        path.matrix[0] = path.matrix[4] = 1.78799f; path.matrix[8] = 1;
        path.matrix[2] = 4; path.matrix[5] = 4.203125f;
        path.red = 171; path.green = 83; path.blue = 47; path.alpha = alpha;
        std::vector<uint8_t> backdrop(size_t(pitch) * height, 255), expected, actual;
        if (noise) for (size_t i = 0; i < backdrop.size(); ++i) backdrop[i] = (i * 17 + i / 11) % 251;
        auto compare = [&] {
            expected = actual = backdrop;
            assert(before_path(expected.data(), width, height, pitch, 1, &path));
            assert(after_path(actual.data(), width, height, pitch, 1, &path));
            assert(expected == actual); ++comparisons;
            if (finish_frame) finish_frame();
        };
        compare(); compare();
        segments[13] += .375f; compare(); compare();
        backdrop[(height - 1) * pitch + width * 4 - 1] ^= 31; compare(); compare();
        clear(); compare();
    }
    for (int scale : {1, 2}) for (int background : {0, 1})
    for (int gradient : {0, 1, 2}) for (int stroke : {0, 1}) {
        float segments[] {
            0, 3.25, 4.5, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            3, 29.5, 24.25, 32, -4, 11, 34, 0, 0, 0, 0, 0,
            1, 7.25, 26.5, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
        float stops[] {.9, .1, .3, .8, 0, .1, .7, .4, .65, 1};
        VoxGraphitePath path {};
        path.matrix[0] = path.matrix[4] = scale; path.matrix[8] = 1;
        path.matrix[2] = -.375f; path.matrix[5] = .25f;
        path.segments = segments; path.segment_count = 4;
        path.red = 35; path.green = 167; path.blue = 79; path.alpha = 190;
        path.stroke = stroke; path.stroke_width = 2.25f; path.miter_limit = 4;
        path.gradient = gradient; path.stops = stops; path.stop_count = 2; path.opacity = .8f;
        path.gradient_points[0] = 2; path.gradient_points[1] = 3;
        path.gradient_points[2] = gradient == 2 ? 1 : 27;
        path.gradient_points[3] = 26; path.gradient_points[4] = 25; path.gradient_points[5] = 30;
        path.gradient_matrix[0] = path.gradient_matrix[4] = path.gradient_matrix[8] = 1;
        int width = 31 * scale, height = 29 * scale, pitch = width * 4 + 12;
        std::vector<uint8_t> backdrop(size_t(pitch) * height, 89), expected, actual;
        auto compare = [&] {
            expected = actual = backdrop;
            assert(before_path(expected.data(), width, height, pitch, background, &path));
            assert(after_path(actual.data(), width, height, pitch, background, &path));
            assert(expected == actual); ++comparisons;
            if (finish_frame) finish_frame();
        };
        compare(); compare();
        segments[13] += .5f; compare(); compare();
        stops[1] += .125f; compare(); compare();
        backdrop[13] ^= 31; compare(); compare();
        path.even_odd = 1; compare(); compare();
        path.line_cap = 1; path.line_join = 2; compare(); compare();
        path.matrix[1] = .125f; compare(); compare();
        path.opacity = .35f; compare(); compare();
        path.tile_mode = 1; path.linear_color_space = 1; compare(); compare();
        path.gradient_matrix[2] = .375f; compare(); compare();
        clear(); compare();
    }
    auto before_shadow = reinterpret_cast<decltype(&vox_graphite_draw_shadow_pixels)>(
        dlsym(control, "vox_graphite_draw_shadow_pixels"));
    auto after_shadow = reinterpret_cast<decltype(before_shadow)>(
        dlsym(candidate, "vox_graphite_draw_shadow_pixels"));
    assert(before_shadow && after_shadow);
    assert(before_shadow != after_shadow);
    for (int scale : {1, 2}) for (int background : {0, 1}) for (float blur : {0.f, 7.f}) {
        int width = 31 * scale, height = 29 * scale, pitch = width * 4 + 12;
        std::vector<uint8_t> backdrop(size_t(pitch) * height, 89), expected, actual;
        VoxGraphiteShadow shadow {};
        shadow.matrix[0] = shadow.matrix[4] = scale; shadow.matrix[8] = 1;
        float outer[] {3, 4, 24, 21, 3, 3, 4, 4, 2, 2, 1, 1};
        float inner[] {7, 8, 15, 12, 2, 2, 2, 2, 1, 1, 1, 1};
        std::copy_n(outer, 12, shadow.shadow);
        std::copy_n(inner, 12, shadow.content);
        shadow.blur = blur; shadow.red = 137; shadow.green = 25; shadow.blue = 61; shadow.alpha = 190;
        auto compare = [&] {
            expected = actual = backdrop;
            assert(before_shadow(expected.data(), width, height, pitch, background, &shadow));
            assert(after_shadow(actual.data(), width, height, pitch, background, &shadow));
            assert(expected == actual); ++comparisons;
            if (finish_frame) finish_frame();
        };
        compare(); compare();
        shadow.blur += 1.25f; compare(); compare();
        shadow.matrix[1] = .125f; compare(); compare();
        shadow.content[4] += .25f; compare(); compare();
        shadow.shadow[2] += .5f; compare(); compare();
        shadow.alpha = 87; compare(); compare();
        backdrop[13] ^= 31; compare(); compare();
        clear(); compare();
    }
    // A cached shadow must remain readable after idle GPU teardown and must
    // not recreate a context merely to replay its owned CPU pixels.
    auto idle = reinterpret_cast<decltype(&vox_graphite_release_idle_graphics_memory)>(
        dlsym(candidate, "vox_graphite_release_idle_graphics_memory"));
    assert(idle);
    clear();
    VoxGraphiteShadow retained_shadow {};
    retained_shadow.matrix[0] = retained_shadow.matrix[4] = retained_shadow.matrix[8] = 1;
    retained_shadow.shadow[2] = 12; retained_shadow.shadow[3] = 10;
    retained_shadow.content[2] = retained_shadow.content[3] = 4;
    retained_shadow.blur = 3; retained_shadow.alpha = 150;
    std::vector<uint8_t> retained_pixels(16 * 16 * 4, 93);
    assert(after_shadow(retained_pixels.data(), 16, 16, 64, 1, &retained_shadow));
    auto retained_output = retained_pixels;
    std::this_thread::sleep_for(std::chrono::milliseconds(2100));
    assert(idle() == 1);
    std::fill(retained_pixels.begin(), retained_pixels.end(), 93);
    assert(after_shadow(retained_pixels.data(), 16, 16, 64, 1, &retained_shadow));
    assert(retained_pixels == retained_output);
    std::this_thread::sleep_for(std::chrono::milliseconds(2100));
    assert(idle() == 0);
    std::cout << "Graphite raster replay: " << comparisons << " exact GPU comparisons and idle shadow replay passed\n";
}
