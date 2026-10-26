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
    void* control = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    void* candidate = dlopen(argv[2], RTLD_NOW | RTLD_LOCAL);
    assert(control && candidate);
    auto full = reinterpret_cast<decltype(&vox_graphite_draw_shape_pixels)>(
        dlsym(control, "vox_graphite_draw_shape_pixels"));
    auto region_draw = reinterpret_cast<decltype(&vox_graphite_draw_shape_region_pixels)>(
        dlsym(candidate, "vox_graphite_draw_shape_region_pixels"));
    auto finish = reinterpret_cast<decltype(&vox_graphite_finish_frame)>(
        dlsym(candidate, "vox_graphite_finish_frame"));
    auto finish_control = reinterpret_cast<decltype(&vox_graphite_finish_frame)>(
        dlsym(control, "vox_graphite_finish_frame"));
    auto clear = reinterpret_cast<decltype(&vox_graphite_release_unused_graphics_memory)>(
        dlsym(candidate, "vox_graphite_release_unused_graphics_memory"));
    assert(full && region_draw && finish && finish_control && clear);
    size_t comparisons = 0;
    constexpr int width = 544, height = 256;
    for (int scale : {1, 2}) for (int msaa : {0, 1}) for (int background : {0, 1})
    for (int fill : {0, 1}) for (int alpha : {97, 255}) for (bool rounded : {false, true})
    for (bool fractional : {false, true}) for (int crop : {0, 1, 2, 3})
    for (int compound : {0, 1, 2, 3}) {
        VoxGraphiteShape shape {};
        shape.matrix[0] = shape.matrix[4] = scale; shape.matrix[8] = 1;
        shape.matrix[2] = fractional ? -.375f : 0;
        // Include the float phase produced by real precise wheel input.
        shape.matrix[5] = fractional ? -25.200001f : 0;
        float rect[] {33, 17, 40, 12, 5, 4, 2, 3, 3, 2, 4, 5};
        std::copy_n(rect, rounded ? 12 : 4, shape.rect);
        shape.fill = fill; shape.thickness = fractional ? 1.25f : 2;
        shape.red = 35; shape.green = 167; shape.blue = 79; shape.alpha = alpha;
        shape.anti_alias = 1; shape.force_msaa = msaa;
        shape.has_float_color = fractional;
        float color[] {.137f, .655f, .31f, alpha / 255.f};
        std::copy_n(color, 4, shape.float_color);
        shape.has_underlay = compound & 1;
        float underlay[] {27, 13, 52, 22, 6, 5, 3, 4, 4, 3, 5, 6};
        std::copy_n(underlay, 12, shape.underlay_rect);
        uint8_t underlay_color[] {71, 97, 131, 173};
        std::copy_n(underlay_color, 4, shape.underlay_rgba);
        std::vector<float> clips {39, 18, 46, 32, 60, 11, 64, 25};
        shape.clip_out_count = compound & 2 ? 2 : 0;
        int x = crop == 1 ? 40 * scale : crop == 2 ? 200 : 20 * scale;
        int y = crop == 1 ? 20 * scale : crop == 2 ? 100 : 10 * scale;
        int view_width = crop == 3 ? 19 : 80 * scale;
        int view_height = crop == 3 ? 11 : 40 * scale;
        int pitch = view_width * 4 + 13;
        std::vector<uint8_t> backdrop(size_t(pitch) * view_height, 0xA9);
        for (int row = 0; row < view_height; ++row) for (int col = 0; col < view_width; ++col) {
            auto* p = backdrop.data() + size_t(row) * pitch + col * 4;
            p[0] = (col * 17 + row * 7) % 256;
            p[1] = (col * 11 + row * 13) % 256;
            p[2] = (col * 5 + row * 19) % 256;
            p[3] = 255;
        }
        // Miss/hit, a backdrop change, mutated borrowed clip bytes, then a
        // different allocation with those same bytes and a changed transform.
        for (int pass = 0; pass < 7; ++pass) {
            if (pass == 2) backdrop[0] ^= 31;
            if (pass == 4) clips[0] += 11;
            if (pass == 5) { auto replacement = clips; clips.swap(replacement); }
            if (pass == 6) shape.matrix[2] += .125f;
            shape.clip_outs = shape.clip_out_count ? clips.data() : nullptr;
            std::vector<uint8_t> expected(size_t(width) * height * 4);
            for (int row = 0; row < view_height; ++row)
                std::memcpy(expected.data() + (size_t(y + row) * width + x) * 4,
                    backdrop.data() + size_t(row) * pitch, size_t(view_width) * 4);
            assert(full(expected.data(), width, height, width * 4, background, &shape));
            auto actual = backdrop;
            VoxGraphitePixelRegion region {x, y, view_width, view_height, pitch, actual.data()};
            assert(region_draw(&region, width, height, background, &shape));
            for (int row = 0; row < view_height; ++row) {
                assert(!std::memcmp(actual.data() + size_t(row) * pitch,
                    expected.data() + (size_t(y + row) * width + x) * 4, size_t(view_width) * 4));
                for (int byte = view_width * 4; byte < pitch; ++byte)
                    assert(actual[size_t(row) * pitch + byte] == 0xA9);
            }
            ++comparisons;
            finish_control();
            finish();
        }
    }
    // Unsupported geometry and invalid views decline without changing caller
    // bytes, allowing the ordinary full-tile renderer to supply the fallback.
    std::vector<uint8_t> pixels(64 * 32 * 4, 71);
    auto untouched = pixels;
    VoxGraphitePixelRegion region {0, 0, 64, 32, 64 * 4, pixels.data()};
    VoxGraphiteShape shape {};
    shape.matrix[0] = shape.matrix[4] = shape.matrix[8] = 1;
    shape.rect[2] = 20; shape.rect[3] = 10; shape.fill = 1; shape.alpha = 255;
    shape.has_underlay = 1;
    assert(!region_draw(&region, width, height, 1, &shape));
    shape.has_underlay = 0;
    shape.clip_outs = nullptr; shape.clip_out_count = 1;
    assert(!region_draw(&region, width, height, 1, &shape));
    float clip[] {0, 0, 10, std::numeric_limits<float>::quiet_NaN()};
    shape.clip_outs = clip;
    assert(!region_draw(&region, width, height, 1, &shape));
    shape.clip_out_count = -1;
    assert(!region_draw(&region, width, height, 1, &shape));
    shape.clip_out_count = 0; shape.matrix[1] = .25f;
    assert(!region_draw(&region, width, height, 1, &shape));
    shape.matrix[1] = 0; region.x = width;
    assert(!region_draw(&region, width, height, 1, &shape));
    region.x = 0; region.pitch = 1;
    assert(!region_draw(&region, width, height, 1, &shape));
    assert(pixels == untouched);
    clear();
    region.pitch = 64 * 4;
    assert(region_draw(&region, width, height, 1, &shape));
    clear();
    auto expected = pixels;
    assert(region_draw(&region, width, height, 1, &shape));
    // This opaque fill is idempotent even after context/cache teardown.
    assert(pixels == expected);
    finish();
    std::printf("Graphite shape regions: %zu exact GPU comparisons and teardown replay passed\n", comparisons);
}
