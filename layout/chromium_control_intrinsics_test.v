module layout

import html

// Dimensions measured in Brave 156 on macOS. Keep the fractional monospace
// advance: rounding each column before multiplying makes this textarea 2px
// too narrow. The text field also includes Blink's maximum-character inset.
fn test_chromium_hacker_news_controls_match_brave_intrinsic_sizes() {
	$if !macos {
		return
	}
	mut document := html.parse_document('<!doctype html><style>
		body{margin:0}input,textarea{font:10pt monospace}
		input[type=submit]{font-family:Verdana,Geneva,sans-serif}
	</style><textarea id="comment" cols="80" rows="8"></textarea>
	<input id="submit" type="submit" value="add comment">
	<input id="search" size="17">')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	run_document_layout(document, 1024, 768) or { panic('layout') }
	for id, dimensions in {
		'comment': [665.0, 126.0]
		'submit':  [107.90625, 22.0]
		'search':  [149.0, 21.0]
	} {
		element := document.get_element_by_id(id) or { panic(id) }
		rect := element.get_bounding_client_rect()
		assert rect.width == dimensions[0], '${id}: width ${rect.width}'
		assert rect.height == dimensions[1], '${id}: height ${rect.height}'
	}
}

fn test_chromium_control_theme_preserves_author_borders_and_backgrounds() {
	mut document := html.parse_document('<!doctype html><style>
		#border{border:3px solid red}#background{background:blue}
	</style><input id="border"><textarea id="background"></textarea>
	<input type="submit" style="appearance:none;border:2px solid lime;background:yellow" value="send">')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	root := layout_document_typed_in_viewport(document, 800, 300)
	commands := root.paint_commands()
	assert commands.any(it.color == 'rgb(255 0 0)')
	assert commands.any(it.kind == 'fill_rect' && it.color == 'rgb(0 0 255)')
	assert commands.any(it.kind == 'fill_rect' && it.color == 'rgb(255 255 0)')
	assert commands.any(it.color == 'rgb(0 255 0)')
}
