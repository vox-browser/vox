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
    std::cout << "Graphite raster replay: " << comparisons << " exact GPU comparisons passed\n";
}
