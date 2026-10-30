module layout

import css
import math

// Solid underlines share the glyph painter's computed sRGB precision. Keep
// synthetic highlight/error colors on their existing path, and retain a fresh
// immutable payload so later style changes cannot modify an earlier recording.
fn chromium_decoration_srgb_color(fragment &TextFragment, serialized string) &PaintSRGBColor {
	if fragment.layout_handle == unsafe { nil } { return unsafe { nil } }
	node := unsafe { &Node(fragment.layout_handle) }
	if node.document().font_rendering_policy() != .chromium { return unsafe { nil } }
	values := node.computed_values()
	color := values.text_decoration_color()
	if color.serialize() != serialized { return unsafe { nil } }
	computed := unsafe { &css.ComputedProperties(values) }
	mut value := computed.typed_property_value(.text_decoration_color) or { return unsafe { nil } }
	if value.is_keyword() && value.to_keyword() == .currentcolor {
		value = computed.typed_property_value(.color) or { return unsafe { nil } }
	}
	components := value.srgb_paint_components() or { return unsafe { nil } }
	bytes := [color.r, color.g, color.b, color.a]!
	for index in 0 .. 4 {
		if math.abs(components[index] * 255 - f64(bytes[index])) > 1e-6 {
			return &PaintSRGBColor{serialized, components}
		}
	}
	return unsafe { nil }
}
