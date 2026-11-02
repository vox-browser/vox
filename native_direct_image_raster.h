#pragma once
#include "native_graphite_bridge.h"
#include <algorithm>
#include <cmath>
#include <optional>

struct VoxDirectImageRasterPlan {
    float scale, width, height;
    int tile_width, tile_height, columns, rows;
};

// The embedding layer selects single-image compositor pictures. This planner
// handles full-source, translated draws at device scale one. Other pictures
// keep the ordinary image path, including cropped and repeated backgrounds.
inline std::optional<VoxDirectImageRasterPlan> vox_direct_image_raster_plan(
    VoxGraphiteImage const& image, int viewport_width, int viewport_height)
{
    if (image.width <= 0 || image.height <= 0 || !image.pixels || image.nearest
        || image.pitch < int64_t(image.width) * 4
        || viewport_width <= 0 || viewport_height <= 0
        || viewport_width > 16384 || viewport_height > 16384
        || size_t(viewport_width) * viewport_height > 8 * 1024 * 1024
        || size_t(image.width) * image.height > 8 * 1024 * 1024
        || image.has_background_color || image.border_width != 0
        || image.flags & (VOX_GRAPHITE_IMAGE_REPEAT_X | VOX_GRAPHITE_IMAGE_REPEAT_Y)) return {};
    for (float value : image.matrix) if (!std::isfinite(value)) return {};
    for (float value : image.destination) if (!std::isfinite(value)) return {};
    for (float value : image.clip) if (!std::isfinite(value)) return {};
    if (image.matrix[0] != 1 || image.matrix[1] != 0 || image.matrix[3] != 0
        || image.matrix[4] != 1 || image.matrix[6] != 0 || image.matrix[7] != 0
        || image.matrix[8] != 1 || !(image.destination[2] > 0 && image.destination[3] > 0)
        || !(image.clip[2] > 0 && image.clip[3] > 0)
        || image.source[0] != 0 || image.source[1] != 0
        || image.source[2] != image.width || image.source[3] != image.height
        || !std::isfinite(image.opacity) || image.opacity < 0 || image.opacity > 1) return {};
    for (int i = 4; i < 12; ++i) if (image.clip[i] < 0) return {};
    float x_scale = image.width / image.destination[2];
    float y_scale = image.height / image.destination[3];
    // Larger scale changes also depend on retained decode/raster history.
    // Keep that policy on the existing path until it is represented here.
    float scale = std::max(x_scale, y_scale);
    if (!std::isfinite(scale) || scale < .1f || scale >= 2
        || scale > 5 * std::min(x_scale, y_scale)) return {};
    float width = image.destination[2] * scale, height = image.destination[3] * scale;
    if (!std::isfinite(width) || !std::isfinite(height) || width > 16384 || height > 16384
        || std::ceil(width) * std::ceil(height) > 8 * 1024 * 1024) return {};
    int content_width = int(std::ceil(width)), content_height = int(std::ceil(height));
    int base_width = viewport_width, tile_width = 0, tile_height = 0;
    for (int pass = 0; pass < 2; ++pass) {
        int divisor = content_width <= base_width / 4 ? 1 : content_width <= base_width / 2 ? 2 : 4;
        tile_width = (base_width + 2 + 31) / 32 * 32;
        tile_height = std::max(((viewport_height + divisor - 1) / divisor + 2 + 31) / 32 * 32, 256);
        if (pass == 0 && content_width > tile_width) { base_width = (base_width + 1) / 2; continue; }
        break;
    }
    if (content_width < tile_width) tile_width = std::min((content_width + 63) / 64 * 64, tile_width);
    if (content_height < tile_height) tile_height = std::min((content_height + 63) / 64 * 64, tile_height);
    tile_width = std::max(4, (tile_width + 3) / 4 * 4);
    tile_height = std::max(4, (tile_height + 3) / 4 * 4);
    int columns = std::max(1, (content_width - 2 + tile_width - 3) / (tile_width - 2));
    int rows = std::max(1, (content_height - 2 + tile_height - 3) / (tile_height - 2));
    return VoxDirectImageRasterPlan{scale, width, height, tile_width, tile_height, columns, rows};
}
