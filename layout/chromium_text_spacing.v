module layout

import css

// Blink retains floating CSS spacing in its font description and applies it
// at text-run precision. Rounding each letter to a 26.6 box-layout unit moves
// later glyphs across the rasterizer's subpixel positions.
fn resolved_text_spacing_for_shaping(node &Node, property_id css.PropertyID) f64 {
	if node.document().font_rendering_policy() != .chromium {
		return resolved_text_spacing_for_node(node, property_id).to_double()
	}
	computed := node.computed_values()
	length := computed.length(property_id)
	if length.is_absolute() {
		return length.absolute_length_to_px_without_rounding()
	}
	mut context := css.LengthResolutionContext.for_document(node.document())
	metrics := layout_font_metrics_for_node(node)
	font_size := computed.resolved_font_size_px()
	context.font_metrics.font_size = CSSPixels.nearest_value_for(font_size)
	context.font_metrics.font_size_unrounded = font_size
	context.font_metrics.x_height = CSSPixels.nearest_value_for(f64(metrics.x_height))
	context.font_metrics.x_height_unrounded = f64(metrics.x_height)
	context.font_metrics.cap_height = CSSPixels.nearest_value_for(font_size * .75)
	context.font_metrics.zero_advance = CSSPixels.nearest_value_for(f64(metrics.advance_of_ascii_zero))
	context.font_metrics.zero_advance_unrounded = f64(metrics.advance_of_ascii_zero)
	context.font_metrics.line_height = computed.line_height()
	return length.to_px_without_rounding(context)
}
