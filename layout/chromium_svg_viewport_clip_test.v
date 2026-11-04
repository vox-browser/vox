module layout

import html
import dom

fn test_outer_svg_clip_snaps_layout_edges_before_the_svg_origin_is_snapped() {
	for policy in [dom.FontRenderingPolicy.chromium, .libweb] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}</style><svg id="icon" width="15.390625" height="15.390625" style="position:absolute;left:24.625px;top:12.296875px"><path d="M0 0H16V16H0Z"/></svg>')
		defer { document.finalize() }
		document.set_font_rendering_policy(policy)
		_ = layout_document_typed_in_viewport(document, 300, 150)
		commands := display_list_commands(document.record_display_list() or { panic('paint') }).filter(it.kind == 'draw_svg_path')
		assert commands.len == 1
		assert commands[0].has_clip
		assert [commands[0].clip_x, commands[0].clip_y, commands[0].clip_width,
			commands[0].clip_height] == [25.0, 12, 15, 16]
	}
}

fn test_nested_svg_viewports_keep_their_fractional_user_space_clip() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}</style><svg width="50" height="50" style="position:absolute;left:24.625px;top:12.296875px"><svg x="0.25" y="0.75" width="15.390625" height="15.390625"><path d="M0 0H16V16H0Z"/></svg></svg>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 300, 150)
	commands := display_list_commands(document.record_display_list() or { panic('paint') }).filter(it.kind == 'draw_svg_path')
	assert commands.len == 1
	assert commands[0].has_clip
	assert [commands[0].clip_x, commands[0].clip_y, commands[0].clip_width, commands[0].clip_height] == [
		25.25,
		12.75,
		15.390625,
		15.390625,
	]
}
