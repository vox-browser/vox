module layout

import css

// SVG strokes use float user-space lengths in Chromium. A box-layout
// LayoutUnit truncates 1.2px to 1.1875px and changes multisample coverage.
fn svg_used_stroke_width(values &css.ComputedValues, percentage_basis f64, chromium bool) f64 {
	if !chromium {
		return values.length_percentage_to_px(.stroke_width, percentage_basis) or { 1.0 }
	}
	value := values.stroke_width()
	if value.is_percentage() {
		return f64(f32(percentage_basis * value.percentage().as_fraction()))
	}
	context := values.length_resolution_context()
	length := if value.is_length() {
		value.length()
	} else {
		css.Length.resolve_calculated_with_px(value.calculated(), context,
			css.CSSPixels.nearest_value_for(percentage_basis))
	}
	return f64(f32(length.to_px_without_rounding(context)))
}
