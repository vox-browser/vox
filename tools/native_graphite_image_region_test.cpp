#include "../native/include/native_graphite_raster_cache.h"
#include <cassert>
#include <cstdio>
#include <dlfcn.h>

static VoxGraphiteImage descriptor(uint8_t const* pixels)
{
    VoxGraphiteImage image {};
    image.matrix[0] = image.matrix[4] = image.matrix[8] = 1;
    image.source[2] = image.width = 37;
    image.source[3] = image.height = 29;
    image.destination[2] = image.clip[2] = 240;
    image.destination[3] = image.clip[3] = 120;
    image.pitch = 37 * 4;
    image.opacity = 1;
    image.pixels = pixels;
    return image;
}

static void check_cache()
{
    std::vector<uint8_t> source(37 * 29 * 4, 87), pixels(23 * 7 * 4, 31);
    auto image = descriptor(source.data());
    VoxGraphiteRasterCache cache;
    VoxGraphitePixelRegion view {11, 13, 23, 7, 23 * 4, pixels.data()};
    auto request = cache.prepare_region(image, 544, 256, view, true);
    assert(!request.hit && request.pending);
    std::fill(pixels.begin(), pixels.end(), 123);
    cache.finish(std::move(request), pixels.data(), view.pitch);
    auto hit = [&] { return cache.prepare_region(image, 544, 256, view, true).hit; };
    std::fill(pixels.begin(), pixels.end(), 31);
    auto backdrop = pixels;
    assert(hit() && pixels == std::vector<uint8_t>(pixels.size(), 123));
    pixels = backdrop; ++view.x; assert(!hit()); --view.x;
    ++view.y; assert(!hit()); --view.y;
    assert(!cache.prepare_region(image, 545, 256, view, true).hit);
    assert(!cache.prepare_region(image, 544, 257, view, true).hit);
    assert(!cache.prepare(image, view.width, view.height, view.pitch, true, pixels.data()).hit);
    ++source.back(); assert(!hit()); --source.back();
    ++pixels.back(); assert(!hit()); --pixels.back();
    auto replacement = source; image.pixels = replacement.data();
    assert(hit());
    std::vector<uint8_t> subview(7 * 3 * 4, 31);
    VoxGraphitePixelRegion smaller {14, 15, 7, 3, 7 * 4, subview.data()};
    assert(cache.prepare_region(image, 544, 256, smaller, true).hit);
    assert(subview == std::vector<uint8_t>(subview.size(), 123));
    std::fill(subview.begin(), subview.end(), 31); subview.back() ^= 1;
    assert(!cache.prepare_region(image, 544, 256, smaller, true).hit);
    std::fill(subview.begin(), subview.end(), 31);
    smaller.x = 10; assert(!cache.prepare_region(image, 544, 256, smaller, true).hit);
    smaller.x = 14;
    ++replacement.back(); assert(!cache.prepare_region(image, 544, 256, smaller, true).hit);
    --replacement.back();
    cache.clear(); pixels = backdrop; assert(!hit());
}

