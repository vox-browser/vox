module css

import dom
import os

const retain_layout_length_value_copies = os.getenv('VOX_RETAIN_LAYOUT_LENGTH_VALUE_COPIES') != ''
const borrowed_layout_length_diagnostics = os.getenv('VOX_BORROWED_LAYOUT_LENGTH_DIAGNOSTICS') != ''

__global borrowed_layout_length_reported_document dom.UniqueNodeID

// Read scalar payloads in place. This retains no value across calls, so a live
// animation or mutation is observed through the ordinary property lookup.
// Relative lengths, calculations and untyped compatibility values still use
// the complete context-consuming path in computed_length.v.
fn (c &ComputedProperties) borrowed_scalar_layout_length_px(value &dom.StyleValue, basis f64) ?f64 {
	if retain_layout_length_value_copies || value.css_value_handle == unsafe { nil } {
		return none
	}
	box := unsafe { &TypedStyleValueBox(value.css_value_handle) }
	mut pixels := f64(0)
	if box.value is LengthStyleValue {
		length := box.value.length_
		if !length.is_absolute() { return none }
		pixels = c.absolute_layout_length_to_px(length).to_double()
	} else if box.value is PercentageStyleValue {
		pixels = LengthPercentage.from_percentage(box.value.percentage_).to_px(
			LengthResolutionContext{}, CSSPixels.nearest_value_for(basis)).to_double()
	} else {
		return none
	}
	c.report_borrowed_layout_length()
	return pixels
}

fn (c &ComputedProperties) report_borrowed_layout_length() {
	if !borrowed_layout_length_diagnostics { return }
	element := c.subject_element_ or { return }
	document := element.document()
	identity := document.as_node().unique_id()
	if borrowed_layout_length_reported_document != identity {
		borrowed_layout_length_reported_document = identity
		eprintln('Vox layout lengths: read retained scalar payload; document=${document.url.serialize()}')
	}
}
