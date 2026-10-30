module layout

import css
import math

// Keep modern RGB paint alpha before SVGPaint resolves its byte color. RGB
// channels and legacy alpha continue through the existing color conversion.
fn chromium_svg_paint_alpha(node &Node, property css.PropertyID, resolved ?css.Color) ?f64 {
	color := resolved or { return none }
	if node.document().font_rendering_policy() != .chromium { return none }
	computed := unsafe { &css.ComputedProperties(node.computed_values()) }
	mut value := computed.typed_property_value(property) or { return none }
	if value.is_keyword() && value.to_keyword() == .currentcolor {
		value = computed.typed_property_value(.color) or { return none }
	}
	components := value.srgb_paint_components() or { return none }
	if math.abs(components[3] * 255 - f64(color.a)) <= 1e-6 { return none }
	return components[3]
}
