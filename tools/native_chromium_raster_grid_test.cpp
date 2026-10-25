#include "../native_chromium_raster_grid.h"
#include <cassert>
#include <cstdio>
#include <limits>

static std::vector<char> reference_msaa_mask(int width, int height, long first_x, long first_y,
    int tw, int th, int columns, std::vector<int> const& tiles)
{
    std::vector<char> result(size_t(width) * height);
    auto owner = [](long v, int size) { return v <= size - 2 ? 0L : (v - 1) / (size - 2); };
    for (int y = 0; y < height; ++y) {
        if (first_y + y < 0) continue;
        long row = owner(first_y + y, th);
        for (int x = 0; x < width; ++x) {
            if (first_x + x < 0) continue;
            long col = std::min(owner(first_x + x, tw), long(columns - 1));
            result[size_t(y) * width + x] = std::binary_search(tiles.begin(), tiles.end(), int(row * columns + col));
        }
    }
    return result;
}
static void check_msaa_masks()
{
    size_t cases = 0;
    auto check = [&](int w, int h, long x, long y, int tw, int th, int cols, auto const& tiles) {
        auto expected = reference_msaa_mask(w,h,x,y,tw,th,cols,tiles);
        assert(expected == vox_chromium_msaa_pixel_mask(w,h,x,y,tw,th,cols,tiles)); ++cases;
    };
    for (int tw : {3, 4, 17, 64, 544}) for (int th : {3, 11, 48, 256})
    for (int cols : {1,3,7}) for (int mode : {0,1,2,3}) {
        std::vector<int> tiles;
        for (int i = 0; i < 56; ++i) if (mode == 1 || (mode == 2 && i % 2) || (mode == 3 && i % 3 == 0)) tiles.push_back(i);
        for (long x : {-173L, -1L, 0L, long(tw - 2), long(tw - 1), long(2 * tw - 4), long(2 * tw - 3), long(cols * tw + 2)})
        for (long y : {-121L, -1L, 0L, long(th - 2), long(th - 1), long(2 * th - 4), long(2 * th - 3), long(8 * th)})
            check(173,121,x,y,tw,th,cols,tiles);
    }
    for (int w : {1,2,1024}) for (int h : {1,2,848})
    for (long x : {-1L,0L,543L}) for (long y : {-1L,0L,255L})
        check(w,h,x,y,544,256,3,std::vector<int>{0,2,4,6,8});
    // Negative origins must not be negated until known to fit the span.
    check(2,2,std::numeric_limits<long>::min(),0,544,256,3,std::vector<int>{0});
    check(2,2,0,std::numeric_limits<long>::min(),544,256,3,std::vector<int>{0});
    assert(vox_chromium_msaa_pixel_mask(0,2,0,0,544,256,3,{}).empty());
    std::printf("Tile MSAA masks: %zu exact per-pixel reference comparisons passed\n",cases);
}


int main()
{
    check_msaa_masks();
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
