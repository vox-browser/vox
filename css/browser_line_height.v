module css

import dom

fn compute_line_height_with_document_policy(value &dom.StyleValue, context ComputationContext) &dom.StyleValue {
	if element := context.abstract_element {
		if element.document().font_rendering_policy() == .chromium {
			if length := computed_interpolation_length_from_dom_style_value(value) {
				if length.is_absolute() {
					// Blink keeps fixed line heights as floats until layout. Rounding
					// here loses precision before the device-coordinate projection.
					return unsafe { value }
				}
			}
		}
	}
	return StyleComputer.compute_line_height(value, context.length_resolution_context.font_metrics.font_size)
}
