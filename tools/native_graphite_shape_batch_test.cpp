#include "../native_graphite_bridge.h"
#include <cassert>
#include <cstdio>
#include <cstring>
#include <dlfcn.h>
#include <vector>

int main(int argc, char** argv)
{
    assert(argc == 3);
    void* control = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    void* candidate = dlopen(argv[2], RTLD_NOW | RTLD_LOCAL);
    if (!control || !candidate) { std::fprintf(stderr, "%s\n", dlerror()); return 1; }
    auto full = reinterpret_cast<decltype(&vox_graphite_draw_shape_pixels)>(
        dlsym(control, "vox_graphite_draw_shape_pixels"));
    auto batch = reinterpret_cast<decltype(&vox_graphite_draw_shape_regions_pixels)>(
        dlsym(candidate, "vox_graphite_draw_shape_regions_pixels"));
    auto finish_control = reinterpret_cast<void(*)()>(dlsym(control, "vox_graphite_finish_frame"));
    auto finish = reinterpret_cast<void(*)()>(dlsym(candidate, "vox_graphite_finish_frame"));
    auto clear = reinterpret_cast<void(*)()>(dlsym(candidate, "vox_graphite_release_unused_graphics_memory"));
    assert(full && batch && finish_control && finish && clear);
    size_t comparisons = 0;
    constexpr int width = 544, height = 256, vw = 130, vh = 96, pitch = vw * 4 + 13;
    for (int count : {2, 3, 8}) for (int scale : {1, 2}) for (int msaa : {0, 1})
    for (int background : {0, 1}) for (int fill : {0, 1, 2, 3, 4, 5})
    for (int fractional : {0, 1}) for (int rounded : {0, 1}) {
        std::vector<VoxGraphiteShape> shapes(count);
        std::vector<VoxGraphitePixelRegion> regions(count);
        std::vector<std::vector<uint8_t>> backdrops(count, std::vector<uint8_t>(pitch * vh, 0xA9));
        for (int i = 0; i < count; ++i) {
            auto& shape = shapes[i];
            shape.matrix[0] = shape.matrix[4] = scale; shape.matrix[8] = 1;
            shape.matrix[2] = 20 + i * 3 + (fractional ? .37f : 0);
            shape.matrix[5] = i % 3 == 0 ? -11.25f : 43.125f;
            shape.rect[0] = .25f; shape.rect[1] = 1.125f;
            shape.rect[2] = 27; shape.rect[3] = 19;
            if (rounded) for (int n = 4; n < 12; ++n) shape.rect[n] = 3.75f;
            shape.fill = fill; shape.thickness = 1.75f; shape.anti_alias = 1;
            for (float& border : shape.border_widths) border = 1.75f;
            shape.force_msaa = msaa ^ (i % 2); shape.red = 197; shape.green = 73;
            shape.blue = 111; shape.alpha = uint8_t(i % 2 ? 97 : 255);
            shape.has_float_color = 1;
            shape.float_color[0] = .7713f; shape.float_color[1] = .2861f;
            shape.float_color[2] = .4367f; shape.float_color[3] = shape.alpha / 255.f;
            regions[i] = {13 + i % 3, 17, vw, vh, pitch, nullptr};
            for (int y = 0; y < vh; ++y) for (int x = 0; x < vw; ++x) {
                auto* pixel = backdrops[i].data() + y * pitch + x * 4;
                pixel[0] = uint8_t((x + i * 17) % 91); pixel[1] = uint8_t(y % 113);
                pixel[2] = 41; pixel[3] = uint8_t(i % 2 ? 173 : 255);
            }
        }
        for (int pass = 0; pass < 4; ++pass) {
            if (pass == 2) for (auto& backdrop : backdrops) backdrop[3 * pitch + 7] ^= 0x15;
            if (pass == 3) for (auto& shape : shapes) shape.matrix[5] += .125f;
            auto actual = backdrops;
            std::vector<std::vector<uint8_t>> expected(count, std::vector<uint8_t>(width * height * 4));
            for (int i = 0; i < count; ++i) {
                regions[i].pixels = actual[i].data();
                if (background) for (int y = 0; y < vh; ++y)
                    std::memcpy(expected[i].data() + (size_t(y + regions[i].y) * width + regions[i].x) * 4,
                        backdrops[i].data() + size_t(y) * pitch, vw * 4);
                assert(full(expected[i].data(), width, height, width * 4, background, &shapes[i]));
            }
            assert(batch(regions.data(), shapes.data(), count, width, height, background));
            for (int i = 0; i < count; ++i) for (int y = 0; y < vh; ++y) {
                assert(!std::memcmp(actual[i].data() + size_t(y) * pitch,
                    expected[i].data() + (size_t(y + regions[i].y) * width + regions[i].x) * 4, vw * 4));
                for (int n = vw * 4; n < pitch; ++n) assert(actual[i][size_t(y) * pitch + n] == 0xA9);
            }
            comparisons += count;
            finish_control(); finish();
        }
        // A failure in the last tile cannot publish earlier tiles.
        auto actual = backdrops;
        for (int i = 0; i < count; ++i) regions[i].pixels = actual[i].data();
        shapes.back().has_underlay = 1;
        assert(!batch(regions.data(), shapes.data(), count, width, height, 1));
        shapes.back().has_underlay = 0;
        regions.back().pitch = 1;
        assert(!batch(regions.data(), shapes.data(), count, width, height, 1));
        assert(actual == backdrops);
    }
    std::vector<uint8_t> pixels(64 * 64 * 4, 71);
    auto untouched = pixels;
    VoxGraphitePixelRegion region{0, 0, 64, 64, 64 * 4, pixels.data()};
    VoxGraphiteShape shape{};
    shape.matrix[0] = shape.matrix[4] = shape.matrix[8] = 1;
    shape.rect[2] = 13; shape.rect[3] = 9; shape.fill = 1; shape.alpha = 255;
    assert(!batch(nullptr, &shape, 1, width, height, 1));
    assert(!batch(&region, nullptr, 1, width, height, 1));
    assert(!batch(&region, &shape, 0, width, height, 1));
    assert(!batch(&region, &shape, 65, width, height, 1));
    assert(!batch(&region, &shape, 1, 2048, 2048, 1));
    assert(!batch(&region, &shape, 33, 512, 512, 1));
    assert(pixels == untouched);
    // Exercise the maximum job count, including cache hits within one batch.
    std::vector<VoxGraphitePixelRegion> many_regions(64, region);
    std::vector<VoxGraphiteShape> many_shapes(64, shape);
    std::vector<std::vector<uint8_t>> many_pixels(64, untouched);
    for (int i = 0; i < 64; ++i) many_regions[i].pixels = many_pixels[i].data();
    std::vector<uint8_t> full_pixels = untouched;
    assert(full(full_pixels.data(), 64, 64, 64 * 4, 1, &shape));
    for (int pass = 0; pass < 2; ++pass) {
        assert(batch(many_regions.data(), many_shapes.data(), 64, 64, 64, 1));
        for (auto const& actual : many_pixels) assert(actual == full_pixels);
        for (auto& actual : many_pixels) actual = untouched;
    }
    comparisons += 128;
    clear();
    assert(batch(&region, &shape, 1, width, height, 1));
    auto expected = pixels;
    clear();
    assert(batch(&region, &shape, 1, width, height, 1));
    assert(pixels == expected);
    finish();
    std::printf("Graphite shape batches: %zu exact GPU tile comparisons and teardown replay passed\n", comparisons);
}
