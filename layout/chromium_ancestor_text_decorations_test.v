module layout

import html

fn test_chromium_nested_link_keeps_outer_underline_color() {
	mut document := html.parse_document('<!doctype html><style>
		body{color:rgb(130 130 130)}a{color:black;text-decoration:underline}
	</style><u><a>reply</a></u>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	root := layout_document_typed_in_viewport(document, 400, 100)
	commands := root.paint_commands()
	underlines := commands.filter(it.kind == 'fill_rect' && it.antialiased_rect)
	assert underlines.len == 2
	assert underlines[0].color == 'rgb(130 130 130)'
	assert underlines[1].color == 'rgb(0 0 0)'
	assert underlines[0].clip_outs == underlines[1].clip_outs
	assert underlines[0].underlays_next
	assert !underlines[1].underlays_next
}
