module main

import html
import layout
import math

fn test_svg_filter_recording_requires_a_complete_supported_svg_scope() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}svg{width:160px;height:80px;transform:rotate(-90deg);filter:drop-shadow(0 20px 4px red)}</style><svg viewBox="0 0 40 20"><path d="M0 0H40V20H0Z"/></svg>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout.layout_document_typed_in_viewport(document, 400, 300)
	commands := layout.display_list_commands(document.record_display_list() or { panic('paint') })
	mut start := -1
	mut leaf := -1
	mut end := -1
	for index, command in commands {
		if command.kind == 'begin_css_filter_layer' { start = index }
		if command.kind == 'draw_svg_path' { leaf = index }
		if command.kind == 'end_css_filter_layer' { end = index }
	}
	assert start >= 0 && leaf > start && end > leaf
	assert layout.css_filter_scope_is_svg_viewport(document, commands[start].visual_layer().scope_id)
	geometry := layout.css_svg_filter_geometry(document, commands[start].visual_layer().scope_id) or { panic('geometry') }
	assert geometry.bounds == layout.LayoutRect{0, 0, 160, 80}
	assert chromium_svg_filter_recording_supported(commands, start)
	assert !chromium_svg_filter_recording_supported(commands[..end], start)
	for kind in ['draw_canvas', 'begin_css_filter_layer', 'begin_svg_mask_layer'] {
		mut changed := commands.clone()
		changed[leaf] = layout.PaintCommand{ ...commands[leaf], kind: kind }
		assert !chromium_svg_filter_recording_supported(changed, start)
	}
	mut changed := commands.clone()
	changed[leaf] = layout.PaintCommand{ ...commands[leaf], opacity: 0.5 }
	assert !chromium_svg_filter_recording_supported(changed, start)
	changed[start] = layout.PaintCommand{ ...commands[start], transform: [f64(2), 0, 0, 1, 0, 0]! }
	assert !chromium_svg_filter_recording_supported(changed, start)
}

fn test_svg_filter_geometry_retains_the_viewport_origin_and_viewbox_extent() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}svg{position:absolute;left:261px;top:612px;width:520px;height:auto;transform:rotate(-90deg);filter:drop-shadow(0 35px 35px white)}</style><svg viewBox="0 0 309 70"><path d="M10 10H20V20H10Z"/></svg>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout.layout_document_typed_in_viewport(document, 1024, 768)
	commands := layout.display_list_commands(document.record_display_list() or { panic('paint') })
	filter := commands.filter(it.kind == 'begin_css_filter_layer')[0]
	geometry := layout.css_svg_filter_geometry(document, filter.visual_layer().scope_id) or { panic('geometry') }
	assert geometry.origin_x == 261 && geometry.origin_y == 612
	assert math.abs(geometry.bounds.x - 0.00546875) < 1e-6
	// Blink's recorded saveLayer rectangle retains SkScalar edges.
	assert f32(geometry.bounds.x + geometry.bounds.width) == f32(519.994506835938)
	assert math.abs(geometry.bounds.y) < 1e-5
	assert f32(geometry.bounds.y + geometry.bounds.height) == f32(117.796875)
}

fn test_html_filter_ancestor_does_not_borrow_its_svg_childs_space() {
	mut document := html.parse_document('<!doctype html><style>section{filter:drop-shadow(0 20px 4px red)}</style><section><svg viewBox="0 0 40 20" width="160" height="80" style="transform:rotate(90deg)"><path d="M0 0H40V20H0Z"/></svg></section>')
	defer { document.finalize() }
	_ = layout.layout_document_typed_in_viewport(document, 400, 300)
	commands := layout.display_list_commands(document.record_display_list() or { panic('paint') })
	filters := commands.filter(it.kind == 'begin_css_filter_layer')
	assert filters.len == 1
	assert !layout.css_filter_scope_is_svg_viewport(document, filters[0].visual_layer().scope_id)
	assert !layout.css_filter_scope_is_svg_viewport(document, 0)
}
