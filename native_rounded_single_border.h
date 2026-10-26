#ifndef VOX_NATIVE_ROUNDED_SINGLE_BORDER_H
#define VOX_NATIVE_ROUNDED_SINGLE_BORDER_H

#include "include/core/SkCanvas.h"
#include "include/core/SkPaint.h"
#include "include/core/SkPathBuilder.h"
#include "include/core/SkRRect.h"
#include <algorithm>

// A single solid rounded CSS border uses Blink's outer/interior clips and a
// rectangle fill. The draw modes 2..5 select top, right, bottom and left.
inline void vox_draw_rounded_single_border(SkCanvas* canvas, SkRRect const& outer,
    SkPaint const& paint, int mode, float const* widths, SkPaint const* background = nullptr)
{
    float top = widths[0], right = widths[1], bottom = widths[2], left = widths[3];
    SkVector radii[4];
    for (int i = 0; i < 4; ++i) {
        auto radius = outer.radii(static_cast<SkRRect::Corner>(i));
        radii[i] = {std::max(0.f, radius.x() - (i == 0 || i == 3 ? left : right)),
            std::max(0.f, radius.y() - (i < 2 ? top : bottom))};
    }
    auto bounds = outer.rect();
    SkRRect inner;
    inner.setRectRadii(SkRect::MakeLTRB(bounds.left() + left, bounds.top() + top,
        bounds.right() - right, bounds.bottom() - bottom), radii);
    canvas->save();
    if (background) {
        canvas->clipRRect(outer, SkClipOp::kIntersect, true);
        canvas->saveLayer(bounds, nullptr);
        canvas->drawRect(bounds, *background);
    }
    int side = mode - 2;
    bool isolated_side = true;
    for (int i = 0; i < 4; ++i)
        if (i != side && widths[i] > 0) isolated_side = false;
    // A missing adjacent side needs only Blink's corner-extent rectangle,
    // after the rounded clips. A hard half-plane before them changes coverage.
    if (isolated_side && !background) {
        canvas->clipRRect(outer, SkClipOp::kIntersect, true);
        canvas->clipRRect(inner, SkClipOp::kDifference, true);
        auto side_bounds = bounds;
        if (side == 0) side_bounds.fBottom = bounds.top() + std::max({top,
            outer.radii(SkRRect::kUpperLeft_Corner).y(), outer.radii(SkRRect::kUpperRight_Corner).y()});
        if (side == 1) side_bounds.fLeft = bounds.right() - std::max({right,
            outer.radii(SkRRect::kUpperRight_Corner).x(), outer.radii(SkRRect::kLowerRight_Corner).x()});
        if (side == 2) side_bounds.fTop = bounds.bottom() - std::max({bottom,
            outer.radii(SkRRect::kLowerLeft_Corner).y(), outer.radii(SkRRect::kLowerRight_Corner).y()});
        if (side == 3) side_bounds.fRight = bounds.left() + std::max({left,
            outer.radii(SkRRect::kUpperLeft_Corner).x(), outer.radii(SkRRect::kLowerLeft_Corner).x()});
        // Match Blink's save level around the side-extent clip and draw.
        canvas->save();
        canvas->clipRect(side_bounds, SkClipOp::kIntersect, true);
        canvas->drawRect(bounds, paint);
        canvas->restore();
        canvas->restore();
        return;
    }
    // Exclude the opposite pair of corners for transparent adjacent borders.
    // The caller requires non-overlapping corners.
    auto side_bounds = bounds;
    if (mode == 2) side_bounds.fBottom = bounds.centerY();
    if (mode == 3) side_bounds.fLeft = bounds.centerX();
    if (mode == 4) side_bounds.fTop = bounds.centerY();
    if (mode == 5) side_bounds.fRight = bounds.centerX();
    canvas->clipRect(side_bounds, SkClipOp::kIntersect, false);
    if (!background) canvas->clipRRect(outer, SkClipOp::kIntersect, true);
    canvas->clipRRect(inner, SkClipOp::kDifference, true);
    // Blink clips each differently colored adjacent side with its own
    // difference quadrilateral. Combining them into one polygon changes the
    // multisampled coverage of the rounded corner.
    SkPoint corners[4] = {{bounds.left(), bounds.top()}, {bounds.right(), bounds.top()},
        {bounds.right(), bounds.bottom()}, {bounds.left(), bounds.bottom()}};
    SkVector offsets[4] = {{left, top}, {-right, top}, {-right, -bottom}, {left, -bottom}};
    int ends[2] = {side, (side + 1) % 4};
    float adjacent_widths[2] = {widths[(side + 3) % 4], widths[(side + 1) % 4]};
    for (int end = 0; end < 2; ++end) {
        if (!(adjacent_widths[end] > 0)) continue;
        int corner = ends[end];
        int adjacent = (corner + (end == 0 ? 3 : 1)) % 4;
        auto outer_corner = corners[corner];
        auto offset = offsets[corner];
        float extent = (side == 0 || side == 2) ? bounds.height() : bounds.width();
        float side_width = widths[side];
        auto intersection = outer_corner + offset * ((extent + side_width) / side_width);
        auto a = corners[adjacent];
        SkPathBuilder miter;
        miter.moveTo(outer_corner - offset).lineTo(intersection)
            .lineTo(a + offset).lineTo(a - offset).close();
        canvas->clipPath(miter.detach(), SkClipOp::kDifference, true);
    }
    canvas->drawRect(bounds, paint);
    if (background) canvas->restore();
    canvas->restore();
}

#endif
