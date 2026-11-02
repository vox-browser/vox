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

#include "native_chromium_staged_raster_grid.h"

// Enumerate disjoint rectangles with constant tile ownership. Keep the grid
// compact even when a leaf covers millions of pixels.
template<typename Selected>
void vox_chromium_msaa_rects(int width, int height,
    long first_x, long first_y, int tile_width, int tile_height, int columns,
    std::vector<int> const& tiles, Selected selected)
{
    if (width <= 0 || height <= 0 || tile_width <= 2 || tile_height <= 2
        || columns <= 0 || tiles.empty()) return;
    int start_x = first_x < 0 ? (first_x <= -long(width) ? width : int(-first_x)) : 0;
    int y = first_y < 0 ? (first_y <= -long(height) ? height : int(-first_y)) : 0;
    auto owner = [](long coordinate, int size) {
        return coordinate <= size - 2 ? 0L : (coordinate - 1) / (size - 2);
    };
    auto span = [](long coordinate, int size) {
        long spacing = size - 2;
        return coordinate <= spacing ? spacing - coordinate + 1
            : spacing - (coordinate - 1) % spacing;
    };
    for (; y < height;) {
        long coordinate_y = first_y + y;
        long row = owner(coordinate_y, tile_height);
        int rows = int(std::min(long(height - y), span(coordinate_y, tile_height)));
        for (int x = start_x; x < width;) {
            long coordinate_x = first_x + x;
            long column = std::min(owner(coordinate_x, tile_width), long(columns - 1));
            int count = column == columns - 1 ? width - x
                : int(std::min(long(width - x), span(coordinate_x, tile_width)));
            int cell = static_cast<int>(row * columns + column);
            if (std::binary_search(tiles.begin(), tiles.end(), cell))
                selected(x, y, count, rows);
            x += count;
        }
        y += rows;
    }
}

inline std::vector<char> vox_chromium_msaa_pixel_mask(int width, int height,
    long first_x, long first_y, int tile_width, int tile_height, int columns,
    std::vector<int> const& tiles)
{
    if (width <= 0 || height <= 0 || tile_width <= 2 || tile_height <= 2 || columns <= 0)
        return {};
    std::vector<char> mask(size_t(width) * height);
    if (tiles.empty()) return mask;
    int start_x = first_x < 0 ? (first_x <= -long(width) ? width : int(-first_x)) : 0;
    int y = first_y < 0 ? (first_y <= -long(height) ? height : int(-first_y)) : 0;
    auto owner = [](long coordinate, int size) {
        return coordinate <= size - 2 ? 0L : (coordinate - 1) / (size - 2);
    };
    auto span = [](long coordinate, int size) {
        long spacing = size - 2;
        return coordinate <= spacing ? spacing - coordinate + 1
            : spacing - (coordinate - 1) % spacing;
    };
    for (; y < height;) {
        long coordinate_y = first_y + y;
        long row = owner(coordinate_y, tile_height);
        int rows = int(std::min(long(height - y), span(coordinate_y, tile_height)));
        auto* output = mask.data() + size_t(y) * width;
        for (int x = start_x; x < width;) {
            long coordinate_x = first_x + x;
            long column = std::min(owner(coordinate_x, tile_width), long(columns - 1));
            int count = column == columns - 1 ? width - x
                : int(std::min(long(width - x), span(coordinate_x, tile_width)));
            int cell = static_cast<int>(row * columns + column);
            if (std::binary_search(tiles.begin(), tiles.end(), cell))
                std::fill_n(output + x, count, char(1));
            x += count;
        }
        for (int copy = 1; copy < rows; ++copy)
            std::copy_n(output, width, output + size_t(copy) * width);
        y += rows;
    }
    return mask;
}

// Both modes see the original backdrop. Resolve only selected tile spans,
// avoiding a per-pixel mask and full-mask scans on every fractional scroll.
template<typename Draw>
bool vox_draw_with_chromium_msaa_grid(std::vector<uint32_t>& pixels, int width, int height,
    long first_x, long first_y, int tile_width, int tile_height, int columns,
    std::vector<int> const& tiles, Draw draw)
{
    struct Rect { int x, y, width, height; };
    std::vector<Rect> selected;
    size_t count = 0;
    vox_chromium_msaa_rects(width, height, first_x, first_y, tile_width, tile_height, columns,
        tiles, [&](int x, int y, int w, int h) {
            selected.push_back({x, y, w, h});
            count += size_t(w) * h;
        });
    if (count == 0) return draw(pixels, false);
    if (count == size_t(width) * height) return draw(pixels, true);
    auto original = pixels;
    auto multisampled = original;
    if (!draw(multisampled, true) || !draw(pixels, false)) {
        pixels = std::move(original);
        return false;
    }
    for (auto const& rect : selected) {
        for (int y = rect.y; y < rect.y + rect.height; ++y) {
            size_t offset = size_t(y) * width + rect.x;
            std::copy_n(multisampled.begin() + offset, rect.width, pixels.begin() + offset);
        }
    }
    return true;
}

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
    if (vox_chromium_staged_grid_enabled()) {
        std::vector<VoxChromiumStagedTile> plan;
        if (vox_chromium_plan_staged_grid<Compact>(width, height, first_x, first_y, grid, plan))
            return vox_chromium_draw_staged_grid<Compact>(pixels, width, height, plan, draw);
    }
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

