module css

import dom
import os

const disable_absolute_font_size_computation = os.getenv('VOX_DISABLE_ABSOLUTE_FONT_SIZE_COMPUTATION') != ''
const absolute_font_size_computation_diagnostics = os.getenv('VOX_ABSOLUTE_FONT_SIZE_COMPUTATION_DIAGNOSTICS') != ''
__global absolute_font_size_computation_reported bool

// Absolute font lengths need neither parent-face metrics nor a query-container
// context. Preserve the document's precise Chromium versus CSS-pixel rounding
// policy; relative, calculated and compatibility values keep the full resolver.
fn compute_absolute_font_size(value &dom.StyleValue, document &dom.Document) ?&dom.StyleValue {
	if disable_absolute_font_size_computation || value.css_value_handle == unsafe { nil } { return none }
	box := unsafe { &TypedStyleValueBox(value.css_value_handle) }
	if box.value !is LengthStyleValue || !box.value.length_.is_absolute() { return none }
	pixels := box.value.length_.absolute_length_to_px_without_rounding()
	length := if document.font_rendering_policy() == .chromium {
		Length.make_px(pixels)
	} else {
		Length.make_css_px(CSSPixels.nearest_value_for(pixels))
	}
	if absolute_font_size_computation_diagnostics && !absolute_font_size_computation_reported {
		absolute_font_size_computation_reported = true
		eprintln('VOX_ABSOLUTE_FONT_SIZE_COMPUTATION resolved without parent metrics')
	}
	return dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(length)))
}
