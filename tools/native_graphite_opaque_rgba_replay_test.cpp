#include "../native_graphite_bridge.h"
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
    auto reference = reinterpret_cast<decltype(&vox_graphite_draw_image_region_pixels)>(
        dlsym(control, "vox_graphite_draw_image_region_pixels"));
    auto draw = reinterpret_cast<decltype(reference)>(dlsym(candidate, "vox_graphite_draw_image_region_pixels"));
    auto full_reference = reinterpret_cast<decltype(&vox_graphite_draw_image_pixels)>(
        dlsym(control, "vox_graphite_draw_image_pixels"));
    auto full_draw = reinterpret_cast<decltype(full_reference)>(dlsym(candidate, "vox_graphite_draw_image_pixels"));
    assert(reference && draw && full_reference && full_draw);
    constexpr int sw = 73, sh = 59, sp = sw * 4 + 16, width = 128, height = 96;
    std::vector<uint8_t> source(sp * sh, 0xA9);
    for (int y = 0; y < sh; ++y) for (int x = 0; x < sw; ++x) {
        auto* p = source.data() + y * sp + x * 4;
        p[0] = uint8_t(x * 3); p[1] = uint8_t(y * 4); p[2] = 137; p[3] = 255;
    }
    size_t cases = 0;
    for (bool full : {false, true}) for (int scale : {1, 2}) for (int msaa : {0, 1}) for (int pattern : {0, 1, 2})
    for (float opacity : {1.f, .7f}) for (int background : {0, 1}) {
        VoxGraphiteImage image {};
        image.width = sw; image.height = sh; image.pitch = sp; image.pixels = source.data();
        image.source[2] = sw; image.source[3] = sh;
        image.destination[0] = 5.25f; image.destination[1] = 4.5f;
        image.destination[2] = 48; image.destination[3] = 36;
        image.clip[0] = 4; image.clip[1] = 3; image.clip[2] = 54; image.clip[3] = 42;
        for (int i = 4; i < 12; ++i) image.clip[i] = 5;
        image.matrix[0] = image.matrix[4] = scale; image.matrix[8] = 1;
        image.matrix[2] = -.25f; image.matrix[5] = .375f;
        image.opacity = opacity; image.flags = 1 | (msaa ? VOX_GRAPHITE_IMAGE_FORCE_MSAA : 0);
        // Distinct backdrops keep each case independent of earlier cache use.
        std::vector<uint8_t> backdrop(width * height * 4);
        for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x) {
            auto* p = backdrop.data() + (y * width + x) * 4;
            uint8_t value = pattern == 0 || (pattern == 2 && y < height / 2)
                ? 173 : uint8_t((y * 73 + x * 17) % 256);
            p[3] = value; p[0] = value / 2; p[1] = value / 3; p[2] = value / 4;
        }
        for (int phase = 0; phase < 5; ++phase) {
            // First populate a complete view; subsequent contained views and
            // changed interior pixels must use the original GPU coordinates.
            bool crop = !full && phase == 2;
            int x = crop ? 7 : 0, y = crop ? 5 : 0;
            int w = crop ? 105 : width, h = crop ? 85 : height, pitch = w * 4 + 16;
            std::vector<uint8_t> expected(pitch * h, 0xB7);
            for (int row = 0; row < h; ++row)
                std::memcpy(expected.data() + row * pitch,
                    backdrop.data() + ((row + y) * width + x) * 4, w * 4);
            if (phase > 0) {
                int px = 29 * scale - x, py = 22 * scale - y;
                expected[py * pitch + px * 4] ^= 1;
            }
            if (phase == 3) expected[0] ^= 1; // Fringe/outside pixels remain backdrop-dependent.
            size_t changed = size_t(sh / 2) * sp + (sw / 2) * 4 + 3;
            if (phase == 4) --source[changed];
            auto actual = expected;
            VoxGraphitePixelRegion before {x, y, w, h, pitch, expected.data()};
            VoxGraphitePixelRegion after {x, y, w, h, pitch, actual.data()};
            assert(full ? full_reference(expected.data(), width, height, pitch, background, &image)
                : reference(&before, width, height, background, &image));
            assert(full ? full_draw(actual.data(), width, height, pitch, background, &image)
                : draw(&after, width, height, background, &image));
            if (phase == 4) ++source[changed];
            if (actual != expected) {
                std::fprintf(stderr, "Opaque image mismatch scale=%d msaa=%d pattern=%d opacity=%g bg=%d phase=%d\n",
                    scale, msaa, pattern, opacity, background, phase);
                return 1;
            }
            ++cases;
        }
    }
    std::printf("Opaque RGBA cache: %zu exact GPU scenes, including subviews and alpha mutation\n", cases);
}
