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
	top_left := chromium_paint_corner_radius(computed.border_top_left_radius(), context, width, height)
	top_right := chromium_paint_corner_radius(computed.border_top_right_radius(), context, width, height)
	bottom_right := chromium_paint_corner_radius(computed.border_bottom_right_radius(), context, width, height)
	bottom_left := chromium_paint_corner_radius(computed.border_bottom_left_radius(), context, width, height)
	// FloatRoundedRect::ConstrainRadii applies one common float factor.
	horizontal := f32(math.max(f32(top_left.x) + f32(top_right.x), f32(bottom_left.x) + f32(bottom_right.x)))
	vertical := f32(math.max(f32(top_left.y) + f32(bottom_left.y), f32(top_right.y) + f32(bottom_right.y)))
	mut factor := f32(1)
	if horizontal > f32(width.to_double()) {
		factor = f32(math.min(f32(width.to_double()) / horizontal, factor))
	}
	if vertical > f32(height.to_double()) {
		factor = f32(math.min(f32(height.to_double()) / vertical, factor))
	}
	return BoxRadii{
		top_left: chromium_scale_paint_corner_radius(top_left, factor)
		top_right: chromium_scale_paint_corner_radius(top_right, factor)
		bottom_right: chromium_scale_paint_corner_radius(bottom_right, factor)
		bottom_left: chromium_scale_paint_corner_radius(bottom_left, factor)
	}
}
