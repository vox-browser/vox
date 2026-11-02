#include "../native_graphite_bridge.h"
#include <algorithm>
#include <cassert>
#include <chrono>
#include <cstdio>
#include <cstring>
#include <dlfcn.h>
#include <vector>

int main(int argc, char** argv)
{
    assert(argc == 3);
    void* control = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    void* candidate = dlopen(argv[2], RTLD_NOW | RTLD_LOCAL);
    assert(control && candidate);
    auto reference = reinterpret_cast<decltype(&vox_graphite_draw_shadow_pixels)>(
        dlsym(control, "vox_graphite_draw_shadow_pixels"));
    auto draw = reinterpret_cast<decltype(&vox_graphite_draw_shadow_pixels)>(
        dlsym(candidate, "vox_graphite_draw_shadow_pixels"));
    assert(reference && draw);
    unsigned comparisons = 0;
    for (int height : {543, 1070, 1086}) for (int background : {0, 1})
    for (bool precise : {false, true}) for (float phase : {0.f, .2f, .4f, .6f, .8f}) {
        int scale = height == 543 ? 1 : 2;
        int width = 1024 * scale, pitch = width * 4 + 13;
        VoxGraphiteShadow shadow {};
        shadow.matrix[0] = shadow.matrix[4] = float(scale);
        shadow.matrix[8] = 1;
        shadow.matrix[2] = .25f;
        shadow.matrix[5] = -phase;
        float box[] {32, 51, 960, 440, 12, 12, 12, 12, 12, 12, 12, 12};
        std::copy_n(box, 12, shadow.shadow);
        std::copy_n(box, 12, shadow.content);
        shadow.shadow[1] += 5;
        shadow.blur = 36;
        shadow.alpha = 143;
        shadow.has_float_color = precise;
        shadow.float_color[0] = .123f;
        shadow.float_color[1] = .456f;
        shadow.float_color[2] = .789f;
        shadow.float_color[3] = .561f;
        std::vector<uint8_t> source(size_t(pitch) * height, 0xa9);
        if (background) for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x) {
            auto* p = source.data() + size_t(y) * pitch + x * 4;
            p[0] = uint8_t(x * 3 + y); p[1] = uint8_t(x + y * 7);
            p[2] = uint8_t(x * 11 + y); p[3] = 255;
        }
        for (int pass = 0; pass < 3; ++pass) {
            auto expected = source, actual = source;
            assert(reference(expected.data(), width, height, pitch, background, &shadow));
            assert(draw(actual.data(), width, height, pitch, background, &shadow));
            if (expected != actual) {
                std::fprintf(stderr, "Shadow mismatch height=%d background=%d precise=%d phase=%g pass=%d\n",
                    height, background, precise, phase, pass);
                return 1;
            }
            for (int y = 0; y < height; ++y) for (int x = width * 4; x < pitch; ++x)
                assert(actual[size_t(y) * pitch + x] == 0xa9);
            ++comparisons;
        }
    }
    std::printf("%u exact large-shadow GPU comparisons, including warmed cache hits and row padding\n", comparisons);
}
