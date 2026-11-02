#pragma once
#include <climits>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <utility>
#if defined(__APPLE__)
#include <dlfcn.h>
#endif

struct VoxChromiumStagedTile {
    long offset_x, offset_y;
    int cell, x, y, width, height;
    int input_x, input_y, source_x, source_y, target_x, target_y, copy_width, copy_height;
    int background_x, background_y, background_width, background_height;
};

inline bool vox_chromium_staged_grid_enabled()
{
    static bool const enabled = [] {
        auto* value = std::getenv("VOX_ENABLE_STAGED_RASTER_GRID");
        return value && !std::strcmp(value, "1") && !std::getenv("VOX_DISABLE_STAGED_RASTER_GRID");
    }();
    return enabled;
}

// Plan exactly the serial grid's intersections and texel ownership. Keep the
// compact payload within the old result-copy plus one full tile budget. Large
// complete tiles may stage up to one extra result surface, capped at 32 MiB.
template<bool Compact>
inline bool vox_chromium_plan_staged_grid(int width, int height, long first_x,
    long first_y, VoxChromiumRasterGrid grid, std::vector<VoxChromiumStagedTile>& plan)
{
    plan.clear();
    if (width <= 0 || height <= 0 || first_x < 0 || first_y < 0
        || grid.width <= 2 || grid.height <= 2 || grid.columns <= 0 || grid.rows <= 0
        || size_t(grid.width) * grid.height > 8 * 1024 * 1024
        || size_t(grid.columns) * grid.rows > INT_MAX) return false;
    long extent_x = long(grid.columns) * (grid.width - 2) + 2;
    long extent_y = long(grid.rows) * (grid.height - 2) + 2;
    if (first_x > extent_x || first_y > extent_y
        || width > extent_x - first_x || height > extent_y - first_y) return false;
    long first_column = grid.owner(first_x, grid.width, grid.columns);
    long last_column = grid.owner(first_x + width - 1, grid.width, grid.columns);
    long first_row = grid.owner(first_y, grid.height, grid.rows);
    long last_row = grid.owner(first_y + height - 1, grid.height, grid.rows);
    size_t count = size_t(last_column - first_column + 1) * (last_row - first_row + 1);
    if (!count || count > 64 || size_t(width) * height < 256) return false;
    if constexpr (!Compact) {
        if (size_t(width) * height < 16384
            || size_t(width) * height * 2 < size_t(grid.width) * grid.height) return false;
    }
    plan.reserve(count);
    size_t staged_pixels = 0, owned_pixels = 0;
    size_t budget = size_t(width) * height + size_t(grid.width) * grid.height;
    if constexpr (!Compact)
        budget = std::min(size_t(8 * 1024 * 1024), budget + size_t(width) * height);
    for (long row = first_row; row <= last_row; ++row) {
        long origin_y = row * (grid.height - 2);
        for (long column = first_column; column <= last_column; ++column) {
            long origin_x = column * (grid.width - 2);
            long left = std::max(first_x, origin_x), top = std::max(first_y, origin_y);
            long right = std::min(first_x + width, origin_x + grid.width);
            long bottom = std::min(first_y + height, origin_y + grid.height);
            int w = Compact ? int(right - left) : grid.width;
            int h = Compact ? int(bottom - top) : grid.height;
            if (w <= 0 || h <= 0) return false;
            staged_pixels += size_t(w) * h;
            if (staged_pixels > budget) return false;
            long owned_left = std::max(first_x, origin_x + (column > 0 ? 1 : 0));
            long owned_top = std::max(first_y, origin_y + (row > 0 ? 1 : 0));
            long owned_right = std::min(first_x + width, origin_x + grid.width
                - (column + 1 < grid.columns ? 1 : 0));
            long owned_bottom = std::min(first_y + height, origin_y + grid.height
                - (row + 1 < grid.rows ? 1 : 0));
            int cw = int(owned_right - owned_left), ch = int(owned_bottom - owned_top);
            if (cw < 0 || ch < 0) return false;
            owned_pixels += size_t(cw) * ch;
            long tile_left = Compact ? left : origin_x, tile_top = Compact ? top : origin_y;
            VoxChromiumStagedTile view;
            view.offset_x = first_x - origin_x; view.offset_y = first_y - origin_y;
            view.cell = int(row * grid.columns + column);
            view.x = int(tile_left - origin_x); view.y = int(tile_top - origin_y);
            view.width = w; view.height = h;
            view.input_x = int(left - first_x); view.input_y = int(top - first_y);
            view.source_x = int(owned_left - tile_left); view.source_y = int(owned_top - tile_top);
            view.target_x = int(owned_left - first_x); view.target_y = int(owned_top - first_y);
            view.copy_width = cw; view.copy_height = ch;
            view.background_x = int(left - tile_left); view.background_y = int(top - tile_top);
            view.background_width = int(right - left); view.background_height = int(bottom - top);
            plan.push_back(view);
        }
    }
    return owned_pixels == size_t(width) * height;
}

