#ifndef VOX_NATIVE_SKIA_SAVE_LAYER_IMAGE_H
#define VOX_NATIVE_SKIA_SAVE_LAYER_IMAGE_H

// A non-composited saveLayer creates a child device inside each parent raster
// tile. Its image input keeps the child's horizontal origin and the vertical
// intersection with that tile, even when the child has no opaque backdrop.
// Bounds and the supported parent grid are selected by the V paint planner.
struct VoxSaveLayerImageRaster {
    double x = 0, y = 0, width = 0, height = 0;
    int tile_rows = 0;
};
static VoxSaveLayerImageRaster s_save_layer_image_raster;

extern "C" void ladybird_v_skia_set_save_layer_image_raster(double x, double y,
    double width, double height, int tile_rows)
{
    s_save_layer_image_raster = {};
    if (std::isfinite(x) && std::isfinite(y) && std::isfinite(width) && std::isfinite(height)
        && x >= 0 && width > 0 && height > 0 && tile_rows > 2 && tile_rows <= 16384)
        s_save_layer_image_raster = {x, y, width, height, tile_rows};
}

static bool draw_chromium_save_layer_image_slices(
    decltype(&vox_graphite_draw_image_pixels) draw, std::vector<uint32_t>& pixels,
    int width, int height, RasterRegion const& region, float scale,
    float page_x, float page_y, float scroll_y, VoxGraphiteImage const& descriptor)
{
    auto const& scope = s_save_layer_image_raster;
    if (!draw || !s_raster_layer_is_root || scope.tile_rows <= 2
        || scope.tile_rows != s_msaa_tile_rows || !(scale > 0) || !std::isfinite(scale)
        || width <= 0 || height <= 0 || pixels.size() != size_t(width) * height
        || descriptor.matrix[6] != 0 || descriptor.matrix[7] != 0 || descriptor.matrix[8] != 1)
        return false;
    double l = std::floor(scope.x * scale), t = std::floor(scope.y * scale);
    double r = std::ceil((scope.x + scope.width) * scale);
    double b = std::ceil((scope.y + scope.height) * scale);
    double x = std::round((region.left - page_x) * scale);
    double y = std::round((region.top - page_y + scroll_y + s_root_raster_scroll_y) * scale);
    if (!std::isfinite(l) || !std::isfinite(t) || !std::isfinite(r) || !std::isfinite(b)
        || !std::isfinite(x) || !std::isfinite(y) || l < 0 || t < 0 || b > INT32_MAX
        || r > INT32_MAX || r <= l || b <= t || r - l > 16384
        || x < l || y < t || x + width > r || y + height > b)
        return false;
    int left = int(l), top = int(t), right = int(r), bottom = int(b);
    int first_x = int(x), first_y = int(y), step = scope.tile_rows - 2;
    int target_width = right - left;
    constexpr size_t maximum_pixels = 8 * 1024 * 1024;
    if (size_t(target_width) * std::min(bottom - top, scope.tile_rows) > maximum_pixels)
        return false;
    auto owner = [step](int row) { return row <= step ? 0 : (row - 1) / step; };
    auto result = pixels;
    for (int tile = owner(first_y); tile <= owner(first_y + height - 1); ++tile) {
        int64_t origin = int64_t(tile) * step;
        int child_top = int(std::max<int64_t>(top, origin));
        int child_bottom = int(std::min<int64_t>(bottom, origin + scope.tile_rows));
        if (child_bottom <= child_top) return false;
        int target_height = child_bottom - child_top;
        std::vector<uint32_t> child(size_t(target_width) * target_height);
        auto image = descriptor;
        image.matrix[2] += first_x - left;
        image.matrix[5] += first_y - child_top;
        long projected = long(origin - std::lround(s_root_raster_scroll_y * scale));
        image.flags = (image.flags & ~VOX_GRAPHITE_IMAGE_FORCE_MSAA)
            | (row_in_msaa_tile(projected + 1) ? VOX_GRAPHITE_IMAGE_FORCE_MSAA : 0);
        if (!draw(reinterpret_cast<uint8_t*>(child.data()), target_width, target_height,
                target_width * 4, 0, &image)) return false;
        int begin = std::max(0, child_top - first_y);
        int end = std::min(height, child_bottom - first_y);
        for (int row = begin; row < end; ++row) {
            if (owner(first_y + row) != tile) continue;
            std::copy_n(child.data() + size_t(first_y + row - child_top) * target_width
                    + first_x - left, width, result.data() + size_t(row) * width);
        }
    }
    pixels = std::move(result);
    return true;
}

#endif
