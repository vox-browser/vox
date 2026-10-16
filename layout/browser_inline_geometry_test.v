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
	mut document := html.parse_document('<!doctype html><style>
		body { margin:0 } #line { font:20px/20px SerenitySans }
		#small { font:10px/12px SerenitySans }
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
