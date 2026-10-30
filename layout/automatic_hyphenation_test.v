module layout

import html

fn test_automatic_hyphenation_fills_the_line_before_a_word_wrap() {
	$if !macos {
		return
	}
	mut document := html.parse_document('<!doctype html><html lang="en"><style>
		body{margin:0;font:16px/24px Arial}div{width:100px;hyphens:auto}
	</style><div>Some generated columns</div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	root := layout_document_typed_in_viewport(document, 320, 240)
	commands := root.paint_commands().filter(it.kind == 'draw_text')
	assert commands.len >= 2
	assert commands[0].text == 'Some gener‐'
	assert commands[1].text.starts_with('ated')
	mut hyphens := 0
	mut source_length := 0
	for command in commands {
		run := command.glyph_run or { panic('missing retained glyph run') }
		for glyph in run.glyphs_ {
			source_length += glyph.length_in_code_units
			if glyph.is_automatic_hyphen {
				hyphens++
				assert glyph.length_in_code_units == 0
				assert glyph.code_point == 0x2010
				assert glyph.should_paint
			}
		}
	}
	assert hyphens > 0
	// Collapsed line-end spaces can be absent from paint, but an inserted
	// hyphen never acquires a source code unit or changes textContent.
	assert source_length <= 'Some generated columns'.len
	body := document.body() or { panic('missing body') }
	assert (body.as_node().text_content() or { '' }) == 'Some generated columns'
}

fn test_automatic_hyphenation_respects_language_nowrap_and_manual_controls() {
	for attributes in ['lang="zz-ZZ"', 'lang="en" style="hyphens:none"',
		'lang="en" style="hyphens:manual"', 'lang="en" style="white-space:nowrap"'] {
		mut document := html.parse_document('<!doctype html><style>
			body{margin:0;font:16px/24px Arial}div{width:60px;hyphens:auto}
		</style><div ${attributes}>generated</div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		root := layout_document_typed_in_viewport(document, 320, 240)
		commands := root.paint_commands().filter(it.kind == 'draw_text')
		assert commands.len == 1
		assert commands[0].text == 'generated'
	}
}

fn test_auto_hyphen_min_content_uses_dictionary_segments_but_max_content_stays_whole() {
	$if !macos {
		return
	}
	mut document := html.parse_document('<!doctype html><html lang="en"><style>
		body{margin:0;font:16px/24px Arial}.auto{hyphens:auto;width:min-content}
		.manual{hyphens:manual;width:min-content}.max{hyphens:auto;width:max-content}
	</style><div id="auto" class="auto">generated</div>
	<div id="manual" class="manual">generated</div><div id="max" class="max">generated</div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 320, 240)
	auto_width := document.get_element_by_id('auto')?.get_bounding_client_rect().width
	manual_width := document.get_element_by_id('manual')?.get_bounding_client_rect().width
	max_width := document.get_element_by_id('max')?.get_bounding_client_rect().width
	assert auto_width < manual_width
	assert manual_width == max_width
	assert auto_width > 0
}

fn test_none_suppresses_soft_hyphen_breaks_without_removing_dom_text() {
	mut document := html.parse_document('<!doctype html><style>
		body{margin:0;font:16px/24px Arial}div{width:50px;hyphens:none}
	</style><div>hy&shy;phenated</div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	root := layout_document_typed_in_viewport(document, 320, 240)
	commands := root.paint_commands().filter(it.kind == 'draw_text')
	assert commands.len == 1
	body := document.body() or { panic('missing body') }
	assert (body.as_node().text_content() or { '' }) == 'hy\u00adphenated'
}
