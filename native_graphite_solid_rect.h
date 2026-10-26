#ifndef VOX_NATIVE_GRAPHITE_SOLID_RECT_H
#define VOX_NATIVE_GRAPHITE_SOLID_RECT_H

#include "native_graphite_bridge.h"
#include <algorithm>
#include <cmath>
#include <cstring>

// An opaque, pixel-aligned rectangle has full coverage at every interior
// sample, including MSAA. Its pixels do not depend on the backdrop. Leave
// partial coverage, blending, rounded corners and compound draws to Graphite.
inline bool vox_axis_aligned_rect(VoxGraphiteShape const& shape, float (&edges)[4])
{
    if (!(shape.rect[2] > 0) || !(shape.rect[3] > 0)
        || (shape.matrix[0] != 1 && shape.matrix[0] != 2)
        || (shape.matrix[4] != 1 && shape.matrix[4] != 2)
        || shape.matrix[1] != 0 || shape.matrix[3] != 0
        || shape.matrix[6] != 0 || shape.matrix[7] != 0 || shape.matrix[8] != 1) return false;
    // Match the rectangle's mapped endpoints, retaining exact device alignment.
    edges[0] = shape.matrix[0] * shape.rect[0] + shape.matrix[2];
    edges[1] = shape.matrix[4] * shape.rect[1] + shape.matrix[5];
    edges[2] = shape.matrix[0] * (shape.rect[0] + shape.rect[2]) + shape.matrix[2];
    edges[3] = shape.matrix[4] * (shape.rect[1] + shape.rect[3]) + shape.matrix[5];
    for (float edge : edges) if (!std::isfinite(edge)) return false;
    return true;
}

inline bool vox_aligned_opaque_rect(VoxGraphiteShape const& shape, float (&edges)[4])
{
    if (shape.fill != 1 || shape.alpha != 255 || shape.has_underlay || shape.clip_out_count
        || !vox_axis_aligned_rect(shape, edges)) return false;
    for (float edge : edges) if (edge != std::floor(edge)) return false;
    return true;
}

inline bool vox_draw_solid_rect(uint8_t* pixels, int width, int height, int pitch,
    bool has_background, VoxGraphiteShape const& shape)
{
    if (!pixels || width <= 0 || height <= 0 || pitch <= 0 || size_t(pitch) < size_t(width) * 4) return false;
    float edges[4];
    if (!vox_aligned_opaque_rect(shape, edges)) return false;
    for (int i = 4; i < 12; ++i) if (shape.rect[i] != 0) return false;
    int left = int(std::clamp<double>(edges[0], 0, width));
    int top = int(std::clamp<double>(edges[1], 0, height));
    int right = int(std::clamp<double>(edges[2], 0, width));
    int bottom = int(std::clamp<double>(edges[3], 0, height));
    uint32_t color = 0xff000000u | uint32_t(shape.red) << 16 | uint32_t(shape.green) << 8 | shape.blue;
    for (int y = 0; y < height; ++y) {
        auto* row = pixels + size_t(y) * pitch;
        if (!has_background) std::memset(row, 0, size_t(width) * 4);
        if (y >= top && y < bottom)
            for (int x = left; x < right; ++x) std::memcpy(row + size_t(x) * 4, &color, 4);
    }
    return true;
}

// A rectangular stroke whose inner and outer edges both land on device
// pixels is four fully covered opaque strips. Keep fractional, rounded and
// compound strokes on the original GPU path.
inline bool vox_draw_solid_stroke(uint8_t* pixels, int width, int height, int pitch,
    bool has_background, VoxGraphiteShape const& shape)
{
    if (shape.fill || shape.alpha != 255 || shape.has_underlay || shape.clip_out_count
        || !pixels || width <= 0 || height <= 0 || pitch <= 0 || size_t(pitch) < size_t(width) * 4)
        return false;
    for (int i = 4; i < 12; ++i) if (shape.rect[i] != 0) return false;
    float edges[4];
    if (!vox_axis_aligned_rect(shape, edges)) return false;
    float dx = shape.thickness * shape.matrix[0] / 2;
    float dy = shape.thickness * shape.matrix[4] / 2;
    if (!(dx > 0 && dy > 0) || !std::isfinite(dx) || !std::isfinite(dy)
        || edges[2] - edges[0] <= dx * 2 || edges[3] - edges[1] <= dy * 2) return false;
    float outer[] {edges[0] - dx, edges[1] - dy, edges[2] + dx, edges[3] + dy};
    float inner[] {edges[0] + dx, edges[1] + dy, edges[2] - dx, edges[3] - dy};
    for (auto edge : outer) if (!std::isfinite(edge) || edge != std::floor(edge)) return false;
    for (auto edge : inner) if (!std::isfinite(edge) || edge != std::floor(edge)) return false;
    if (!(outer[0] < inner[0] && inner[0] < inner[2] && inner[2] < outer[2]
        && outer[1] < inner[1] && inner[1] < inner[3] && inner[3] < outer[3])) return false;
    if (!has_background) for (int y = 0; y < height; ++y)
        std::memset(pixels + size_t(y) * pitch, 0, size_t(width) * 4);
    VoxGraphiteShape strip {};
    strip.fill = 1; strip.alpha = 255;
    strip.red = shape.red; strip.green = shape.green; strip.blue = shape.blue;
    strip.matrix[0] = strip.matrix[4] = strip.matrix[8] = 1;
    auto draw = [&](float left, float top, float right, float bottom) {
        left = std::clamp(left, 0.0f, float(width)); right = std::clamp(right, 0.0f, float(width));
        top = std::clamp(top, 0.0f, float(height)); bottom = std::clamp(bottom, 0.0f, float(height));
        if (left >= right || top >= bottom) return true;
        strip.rect[0] = left; strip.rect[1] = top;
        strip.rect[2] = right - left; strip.rect[3] = bottom - top;
        return vox_draw_solid_rect(pixels, width, height, pitch, true, strip);
    };
    return draw(outer[0], outer[1], outer[2], inner[1])
        && draw(outer[0], inner[3], outer[2], outer[3])
        && draw(outer[0], inner[1], inner[0], inner[3])
        && draw(inner[2], inner[1], outer[2], inner[3]);
}

#endif
