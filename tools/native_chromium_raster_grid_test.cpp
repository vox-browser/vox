#include "../native_chromium_raster_grid.h"
#include <cassert>
#include <cstdio>

int main()
{
    size_t comparisons = 0;
    for (long first_y : {0L, 2L, 3L, 4L, 5L})
    for (long first_x : {0L, 3L, 4L, 5L, 6L})
    for (int height : {1, 2, 3, 5}) for (int width : {1, 2, 4, 6}) {
        VoxChromiumRasterGrid grid {6, 5, 3, 3};
        std::vector<uint32_t> pixels(size_t(width) * height);
        for (size_t i = 0; i < pixels.size(); ++i) pixels[i] = 0xFF000000U + i;
        auto backdrop = pixels;
        int calls = 0;
        assert(vox_draw_chromium_raster_grid(pixels, width, height, first_x, first_y, grid,
            [&](auto& tile, long offset_x, long offset_y, int cell) {
                ++calls;
                // The callback may overwrite the entire tile. Subsequent
                // tiles must still start with only the immutable backdrop.
                for (int y = 0; y < grid.height; ++y) for (int x = 0; x < grid.width; ++x) {
                    long source_x = x - offset_x, source_y = y - offset_y;
                    uint32_t expected = source_x >= 0 && source_x < width
                        && source_y >= 0 && source_y < height
                        ? backdrop[size_t(source_y) * width + source_x] : 0;
                    assert(tile[size_t(y) * grid.width + x] == expected);
                    tile[size_t(y) * grid.width + x] = uint32_t(cell + 1);
                }
                return true;
            }));
        assert(calls > 0);
        for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x) {
            long global_x = first_x + x, global_y = first_y + y;
            int column = global_x <= 4 ? 0 : global_x <= 8 ? 1 : 2;
            int row = global_y <= 3 ? 0 : global_y <= 6 ? 1 : 2;
            assert(pixels[size_t(y) * width + x] == uint32_t(row * 3 + column + 1));
            ++comparisons;
        }
        auto expected = pixels;
        pixels = backdrop;
        assert(vox_draw_chromium_raster_grid_regions(pixels, width, height,
            first_x, first_y, grid,
            [&](auto& tile, long offset_x, long offset_y, int cell,
                int left, int top, int tile_width, int tile_height) {
                assert(left >= 0 && top >= 0 && left + tile_width <= grid.width
                    && top + tile_height <= grid.height);
                assert(tile.size() == size_t(tile_width) * tile_height);
                for (int y = 0; y < tile_height; ++y) for (int x = 0; x < tile_width; ++x) {
                    long source_x = left + x - offset_x, source_y = top + y - offset_y;
                    assert(source_x >= 0 && source_x < width && source_y >= 0 && source_y < height);
                    assert(tile[size_t(y) * tile_width + x] == backdrop[size_t(source_y) * width + source_x]);
                    tile[size_t(y) * tile_width + x] = uint32_t(cell + 1);
                }
                return true;
            }));
        assert(pixels == expected);
        pixels = backdrop;
        calls = 0;
        bool success = vox_draw_chromium_raster_grid(pixels, width, height,
            first_x, first_y, grid, [&](auto& tile, long, long, int) {
                std::fill(tile.begin(), tile.end(), 0xDEADBEEFU);
                return ++calls < 2;
            });
        if (!success) assert(pixels == backdrop);
        pixels = backdrop;
        calls = 0;
        success = vox_draw_chromium_raster_grid_regions(pixels, width, height,
            first_x, first_y, grid, [&](auto& tile, long, long, int, int, int, int, int) {
                std::fill(tile.begin(), tile.end(), 0xDEADBEEFU);
                return ++calls < 2;
            });
        if (!success) assert(pixels == backdrop);
    }
    std::vector<uint32_t> invalid(4, 0x12345678U);
    auto untouched = invalid;
    assert(!vox_draw_chromium_raster_grid_regions(invalid, 2, 2, 100, 0,
        {6, 5, 3, 3}, [](auto&, long, long, int, int, int, int, int) { assert(false); return true; }));
    assert(invalid == untouched);
    std::printf("Chromium raster grid: %zu ownership/backdrop comparisons passed\n", comparisons);
}
