module layout

import css
import dom
import html

fn test_svg_text_position_lengths_resolve_against_the_element_font_and_viewport() {
	mut resolution := css.LengthResolutionContext.default()
	resolution.font_metrics.font_size = css.CSSPixels.new(10)
	resolution.root_font_metrics.font_size = css.CSSPixels.new(16)
	for input, expected in {'3em': f64(30), '-2em': -20, '2rem': 32, '1in': 96,
		'12px, 40': 12, '25%': 50, '-2.5': -2.5, '1e1': 10} {
		assert first_svg_text_position(input, CSSPixels.new(200), resolution)? == expected, input
	}
	assert first_svg_text_position('12wat', CSSPixels.new(200), resolution) == none
}

fn test_svg_tspan_font_relative_offsets_remain_in_user_space_at_device_scales() {
	for scale in [f64(1), 2] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}</style><svg width="300" height="200"><text font-size="10" x="10" y="20">A<tspan id="span" x="2em" dx="1em" dy="3em">B</tspan></text></svg>')
		document.set_layout_coordinate_scale(scale)
		document.set_display_device_pixel_ratio(scale)
		result := run_document_layout(document, 400, 300) or { panic('layout') }
		span := document.get_element_by_id('span') or { panic('span') }
		node := find_svg_text_position_node(result.root, span.as_node().unique_id()) or { panic('node') }
		styled := node.as_node_with_style() or { panic('style') }
		used := result.used_values_for(styled) or { panic('values') }
		origin := used.svg_text_paint_origin() or { panic('origin') }
		assert origin.x == 30, 'scale=${scale} x=${origin.x}'
		assert origin.baseline_y == 50, 'scale=${scale} y=${origin.baseline_y}'
		document.finalize()
	}
}

fn find_svg_text_position_node(root &Node, id dom.UniqueNodeID) ?&Node {
	if node := root.dom_node() {
		if node.unique_id() == id { return root }
	}
	for child in root.children() {
		if found := find_svg_text_position_node(child, id) { return found }
	}
	return none
}
