module layout

import css
import html
import platform

fn test_browser_inline_leading_puts_odd_remainder_below_the_baseline() {
	metrics := platform.FontPixelMetrics{ascent: 14, descent: 3, floor_inline_leading: true}
	assert font_baseline_for_line_height(metrics, CSSPixels.new(18)).to_double() == 14
	assert font_baseline_for_line_height(metrics, CSSPixels.nearest_value_for(20.5)).to_double() == 15
	assert font_baseline_for_line_height(metrics, CSSPixels.new(16)).to_double() == 13
	assert font_baseline_for_line_height(platform.FontPixelMetrics{ascent: 14, descent: 3}, CSSPixels.new(18)).to_double() == 14.5
}

fn test_middle_alignment_uses_the_immediate_parent_font_and_retains_fractional_offset() {
	// A file-backed face keeps the fixture independent of installed fonts.
	serenity := platform.document_font_path(400) or { panic('missing test font') }
	mut document := html.parse_document('<!doctype html><style>
		@font-face { font-family:Fixture; src:url("file://${serenity}") }
		body { margin:0 } #line { font:20px/20px Fixture }
		#small { font:10px/12px Fixture }
		#middle { display:inline-block; width:20px; height:12px; vertical-align:middle }
	</style><div id="line">X<span id="small">x<span id="middle"></span></span></div>')
	document.set_font_rendering_policy(.chromium)
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	mut middle := ?&Node(none)
	mut line := ?&Node(none)
	mut pending := [result.root]
	for pending.len > 0 {
		node := pending.pop()
		if source := node.dom_node() {
			if element := source.as_element() {
				if element.get_attribute_value('id') == 'middle' { middle = node }
				if element.get_attribute_value('id') == 'line' { line = node }
			}
		}
		pending << node.children()
	}
	line_node := line or { panic('missing line') }
	middle_node := middle or { panic('missing middle') }
	line_state := result.used_values_for(line_node.as_node_with_style() or { panic('style') }) or { panic('line state') }
	middle_state := result.used_values_for(middle_node.as_node_with_style() or { panic('style') }) or { panic('middle state') }
	// SerenitySans at 10px has a 5.375px x-height: the 12px box's center
	// sits 2.6875px above the common baseline, including through the span.
	assert line_state.line_boxes.len == 1
	baseline := line_state.line_boxes[0].baseline().to_double()
	assert middle_state.offset.y().to_double() == baseline - 6 - 2.6875
}

fn test_chromium_middle_alignment_rounds_the_projected_x_height() {
	mut document := html.parse_document('<!doctype html><div></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	for scale in [1.0, 2.0] {
		document.set_layout_coordinate_scale(scale)
		result := run_document_layout(document, 800, 600) or { panic('layout') }
		node := result.root
		// Blink rounds half the selected font metric in layout coordinates.
		// At scale 2 this is 8.734375, rather than twice 4.359375.
		offset := middle_alignment_offset(node, CSSPixels.new(0), CSSPixels.new(0),
			CSSPixels.new(0), f32(8.7265625 * scale))
		assert offset == CSSPixels.nearest_value_for(if scale == 1 { -4.359375 } else { -8.734375 })
	}
}
