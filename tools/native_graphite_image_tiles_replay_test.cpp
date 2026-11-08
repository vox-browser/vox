#include "../native/include/native_graphite_bridge.h"
#include <algorithm>
#include <cassert>
#include <dlfcn.h>
#include <iostream>
#include <vector>

int main(int argc, char** argv)
{
    assert(argc == 3);
    auto load = [](char const* path) {
        auto library = dlopen(path, RTLD_NOW | RTLD_LOCAL);
        if (!library) std::cerr << dlerror() << '\n';
        assert(library);
        return library;
    };
    auto control = load(argv[1]), candidate = load(argv[2]);
    auto before = reinterpret_cast<decltype(&vox_graphite_draw_image_tiles)>(dlsym(control, "vox_graphite_draw_image_tiles"));
    auto after = reinterpret_cast<decltype(before)>(dlsym(candidate, "vox_graphite_draw_image_tiles"));
    auto clear = reinterpret_cast<decltype(&vox_graphite_release_unused_graphics_memory)>(dlsym(candidate, "vox_graphite_release_unused_graphics_memory"));
    assert(before && after && clear);
    int comparisons = 0;
    for (int flags : {0, 1, 4, 4 | 8, 4 | 16, 4 | 8 | 16})
    for (int scale : {1, 2}) for (int background : {0, 1})
    for (int msaa : {0, 1}) for (int tagged : {0, 1}) {
        std::vector<uint8_t> source(37 * 29 * 4);
        for (size_t i = 0; i < source.size(); ++i) source[i] = (i * 37 + i / 11) % 256;
        if (flags & 1) for (size_t i = 0; i < source.size(); i += 4)
            for (int c = 0; c < 3; ++c) source[i + c] = source[i + c] * source[i + 3] / 255;
        int width = 47 * scale, height = 31 * scale, pitch = width * 4 + 12;
        std::vector<uint8_t> backdrop(pitch * height), expected, actual;
        for (size_t i = 0; i < backdrop.size(); ++i) backdrop[i] = i % 4 == 3 ? 255 : (i * 19) % 256;
        std::vector<VoxGraphiteImage> images(3);
        for (int i = 0; i < 3; ++i) {
            auto& image = images[i];
            image.matrix[0] = image.matrix[4] = scale; image.matrix[8] = 1;
            image.matrix[2] = .375f; image.matrix[5] = -.25f;
            image.source[0] = i; image.source[1] = 2;
            image.source[2] = 25; image.source[3] = 19;
            image.destination[0] = 1.25f + i * 11; image.destination[1] = 2.5f;
            image.destination[2] = 21.5f; image.destination[3] = 25;
            image.clip[0] = 2; image.clip[1] = 3; image.clip[2] = 40; image.clip[3] = 24;
            for (int p = 4; p < 12; ++p) image.clip[p] = 3.5f;
            image.opacity = .75f; image.nearest = i % 2;
            image.width = 37; image.height = 29; image.pitch = 37 * 4;
            image.flags = flags | (msaa && i == 1 ? VOX_GRAPHITE_IMAGE_FORCE_MSAA : 0);
            image.has_color_profile = tagged; image.color_profile[0] = 2.2f;
            image.pixels = source.data();
        }
        auto compare = [&] {
            expected = actual = backdrop;
            assert(before(expected.data(), width, height, pitch, background, images.data(), int(images.size())));
            assert(after(actual.data(), width, height, pitch, background, images.data(), int(images.size())));
            assert(expected == actual);
            ++comparisons;
        };
        compare(); compare(); // Cold and warm, including overlapping placements.
        source.back() ^= 1; compare(); compare();
        auto replacement = source;
        for (auto& image : images) image.pixels = replacement.data();
        compare();
        images[2].opacity = .35f; compare(); compare();
        backdrop[8] ^= 1; compare(); compare();
        std::swap(images[0], images[2]); compare(); compare();
        clear(); compare();
        // A batch with separate sources remains on the uncached GPU path.
        auto separate = replacement;
        separate[0] ^= 1;
        images[1].pixels = separate.data();
        compare(); compare();
    }
    std::cout << "Image tile GPU replay: " << comparisons << " exact cold/warm comparisons, source/backdrop changes, profiles, overlap, MSAA and idle eviction passed\n";
}
