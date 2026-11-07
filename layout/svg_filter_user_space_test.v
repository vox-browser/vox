module layout

import html
import math

// Brave 156: shields.io badges blur a text shadow with stdDeviation 16 inside
// scale(.1). SVG geometry is painted in page space, so the filter region and
// primitive lengths are mapped out of the text's user space the same way.
fn test_svg_filter_region_and_lengths_follow_the_user_space_transform() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}</style><svg width="300" height="60"><filter id="b"><feGaussianBlur stdDeviation="20"/></filter><g transform="scale(.1)"><text x="200" y="400" font-size="300" filter="url(#b)">sponsors</text></g></svg>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 400, 300)
	commands := display_list_commands(document.record_display_list() or { panic('paint') })
	layers := commands.filter(it.kind == 'begin_css_filter_layer')
	assert layers.len == 1
	filter := layers[0].visual_layer().filter or { panic('no filter') }
	bounds := filter.bounds or { panic('no filter region') }
	paths := commands.filter(it.kind == 'draw_svg_path')
	assert paths.len == 1
	// The region is the path's page-space visual bounds, not its user space.
	assert math.abs(bounds.x - paths[0].x) < 0.01 && math.abs(bounds.width - paths[0].width) < 0.01,
		'${bounds.x} ${bounds.width} ${paths[0].x} ${paths[0].width}'
	blurs := filter.nodes.filter(it.kind == 'blur')
	assert blurs.len == 1
	assert math.abs((blurs[0].parameters['radius_x'] or { 0.0 }) - 2) < 1e-5
	assert math.abs((blurs[0].parameters['radius_y'] or { 0.0 }) - 2) < 1e-5
}
