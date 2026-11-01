#include "../native_graphite_bridge.h"
#include <algorithm>
#include <cassert>
#include <cstdio>
#include <cstring>
#include <dlfcn.h>
#include <limits>
#include <vector>

int main(int argc, char** argv)
{
    assert(argc == 3);
    auto* control = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    auto* candidate = dlopen(argv[2], RTLD_NOW | RTLD_LOCAL);
    assert(control && candidate);
    auto full = reinterpret_cast<decltype(&vox_graphite_draw_shape_pixels)>(
        dlsym(control, "vox_graphite_draw_shape_pixels"));
    auto draw = reinterpret_cast<decltype(&vox_graphite_draw_rounded_parts_pixels)>(
        dlsym(candidate, "vox_graphite_draw_rounded_parts_pixels"));
    assert(full && draw);
    constexpr int width = 544, height = 256;
    constexpr int crops[][4] {{0, 0, 91, 59}, {40, 12, 1, 1},
        {1, 1, 17, 3}, {230, 117, 87, 41}, {512, 220, 32, 36}};
    constexpr float rects[][4] {{20, 12, 400, 180}, {-60, -24, 500, 280},
        {530, 248, 30, 14}};
    size_t comparisons = 0, rejected = 0;
    for (int scale : {1, 2}) for (int msaa : {0, 1}) for (int background : {0, 1})
    for (int translate : {0, -17, 31}) for (auto const& rect : rects)
    for (auto const& crop : crops) for (int color : {35}) for (int floating : {0, 1})
    for (int fill : {0, 1}) for (float radius : {3.f, 7.f}) for (float fraction : {0.f, .25f}) {
        VoxGraphiteShape shape {};
        shape.matrix[0] = shape.matrix[4] = scale; shape.matrix[8] = 1;
        shape.matrix[2] = translate; shape.matrix[5] = -translate;
        std::copy_n(rect, 4, shape.rect);
        shape.rect[0] += fraction; shape.rect[1] -= fraction;
        for (int corner = 4; corner < 12; ++corner) shape.rect[corner] = radius + (corner % 3);
        shape.fill = fill; shape.thickness = 2.f / scale; shape.anti_alias = 1; shape.force_msaa = msaa;
        shape.red = color; shape.green = 167; shape.blue = 79; shape.alpha = 255;
        shape.has_float_color = floating;
        shape.float_color[0] = color * (1.f / 255);
        shape.float_color[1] = 167 * (1.f / 255);
        shape.float_color[2] = 79 * (1.f / 255); shape.float_color[3] = 1;
        int x = crop[0], y = crop[1], w = crop[2], h = crop[3], pitch = w * 4 + 13;
        // One-byte offset and odd row stride exercise unaligned compact views.
        std::vector<uint8_t> storage(1 + size_t(pitch) * h, 0xA9);
        for (int row = 0; row < h; ++row) for (int col = 0; col < w; ++col) {
            auto* p = storage.data() + 1 + size_t(row) * pitch + col * 4;
            p[0] = uint8_t(col * 17 + row * 7); p[1] = uint8_t(col * 11 + row * 13);
            p[2] = uint8_t(col * 5 + row * 19); p[3] = 255;
        }
        std::vector<uint8_t> expected(size_t(width) * height * 4);
        for (int row = 0; row < h; ++row)
            std::memcpy(expected.data() + (size_t(y + row) * width + x) * 4,
                storage.data() + 1 + size_t(row) * pitch, size_t(w) * 4);
        assert(full(expected.data(), width, height, width * 4, background, &shape));
        VoxGraphitePixelRegion region {x, y, w, h, pitch, storage.data() + 1};
        auto saved = storage;
        if (!draw(&region, 1, width, height, background, &shape)) {
            assert(storage == saved);
            ++rejected;
            continue;
        }
        assert(storage[0] == 0xA9);
        for (int row = 0; row < h; ++row) {
            assert(!std::memcmp(storage.data() + 1 + size_t(row) * pitch,
                expected.data() + (size_t(y + row) * width + x) * 4, size_t(w) * 4));
            for (int byte = w * 4; byte < pitch; ++byte)
                assert(storage[1 + size_t(row) * pitch + byte] == 0xA9);
        }
        ++comparisons;
    }
    for (int scale : {1, 2}) for (int msaa : {0, 1}) for (int background : {0, 1})
    for (int stroke : {0, 1, 2}) for (int mutation : {0, 1, 2}) {
        VoxGraphiteShape shape {};
        shape.matrix[0] = shape.matrix[4] = scale; shape.matrix[8] = 1;
        shape.rect[0] = 20.f / scale; shape.rect[1] = 12.f / scale;
        shape.rect[2] = 400.f / scale; shape.rect[3] = 180.f / scale;
        for (int i = 4; i < 12; ++i) shape.rect[i] = 3 + i % 3;
        shape.fill = stroke == 0; shape.anti_alias = 1; shape.force_msaa = msaa;
        shape.thickness = (stroke == 2 ? 1.f : 2.f) / scale;
        if (stroke == 2) { shape.rect[0] += .5f / scale; shape.rect[1] += .5f / scale; }
        shape.alpha = 255; shape.red = 197; shape.green = 37; shape.blue = 83;
        constexpr int locations[][2] {{16, 8}, {400, 8}, {16, 172}, {400, 172}};
        constexpr int w = 24, h = 24, pitch = w * 4 + 13;
        std::vector<uint8_t> storage[4];
        VoxGraphitePixelRegion views[4];
        std::vector<uint8_t> expected(size_t(width) * height * 4);
        for (int i = 0; i < 4; ++i) {
            storage[i].assign(1 + pitch * h, 0xa9);
            views[i] = {locations[i][0], locations[i][1], w, h, pitch, storage[i].data() + 1};
            for (int y = 0; y < h; ++y) for (int x = 0; x < w; ++x) {
                auto* p = views[i].pixels + y * pitch + x * 4;
                p[3] = uint8_t((x * 17 + y * 19 + i * 7 + mutation * 23) % 256);
                p[0] = p[3] / 2; p[1] = p[3] / 3; p[2] = p[3] / 4;
            }
            for (int y = 0; y < h; ++y)
                std::memcpy(expected.data() + (size_t(views[i].y + y) * width + views[i].x) * 4,
                    views[i].pixels + y * pitch, w * 4);
        }
        assert(full(expected.data(), width, height, width * 4, background, &shape));
        assert(draw(views, 4, width, height, background, &shape));
        for (int i = 0; i < 4; ++i) {
            assert(storage[i][0] == 0xa9);
            for (int y = 0; y < h; ++y) {
                assert(!std::memcmp(views[i].pixels + y * pitch,
                    expected.data() + (size_t(views[i].y + y) * width + views[i].x) * 4, w * 4));
                for (int b = w * 4; b < pitch; ++b) assert(views[i].pixels[y * pitch + b] == 0xa9);
            }
        }
        std::vector<uint8_t> saved[4];
        for (int i = 0; i < 4; ++i) saved[i] = storage[i];
        auto unchanged = [&] {
            for (int i = 0; i < 4; ++i) assert(storage[i] == saved[i]);
        };
        auto original_x = views[1].x, original_y = views[1].y;
        views[1].x = views[0].x; views[1].y = views[0].y;
        assert(!draw(views, 4, width, height, background, &shape));
        unchanged();
        views[1].x = original_x; views[1].y = original_y;
        assert(!draw(views, 0, width, height, background, &shape));
        unchanged();
        views[0].pitch = w * 4 - 1;
        assert(!draw(views, 4, width, height, background, &shape));
        unchanged();
        views[0].pitch = pitch;
        if (stroke) {
            auto valid = shape;
            // Fractional thin strokes retain every covered edge from the GPU.
            // Compare all four compact views with the unchanged full renderer.
            for (float thickness : {.25f, .75f}) {
                shape = valid;
                shape.thickness = thickness / scale;
                std::fill(expected.begin(), expected.end(), 0);
                for (int i = 0; i < 4; ++i) for (int y = 0; y < h; ++y)
                    std::memcpy(expected.data() + (size_t(views[i].y + y) * width + views[i].x) * 4,
                        views[i].pixels + y * pitch, w * 4);
                assert(full(expected.data(), width, height, width * 4, background, &shape));
                assert(draw(views, 4, width, height, background, &shape));
                for (int i = 0; i < 4; ++i) {
                    assert(storage[i][0] == 0xa9);
                    for (int y = 0; y < h; ++y) {
                        assert(!std::memcmp(views[i].pixels + y * pitch,
                            expected.data() + (size_t(views[i].y + y) * width + views[i].x) * 4, w * 4));
                        for (int b = w * 4; b < pitch; ++b) assert(views[i].pixels[y * pitch + b] == 0xa9);
                    }
                    std::copy(saved[i].begin(), saved[i].end(), storage[i].begin());
                }
                ++comparisons;
            }
            for (int defect : {0, 1, 2, 3, 5, 6, 7}) {
                shape = valid;
                if (defect == 0) shape.thickness = 0;
                if (defect == 1) shape.thickness = -1;
                if (defect == 2) shape.thickness = std::numeric_limits<float>::infinity();
                if (defect == 3) shape.thickness = std::numeric_limits<float>::quiet_NaN();
                if (defect == 5) shape.rect[2] = shape.thickness / 2;
                if (defect == 6) shape.has_underlay = 1;
                if (defect == 7) shape.alpha = 128;
                assert(!draw(views, 4, width, height, background, &shape));
                unchanged();
            }
        }
        ++comparisons;
    }
    assert(comparisons >= 3300 && rejected > 0);
    std::printf("Unsupported rounded-part cases preserved: %zu\n", rejected);
    std::printf("Rounded shape parts: %zu exact original-renderer comparisons passed\n", comparisons);
}
