module layout

import html
import math

fn test_non_stacking_svg_group_opacity_reaches_paint_and_group_alpha_once() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}</style><svg width="60" height="40" style="opacity:.5"><g opacity=".7"><path opacity=".8" fill="red" d="M0 0H20V20H0Z"/></g><path fill="blue" d="M20 0H40V20H20Z"/></svg>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 300, 150)
	commands := display_list_commands(document.record_display_list() or { panic('paint') })
	paths := commands.filter(it.kind == 'draw_svg_path')
	assert paths.len == 2
	assert paths[0].color == 'rgb(255 0 0)'
	assert paths[1].color == 'rgb(0 0 255)'
	assert math.abs(paths[0].opacity - 0.28) < 1e-6
	assert math.abs(paths[0].group_opacity - 0.28) < 1e-6
	assert paths[1].opacity == 0.5 && paths[1].group_opacity == 0.5
	groups := commands.filter(it.kind == 'begin_css_effect_layer')
	assert groups.len == 3
	assert !groups[0].visual_layer().svg_graphics_opacity
	assert groups[1].visual_layer().svg_graphics_opacity
	assert groups[2].visual_layer().svg_graphics_opacity
}
