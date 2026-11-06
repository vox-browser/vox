module css

import os

const retain_font_radius_longhands = os.getenv('VOX_RETAIN_FONT_RADIUS_LONGHANDS') != ''
const font_radius_longhand_diagnostics = os.getenv('VOX_FONT_RADIUS_LONGHAND_DIAGNOSTICS') != ''
__global font_radius_longhand_reported bool

// Only the two scalar components of a direct border-radius value. The caller
// reuses the existing exact radius snapshot/hash and font-size environment key.
// Lists, calculations and current-font/metric units stay excluded.
fn font_radius_longhand_is_reusable(value &StyleValue) bool {
	if retain_font_radius_longhands || retain_font_size_unit_longhands
		|| disable_longhand_shape_reuse { return false }
	if value !is BorderRadiusStyleValue { return false }
	if value.horizontal_radius.len != 1 || value.vertical_radius.len != 1 { return false }
	horizontal := &value.horizontal_radius[0]
	vertical := &value.vertical_radius[0]
	return (font_radius_component_uses_font_size(horizontal) || font_radius_component_uses_font_size(vertical))
		&& (longhand_radius_component_is_simple(horizontal) || font_radius_component_uses_font_size(horizontal))
		&& (longhand_radius_component_is_simple(vertical) || font_radius_component_uses_font_size(vertical))
}

fn font_radius_component_uses_font_size(value &StyleValue) bool {
	return value is LengthStyleValue && value.length_.unit_ == .rem
}

fn report_font_radius_longhand_reuse(inputs []ComputedLonghandReuseInput) {
	if !font_radius_longhand_diagnostics || font_radius_longhand_reported { return }
	for input in inputs {
		if input.snapshot.kind != .border_radius { continue }
		for component in input.snapshot.children {
			if component.kind == .length && component.length_unit == .rem {
				font_radius_longhand_reported = true
				eprintln('Vox font radius longhands: restored guarded rem radius')
				return
			}
		}
	}
}
