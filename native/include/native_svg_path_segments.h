#ifndef VOX_NATIVE_SVG_PATH_SEGMENTS_H
#define VOX_NATIVE_SVG_PATH_SEGMENTS_H

// Builds an SkPath from the browser's serialized SVG segments (twelve floats
// per segment, beginning with the segment kind) for the Graphite backend. It
// mirrors path_from_serialized_segments() in native_skia_text_darwin.cpp,
// using the builder API of the backend's newer Skia.
#include "include/core/SkPathBuilder.h"
#include <cmath>

inline SkPath vox_path_from_serialized_segments(float const* data, int segment_count)
{
    SkPathBuilder path;
    if (!data || segment_count <= 0)
        return path.detach();

    float last_move_x = 0.0f;
    float last_move_y = 0.0f;
    bool has_move = false;
    for (int index = 0; index < segment_count; ++index) {
        auto const* segment = data + index * 12;
        switch (static_cast<int>(segment[0])) {
        case 0:
            path.moveTo(segment[1], segment[2]);
            last_move_x = segment[1];
            last_move_y = segment[2];
            has_move = true;
            break;
        case 1:
            path.lineTo(segment[1], segment[2]);
            break;
        case 2:
            path.quadTo(segment[3], segment[4], segment[1], segment[2]);
            break;
        case 3:
            path.cubicTo(segment[3], segment[4], segment[5], segment[6],
                segment[1], segment[2]);
            break;
        case 4:
            path.arcTo({std::abs(segment[7]), std::abs(segment[8])},
                segment[9] * 180.0f / static_cast<float>(M_PI),
                segment[10] != 0.0f ? SkPathBuilder::kLarge_ArcSize : SkPathBuilder::kSmall_ArcSize,
                segment[11] != 0.0f ? SkPathDirection::kCW : SkPathDirection::kCCW,
                {segment[1], segment[2]});
            break;
        case 5:
            path.close();
            // Gfx::PathImplSkia starts a fresh contour at the last move point
            // after close(), so retain the same behavior for subsequent segments.
            if (has_move)
                path.moveTo(last_move_x, last_move_y);
            break;
        case 6:
            // Explicit SVG circle/ellipse provenance, never inferred from arcs.
            // LTRB bounds use the existing twelve-float segment stride.
            if (std::isfinite(segment[1]) && std::isfinite(segment[2])
                && std::isfinite(segment[3]) && std::isfinite(segment[4])
                && segment[3] > segment[1] && segment[4] > segment[2])
                path.addOval(SkRect::MakeLTRB(segment[1], segment[2], segment[3], segment[4]),
                    SkPathDirection::kCW, 1);
            break;
        default:
            break;
        }
    }
    return path.detach();
}

#endif
