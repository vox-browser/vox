// Compare cached GPU output with an uncached build of the same renderer.
// Usage: native_graphite_raster_replay_test CONTROL.dylib CANDIDATE.dylib
#include "../native_graphite_bridge.h"
#include <algorithm>
#include <cassert>
#include <cstring>
#include <dlfcn.h>
#include <iostream>
#include <vector>

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
    int comparisons = 0;
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
    std::cout << "Graphite raster replay: " << comparisons << " exact GPU comparisons passed\n";
}
