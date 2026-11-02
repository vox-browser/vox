#include "../native_graphite_bridge.h"
#include "../native_chromium_image_decode_cache.h"
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
    auto reference = reinterpret_cast<decltype(&vox_graphite_draw_image_pixels)>(
        dlsym(control, "vox_graphite_draw_image_pixels"));
    auto draw = reinterpret_cast<decltype(reference)>(dlsym(candidate, "vox_graphite_draw_image_pixels"));
    assert(reference && draw);
    // Larger than the complete-raster cache's source bound, so each changing
    // destination must execute the texture path rather than reuse a raster.
    constexpr int width = 4097, height = 1031, source_pitch = width * 4 + 16;
    std::vector<uint8_t> pixels(size_t(source_pitch) * height, 0xA9);
    for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x) {
        auto* p = pixels.data() + size_t(y) * source_pitch + x * 4;
        p[3] = uint8_t((x / 128 + y / 64) % 3 == 0 ? 0 : 229);
        p[0] = p[3] / 2; p[1] = p[3] / 3; p[2] = p[3] / 4;
    }
    size_t cases = 0;
    for (int scale : {1, 2}) for (int msaa : {0, 1}) for (int background : {0, 1})
    for (float opacity : {.65f, 1.f}) for (int mutation : {0, 1}) {
        // Warm a base, add CPU-generated mip levels, then return to the base.
        for (int destination : {576, 192, 384, 576, 192}) {
            int w = 1200, h = 320, pitch = w * 4 + 16;
            std::vector<uint8_t> expected(size_t(pitch) * h, 0xB7);
            for (int y = 0; y < h; ++y) for (int x = 0; x < w; ++x) {
                auto* p = expected.data() + size_t(y) * pitch + x * 4;
                p[3] = uint8_t((x * 7 + y * 11 + destination) % 256);
                p[0] = p[3] / 2; p[1] = p[3] / 3; p[2] = p[3] / 4;
            }
            auto actual = expected;
            VoxGraphiteImage image {};
            image.width = width; image.height = height; image.pitch = source_pitch;
            image.pixels = pixels.data(); image.opacity = opacity;
            image.flags = vox_image_with_decode_level(1 | (msaa ? VOX_GRAPHITE_IMAGE_FORCE_MSAA : 0), 3);
            image.matrix[0] = image.matrix[4] = scale; image.matrix[8] = 1;
            image.matrix[2] = .375f; image.matrix[5] = -.25f;
            image.source[2] = width; image.source[3] = height;
            image.destination[0] = image.clip[0] = 3.25f;
            image.destination[1] = image.clip[1] = 4.5f;
            image.destination[2] = image.clip[2] = destination;
            image.destination[3] = image.clip[3] = destination / 4.f;
            for (int i = 4; i < 12; ++i) image.clip[i] = 3.5f;
            size_t changed = size_t(source_pitch) * (height / 2) + width * 2;
            if (mutation) ++pixels[changed];
            assert(reference(expected.data(), w, h, pitch, background, &image));
            assert(draw(actual.data(), w, h, pitch, background, &image));
            if (mutation) --pixels[changed];
            if (actual != expected) {
                std::fprintf(stderr, "Large upload mismatch scale=%d msaa=%d bg=%d opacity=%g mutation=%d size=%d\n",
                    scale, msaa, background, opacity, mutation, destination);
                return 1;
            }
            ++cases;
        }
    }
    std::printf("Large texture uploads: %zu exact GPU comparisons, including CPU mip transitions\n", cases);
}
