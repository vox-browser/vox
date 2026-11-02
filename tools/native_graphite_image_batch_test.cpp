#include "../native_graphite_bridge.h"
#include <algorithm>
#include <array>
#include <cassert>
#include <cstdio>
#include <cstring>
#include <dlfcn.h>
#include <climits>
#include <vector>

int main(int argc, char** argv)
{
    assert(argc == 3);
    auto* control = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    auto* candidate = dlopen(argv[2], RTLD_NOW | RTLD_LOCAL);
    assert(control && candidate);
    auto serial = reinterpret_cast<decltype(&vox_graphite_draw_image_region_pixels)>(
        dlsym(control, "vox_graphite_draw_image_region_pixels"));
    auto batch = reinterpret_cast<decltype(&vox_graphite_draw_image_regions_pixels)>(
        dlsym(candidate, "vox_graphite_draw_image_regions_pixels"));
    assert(serial && batch);
    constexpr int sw = 67, sh = 51, sp = sw * 4 + 16, width = 128, height = 96, count = 4;
    std::vector<uint8_t> source(sp * sh, 0xAE);
    std::array<VoxGraphiteImage, count> images {};
    std::array<VoxGraphitePixelRegion, count> before {}, after {};
    std::array<std::vector<uint8_t>, count> expected, actual;
    size_t scenes = 0;
    for (int scale : {1, 2}) for (int nearest : {0, 1}) for (int opaque : {0, 1})
    for (int background : {0, 1}) for (int sample : {0, 1, 2}) for (int phase = 0; phase < 4; ++phase) {
        for (int y = 0; y < sh; ++y) for (int x = 0; x < sw; ++x) {
            auto* p = source.data() + y * sp + x * 4;
            p[3] = opaque ? 255 : uint8_t(90 + (x + y) % 160);
            p[0] = uint8_t((x * 3) % p[3]); p[1] = uint8_t((y * 4) % p[3]);
            p[2] = p[3] / 2;
        }
        if (phase == 2) source[(sh / 2) * sp + (sw / 2) * 4] ^= 1;
        for (int i = 0; i < count; ++i) {
            int x = 3 + i, y = 4 + i, w = width - x - 9, h = height - y - 7, pitch = w * 4 + 16;
            expected[i].assign(pitch * h, 0xB7);
            for (int row = 0; row < h; ++row) for (int col = 0; col < w; ++col) {
                auto* p = expected[i].data() + row * pitch + col * 4;
                p[3] = uint8_t(120 + (row + col + i) % 120);
                p[0] = p[3] / 2; p[1] = p[3] / 3; p[2] = p[3] / 4;
            }
            if (phase == 3) expected[i][pitch * (h / 2) + (w / 2) * 4] ^= 1;
            actual[i] = expected[i];
            before[i] = {x, y, w, h, pitch, expected[i].data()};
            after[i] = {x, y, w, h, pitch, actual[i].data()};
            auto& image = images[i]; image = {};
            image.width = sw; image.height = sh; image.pitch = sp; image.pixels = source.data();
            image.source[2] = sw; image.source[3] = sh;
            image.destination[0] = 5.25f; image.destination[1] = 4.5f;
            image.destination[2] = 48; image.destination[3] = 36;
            image.clip[0] = 4; image.clip[1] = 3; image.clip[2] = 54; image.clip[3] = 42;
            for (int r = 4; r < 12; ++r) image.clip[r] = 5;
            image.matrix[0] = image.matrix[4] = scale; image.matrix[8] = 1;
            image.matrix[2] = -i * 3.25f; image.matrix[5] = i * 2.375f;
            image.opacity = i == 3 ? .7f : 1.f; image.nearest = nearest;
            image.flags = 1 | ((sample == 1 || (sample == 2 && i % 2)) ? VOX_GRAPHITE_IMAGE_FORCE_MSAA : 0);
            assert(serial(&before[i], width, height, background, &image));
        }
        assert(batch(after.data(), images.data(), count, width, height, background));
        for (int i = 0; i < count; ++i) {
            if (actual[i] != expected[i]) {
                std::fprintf(stderr, "Batch mismatch scale=%d nearest=%d opaque=%d bg=%d sample=%d phase=%d tile=%d\n",
                    scale, nearest, opaque, background, sample, phase, i);
                return 1;
            }
            ++scenes;
        }
    }
    size_t rejects = 0;
    auto reject = [&] {
        auto unchanged = actual;
        assert(!batch(after.data(), images.data(), count, width, height, 1));
        assert(actual == unchanged); ++rejects;
    };
    auto valid_views = after; auto valid_images = images;
    after[1] = after[0]; reject(); after = valid_views;
    images[1].pixels = after[0].pixels; reject(); images = valid_images;
    after[2].x = width; reject(); after = valid_views;
    after[2].width = 0; reject(); after = valid_views;
    after[2].width = INT_MIN; reject(); after = valid_views;
    after[2].pitch = 1; reject(); after = valid_views;
    images[2].flags |= 4; reject(); images = valid_images;
    images[2].pitch = 0; reject(); images = valid_images;
    // The second upload has an unsupported RGBA byte stride. It fails after
    // the first tile has queued a readback; outputs must still be untouched.
    std::vector<uint8_t> odd_source(size_t(sp + 1) * sh, 255);
    for (int repetition = 0; repetition < 8; ++repetition) {
        images = valid_images;
        for (auto& image : images) image.matrix[5] += 17.125f + repetition;
        images[1].pixels = odd_source.data(); images[1].pitch = sp + 1;
        reject();
        images[1].pixels = source.data(); images[1].pitch = sp;
        auto input = actual;
        assert(batch(after.data(), images.data(), count, width, height, 1));
        for (int i = 0; i < count; ++i) {
            before[i].pixels = input[i].data();
            assert(serial(&before[i], width, height, 1, &images[i]));
            assert(input[i] == actual[i]); ++scenes;
        }
    }
    std::printf("Image batch: %zu exact tile comparisons, %zu transactional rejections including 8 late failures\n", scenes, rejects);
}
