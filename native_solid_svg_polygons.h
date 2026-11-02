#pragma once

#include "native_graphite_bridge.h"
#include <algorithm>
#include <array>
#include <cmath>
#include <cstring>
#include <vector>

// Resolve a small opaque polygon batch at the four standard Metal sample
// positions. Convex analytic primitives, fractional clips, curves, blending
// and ambiguous sample boundaries retain the original GPU renderer. Output is
// transactional: even a late eligibility failure leaves the backdrop intact.
inline bool vox_draw_solid_svg_polygons(VoxGraphitePixelRegion const& view,
    VoxGraphitePath const* paths, int count, float const* parent,
    float const* viewport, float const* device_clip)
{
    if (!view.pixels || view.x < 0 || view.y < 0 || view.x > 4096 || view.y > 4096
        || view.width <= 0 || view.height <= 0
        || view.width > 128 || view.height > 128 || view.pitch <= 0
        || size_t(view.pitch) < size_t(view.width) * 4 || !paths || count <= 0
        || count > 8 || !parent || !viewport || !device_clip) return false;
    auto axis_matrix = [](float const* m) {
        return m[0] > 0 && m[0] <= 16 && m[4] > 0 && m[4] <= 16
            && m[1] == 0 && m[3] == 0 && m[6] == 0 && m[7] == 0 && m[8] == 1
            && std::isfinite(m[2]) && std::isfinite(m[5])
            && std::abs(m[2]) <= 4096 && std::abs(m[5]) <= 4096;
    };
    if (!axis_matrix(parent)) return false;
    float clip[] {parent[0] * viewport[0] + parent[2], parent[4] * viewport[1] + parent[5],
        parent[0] * (viewport[0] + viewport[2]) + parent[2],
        parent[4] * (viewport[1] + viewport[3]) + parent[5]};
    for (int i = 0; i < 4; ++i) {
        if (!std::isfinite(clip[i]) || clip[i] != std::floor(clip[i])
            || !std::isfinite(device_clip[i]) || device_clip[i] != std::floor(device_clip[i])) return false;
    }
    clip[0] = std::max(clip[0], device_clip[0]); clip[1] = std::max(clip[1], device_clip[1]);
    clip[2] = std::min(clip[2], device_clip[2]); clip[3] = std::min(clip[3], device_clip[3]);
    struct Point { double x, y; };
    struct Polygon { std::vector<Point> points, snapped; uint32_t color; bool even_odd; };
    std::vector<Polygon> polygons;
    for (int index = 0; index < count; ++index) {
        auto const& source = paths[index];
        if (source.stroke || source.gradient || source.has_clip || source.has_ancestor_clip
            || source.alpha != 255 || (source.has_float_alpha && source.opacity != 1)
            || !source.segments || source.segment_count < 4 || source.segment_count > 34
            || !axis_matrix(source.matrix)) return false;
        if (source.has_float_color && (source.float_color[0] != source.red / 255.f
            || source.float_color[1] != source.green / 255.f
            || source.float_color[2] != source.blue / 255.f || source.float_color[3] != 1)) return false;
        Polygon polygon;
        polygon.color = 0xff000000u | uint32_t(source.red) << 16 | uint32_t(source.green) << 8 | source.blue;
        polygon.even_odd = source.even_odd;
        float ax = parent[0] * source.matrix[0], ay = parent[4] * source.matrix[4];
        float tx = parent[0] * source.matrix[2] + parent[2];
        float ty = parent[4] * source.matrix[5] + parent[5];
        for (int i = 0; i < source.segment_count; ++i) {
            auto* segment = source.segments + i * 12;
            if (segment[0] != (i == 0 ? 0 : i == source.segment_count - 1 ? 5 : 1)) return false;
            if (i == source.segment_count - 1) break;
            if (!std::isfinite(segment[1]) || !std::isfinite(segment[2])
                || std::abs(segment[1]) > 65536 || std::abs(segment[2]) > 65536) return false;
            Point point {ax * segment[1] + tx, ay * segment[2] + ty};
            if (!std::isfinite(point.x) || !std::isfinite(point.y)
                || std::abs(point.x) > 4096 || std::abs(point.y) > 4096) return false;
            polygon.points.push_back(point);
            polygon.snapped.push_back({std::round(point.x * 256) / 256, std::round(point.y * 256) / 256});
        }
        bool positive = false, negative = false, rectangle = polygon.points.size() == 4;
        for (size_t i = 0; i < polygon.points.size(); ++i) {
            auto a = polygon.points[i], b = polygon.points[(i + 1) % polygon.points.size()];
            auto c = polygon.points[(i + 2) % polygon.points.size()];
            double turn = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x);
            positive |= turn > 0; negative |= turn < 0;
            rectangle &= (a.x == b.x || a.y == b.y)
                && a.x == std::floor(a.x) && a.y == std::floor(a.y) && (a.x != b.x || a.y != b.y);
        }
        // Non-convex paths select stencil MSAA; convex paths can instead use
        // analytic coverage even in an MSAA render pass.
        if (!(positive && negative) && !rectangle) return false;
        polygons.push_back(std::move(polygon));
    }
    auto inside = [](std::vector<Point> const& points, double x, double y, bool even_odd, bool& safe) {
        int winding = 0;
        for (size_t i = 0; i < points.size(); ++i) {
            auto a = points[i], b = points[(i + 1) % points.size()];
            double dx = b.x - a.x, dy = b.y - a.y;
            double cross = dx * (y - a.y) - dy * (x - a.x);
            if (x >= std::min(a.x, b.x) - .001 && x <= std::max(a.x, b.x) + .001
                && y >= std::min(a.y, b.y) - .001 && y <= std::max(a.y, b.y) + .001
                && cross * cross < (dx * dx + dy * dy) * .000001) safe = false;
            if (a.y <= y && b.y > y && cross > 0) ++winding;
            else if (a.y > y && b.y <= y && cross < 0) --winding;
        }
        return even_odd ? winding % 2 != 0 : winding != 0;
    };
    std::vector<uint8_t> output(size_t(view.width) * view.height * 4);
    constexpr double samples[4][2] {{.375, .125}, {.875, .375}, {.125, .625}, {.625, .875}};
    for (int row = 0; row < view.height; ++row) for (int column = 0; column < view.width; ++column) {
        auto* pixel = view.pixels + size_t(row) * view.pitch + column * 4;
        if (pixel[3] != 255) return false;
        uint32_t backdrop; std::memcpy(&backdrop, pixel, 4);
        unsigned sums[4] {};
        for (auto const& sample : samples) {
            double x = view.x + column + sample[0], y = view.y + row + sample[1];
            uint32_t color = backdrop;
            if (x >= clip[0] && y >= clip[1] && x < clip[2] && y < clip[3]) {
                for (auto const& polygon : polygons) {
                    bool safe = true;
                    // Keep full-precision and subpixel-grid classifications
                    // equal, with a safety band at both sets of edges.
                    bool covered = inside(polygon.points, x, y, polygon.even_odd, safe);
                    bool snapped = inside(polygon.snapped, x, y, polygon.even_odd, safe);
                    if (!safe || covered != snapped) return false;
                    if (covered) color = polygon.color;
                }
            }
            for (int channel = 0; channel < 4; ++channel) sums[channel] += (color >> (channel * 8)) & 255;
        }
        auto* result = output.data() + (size_t(row) * view.width + column) * 4;
        for (int channel = 0; channel < 4; ++channel) result[channel] = (sums[channel] + 2) / 4;
    }
    for (int row = 0; row < view.height; ++row)
        std::memcpy(view.pixels + size_t(row) * view.pitch, output.data() + size_t(row) * view.width * 4, size_t(view.width) * 4);
    return true;
}
