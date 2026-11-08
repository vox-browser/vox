#include "../native/include/native_graphite_bridge.h"
#include <cassert>
#include <cstring>
#include <dlfcn.h>
#include <iostream>
#include <vector>

int main(int argc, char** argv)
{
    assert(argc == 3);
    auto* control = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    auto* candidate = dlopen(argv[2], RTLD_NOW | RTLD_LOCAL);
    assert(control && candidate);
    using Draw = decltype(&vox_graphite_draw_path_batch_pixels);
    auto before = reinterpret_cast<Draw>(dlsym(control, "vox_graphite_draw_path_batch_pixels"));
    auto after = reinterpret_cast<Draw>(dlsym(candidate, "vox_graphite_draw_path_batch_pixels"));
    auto clear = reinterpret_cast<decltype(&vox_graphite_release_unused_graphics_memory)>(
        dlsym(candidate, "vox_graphite_release_unused_graphics_memory"));
    assert(before && after && before != after && clear);
    float segments[] {0,2,2,0,0,0,0,0,0,0,0,0,
        1,27,2,0,0,0,0,0,0,0,0,0,
        1,7,26,0,0,0,0,0,0,0,0,0,
        5,0,0,0,0,0,0,0,0,0,0,0};
    unsigned comparisons = 0;
    for (int epoch = 0; epoch < 3; ++epoch) {
        clear();
        for (int iteration = 0; iteration < 32; ++iteration) {
            int width = 40 + (iteration % 3) * 17, height = 35 + iteration % 7;
            int pitch = width * 4 + 7;
            VoxGraphitePath paths[2] {};
            for (int i = 0; i < 2; ++i) {
                auto& path = paths[i];
                path.matrix[0] = path.matrix[4] = path.matrix[8] = 1;
                path.matrix[2] = iteration * .125f; path.matrix[5] = i * 3.5f;
                path.segments = segments; path.segment_count = 4;
                path.red = 37 + epoch; path.green = 117; path.blue = 193;
                path.alpha = i ? 173 : 211;
                path.has_clip = i; path.clip[0] = path.clip[1] = 3.25f;
                path.clip[2] = path.clip[3] = 25.5f;
            }
            std::vector<uint8_t> backdrop(1 + size_t(pitch) * height, 91);
            for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x) {
                auto* p = backdrop.data() + 1 + size_t(y) * pitch + x * 4;
                p[0] = 11; p[1] = 27; p[2] = 43; p[3] = 255;
            }
            // Fail after the first path records commands. Its abandoned work
            // must not appear in the next complete draw on the shared recorder.
            auto invalid = paths[1]; invalid.gradient = 1;
            VoxGraphitePath failed[] {paths[0], invalid};
            auto actual = backdrop;
            assert(!after(actual.data() + 1, width, height, pitch, 1, failed, 2));
            assert(actual == backdrop);
            auto expected = backdrop;
            assert(before(expected.data() + 1, width, height, pitch, 1, paths, 2));
            assert(after(actual.data() + 1, width, height, pitch, 1, paths, 2));
            assert(actual == expected);
            ++comparisons;
        }
    }
    clear();
    std::cout << comparisons << " recorder replays preserve pixels after failures and teardown\n";
}
