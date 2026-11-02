#include "../native_graphite_raster_cache.h"
#include <cassert>
#include <cstdlib>
#include <iostream>
#include <memory>

int main(int argc, char** argv)
{
    if (argc == 3 && !std::strcmp(argv[1], "--policy")) {
        assert(vox_opaque_rgba_image_cache_enabled() == (argv[2][0] == '1'));
        return 0;
    }
    assert(argc == 1);
    setenv("VOX_ENABLE_OPAQUE_RGBA_IMAGE_CACHE", "1", 1);
    unsetenv("VOX_DISABLE_OPAQUE_RGBA_IMAGE_CACHE");
    constexpr int size = 64, source_pitch = size * 4 + 13;
    std::vector<uint8_t> source(source_pitch * size, 0xA9);
    for (int y = 0; y < size; ++y) for (int x = 0; x < size; ++x) {
        auto* p = source.data() + y * source_pitch + x * 4;
        p[0] = 73; p[1] = 91; p[2] = 137; p[3] = 255;
    }
    VoxGraphiteImage image {};
    image.matrix[0] = image.matrix[4] = image.matrix[8] = 1;
    image.source[2] = image.source[3] = size;
    image.destination[0] = image.destination[1] = 4;
    image.destination[2] = image.destination[3] = 56;
    image.clip[2] = image.clip[3] = size;
    image.width = image.height = size; image.pitch = source_pitch;
    image.opacity = 1; image.flags = 1; image.pixels = source.data();
    constexpr int pitch = size * 4 + 17;
    for (int pattern : {0, 1, 2}) {
        std::vector<uint8_t> pixels(pitch * size, 31);
        for (int y = 0; y < size; ++y) for (int x = 0; x < size * 4; ++x)
            if (pattern == 1 || (pattern == 2 && y >= size / 2))
                pixels[y * pitch + x] = uint8_t(y * 73 + x * 17);
        auto original = pixels;
        VoxGraphiteRasterCache cache;
        VoxGraphitePixelRegion view {0, 0, size, size, pitch, pixels.data()};
        auto miss = cache.prepare_region(image, size, size, view, true);
        assert(miss.pending && !miss.hit);
        for (int y = 0; y < size; ++y) std::fill_n(pixels.data() + y * pitch, size * 4, 117);
        cache.finish(std::move(miss), pixels.data(), pitch);
        auto reset = [&] { pixels = original; view.pixels = pixels.data(); };
        reset(); pixels[20 * pitch + 20 * 4]++;
        assert(cache.prepare_region(image, size, size, view, true).hit);
        for (int y = 0; y < size; ++y) {
            for (int x = 0; x < size * 4; ++x) assert(pixels[y * pitch + x] == 117);
            for (int x = size * 4; x < pitch; ++x) assert(pixels[y * pitch + x] == 31);
        }
        reset(); pixels[4 * pitch + 4 * 4]++;
        auto saved = pixels;
        assert(!cache.prepare_region(image, size, size, view, true).hit && pixels == saved);
        reset(); pixels[20 * pitch + 20 * 4]++;
        source[20 * source_pitch + 20 * 4 + 3] = 254;
        saved = pixels;
        assert(!cache.prepare_region(image, size, size, view, true).hit && pixels == saved);
        source[20 * source_pitch + 20 * 4 + 3] = 255;
        // Subviews retain the original surface and snapshot coordinates. Their
        // ignored interior must move by the cached view's origin exactly once.
        constexpr int small = 24, small_pitch = small * 4 + 13;
        std::vector<uint8_t> clipped(small_pitch * small, 31);
        for (int y = 0; y < small; ++y)
            std::memcpy(clipped.data() + y * small_pitch,
                original.data() + (y + 12) * pitch + 12 * 4, small * 4);
        clipped[8 * small_pitch + 8 * 4]++;
        VoxGraphitePixelRegion inner {12, 12, small, small, small_pitch, clipped.data()};
        assert(cache.prepare_region(image, size, size, inner, true).hit);
        for (int y = 0; y < small; ++y) {
            for (int x = 0; x < small * 4; ++x) assert(clipped[y * small_pitch + x] == 117);
            for (int x = small * 4; x < small_pitch; ++x) assert(clipped[y * small_pitch + x] == 31);
        }
        for (int guard = 0; guard < 5; ++guard) {
            auto unsupported = image;
            if (guard == 0) unsupported.opacity = .7f;
            if (guard == 1) unsupported.matrix[1] = .125f;
            if (guard == 2) unsupported.has_color_profile = 1;
            if (guard == 3) source[20 * source_pitch + 20 * 4 + 3] = 254;
            if (guard == 4) unsupported.source[0] = -1;
            VoxGraphiteRasterCache excluded;
            reset(); auto first = excluded.prepare_region(unsupported, size, size, view, true);
            assert(first.pending);
            for (int y = 0; y < size; ++y) std::fill_n(pixels.data() + y * pitch, size * 4, 117);
            excluded.finish(std::move(first), pixels.data(), pitch);
            reset(); pixels[20 * pitch + 20 * 4]++;
            assert(!excluded.prepare_region(unsupported, size, size, view, true).hit);
            source[20 * source_pitch + 20 * 4 + 3] = 255;
        }
    }
    {
        VoxGraphiteRasterCache shifted;
        constexpr int outer = 56, outer_pitch = outer * 4 + 17;
        std::vector<uint8_t> background(outer_pitch * outer, 31);
        VoxGraphitePixelRegion first {2, 3, outer, outer, outer_pitch, background.data()};
        auto request = shifted.prepare_region(image, size, size, first, true);
        assert(request.pending);
        for (int y = 0; y < outer; ++y) std::fill_n(background.data() + y * outer_pitch, outer * 4, 117);
        shifted.finish(std::move(request), background.data(), outer_pitch);
        constexpr int inner_size = 24, inner_pitch = inner_size * 4 + 13;
        std::vector<uint8_t> input(inner_pitch * inner_size, 31);
        VoxGraphitePixelRegion inner {3, 4, inner_size, inner_size, inner_pitch, input.data()};
        input[10 * inner_pitch + 10 * 4]++;
        assert(shifted.prepare_region(image, size, size, inner, true).hit);
        std::fill(input.begin(), input.end(), 31); input[4]++;
        assert(!shifted.prepare_region(image, size, size, inner, true).hit);
    }
    std::cout << "Opaque RGBA regions: interior independence, edges, mutation and subviews passed\n";
}
