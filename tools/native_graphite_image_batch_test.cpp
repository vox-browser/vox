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
    auto reference = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    auto candidate = dlopen(argv[2], RTLD_NOW | RTLD_LOCAL);
    if (!reference || !candidate) std::fprintf(stderr, "%s\n", dlerror());
    assert(reference && candidate);
    auto full = reinterpret_cast<decltype(&vox_graphite_draw_image_pixels)>(
        dlsym(reference, "vox_graphite_draw_image_pixels"));
    auto batch = reinterpret_cast<decltype(&vox_graphite_draw_image_regions_pixels)>(
        dlsym(candidate, "vox_graphite_draw_image_regions_pixels"));
    auto clear = reinterpret_cast<decltype(&vox_graphite_release_unused_graphics_memory)>(
        dlsym(candidate, "vox_graphite_release_unused_graphics_memory"));
    assert(full && batch && clear);
    constexpr int width = 544, height = 256, count = 3;
    constexpr int crops[count][4] {{0, 0, 301, 137}, {11, 29, 233, 73}, {512, 220, 32, 36}};
    int comparisons = 0;
    for (int flags : {0, 1, 4, 4 | 8, 4 | 16, 4 | VOX_GRAPHITE_IMAGE_YUV422,
            1 | VOX_GRAPHITE_IMAGE_VIDEO_FRAME})
    for (int background : {0, 1}) for (int nearest : {0, 1})
    for (int fractional : {0, 1}) for (int downscale : {0, 1}) {
        constexpr int source_width = 257, source_height = 193;
        std::vector<uint8_t> source(source_width * source_height * 4);
        for (size_t i = 0; i < source.size(); ++i) source[i] = uint8_t(i * 37 + i / 11);
        if (flags & 1) for (size_t i = 0; i < source.size(); i += 4)
            for (int c = 0; c < 3; ++c) source[i + c] = source[i + c] * source[i + 3] / 255;
        for (int pass : {0, 1, 2}) {
            // Warm cache, changed source at the same address, then changed
            // backdrop/geometry. No address is an immutable image identity.
            if (pass == 1) source[0] ^= 127;
            std::vector<uint8_t> outputs[count], original[count], expected[count];
            VoxGraphitePixelRegion views[count];
            VoxGraphiteImage images[count] {};
            for (int i = 0; i < count; ++i) {
                auto const* crop = crops[i];
                int x = crop[0], y = crop[1], w = crop[2], h = crop[3], pitch = w * 4 + 13;
                outputs[i].assign(1 + size_t(pitch) * h, 0xa9);
                for (int row = 0; row < h; ++row) for (int col = 0; col < w; ++col) {
                    auto* pixel = outputs[i].data() + 1 + size_t(row) * pitch + col * 4;
                    pixel[3] = background == 1 && pass == 2 ? 173 : 255;
                    pixel[0] = (col * 17 + row * 7 + pass) % (pixel[3] + 1);
                    pixel[1] = (col * 11 + row * 13) % (pixel[3] + 1);
                    pixel[2] = (col * 5 + row * 19) % (pixel[3] + 1);
                }
                original[i] = outputs[i];
                views[i] = {x, y, w, h, pitch, outputs[i].data() + 1};
                auto& image = images[i];
                image.matrix[0] = image.matrix[4] = image.matrix[8] = 1;
                image.matrix[2] = fractional ? -.375f : 0;
                image.matrix[5] = fractional ? .25f : 0;
                image.source[2] = image.width = source_width;
                image.source[3] = image.height = source_height;
                image.destination[2] = image.clip[2] = downscale ? 83.25f : 540;
                image.destination[3] = image.clip[3] = downscale ? 63.5f : 244;
                image.pitch = source_width * 4; image.pixels = source.data();
                image.opacity = pass == 2 ? .35f : .8f;
                image.nearest = nearest;
                image.flags = flags | (i % 2 ? VOX_GRAPHITE_IMAGE_FORCE_MSAA : 0);
                if (pass == 2) {
                    image.clip[0] = 5; image.clip[1] = 8;
                    std::fill(image.clip + 4, image.clip + 12, 3.5f);
                    image.border_width = 1.25f;
                    std::copy_n(image.clip, 12, image.border_rect);
                    image.border_rgba[0] = 71; image.border_rgba[3] = 163;
                    image.has_color_profile = 1; image.color_profile[0] = 2.2f;
                }
                expected[i].resize(size_t(width) * height * 4);
                for (int row = 0; row < h; ++row)
                    std::memcpy(expected[i].data() + (size_t(y + row) * width + x) * 4,
                        views[i].pixels + size_t(row) * pitch, size_t(w) * 4);
                assert(full(expected[i].data(), width, height, width * 4, background, &image));
            }
            for (int warm : {0, 1}) {
                (void)warm;
                for (int i = 0; i < count; ++i) std::copy(original[i].begin(), original[i].end(), outputs[i].begin());
                assert(batch(views, images, count, width, height, background));
                for (int i = 0; i < count; ++i) {
                    auto const& view = views[i];
                    for (int row = 0; row < view.height; ++row) {
                        if (std::memcmp(view.pixels + size_t(row) * view.pitch,
                                expected[i].data() + (size_t(row + view.y) * width + view.x) * 4,
                                size_t(view.width) * 4)) {
                            std::fprintf(stderr, "Mismatch flags=%d bg=%d nearest=%d fractional=%d down=%d pass=%d warm=%d tile=%d row=%d\n",
                                flags, background, nearest, fractional, downscale, pass, warm, i, row);
                            return 1;
                        }
                        for (int p = view.width * 4; p < view.pitch; ++p)
                            assert(view.pixels[size_t(row) * view.pitch + p] == 0xa9);
                    }
                    assert(outputs[i][0] == 0xa9);
                    ++comparisons;
                }
            }
            // Reject a bad final tile atomically, even if the preceding views
            // have cache hits that could otherwise be copied to the caller.
            for (int i = 0; i < count; ++i) std::copy(original[i].begin(), original[i].end(), outputs[i].begin());
            views[count - 1].x = width;
            assert(!batch(views, images, count, width, height, background));
            for (int i = 0; i < count; ++i) assert(outputs[i] == original[i]);
            if (!(flags & 4)) {
                // Fail texture preparation after earlier cache misses have
                // queued GPU reads. Draining them must publish nothing.
                views[count - 1].x = crops[count - 1][0];
                for (auto& image : images) image.opacity = .61f;
                images[count - 1].pitch = 1;
                assert(!batch(views, images, count, width, height, background));
                for (int i = 0; i < count; ++i) assert(outputs[i] == original[i]);
            }
        }
        clear();
    }
    std::printf("Image batches: %d exact complete-target comparisons passed\n", comparisons);
}
