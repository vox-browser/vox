#pragma once
#include "native_chromium_raster_grid.h"
#include <climits>

struct VoxChromiumRasterRegion {
    std::vector<uint32_t> pixels;
    long offset_x, offset_y;
    int cell, x, y, width, height;
    int source_x, source_y, target_x, target_y, copy_width, copy_height;
};

// Retain tile border texels and original GPU coordinates exactly as the serial
// grid does. Only independent tiles of this one leaf enter the batch. Bound
// temporary CPU storage and keep the source unchanged when the backend declines.
template<typename Draw>
bool vox_draw_chromium_raster_grid_batch(std::vector<uint32_t>& pixels, int width,
    int height, long first_x, long first_y, VoxChromiumRasterGrid grid, Draw draw)
{
    constexpr size_t max_pixels = 1024 * 1024;
    if (width <= 0 || height <= 0 || size_t(width) * height > max_pixels
        || pixels.size() < size_t(width) * height || first_x < 0 || first_y < 0
        || grid.width <= 2 || grid.height <= 2 || grid.columns <= 0 || grid.rows <= 0
        || size_t(grid.columns) * grid.rows > INT_MAX
        || size_t(grid.width) * grid.height > max_pixels) return false;
    long extent_x = long(grid.columns) * (grid.width - 2) + 2;
    long extent_y = long(grid.rows) * (grid.height - 2) + 2;
    if (first_x > extent_x || first_y > extent_y
        || width > extent_x - first_x || height > extent_y - first_y) return false;
    long first_column = grid.owner(first_x, grid.width, grid.columns);
    long last_column = grid.owner(first_x + width - 1, grid.width, grid.columns);
    long first_row = grid.owner(first_y, grid.height, grid.rows);
    long last_row = grid.owner(first_y + height - 1, grid.height, grid.rows);
    size_t count = size_t(last_column - first_column + 1) * (last_row - first_row + 1);
    if (count < 2 || count > 64 || count * size_t(grid.width) * grid.height > 8 * max_pixels)
        return false;
    std::vector<VoxChromiumRasterRegion> regions;
    regions.reserve(count);
    size_t total = 0;
    for (long row = first_row; row <= last_row; ++row) {
        long origin_y = row * (grid.height - 2);
        for (long column = first_column; column <= last_column; ++column) {
            long origin_x = column * (grid.width - 2);
            long left = std::max(first_x, origin_x);
            long right = std::min(first_x + width, origin_x + grid.width);
            long top = std::max(first_y, origin_y);
            long bottom = std::min(first_y + height, origin_y + grid.height);
            VoxChromiumRasterRegion region;
            region.offset_x = first_x - origin_x;
            region.offset_y = first_y - origin_y;
            region.cell = int(row * grid.columns + column);
            region.x = int(left - origin_x);
            region.y = int(top - origin_y);
            region.width = int(right - left);
            region.height = int(bottom - top);
            total += size_t(region.width) * region.height;
            if (total > max_pixels) return false;
            region.pixels.resize(size_t(region.width) * region.height);
            for (long y = top; y < bottom; ++y)
                std::copy_n(pixels.begin() + (y - first_y) * width + left - first_x,
                    region.width, region.pixels.begin() + (y - top) * region.width);
            long owned_left = std::max(first_x, origin_x + (column > 0 ? 1 : 0));
            long owned_top = std::max(first_y, origin_y + (row > 0 ? 1 : 0));
            long owned_right = std::min(first_x + width,
                origin_x + grid.width - (column + 1 < grid.columns ? 1 : 0));
            long owned_bottom = std::min(first_y + height,
                origin_y + grid.height - (row + 1 < grid.rows ? 1 : 0));
            region.source_x = int(owned_left - left);
            region.source_y = int(owned_top - top);
            region.target_x = int(owned_left - first_x);
            region.target_y = int(owned_top - first_y);
            region.copy_width = int(owned_right - owned_left);
            region.copy_height = int(owned_bottom - owned_top);
            regions.push_back(std::move(region));
        }
    }
    if (!draw(regions)) return false;
    for (auto const& region : regions)
        for (int y = 0; y < region.copy_height; ++y)
            std::copy_n(region.pixels.begin() + size_t(region.source_y + y) * region.width + region.source_x,
                region.copy_width, pixels.begin() + size_t(region.target_y + y) * width + region.target_x);
    return true;
}
