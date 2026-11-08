#pragma once
#include "native_graphite_bridge.h"
#include <algorithm>
#include <cmath>
#include <vector>

// Conservative, disjoint device-pixel bounds for separate straight contours.
// Keep the original path, matrix and GPU surface; only transfers are cropped.
struct VoxPathRegion {
    int left, top, right, bottom;
    int width() const { return right - left; }
    int height() const { return bottom - top; }
};

inline bool vox_sparse_path_regions(VoxGraphitePath const& path, int width, int height,
    std::vector<VoxPathRegion>& output)
{
    output.clear();
    auto const* m = path.matrix;
    if (!path.segments || path.segment_count <= 0 || path.segment_count > 128
        || path.stroke || path.gradient || path.has_clip || path.has_ancestor_clip
        || width <= 0 || height <= 0 || width > 16384 || height > 16384
        || size_t(width) * height < 8192
        || (m[0] != 1 && m[0] != 2) || (m[4] != 1 && m[4] != 2)
        || m[1] != 0 || m[3] != 0 || m[6] != 0 || m[7] != 0 || m[8] != 1)
        return false;
    for (float value : path.matrix)
        if (!std::isfinite(value) || std::abs(value) > 65536) return false;
    std::vector<VoxPathRegion> contours;
    float left = 0, top = 0, right = 0, bottom = 0;
    bool started = false;
    auto finish = [&] {
        if (!started) return;
        auto bound = [](double value, int limit) { return int(std::clamp(value, 0.0, double(limit))); };
        VoxPathRegion rect {bound(std::floor(left) - 2, width), bound(std::floor(top) - 2, height),
            bound(std::ceil(right) + 2, width), bound(std::ceil(bottom) + 2, height)};
        if (rect.width() > 0 && rect.height() > 0) contours.push_back(rect);
        started = false;
    };
    for (int i = 0; i < path.segment_count; ++i) {
        auto const* segment = path.segments + i * 12;
        float verb = segment[0];
        if (verb == 5) { finish(); continue; }
        // A zero-radius SVG arc is a straight line. Curves retain full replay.
        if (verb != 0 && verb != 1 && !(verb == 4 && (segment[7] == 0 || segment[8] == 0))) return false;
        if (verb == 4)
            for (int j = 7; j < 12; ++j)
                if (!std::isfinite(segment[j])) return false;
        if (verb == 0) finish();
        if (!started && verb != 0) return false;
        if (!std::isfinite(segment[1]) || !std::isfinite(segment[2])
            || std::abs(segment[1]) > 65536 || std::abs(segment[2]) > 65536) return false;
        float x = m[0] * segment[1] + m[2], y = m[4] * segment[2] + m[5];
        if (!started) { left = right = x; top = bottom = y; started = true; }
        else { left = std::min(left, x); right = std::max(right, x); top = std::min(top, y); bottom = std::max(bottom, y); }
    }
    finish();
    if (contours.size() < 2 || contours.size() > 16) return false;
    for (auto rect : contours) {
        std::vector<VoxPathRegion> pending {rect};
        for (auto prior : output) {
            std::vector<VoxPathRegion> remaining;
            for (auto part : pending) {
                int l = std::max(part.left, prior.left), t = std::max(part.top, prior.top);
                int r = std::min(part.right, prior.right), b = std::min(part.bottom, prior.bottom);
                if (l >= r || t >= b) { remaining.push_back(part); continue; }
                if (part.top < t) remaining.push_back({part.left, part.top, part.right, t});
                if (b < part.bottom) remaining.push_back({part.left, b, part.right, part.bottom});
                if (part.left < l) remaining.push_back({part.left, t, l, b});
                if (r < part.right) remaining.push_back({r, t, part.right, b});
            }
            pending = std::move(remaining);
            if (pending.size() + output.size() > 32) return false;
        }
        output.insert(output.end(), pending.begin(), pending.end());
    }
    size_t area = 0;
    for (auto rect : output) area += size_t(rect.width()) * rect.height();
    return !output.empty() && area <= 65536 && area * 2 < size_t(width) * height;
}
