#include "../native_chromium_raster_batch.h"
#include <cassert>
#include <cstdio>

int main()
{
    size_t comparisons = 0;
    for (int tw : {4, 17, 64, 544}) for (int th : {5, 19, 256})
    for (int columns : {2, 4}) for (int rows : {2, 4})
    for (int x : {0, 1, tw - 2, tw - 1}) for (int y : {0, 1, th - 2, th - 1})
    for (int w : {2, 31, 109}) for (int h : {2, 23, 83}) {
        VoxChromiumRasterGrid grid{tw, th, columns, rows};
        int width = std::min(w, columns * (tw - 2) + 2 - x);
        int height = std::min(h, rows * (th - 2) + 2 - y);
        if (width <= 0 || height <= 0) continue;
        std::vector<uint32_t> backdrop(size_t(width) * height + 13);
        for (size_t n = 0; n < backdrop.size(); ++n) backdrop[n] = uint32_t(n * 23 + 71);
        auto expected = backdrop;
        int tile_count = 0;
        auto paint = [](auto& pixels, int tile_width, int cell, int left, int top) {
            for (size_t n = 0; n < pixels.size(); ++n)
                pixels[n] ^= uint32_t(cell * 1729 + (n % tile_width + left) * 103
                    + (n / tile_width + top) * 7);
        };
        assert(vox_draw_chromium_raster_grid_regions(expected, width, height, x, y, grid,
            [&](auto& tile, long, long, int cell, int left, int top, int tile_width, int) {
                ++tile_count;
                paint(tile, tile_width, cell, left, top);
                return true;
            }));
        auto actual = backdrop;
        bool called = false;
        bool success = vox_draw_chromium_raster_grid_batch(actual, width, height, x, y, grid,
            [&](auto& regions) {
                called = true;
                assert(regions.size() == size_t(tile_count));
                for (auto& region : regions)
                    paint(region.pixels, region.width, region.cell, region.x, region.y);
                return true;
            });
        assert(success == (tile_count >= 2 && tile_count <= 64));
        assert(called == success);
        assert(actual == (success ? expected : backdrop));
        actual = backdrop;
        assert(!vox_draw_chromium_raster_grid_batch(actual, width, height, x, y, grid,
            [&](auto& regions) {
                for (auto& region : regions) std::fill(region.pixels.begin(), region.pixels.end(), 0);
                return false;
            }));
        assert(actual == backdrop);
        ++comparisons;
    }
    std::vector<uint32_t> pixels(1024, 71);
    auto untouched = pixels;
    for (auto grid : {VoxChromiumRasterGrid{2, 8, 2, 2}, {8, 2, 2, 2}, {8, 8, 0, 2},
             {8, 8, 2, 0}, {3, 3, 64, 64}, {2048, 2048, 2, 2}, {8, 8, INT_MAX, 2}})
        assert(!vox_draw_chromium_raster_grid_batch(pixels, 32, 32, 0, 0, grid,
            [](auto&) { assert(false); return true; }));
    assert(!vox_draw_chromium_raster_grid_batch(pixels, 32, 32, -1, 0, {544, 256, 4, 4},
        [](auto&) { assert(false); return true; }));
    assert(!vox_draw_chromium_raster_grid_batch(pixels, 1025, 1024, 0, 0, {544, 256, 4, 4},
        [](auto&) { assert(false); return true; }));
    assert(pixels == untouched);
    std::printf("Chromium raster batches: %zu exact serial ownership/backdrop comparisons passed\n", comparisons);
}
