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
    auto reference = reinterpret_cast<decltype(&vox_graphite_draw_shape_pixels)>(
        dlsym(control, "vox_graphite_draw_shape_pixels"));
    auto draw = reinterpret_cast<decltype(&vox_graphite_draw_shape_pixels)>(
        dlsym(candidate, "vox_graphite_draw_shape_pixels"));
    assert(reference && draw);
    auto release_reference = reinterpret_cast<decltype(&vox_graphite_release_unused_graphics_memory)>(
        dlsym(control, "vox_graphite_release_unused_graphics_memory"));
    auto release_candidate = reinterpret_cast<decltype(&vox_graphite_release_unused_graphics_memory)>(
        dlsym(candidate, "vox_graphite_release_unused_graphics_memory"));
    assert(release_reference && release_candidate);
    constexpr int width = 544, height = 256, pitch = width * 4 + 13;
    constexpr float rects[][4] {{20, 12, 400, 180}, {20, -128, 400, 512}, {-64, 12, 672, 180}};
    size_t comparisons = 0;
    for (int scale : {1, 2}) for (int msaa : {0, 1}) for (int background : {0, 1})
    for (auto const& rect : rects) for (float fraction_x : {0.f, .25f})
    for (float fraction_y : {0.f, .2f, .5f}) for (int fill : {0, 1})
    for (int floating : {0, 1}) for (int alpha : {127, 255}) for (int aa : {0, 1}) {
        VoxGraphiteShape shape {};
        shape.matrix[0] = shape.matrix[4] = scale; shape.matrix[8] = 1;
        for (int i = 0; i < 4; ++i) shape.rect[i] = rect[i] / scale;
        shape.matrix[2] = fraction_x; shape.matrix[5] = fraction_y;
        for (int i = 4; i < 12; ++i) shape.rect[i] = rect[0] < 0 ? 0 : (3 + i % 3) / float(scale);
        shape.fill = fill; shape.thickness = 2.f / scale;
        shape.anti_alias = aa; shape.force_msaa = msaa;
        shape.red = 35; shape.green = 167; shape.blue = 79; shape.alpha = alpha;
        shape.has_float_color = floating;
        shape.float_color[0] = 35 * (1.f / 255);
        shape.float_color[1] = 167 * (1.f / 255);
        shape.float_color[2] = 79 * (1.f / 255);
        shape.float_color[3] = alpha * (1.f / 255);
        // Repeated identical and changed backdrops exercise cached patch identity.
        for (int mutation : {0, 0, 1}) {
            std::vector<uint8_t> expected(1 + size_t(pitch) * height, 0xa9);
            for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x) {
                auto* pixel = expected.data() + 1 + size_t(y) * pitch + x * 4;
                pixel[3] = uint8_t((x * 17 + y * 19 + mutation * 23) % 256);
                pixel[0] = pixel[3] / 2; pixel[1] = pixel[3] / 3; pixel[2] = pixel[3] / 4;
            }
            auto actual = expected;
            assert(reference(expected.data() + 1, width, height, pitch, background, &shape));
            assert(draw(actual.data() + 1, width, height, pitch, background, &shape));
            if (actual != expected) {
                auto mismatch = std::mismatch(actual.begin(), actual.end(), expected.begin());
                std::fprintf(stderr, "case=%zu scale=%d msaa=%d bg=%d fill=%d float=%d alpha=%d x=%g y=%g byte=%zu expected=%u actual=%u\n",
                    comparisons, scale, msaa, background, fill, floating, alpha,
                    fraction_x, fraction_y, size_t(mismatch.first - actual.begin()), *mismatch.second, *mismatch.first);
                return 1;
            }
            assert(actual.front() == 0xa9);
            for (int y = 0; y < height; ++y) for (int b = width * 4; b < pitch; ++b)
                assert(actual[1 + size_t(y) * pitch + b] == 0xa9);
            ++comparisons;
        }
    }
    // Recreate both contexts after populated draw/recorder caches have retired.
    // Alternate dimensions to reuse and evict different render-target resources.
    for (int epoch = 0; epoch < 3; ++epoch) {
        release_reference(); release_candidate();
        for (int w : {544, 900, 544}) for (int h : {256, 400})
        for (int msaa : {0, 1}) for (int fill : {0, 1}) {
            VoxGraphiteShape shape {};
            shape.matrix[0] = shape.matrix[4] = shape.matrix[8] = 1;
            shape.rect[0] = 20.25f; shape.rect[1] = 12.2f;
            shape.rect[2] = w - 50.f; shape.rect[3] = h - 30.f;
            std::fill_n(shape.rect + 4, 8, 7.5f);
            shape.thickness = 1; shape.anti_alias = 1; shape.force_msaa = msaa;
            shape.fill = fill; shape.alpha = 255;
            shape.red = 35; shape.green = 167; shape.blue = uint8_t(79 + epoch);
            std::vector<uint8_t> expected(size_t(w) * h * 4, 255), actual = expected;
            assert(reference(expected.data(), w, h, w * 4, 1, &shape));
            assert(draw(actual.data(), w, h, w * 4, 1, &shape));
            assert(actual == expected);
            ++comparisons;
        }
    }
    std::printf("%zu full rounded-shape comparisons are byte-exact\n", comparisons);
}