int main(int argc, char** argv)
{
    check_cache();
    assert(argc == 3);
    auto control = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    auto candidate = dlopen(argv[2], RTLD_NOW | RTLD_LOCAL);
    if (!control || !candidate) std::fprintf(stderr, "%s\n", dlerror());
    assert(control && candidate);
    auto full = reinterpret_cast<decltype(&vox_graphite_draw_image_pixels)>(
        dlsym(control, "vox_graphite_draw_image_pixels"));
    auto draw = reinterpret_cast<decltype(&vox_graphite_draw_image_region_pixels)>(
        dlsym(candidate, "vox_graphite_draw_image_region_pixels"));
    auto reference_region = reinterpret_cast<decltype(&vox_graphite_draw_image_region_pixels)>(
        dlsym(control, "vox_graphite_draw_image_region_pixels"));
    auto clear = reinterpret_cast<decltype(&vox_graphite_release_unused_graphics_memory)>(
        dlsym(candidate, "vox_graphite_release_unused_graphics_memory"));
    assert(full && draw && reference_region && clear);
    constexpr int width = 544, height = 256;
    constexpr int crops[][4] {{0, 0, width, height}, {1, 1, 17, 3},
        {57, 23, 81, 37}, {512, 220, 32, 36}};
    size_t comparisons = 0;
    for (int flags : {0, 1, 4, 4 | 8, 4 | 16})
    for (int scale : {1, 2}) for (int background : {0, 1})
    for (int msaa : {0, 1}) for (int fractional : {0, 1})
    for (auto const& crop : crops) {
        std::vector<uint8_t> source(37 * 29 * 4);
        for (size_t i = 0; i < source.size(); ++i) source[i] = uint8_t(i * 37 + i / 11);
        if (flags & 1) for (size_t i = 0; i < source.size(); i += 4)
            for (int c = 0; c < 3; ++c) source[i + c] = source[i + c] * source[i + 3] / 255;
        auto image = descriptor(source.data());
        image.flags = flags | (msaa ? VOX_GRAPHITE_IMAGE_FORCE_MSAA : 0);
        image.matrix[0] = image.matrix[4] = scale;
        image.matrix[2] = fractional ? -.375f : 0;
        image.matrix[5] = fractional ? .25f : 0;
        image.source[0] = 2; image.source[1] = 3;
        image.source[2] = 31; image.source[3] = 23;
        int x = crop[0], y = crop[1], w = crop[2], h = crop[3], pitch = w * 4 + 13;
        for (int pass : {0, 1, 2}) {
            image.opacity = pass == 2 ? .35f : .8f;
            if (pass == 1) {
                image.clip[0] = 5; image.clip[1] = 8;
                image.clip[2] = 210; image.clip[3] = 95;
                std::fill(image.clip + 4, image.clip + 12, 3.5f);
                image.has_color_profile = 1; image.color_profile[0] = 2.2f;
            }
            if (pass == 2) {
                size_t last = flags & 4 ? 37 * 29 + 2 * 19 * 15 - 1 : source.size() - 1;
                source[last] ^= 1;
            }
            for (int warm : {0, 1}) {
                (void)warm;
                std::vector<uint8_t> actual(1 + size_t(pitch) * h, 0xA9);
                std::vector<uint8_t> expected(size_t(width) * height * 4);
                for (int row = 0; row < h; ++row) for (int col = 0; col < w; ++col) {
                    auto* p = actual.data() + 1 + size_t(row) * pitch + col * 4;
                    p[0] = uint8_t(col * 17 + row * 7 + pass);
                    p[1] = uint8_t(col * 11 + row * 13);
                    p[2] = uint8_t(col * 5 + row * 19); p[3] = 255;
                }
                for (int row = 0; row < h; ++row)
                    std::memcpy(expected.data() + (size_t(y + row) * width + x) * 4,
                        actual.data() + 1 + size_t(row) * pitch, size_t(w) * 4);
                assert(full(expected.data(), width, height, width * 4, background, &image));
                VoxGraphitePixelRegion view {x, y, w, h, pitch, actual.data() + 1};
                assert(draw(&view, width, height, background, &image));
                for (int row = 0; row < h; ++row) {
                    if (std::memcmp(actual.data() + 1 + size_t(row) * pitch,
                            expected.data() + (size_t(y + row) * width + x) * 4, size_t(w) * 4)) {
                        std::fprintf(stderr, "Mismatch flags=%d scale=%d bg=%d msaa=%d fractional=%d crop=%d,%d,%d,%d pass=%d warm=%d\n",
                            flags, scale, background, msaa, fractional, x, y, w, h, pass, warm);
                        return 1;
                    }
                    for (int i = w * 4; i < pitch; ++i)
                        assert(actual[1 + size_t(row) * pitch + i] == 0xA9);
                }
                assert(actual[0] == 0xA9); ++comparisons;
            }
        }
        clear();
    }
    // Populate a larger view, then request every edge and interior subview.
    // Retain identical GPU coordinates, source bytes and cropped backgrounds.
    for (int msaa : {0, 1}) for (int background : {0, 1}) for (int pass : {0, 1, 2}) {
        std::vector<uint8_t> source(37 * 29 * 4, 79);
        auto image = descriptor(source.data());
        image.flags = msaa ? VOX_GRAPHITE_IMAGE_FORCE_MSAA : 0;
        image.matrix[2] = -.375f; image.matrix[5] = .25f;
        std::vector<uint8_t> original(240 * 120 * 4);
        for (size_t i = 0; i < original.size(); ++i) original[i] = uint8_t(i * 31 + i / 7);
        for (size_t i = 3; i < original.size(); i += 4) original[i] = 255;
        auto large = original;
        VoxGraphitePixelRegion parent {11, 13, 240, 120, 240 * 4, large.data()};
        assert(draw(&parent, width, height, background, &image));
        if (pass == 1) source.back() ^= 3;
        if (pass == 2) image.opacity = .35f;
        for (int x : {0, 1, 127, 223}) for (int y : {0, 1, 71, 117}) {
            int w = 240 - x, h = 120 - y, pitch = w * 4 + 7;
            std::vector<uint8_t> expected(size_t(pitch) * h, 0xA9);
            for (int row = 0; row < h; ++row)
                std::memcpy(expected.data() + size_t(row) * pitch,
                    original.data() + (size_t(row + y) * 240 + x) * 4, size_t(w) * 4);
            if (pass == 2) expected[0] ^= 17;
            auto actual = expected;
            VoxGraphitePixelRegion before {11 + x, 13 + y, w, h, pitch, expected.data()};
            VoxGraphitePixelRegion after {11 + x, 13 + y, w, h, pitch, actual.data()};
            assert(reference_region(&before, width, height, background, &image));
            assert(draw(&after, width, height, background, &image));
            assert(expected == actual); ++comparisons;
        }
        clear();
    }
    std::vector<uint8_t> pixels(64 * 32 * 4, 71), source(37 * 29 * 4);
    auto untouched = pixels;
    auto image = descriptor(source.data());
    VoxGraphitePixelRegion view {0, 0, 64, 32, 256, pixels.data()};
    view.x = width; assert(!draw(&view, width, height, 1, &image));
    view.x = 0; view.pitch = 1; assert(!draw(&view, width, height, 1, &image));
    view.pitch = 256; image.pixels = nullptr; assert(!draw(&view, width, height, 1, &image));
    assert(pixels == untouched);
    std::printf("Image regions: %zu exact cold/warm GPU comparisons; cache origins, sources, backdrops, profiles, clips, MSAA and padding passed\n", comparisons);
}
