#include "../native/include/native_graphite_bridge.h"
#include <algorithm>
#include <cassert>
#include <cstdio>
#include <cstring>
#include <dlfcn.h>
#include <vector>

int main(int argc, char** argv)
{
    assert(argc == 3);
    auto* control = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    auto* candidate = dlopen(argv[2], RTLD_NOW | RTLD_LOCAL);
    assert(control && candidate);
    auto full = reinterpret_cast<decltype(&vox_graphite_draw_shape_pixels)>(
        dlsym(control, "vox_graphite_draw_shape_pixels"));
    auto draw = reinterpret_cast<decltype(&vox_graphite_draw_shape_region_pixels)>(
        dlsym(candidate, "vox_graphite_draw_shape_region_pixels"));
    assert(full && draw);
    int comparisons = 0;
    for (int vertical : {0, 1}) for (int scale : {1, 2}) for (int msaa : {0, 1})
    for (int background : {0, 1}) for (int fill : {0, 1})
    for (float phase : {.1f, .5f, .99999f}) for (int alpha : {128, 255}) {
        int width = vertical ? 384 : 2048, height = vertical ? 2048 : 384;
        VoxGraphiteShape shape {};
        shape.matrix[0] = shape.matrix[4] = scale; shape.matrix[8] = 1;
        shape.matrix[vertical ? 2 : 5] = -1146;
        shape.rect[0] = (vertical ? 1520.f : 2.f) / scale;
        shape.rect[1] = (vertical ? 2.f : 1520.f) / scale;
        shape.rect[2] = (vertical ? 6.f : 1951.f) / scale;
        shape.rect[3] = (vertical ? 1951.f : 6.f) / scale;
        shape.rect[vertical ? 0 : 1] += phase / scale;
        for (int i = 4; i < 12; ++i) shape.rect[i] = 3.f / scale;
        shape.fill = fill; shape.thickness = 1.25f / scale;
        shape.alpha = alpha; shape.red = 37; shape.green = 83; shape.blue = 197;
        shape.anti_alias = 1; shape.force_msaa = msaa;
        int x = vertical ? 368 : 0, y = vertical ? 0 : 368;
        int w = vertical ? 16 : 1960, h = vertical ? 1960 : 16, pitch = w * 4 + 13;
        std::vector<uint8_t> original(2 + size_t(pitch) * h, 0xa9);
        for (int row = 0; row < h; ++row) for (int col = 0; col < w; ++col) {
            auto* p = original.data() + 1 + size_t(row) * pitch + col * 4;
            p[3] = uint8_t((col * 17 + row * 19) % 256);
            p[0] = p[3] / 2; p[1] = p[3] / 3; p[2] = p[3] / 4;
        }
        // Repeat a cache hit, then change backdrop bytes within the long edge.
        for (int pass = 0; pass < 3; ++pass) {
            if (pass == 2) original[1 + size_t(h / 2) * pitch + (w / 2) * 4] ^= 1;
            std::vector<uint8_t> expected(size_t(width) * height * 4);
            for (int row = 0; row < h; ++row)
                std::memcpy(expected.data() + (size_t(y + row) * width + x) * 4,
                    original.data() + 1 + size_t(row) * pitch, w * 4);
            assert(full(expected.data(), width, height, width * 4, background, &shape));
            auto pixels = original;
            VoxGraphitePixelRegion view {x, y, w, h, pitch, pixels.data() + 1};
            assert(draw(&view, width, height, background, &shape));
            assert(pixels.front() == 0xa9 && pixels.back() == 0xa9);
            for (int row = 0; row < h; ++row) {
                assert(!std::memcmp(view.pixels + size_t(row) * pitch,
                    expected.data() + (size_t(y + row) * width + x) * 4, w * 4));
                for (int b = w * 4; b < pitch; ++b)
                    assert(view.pixels[size_t(row) * pitch + b] == 0xa9);
            }
            ++comparisons;
        }
    }
    // The larger allowance applies only to thin, bounded patches. Declines
    // leave caller bytes untouched for ordinary full-tile fallback.
    std::vector<uint8_t> pixels(64 * 32 * 4, 71); auto original = pixels;
    VoxGraphitePixelRegion view {0, 0, 64, 32, 64 * 4, pixels.data()};
    VoxGraphiteShape shape {};
    shape.matrix[0] = shape.matrix[4] = shape.matrix[8] = 1;
    shape.rect[2] = 600; shape.rect[3] = 40; shape.fill = 1; shape.alpha = 255;
    assert(!draw(&view, 2048, 384, 1, &shape));
    shape.rect[2] = 8190; shape.rect[3] = 10;
    assert(!draw(&view, 8192, 384, 1, &shape));
    assert(pixels == original);
    std::printf("Thin shape regions: %d exact GPU comparisons; bounded fallback passed\n", comparisons);
}
