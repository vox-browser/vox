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
    // A uniform elliptical CSS border has independently inset radii. A
    // stroked ellipse offsets its contour instead, producing different edges.
    // Mode 6 receives the center rectangle and the uniform border width.
    if (mode == 6 || mode == 7) {
        SkRRect outside, inside;
        float half = widths[0] / 2;
        outer.outset(half, half, &outside);
        outer.inset(half, half, &inside);
        SkPaint fill(paint);
        fill.setStyle(SkPaint::kFill_Style);
        // Blink's background bleed avoidance clips a single layer to the
        // outer contour, then paints the background and inverse inner path.
        // Independent antialias coverage of a background and translucent
        // stroke darkens their shared edge.
        if (mode == 7 && background) {
            canvas->save();
            canvas->clipRRect(outside, SkClipOp::kIntersect, paint.isAntiAlias());
            // With an invisible border Blink only clips the background. A
            // drawRRect, or an unnecessary saveLayer, resolves its edge with
            // different GPU coverage and premultiplied rounding.
            if (paint.getAlphaf() == 0) {
                canvas->drawRect(outside.rect(), *background);
                canvas->restore();
                return;
            }
            canvas->saveLayer(nullptr, nullptr);
            canvas->drawRect(outside.rect(), *background);
            SkPathBuilder builder;
            builder.addRRect(inside);
            auto inverse_inner = builder.detach();
            inverse_inner.setFillType(SkPathFillType::kInverseWinding);
            canvas->drawPath(inverse_inner, fill);
            canvas->restore();
            canvas->restore();
            return;
        }
        canvas->drawDRRect(outside, inside, fill);
        return;
    }
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
    if (mode == 8) {
        // A square-ended, three-sided rounded label still paints each side
        // separately in Blink. Its soft missing-side clip and hard corner
        // miter must keep their order: combining the sides changes outer-edge
        // coverage even when every visible border has the same opaque color.
        bool missing_left = left == 0 && top > 0 && top == right && top == bottom;
        bool missing_right = right == 0 && top > 0 && top == left && top == bottom;
        auto upper = outer.radii(missing_left ? SkRRect::kUpperRight_Corner : SkRRect::kUpperLeft_Corner);
        auto lower = outer.radii(missing_left ? SkRRect::kLowerRight_Corner : SkRRect::kLowerLeft_Corner);
        auto square_upper = outer.radii(missing_left ? SkRRect::kUpperLeft_Corner : SkRRect::kUpperRight_Corner);
        auto square_lower = outer.radii(missing_left ? SkRRect::kLowerLeft_Corner : SkRRect::kLowerRight_Corner);
        if ((missing_left || missing_right) && upper == lower && upper.x() == upper.y()
            && upper.x() > top && upper.x() * 2 <= bounds.height()
            && upper.x() <= bounds.width() && square_upper.isZero() && square_lower.isZero()) {
            float l = bounds.left(), r = bounds.right(), t = bounds.top(), b = bounds.bottom();
            float depth = top + (upper.x() - top) / 2;
            // Blink extends the miter by 0.1 CSS pixels along its edge. This
            // keeps the soft missing-side rectangle from clipping its neighbor.
            constexpr float extension = .1f;
            SkPathBuilder top_path, bottom_path, end_path;
            if (missing_left) {
                top_path.moveTo(l, t).lineTo(l, t + depth)
                    .lineTo(r - depth + extension, t + depth).lineTo(r + extension, t);
                bottom_path.moveTo(r + extension, b).lineTo(r - depth + extension, b - depth)
                    .lineTo(l, b - depth).lineTo(l, b);
                end_path.moveTo(r, t).lineTo(r - depth, t + depth)
                    .lineTo(r - depth, b - depth).lineTo(r, b);
            } else {
                top_path.moveTo(l - extension, t).lineTo(l + depth - extension, t + depth)
                    .lineTo(r, t + depth).lineTo(r, t);
                bottom_path.moveTo(r, b).lineTo(r, b - depth)
                    .lineTo(l + depth - extension, b - depth).lineTo(l - extension, b);
                end_path.moveTo(l, b).lineTo(l + depth, b - depth)
                    .lineTo(l + depth, t + depth).lineTo(l, t);
            }
            auto top_clip = SkRect::MakeLTRB(l - (missing_left ? extension : 0), t,
                r + (missing_right ? extension : 0), t + depth);
            auto bottom_clip = SkRect::MakeLTRB(top_clip.left(), b - depth, top_clip.right(), b);
            auto top_miter = top_path.detach(), bottom_miter = bottom_path.detach();
            canvas->save();
            canvas->clipRRect(outer, SkClipOp::kIntersect, true);
            canvas->clipRRect(inner, SkClipOp::kDifference, true);
            for (int side : {0, 2, 1}) {
                canvas->save();
                if (side == 1) {
                    canvas->clipPath(end_path.detach(), SkClipOp::kIntersect, false);
                } else {
                    auto clip = side == 0 ? top_clip : bottom_clip;
                    auto const& miter = side == 0 ? top_miter : bottom_miter;
                    bool soft_first = (side == 0) == missing_left;
                    if (soft_first) canvas->clipRect(clip, SkClipOp::kIntersect, true);
                    canvas->clipPath(miter, SkClipOp::kIntersect, false);
                    if (!soft_first) canvas->clipRect(clip, SkClipOp::kIntersect, true);
                }
                canvas->drawRect(bounds, paint);
                canvas->restore();
            }
            canvas->restore();
            return;
        }
        // All present sides share an opaque solid color. Their union is the
        // border area; one clipped fill avoids seams at adjoining corners.
        canvas->save();
        canvas->clipRRect(outer, SkClipOp::kIntersect, true);
        canvas->clipRRect(inner, SkClipOp::kDifference, true);
        canvas->drawRect(bounds, paint);
        canvas->restore();
        return;
    }
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
