#include "../native_graphite_bridge.h"
#include "../native_graphite_raster_cache.h"
#include <cassert>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <dlfcn.h>
#include <limits>
#include <vector>

static void cache_view_identity()
{
    VoxGraphiteRasterCache cache;
    VoxGraphiteShape shape {};
    shape.matrix[0] = shape.matrix[4] = shape.matrix[8] = 1;
    shape.fill = 1; shape.alpha = 255;
    std::vector<uint8_t> pixels(64, 31);
    std::vector<int> original {1, 2, 4, 4}, moved {3, 4, 4, 4};
    auto request = cache.prepare_shape_parts(shape, 64, 64, 16, true, pixels.data(), original);
    assert(!request.hit && request.pending);
    std::fill(pixels.begin(), pixels.end(), 127);
    cache.finish(std::move(request), pixels.data(), 64);
    std::fill(pixels.begin(), pixels.end(), 31);
    assert(!cache.prepare_shape_parts(shape, 64, 64, 16, true, pixels.data(), moved).hit);
    assert(pixels == std::vector<uint8_t>(64, 31));
    assert(cache.prepare_shape_parts(shape, 64, 64, 16, true, pixels.data(), original).hit);
    assert(pixels == std::vector<uint8_t>(64, 127));
}

int main(int argc, char** argv)
{
    assert(argc == 3 || (argc == 4 && !std::strcmp(argv[3], "--failure-points")));
    cache_view_identity();
    auto* control = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    auto* candidate = dlopen(argv[2], RTLD_NOW | RTLD_LOCAL);
    assert(control && candidate);
    auto full = reinterpret_cast<decltype(&vox_graphite_draw_shape_pixels)>(
        dlsym(control, "vox_graphite_draw_shape_pixels"));
    auto batch = reinterpret_cast<decltype(&vox_graphite_draw_shape_parts_batch_pixels)>(
        dlsym(candidate, "vox_graphite_draw_shape_parts_batch_pixels"));
    assert(full && batch);
    constexpr int width = 256, height = 128, w = 32, h = 24, pitch = w * 4 + 13;
    constexpr int locations[][2] {{0, 0}, {224, 0}, {0, 104}, {224, 104}};
    size_t comparisons = 0, rejections = 0;
    for (int jobs : {2, 4}) for (int background : {0, 1}) for (int scale : {1, 2})
    for (int samples : {0, 1, 2}) for (int fill : {0, 1}) for (int fractional : {0, 1})
    for (int views : {1, 4}) for (int warm = 0; warm < 2; ++warm) {
        std::vector<std::vector<uint8_t>> storage(jobs * views), expected(jobs);
        std::vector<VoxGraphitePixelRegion> regions(jobs * views);
        std::vector<VoxGraphiteShapeParts> input(jobs);
        for (int i = 0; i < jobs; ++i) {
            auto& shape = input[i].shape;
            shape.matrix[0] = shape.matrix[4] = scale; shape.matrix[8] = 1;
            shape.matrix[2] = -i * 1.25f; shape.matrix[5] = i * .75f;
            shape.rect[0] = 3.5f / scale; shape.rect[1] = 4.f / scale;
            shape.rect[2] = 240.f / scale; shape.rect[3] = 116.f / scale;
            for (int corner = 4; corner < 12; ++corner) shape.rect[corner] = float(4 + corner % 3) / scale;
            shape.fill = fill; shape.alpha = 255; shape.red = 197; shape.green = 37; shape.blue = 83;
            shape.thickness = 1.5f / scale; shape.anti_alias = 1;
            shape.force_msaa = samples == 1 || (samples == 2 && i % 2);
            if (fractional) { shape.has_float_color = 1; shape.float_color[0] = .4237f;
                shape.float_color[1] = .2679f; shape.float_color[2] = .8643f; shape.float_color[3] = .73f; }
            expected[i].resize(size_t(width) * height * 4);
            for (int j = 0; j < views; ++j) {
                int k = i * views + j;
                storage[k].assign(1 + size_t(pitch) * h, 0xA9);
                // Alternate equal-sized coordinates to verify packed cache keys.
                int x = locations[j][0] + (warm ? (j % 2 ? -1 : 1) : 0), y = locations[j][1];
                regions[k] = {x, y, w, h, pitch, storage[k].data() + 1};
                for (int row = 0; row < h; ++row) for (int col = 0; col < w; ++col) {
                    auto* p = regions[k].pixels + size_t(row) * pitch + col * 4;
                    p[3] = uint8_t((col * 17 + row * 19 + i * 7) % 256);
                    p[0] = p[3] / 2; p[1] = p[3] / 3; p[2] = p[3] / 4;
                }
                if (background) for (int row = 0; row < h; ++row)
                    std::memcpy(expected[i].data() + (size_t(y + row) * width + x) * 4,
                        regions[k].pixels + size_t(row) * pitch, size_t(w) * 4);
            }
            input[i].regions = regions.data() + i * views; input[i].count = views;
            assert(full(expected[i].data(), width, height, width * 4, background, &shape));
        }
        assert(batch(input.data(), jobs, width, height, background));
        for (int i = 0; i < jobs; ++i) for (int j = 0; j < views; ++j) {
            int k = i * views + j; auto const& view = regions[k];
            assert(storage[k][0] == 0xA9);
            for (int row = 0; row < h; ++row) {
                assert(!std::memcmp(view.pixels + size_t(row) * pitch,
                    expected[i].data() + (size_t(view.y + row) * width + view.x) * 4, size_t(w) * 4));
                for (int byte = w * 4; byte < pitch; ++byte)
                    assert(view.pixels[size_t(row) * pitch + byte] == 0xA9);
            }
            ++comparisons;
        }
        auto saved = storage;
        auto invalid = input;
        invalid.back().shape.matrix[1] = std::numeric_limits<float>::quiet_NaN();
        assert(!batch(invalid.data(), jobs, width, height, background));
        assert(storage == saved); ++rejections;
        invalid = input; invalid.back().count = 5;
        assert(!batch(invalid.data(), jobs, width, height, background));
        assert(storage == saved); ++rejections;
        auto last = regions.back(); regions.back().pitch = w * 4 - 1;
        assert(!batch(input.data(), jobs, width, height, background));
        assert(storage == saved); ++rejections; regions.back() = last;
    }
    assert(!batch(nullptr, 1, width, height, 1));
    int failure_index = 0;
    if (argc == 4) for (auto* flag : {"VOX_TEST_SHAPE_PARTS_FAIL_AFTER_QUEUE",
            "VOX_TEST_SHAPE_PARTS_FAIL_BEFORE_PUBLISH"}) {
        for (int iteration = 0; iteration < 8; ++iteration) {
            std::vector<uint8_t> pixels[2], expected[2];
            VoxGraphitePixelRegion views[2];
            VoxGraphiteShapeParts input[2] {};
            for (int i = 0; i < 2; ++i) {
                pixels[i].assign(size_t(pitch) * h, 51);
                expected[i].assign(size_t(width) * height * 4, 0);
                for (int y = 0; y < h; ++y)
                    std::memcpy(expected[i].data() + size_t(y) * width * 4,
                        pixels[i].data() + size_t(y) * pitch, w * 4);
                views[i] = {0, 0, w, h, pitch, pixels[i].data()};
                input[i].regions = views + i; input[i].count = 1;
                auto& shape = input[i].shape;
                shape.matrix[0] = shape.matrix[4] = shape.matrix[8] = 1;
                shape.matrix[2] = iteration * .25f + i * .125f + failure_index * .0625f;
                shape.rect[2] = 64; shape.rect[3] = 40;
                shape.fill = 1; shape.alpha = 255; shape.red = 197;
                assert(full(expected[i].data(), width, height, width * 4, 1, &shape));
            }
            auto first = pixels[0], second = pixels[1];
            setenv(flag, "1", 1);
            assert(!batch(input, 2, width, height, 1));
            unsetenv(flag);
            assert(pixels[0] == first && pixels[1] == second);
            assert(batch(input, 2, width, height, 1));
            for (int i = 0; i < 2; ++i) for (int y = 0; y < h; ++y)
                assert(!std::memcmp(pixels[i].data() + size_t(y) * pitch,
                    expected[i].data() + size_t(y) * width * 4, w * 4));
            ++rejections;
        }
        ++failure_index;
    }
    std::printf("Shape parts batch: %zu exact view comparisons, %zu transactional rejections\n",
        comparisons, rejections);
}
