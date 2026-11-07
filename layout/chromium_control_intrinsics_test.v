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

fn test_chromium_textarea_intrinsic_width_rounds_after_device_projection() {
	$if !macos {
		return
	}
	mut document := html.parse_document('<style>input,textarea{font:10pt monospace}</style>
		<textarea id="comment" cols="80" rows="8"></textarea><input id="search" size="17">')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	for scale in [1.0, 2.0, 1.0] {
		document.set_layout_coordinate_scale(scale)
		run_document_layout(document, 1024, 768) or { panic('layout') }
		comment := document.get_element_by_id('comment') or { panic('comment') }
		// Native Brave 156, macOS monospace, including padding and border.
		expected := if scale == 2 { 664.5 } else { 665.0 }
		assert comment.get_bounding_client_rect().width == expected
		search := document.get_element_by_id('search') or { panic('search') }
		assert search.get_bounding_client_rect().width == 149
	}
}

// Brave 156 on macOS sizes text fields from SimpleFontData::WidthForGlyph('x'),
// Skia's strike advance without SF's AAT 'trak' tracking, and from the rounded
// ascent. Shaped SF text at 14px advances 7.19px per 'x'; the field uses 7.35px.
// GitHub's "Go to file" input (borderless, padding 1px 0) is 154px wide.
// At 18px HarfBuzz interpolates SF's optical size 0.002px wider than CoreText,
// so only one column is compared there.
fn test_chromium_system_font_text_fields_use_untracked_advance_and_rounded_ascent() {
	$if !macos {
		return
	}
	mut sizes := []string{}
	for size in [10, 12, 13, 14, 16, 18, 20, 24, 28] {
		sizes << '<input id="s${size}-1" size="1" style="font-size:${size}px"><input id="s${size}-201" size="201" style="font-size:${size}px">'
	}
	mut document := html.parse_document('<!doctype html><style>
		body{margin:0;font-family:system-ui}
		input{display:block;margin:0;padding:0;border:0;font-family:system-ui}
		#github{font:14px/20px "Mona Sans VF",-apple-system,BlinkMacSystemFont,"Segoe UI","Noto Sans",Helvetica,Arial,sans-serif;padding:1px 0;appearance:none}
	</style>' + sizes.join('') + '<input id="github">')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	run_document_layout(document, 2400, 768) or { panic('layout') }
	for id, width in {
		's10-1':   10.0
		's10-201': 1059.0
		's12-1':   12.0
		's12-201': 1271.0
		's13-1':   13.0
		's13-201': 1413.0
		's14-1':   14.0
		's14-201': 1483.0
		's16-1':   15.0
		's16-201': 1694.0
		's18-1':   17.0
		's20-1':   19.0
		's20-201': 2064.0
		's24-1':   23.0
		's24-201': 2320.0
		's28-1':   27.0
		's28-201': 2650.0
		'github':  154.0
	} {
		element := document.get_element_by_id(id) or { panic(id) }
		assert element.get_bounding_client_rect().width == width, '${id}: ${element.get_bounding_client_rect().width}'
	}
}

// Blink's ch is FontMetrics::ZeroWidth(), the zero glyph's untracked strike
// advance, multiplied as a float before LayoutUnit truncation. Brave 156 sizes
// 100ch in SF at 14px to 881.828125px; shaped SF text advances only 8.668px.
fn test_chromium_ch_lengths_use_the_untracked_float_zero_advance() {
	$if !macos {
		return
	}
	mut document := html.parse_document('<!doctype html><style>body{margin:0}div{height:4px;width:100ch}</style>
		<div id="c14" style="font:14px system-ui"></div><div id="c16" style="font:16px system-ui"></div>
		<div id="c12" style="font:12px system-ui"></div><div id="a14" style="font:14px Arial"></div>
		<div id="h14" style="font:14px Helvetica"></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	run_document_layout(document, 1600, 300) or { panic('layout') }
	for id, width in {
		'c14': 881.828125
		'c16': 1007.8125
		'c12': 755.859375
		'a14': 778.609375
		'h14': 778.609375
	} {
		element := document.get_element_by_id(id) or { panic(id) }
		assert element.get_bounding_client_rect().width == width, '${id}: ${element.get_bounding_client_rect().width}'
	}
}
