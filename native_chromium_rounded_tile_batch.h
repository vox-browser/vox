#pragma once

// Prepare all corner views from the same immutable destination before asking
// the backend to render their original tiles. The normal serial path remains
// available when the experiment is disabled, unavailable or exceeds a budget.
template<typename Parts>
static bool draw_sparse_rounded_tiles_batch(Parts& parts, Backdrop const& backdrop,
    VoxGraphiteShape const& shape, VoxChromiumRasterGrid const& grid,
    long first_x, long first_y, long fc, long lc, long fr, long lr)
{
    static bool enabled = [] {
        auto* value = std::getenv("VOX_ENABLE_ROUNDED_TILE_BATCH");
        return value && !std::strcmp(value, "1")
            && !std::getenv("VOX_DISABLE_ROUNDED_TILE_BATCH");
    }();
    if (!enabled) return false;
    auto draw = graphite_shape_parts_batch_draw();
    if (!draw || (lc - fc + 1) * (lr - fr + 1) > 64) return false;
    struct Input { int part, left, top, width, height; std::vector<uint32_t> pixels; };
    struct Tile {
        long row, column, ox, oy;
        VoxGraphiteShape shape;
        std::vector<Input> inputs;
        std::vector<VoxGraphitePixelRegion> views;
    };
    std::vector<Tile> tiles;
    for (long row = fr; row <= lr; ++row) for (long column = fc; column <= lc; ++column) {
        long ox = first_x - column * (grid.width - 2), oy = first_y - row * (grid.height - 2);
        Tile tile {row, column, ox, oy, shape, {}, {}};
        tile.shape.matrix[2] += ox; tile.shape.matrix[5] += oy;
        tile.shape.force_msaa = std::binary_search(s_msaa_grid_tiles.begin(), s_msaa_grid_tiles.end(),
            int(row * grid.columns + column));
        for (int i = 0; i < int(parts.size()); ++i) {
            auto const& part = parts[i];
            int l = int(std::max<long>(part.left, -ox)), t = int(std::max<long>(part.top, -oy));
            int r = int(std::min<long>(part.left + part.width, grid.width - ox));
            int b = int(std::min<long>(part.top + part.height, grid.height - oy));
            if (l >= r || t >= b) continue;
            Input input {i, l, t, r - l, b - t, std::vector<uint32_t>(size_t(r - l) * (b - t))};
            Backdrop source {backdrop.pixels + size_t(t) * backdrop.pitch + size_t(l) * 4, backdrop.pitch};
            copy_backdrop_pixels(source, input.width, input.height, input.pixels);
            tile.inputs.push_back(std::move(input));
        }
        if (!tile.inputs.empty()) tiles.push_back(std::move(tile));
    }
    if (tiles.size() < 2) return false;
    std::vector<VoxGraphiteShapeParts> jobs;
    for (auto& tile : tiles) {
        for (auto& input : tile.inputs)
            tile.views.push_back({int(input.left + tile.ox), int(input.top + tile.oy),
                input.width, input.height, input.width * 4,
                reinterpret_cast<uint8_t*>(input.pixels.data())});
        jobs.push_back({tile.views.data(), int(tile.views.size()), tile.shape});
    }
    if (!draw(jobs.data(), int(jobs.size()), grid.width, grid.height, 1)) return false;
    for (auto const& tile : tiles) for (auto const& input : tile.inputs) {
        auto& part = parts[input.part];
        int l = int(std::max<long>(input.left, -tile.ox + (tile.column > 0 ? 1 : 0)));
        int t = int(std::max<long>(input.top, -tile.oy + (tile.row > 0 ? 1 : 0)));
        int r = int(std::min<long>(input.left + input.width,
            grid.width - tile.ox - (tile.column + 1 < grid.columns ? 1 : 0)));
        int b = int(std::min<long>(input.top + input.height,
            grid.height - tile.oy - (tile.row + 1 < grid.rows ? 1 : 0)));
        for (int y = t; y < b; ++y) if (l < r)
            std::copy_n(input.pixels.data() + size_t(y - input.top) * input.width + l - input.left,
                r - l, part.pixels.data() + size_t(y - part.top) * part.width + l - part.left);
    }
    return true;
}
