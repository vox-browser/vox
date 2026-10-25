#pragma once
#include <algorithm>
#include <cstdint>
#include <vector>

struct VoxChromiumRasterGrid {
    int width, height, columns, rows;
    static long owner(long coordinate, int size, int count) {
        long cell = coordinate <= size - 2 ? 0 : (coordinate - 1) / (size - 2);
        return std::clamp(cell, 0L, static_cast<long>(count - 1));
    }
};

// Draw each intersecting raster tile from the same immutable backdrop. Its
// border texels participate in rasterization, then each pixel is copied from
// the one tile that owns it. The last tile retains the outer border too.
template<bool Compact, typename Draw>
bool vox_draw_chromium_raster_grid_impl(std::vector<uint32_t>& pixels, int width,
    int height, long first_x, long first_y, VoxChromiumRasterGrid grid, Draw draw)
{
    if (width <= 0 || height <= 0 || pixels.size() < size_t(width) * height
        || first_x < 0 || first_y < 0 || grid.width <= 2 || grid.height <= 2
        || grid.columns <= 0 || grid.rows <= 0
        || static_cast<size_t>(grid.width) * grid.height > 8 * 1024 * 1024) return false;
    long extent_x = long(grid.columns) * (grid.width - 2) + 2;
    long extent_y = long(grid.rows) * (grid.height - 2) + 2;
    if (first_x > extent_x || first_y > extent_y
        || width > extent_x - first_x || height > extent_y - first_y) return false;
    auto result = pixels;
    std::vector<uint32_t> tile;
    if constexpr (!Compact) tile.resize(static_cast<size_t>(grid.width) * grid.height);
    long first_column = grid.owner(first_x, grid.width, grid.columns);
    long last_column = grid.owner(first_x + width - 1, grid.width, grid.columns);
    long first_row = grid.owner(first_y, grid.height, grid.rows);
    long last_row = grid.owner(first_y + height - 1, grid.height, grid.rows);
    for (long row = first_row; row <= last_row; ++row) {
        long origin_y = row * (grid.height - 2);
        for (long column = first_column; column <= last_column; ++column) {
            long origin_x = column * (grid.width - 2);
            long left = std::max(first_x, origin_x);
            long right = std::min(first_x + width, origin_x + grid.width);
            long top = std::max(first_y, origin_y);
            long bottom = std::min(first_y + height, origin_y + grid.height);
            long tile_left = Compact ? left : origin_x;
            long tile_top = Compact ? top : origin_y;
            int tile_width = Compact ? int(right - left) : grid.width;
            int tile_height = Compact ? int(bottom - top) : grid.height;
            if constexpr (Compact) {
                tile.resize(size_t(tile_width) * tile_height);
            } else {
                // Construction already cleared the first tile. Later draws
                // can modify every texel, so reset it before reusing it.
                if (column != first_column || row != first_row)
                    std::fill(tile.begin(), tile.end(), 0);
            }
            for (long y = top; y < bottom; ++y) {
                std::copy_n(pixels.begin() + (y - first_y) * width + left - first_x,
                    right - left, tile.begin() + (y - tile_top) * tile_width + left - tile_left);
            }
            if (!draw(tile, first_x - origin_x, first_y - origin_y,
                    static_cast<int>(row * grid.columns + column),
                    int(tile_left - origin_x), int(tile_top - origin_y), tile_width, tile_height)) return false;
            left = std::max(first_x, origin_x + (column > 0 ? 1 : 0));
            top = std::max(first_y, origin_y + (row > 0 ? 1 : 0));
            right = std::min(first_x + width, origin_x + grid.width
                - (column + 1 < grid.columns ? 1 : 0));
            bottom = std::min(first_y + height, origin_y + grid.height
                - (row + 1 < grid.rows ? 1 : 0));
            for (long y = top; y < bottom; ++y) {
                std::copy_n(tile.begin() + (y - tile_top) * tile_width + left - tile_left,
                    right - left, result.begin() + (y - first_y) * width + left - first_x);
            }
        }
    }
    pixels = std::move(result);
    return true;
}

template<typename Draw>
bool vox_draw_chromium_raster_grid(std::vector<uint32_t>& pixels, int width,
    int height, long first_x, long first_y, VoxChromiumRasterGrid grid, Draw draw)
{
    return vox_draw_chromium_raster_grid_impl<false>(pixels, width, height,
        first_x, first_y, grid,
        [&](auto& tile, long offset_x, long offset_y, int cell, int, int, int, int) {
            return draw(tile, offset_x, offset_y, cell);
        });
}

// A region-capable backend retains the full GPU tile's dimensions and origin,
// but only transfers the leaf's intersection. Pixels outside it are transparent.
template<typename Draw>
bool vox_draw_chromium_raster_grid_regions(std::vector<uint32_t>& pixels, int width,
    int height, long first_x, long first_y, VoxChromiumRasterGrid grid, Draw draw)
{
    return vox_draw_chromium_raster_grid_impl<true>(pixels, width, height,
        first_x, first_y, grid, draw);
}
