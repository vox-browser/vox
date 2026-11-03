module layout

import html
import platform

fn test_device_leading_retains_half_css_pixels_and_puts_the_remainder_below() {
	metrics := platform.FontPixelMetrics{
		ascent:               13.5
		descent:              3
		floor_inline_leading: true
		inline_leading_scale: 2
	}
	assert font_baseline_for_line_height(metrics, CSSPixels.nearest_value_for(20.578125)).to_double() == 15.5
	assert font_baseline_for_line_height(metrics, CSSPixels.nearest_value_for(20.296875)).to_double() == 15
	assert inline_half_leading(CSSPixels.nearest_value_for(-1.5), metrics).to_double() == -1
	assert normal_line_height_for_font_metrics(metrics).to_double() == 16.5
	css_metrics := platform.FontPixelMetrics{ ...metrics, ascent: 14, inline_leading_scale: 1 }
	assert font_baseline_for_line_height(css_metrics, CSSPixels.nearest_value_for(20.578125)).to_double() == 15
}

fn test_layout_font_density_tracks_display_changes_without_double_scaling() {
	font_path := platform.document_font_path(400) or { panic('missing fixture font') }
	mut document := html.parse_document('<!doctype html><style>
		@font-face{font-family:Fixture;src:url("file://${font_path}")}
		body{margin:0}#line{font:17px Fixture}
	</style><div id="line">A line</div><svg width="1" height="1"></svg>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	for density in [f64(1), 2, 1] {
		document.set_display_device_pixel_ratio(density)
		for coordinates in [f64(1), 2] {
			document.set_layout_coordinate_scale(coordinates)
			_ = run_document_layout(document, 800, 600) or { panic('layout') }
			element := document.get_element_by_id('line') or { panic('line') }
			bridge := element.as_node().layout_node() or { panic('bridge') }
			node := unsafe { &Node(bridge.layout_handle) }
			metrics := layout_font_metrics_for_node(node)
			assert metrics.inline_leading_scale == density / coordinates
			assert node.computed_values().line_height() == normal_line_height_for_font_metrics(metrics)
		}
	}
	document.set_font_rendering_policy(.libweb)
	_ = run_document_layout(document, 800, 600) or { panic('layout') }
	element := document.get_element_by_id('line') or { panic('line') }
	bridge := element.as_node().layout_node() or { panic('bridge') }
	node := unsafe { &Node(bridge.layout_handle) }
	assert !layout_font_metrics_for_node(node).floor_inline_leading
	assert layout_font_metrics_for_node(node).inline_leading_scale == 1
}
