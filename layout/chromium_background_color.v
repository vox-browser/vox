module layout

import css
import math

pub struct PaintSRGBColor {
pub:
	serialized string
	components [4]f64
}

fn chromium_background_srgb_color(node &Node, computed &css.ComputedProperties,
	color css.Color) &PaintSRGBColor {
	if node.document().font_rendering_policy() != .chromium { return unsafe { nil } }
	value := computed.typed_property_value(.background_color) or { return unsafe { nil } }
	components := value.srgb_paint_components() or { return unsafe { nil } }
	// Opaque legacy sRGB backgrounds are the supported float-color slice.
	if components[3] != 1 { return unsafe { nil } }
	bytes := [color.r, color.g, color.b, color.a]!
	for index in 0 .. 3 {
		if math.abs(components[index] * 255 - f64(bytes[index])) > 1e-6 {
			retained := PaintSRGBColor{color.serialize(), components}
			return &retained
		}
	}
	return unsafe { nil }
}
