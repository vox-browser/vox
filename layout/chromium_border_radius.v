module layout

import css
import math

// Blink's CalcRadiiFor uses SizeForLengthSize/FloatValueForLength, rather
// than LayoutUnit resolution. Keep the pre-snap box as the percentage basis.
// Quantizing these values to CSSPixels changes small rounded backgrounds.
fn chromium_paint_radius_length(value css.LengthPercentage, context css.LengthResolutionContext, basis CSSPixels) f32 {
	if value.is_percentage() {
		return f32(basis.to_double()) * f32(value.percentage().value()) / f32(100)
	}
	length := if value.is_length() { value.length() } else {
		css.Length.resolve_calculated_with_px(value.calculated(), context, basis)
	}
	return f32(length.to_px_without_rounding(context))
}

fn chromium_paint_corner_radius(radius css.BorderRadiusData, context css.LengthResolutionContext, width CSSPixels, height CSSPixels) CornerRadius {
	return CornerRadius{
		f64(chromium_paint_radius_length(radius.horizontal_radius, context, width)),
		f64(chromium_paint_radius_length(radius.vertical_radius, context, height)),
	}
}

fn chromium_scale_paint_corner_radius(radius CornerRadius, factor f32) CornerRadius {
	x := f32(radius.x) * factor
	y := f32(radius.y) * factor
	if factor != 1 && (x == 0 || y == 0) {
		return CornerRadius{}
	}
	return CornerRadius{f64(x), f64(y)}
}

fn chromium_paintable_box_border_radii(computed &css.ComputedValues, context css.LengthResolutionContext, width CSSPixels, height CSSPixels) BoxRadii {
	return chromium_paintable_box_border_radii_constrained(computed, context, width, height,
		f32(width.to_double()), f32(height.to_double()))
}

// Blink's ComputeContouredBorderFromStyle resolves radius lengths against the
// layout size but runs ConstrainRadii against the rect it paints, which for
// backgrounds and borders is the pixel-snapped border box. GitHub's 25.5px
// topic pills keep their 13px radius on the 26px snapped box.
fn chromium_paintable_box_border_radii_constrained(computed &css.ComputedValues, context css.LengthResolutionContext,
	width CSSPixels, height CSSPixels, constraint_width f32, constraint_height f32) BoxRadii {
	top_left := chromium_paint_corner_radius(computed.border_top_left_radius(), context, width, height)
	top_right := chromium_paint_corner_radius(computed.border_top_right_radius(), context, width, height)
	bottom_right := chromium_paint_corner_radius(computed.border_bottom_right_radius(), context, width, height)
	bottom_left := chromium_paint_corner_radius(computed.border_bottom_left_radius(), context, width, height)
	// An elliptical box (50% radii) stays an oval of the snapped box. Blink's
	// common factor leaves it a hair short of one (13x15.93 on a 26x32 avatar
	// laid out 26.11px wide), which looks the same in its analytic raster but
	// would move Vox off its exact oval raster path.
	half_width := f32(width.to_double()) / 2
	half_height := f32(height.to_double()) / 2
	if constraint_width > 0 && constraint_height > 0
		&& [top_left, top_right, bottom_right, bottom_left].all(f32(it.x) == half_width
		&& f32(it.y) == half_height) {
		oval := CornerRadius{f64(constraint_width / 2), f64(constraint_height / 2)}
		return BoxRadii{oval, oval, oval, oval}
	}
	// FloatRoundedRect::ConstrainRadii applies one common float factor.
	horizontal := f32(math.max(f32(top_left.x) + f32(top_right.x), f32(bottom_left.x) + f32(bottom_right.x)))
	vertical := f32(math.max(f32(top_left.y) + f32(bottom_left.y), f32(top_right.y) + f32(bottom_right.y)))
	mut factor := f32(1)
	if horizontal > constraint_width {
		factor = f32(math.min(constraint_width / horizontal, factor))
	}
	if vertical > constraint_height {
		factor = f32(math.min(constraint_height / vertical, factor))
	}
	return BoxRadii{
		top_left: chromium_scale_paint_corner_radius(top_left, factor)
		top_right: chromium_scale_paint_corner_radius(top_right, factor)
		bottom_right: chromium_scale_paint_corner_radius(bottom_right, factor)
		bottom_left: chromium_scale_paint_corner_radius(bottom_left, factor)
	}
}
