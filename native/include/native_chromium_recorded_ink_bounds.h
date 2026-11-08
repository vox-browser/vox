#pragma once
#include "include/core/SkMatrix.h"
#include "include/core/SkRRect.h"
#include <cmath>
#include <initializer_list>

// A rectangular clip on device-pixel edges has no coverage outside this box.
// Keep uncertain clips conservative: shrinking their ink could lose an AA
// fringe or change the raster phase of visible overflow.
inline SkRect vox_chromium_clip_recorded_ink(SkRect bounds, SkRRect const& clip,
    SkMatrix const& matrix, float scale)
{
    if (!bounds.isFinite() || !clip.isRect() || !matrix.isFinite()
        || !matrix.rectStaysRect() || !(scale > 0) || !std::isfinite(scale))
        return bounds;
    auto clipped = matrix.mapRect(clip.rect());
    if (!clipped.isFinite()) return bounds;
    for (float edge : {clipped.left(), clipped.top(), clipped.right(), clipped.bottom()}) {
        float device_edge = edge * scale;
        if (!std::isfinite(device_edge) || device_edge != std::floor(device_edge)) return bounds;
    }
    if (!bounds.intersect(clipped)) return SkRect::MakeEmpty();
    return bounds;
}
