module layout

import css
import math

// Preserve fractional solid paint channels before SVGPaint resolves its byte
// color. The common exact-byte case needs no additional retained allocation.
fn chromium_svg_paint_components(node &Node, property css.PropertyID, resolved ?css.Color) ?[4]f64 {
	color := resolved or { return none }
	if node.document().font_rendering_policy() != .chromium { return none }
	computed := unsafe { &css.ComputedProperties(node.computed_values()) }
	mut value := computed.typed_property_value(property) or { return none }
	if value.is_keyword() && value.to_keyword() == .currentcolor {
		value = computed.typed_property_value(.color) or { return none }
	}
	components := value.srgb_paint_components() or { return none }
	bytes := [color.r, color.g, color.b, color.a]!
	for index in 0 .. 4 {
		if math.abs(components[index] * 255 - f64(bytes[index])) > 1e-6 {
			return components
		}
	}
	return none
}