// A leaf's conservative raster fringe may start outside its compositor grid.
// Preserve that backdrop while replaying the intersection in complete tiles.
// Callback offsets still refer to the original leaf, before this clipping.
template<typename Draw>
bool vox_draw_chromium_raster_grid_clipped(std::vector<uint32_t>& pixels, int width,
    int height, long first_x, long first_y, VoxChromiumRasterGrid grid,
    int content_width, int content_height, Draw draw)
{
    if (width <= 0 || height <= 0 || pixels.size() < size_t(width) * height
        || grid.width <= 2 || grid.height <= 2 || grid.columns <= 0 || grid.rows <= 0
        || content_width <= 0 || content_height <= 0
        || size_t(grid.width) * grid.height > 8 * 1024 * 1024) return false;
    if (content_width > long(grid.columns) * (grid.width - 2) + 2
        || content_height > long(grid.rows) * (grid.height - 2) + 2) return false;
    long extent_x = content_width, extent_y = content_height;
    // Check before negating or adding an arbitrary caller-supplied origin.
    if (first_x <= -long(width) || first_y <= -long(height)
        || first_x >= extent_x || first_y >= extent_y) return true;
    int left = first_x < 0 ? int(-first_x) : 0;
    int top = first_y < 0 ? int(-first_y) : 0;
    int right = int(std::min(long(width), extent_x - first_x));
    int bottom = int(std::min(long(height), extent_y - first_y));
    int clipped_width = right - left, clipped_height = bottom - top;
    std::vector<uint32_t> clipped(size_t(clipped_width) * clipped_height);
    for (int y = top; y < bottom; ++y)
        std::copy_n(pixels.data() + size_t(y) * width + left, clipped_width,
            clipped.data() + size_t(y - top) * clipped_width);
    if (!vox_draw_chromium_raster_grid(clipped, clipped_width, clipped_height,
            first_x + left, first_y + top, grid,
            [&](auto& tile, long offset_x, long offset_y, int cell) {
                return draw(tile, offset_x - left, offset_y - top, cell);
            })) return false;
    for (int y = top; y < bottom; ++y)
        std::copy_n(clipped.data() + size_t(y - top) * clipped_width, clipped_width,
            pixels.data() + size_t(y) * width + left);
    return true;
}

// Keep the same clipping and original tile coordinates while allocating only
// each leaf/tile intersection for a region-capable backend.
template<typename Draw>
bool vox_draw_chromium_raster_grid_clipped_regions(std::vector<uint32_t>& pixels, int width,
    int height, long first_x, long first_y, VoxChromiumRasterGrid grid,
    int content_width, int content_height, Draw draw)
{
    if (width <= 0 || height <= 0 || pixels.size() < size_t(width) * height
        || grid.width <= 2 || grid.height <= 2 || grid.columns <= 0 || grid.rows <= 0
        || content_width <= 0 || content_height <= 0
        || size_t(grid.width) * grid.height > 8 * 1024 * 1024) return false;
    if (content_width > long(grid.columns) * (grid.width - 2) + 2
        || content_height > long(grid.rows) * (grid.height - 2) + 2) return false;
    long extent_x = content_width, extent_y = content_height;
    // Check before negating or adding an arbitrary caller-supplied origin.
    if (first_x <= -long(width) || first_y <= -long(height)
        || first_x >= extent_x || first_y >= extent_y) return true;
    int left = first_x < 0 ? int(-first_x) : 0;
    int top = first_y < 0 ? int(-first_y) : 0;
    int right = int(std::min(long(width), extent_x - first_x));
    int bottom = int(std::min(long(height), extent_y - first_y));
    int clipped_width = right - left, clipped_height = bottom - top;
    std::vector<uint32_t> clipped(size_t(clipped_width) * clipped_height);
    for (int y = top; y < bottom; ++y)
        std::copy_n(pixels.data() + size_t(y) * width + left, clipped_width,
            clipped.data() + size_t(y - top) * clipped_width);
    if (!vox_draw_chromium_raster_grid_impl<true>(clipped, clipped_width, clipped_height,
            first_x + left, first_y + top, grid,
            [&](auto& tile, long offset_x, long offset_y, int cell, int x, int y, int w, int h) {
                return draw(tile, offset_x - left, offset_y - top, cell, x, y, w, h);
            })) return false;
    for (int y = top; y < bottom; ++y)
        std::copy_n(clipped.data() + size_t(y - top) * clipped_width, clipped_width,
            pixels.data() + size_t(y) * width + left);
    return true;
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
