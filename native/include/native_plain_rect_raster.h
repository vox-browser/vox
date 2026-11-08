#pragma once
#include "native_graphite_solid_rect.h"

// Keep a two-device-pixel guard inside every fractional edge. A fill's core
// has complete coverage; a stroke's core preserves its backdrop. The original
// GPU tiles paint the surrounding strips, including their antialiasing.
struct VoxPlainRectCore {
    int left, top, right, bottom;
    bool empty() const { return left >= right || top >= bottom; }
};

inline VoxPlainRectCore vox_plain_rect_core(VoxGraphiteShape const& shape, int width, int height)
{
    if ((shape.fill != 0 && shape.fill != 1) || shape.alpha != 255 || shape.has_underlay || shape.clip_out_count
        || width <= 0 || height <= 0) return {};
    for (int i = 4; i < 12; ++i) if (shape.rect[i] != 0) return {};
    float edges[4];
    if (!vox_axis_aligned_rect(shape, edges)) return {};
    double inset_x = shape.fill ? 0 : shape.thickness * shape.matrix[0] / 2;
    double inset_y = shape.fill ? 0 : shape.thickness * shape.matrix[4] / 2;
    if (!std::isfinite(inset_x) || !std::isfinite(inset_y) || inset_x < 0 || inset_y < 0) return {};
    auto bound = [](double value, int extent) { return int(std::clamp(value, 0.0, double(extent))); };
    return {bound(std::ceil(edges[0] + inset_x) + 2, width), bound(std::ceil(edges[1] + inset_y) + 2, height),
        bound(std::floor(edges[2] - inset_x) - 2, width), bound(std::floor(edges[3] - inset_y) - 2, height)};
}
