module layout

import css
import math

// Preserve the computed RGB precision until the native glyph paint is built.
// Synthetic/selected colors whose byte value differs keep their existing path.
fn chromium_text_srgb_color(fragment &TextFragment) &PaintSRGBColor {
	if fragment.layout_handle == unsafe { nil } { return unsafe { nil } }
	node := unsafe { &Node(fragment.layout_handle) }
	if node.document().font_rendering_policy() != .chromium { return unsafe { nil } }
	computed := unsafe { &css.ComputedProperties(node.computed_values()) }
	if node.computed_values().color() != fragment.color { return unsafe { nil } }
	value := computed.typed_property_value(.color) or { return unsafe { nil } }
	components := value.srgb_paint_components() or { return unsafe { nil } }
	// Even a legacy byte alpha must blend with glyph coverage before the final
	// page pixel is rounded. The native byte blitter rounds that product early.
	if fragment.color.a != 255 {
		return &PaintSRGBColor{fragment.color.serialize(), components}
	}
	bytes := [fragment.color.r, fragment.color.g, fragment.color.b, fragment.color.a]!
	for index in 0 .. 4 {
		if math.abs(components[index] * 255 - f64(bytes[index])) > 1e-6 {
			return &PaintSRGBColor{fragment.color.serialize(), components}
		}
	}
	return unsafe { nil }
}