template<bool Compact, typename Draw>
bool vox_chromium_draw_staged_grid(std::vector<uint32_t>& pixels, int width,
    int height, std::vector<VoxChromiumStagedTile> const& plan, Draw& draw)
{
    auto render = [&](std::vector<uint32_t>& tile, VoxChromiumStagedTile const& view) {
        tile.reserve(size_t(view.width) * view.height);
        // Initialize uncovered texels to transparency and construct covered
        // rows directly. Avoid clearing pixels that will be overwritten.
        tile.insert(tile.end(), size_t(view.background_y) * view.width, uint32_t(0));
        for (int y = 0; y < view.background_height; ++y) {
            tile.insert(tile.end(), view.background_x, uint32_t(0));
            auto begin = pixels.begin() + size_t(view.input_y + y) * width + view.input_x;
            tile.insert(tile.end(), begin, begin + view.background_width);
            tile.insert(tile.end(), view.width - view.background_x - view.background_width, uint32_t(0));
        }
        tile.insert(tile.end(), size_t(view.height - view.background_y - view.background_height) * view.width, uint32_t(0));
        return draw(tile, view.offset_x, view.offset_y, view.cell,
                view.x, view.y, view.width, view.height)
            && tile.size() >= size_t(view.width) * view.height;
    };
    auto publish = [&](VoxChromiumStagedTile const& view, std::vector<uint32_t> const& tile) {
        for (int y = 0; y < view.copy_height; ++y)
            std::copy_n(tile.begin() + size_t(view.source_y + y) * view.width + view.source_x,
                view.copy_width, pixels.begin() + size_t(view.target_y + y) * width + view.target_x);
    };
    if (plan.size() == 1) {
        auto const& view = plan.front();
        std::vector<uint32_t> tile;
        if (!render(tile, view)) return false;
        if (pixels.size() == size_t(width) * height && tile.size() == pixels.size()
            && view.source_x == 0 && view.source_y == 0 && view.target_x == 0 && view.target_y == 0
            && view.copy_width == width && view.copy_height == height)
            pixels = std::move(tile);
        else publish(view, tile);
    } else {
        std::vector<std::vector<uint32_t>> outputs;
        outputs.reserve(plan.size());
        for (auto const& view : plan) {
            outputs.emplace_back();
            if (!render(outputs.back(), view)) return false;
        }
        // All callbacks saw the original input. Commit only after every draw
        // succeeds, avoiding the serial implementation's complete result copy.
        for (size_t i = 0; i < plan.size(); ++i) publish(plan[i], outputs[i]);
    }
    if (std::getenv("VOX_STAGED_RASTER_GRID_DIAGNOSTICS")) {
        double time = -1;
#if defined(__APPLE__)
        using Clock = double (*)();
        static auto clock = reinterpret_cast<Clock>(dlsym(RTLD_DEFAULT, "vox_precise_scroll_diagnostic_time"));
        if (clock) time = clock();
#endif
        std::fprintf(stderr, "VOX_STAGED_RASTER_GRID compact=%d tiles=%zu pixels=%zu avoided_copy_bytes=%zu t_us=%.3f\n",
            Compact, plan.size(), size_t(width) * height, size_t(width) * height * 4, time);
    }
    return true;
}
