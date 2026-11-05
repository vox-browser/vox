module layout

import html
import math
import platform

fn test_closing_quotes_preserve_automatic_hyphens_and_source_offsets() {
	$if !macos { return }
	for suffix in [",'", '...”', '?!'] {
		content := 'Some generated${suffix} columns'
		mut document := html.parse_document('<!doctype html><html lang="en-US"><style>
			body{margin:0;font:16px/24px Arial}p{width:100px;hyphens:auto}
		</style><p>${content}</p>')
		document.set_font_rendering_policy(.chromium)
		root := layout_document_typed_in_viewport(document, 320, 240)
		commands := root.paint_commands().filter(it.kind == 'draw_text')
		assert commands[0].text == 'Some gener‐'
		assert commands[1].text.starts_with('ated${suffix}')
		mut hyphens := 0
		for command in commands {
			run := command.glyph_run or { panic('missing run') }
			for glyph in run.glyphs_ {
				if glyph.is_automatic_hyphen {
					hyphens++
					assert glyph.length_in_code_units == 0
				}
			}
		}
		assert hyphens > 0
		body := document.body() or { panic('missing body') }
		assert (body.as_node().text_content() or { '' }) == content
		document.finalize()
	}
}

fn test_paragraph_final_word_wraps_whole_but_an_overlong_first_word_can_hyphenate() {
	$if !macos { return }
	for suffix in ['continue', '<span>continue</span>', 'continue   '] {
		mut document := html.parse_document('<!doctype html><html lang="en-US"><style>
			body{margin:0;font:16px/22.4px Arial}p{width:233.625px;hyphens:auto}
		</style><p>Revised IPO filing warns 12x revenue growth is unlikely to ${suffix}</p>')
		document.set_font_rendering_policy(.chromium)
		root := layout_document_typed_in_viewport(document, 1024, 768)
		commands := root.paint_commands().filter(it.kind == 'draw_text' && it.text.trim_space() != '')
		assert commands.last().text.trim_space() == 'continue'
		assert !commands.any(it.text == 'contin‐')
		document.finalize()
	}
	mut document := html.parse_document('<!doctype html><html lang="en-US"><style>
		body{margin:0;font:16px/24px Arial}p{width:40px;hyphens:auto}
	</style><p>generated</p>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	root := layout_document_typed_in_viewport(document, 320, 240)
	commands := root.paint_commands().filter(it.kind == 'draw_text')
	assert commands.len > 1
	assert commands.any(it.text.contains('‐'))
}

fn test_first_word_in_a_new_text_range_can_hyphenate_on_an_existing_line() {
	$if !macos { return }
	for word in ['generated', '<span>generated</span>'] {
		mut document := html.parse_document('<!doctype html><html lang="en-US"><style>
			body{margin:0;font:16px/24px Arial}p{width:100px;hyphens:auto}
		</style><p>Some ${word}</p>')
		document.set_font_rendering_policy(.chromium)
		root := layout_document_typed_in_viewport(document, 320, 240)
		commands := root.paint_commands().filter(it.kind == 'draw_text')
		assert commands.any(it.text.contains('gener‐')) == word.starts_with('<span>')
		document.finalize()
	}
}

fn test_inserted_hyphen_does_not_kern_with_the_source_word() {
	$if !macos { return }
	font := &platform.Font{family: 'system-ui', point_size: 17, font_rendering_policy: .chromium}
	whole := platform.shape_text(0, 0, 'generated', font, .ltr)
	// This face has a real r-hyphen kern. Explicit text keeps it, while an
	// automatically inserted hyphen must preserve the unkerned source end.
	joined := platform.shape_text(0, 0, 'gener‐', font, .ltr)
	for spacing in [f32(0), f32(0.25)] {
		prefix := platform.shape_text_with_spacing(0, spacing, 0, 'gener', font, .ltr).glyph_run
		hyphen := platform.shape_text_with_spacing(0, spacing, 0, '‐', font, .ltr).glyph_run
		run := shape_automatically_hyphenated_prefix('gener', '‐', whole, spacing, 0)
		assert run.glyphs_.len == prefix.glyphs_.len + 1
		for index, glyph in prefix.glyphs_ { assert run.glyphs_[index] == glyph }
		last := run.glyphs_.last()
		assert last.glyph_index == hyphen.glyphs_[0].glyph_index
		assert last.position.x == prefix.width() + hyphen.glyphs_[0].position.x
		assert math.abs(run.width() - (prefix.width() + hyphen.width())) < 0.00001
		if spacing == 0 {
			assert run.glyphs_.last().position.x - joined.glyphs_.last().position.x > 0.5
		}
	}
}

fn test_automatic_hyphen_fit_includes_the_independent_hyphen_width() {
	$if !macos { return }
	mut document := html.parse_document('<!doctype html><html lang="en"><style>
		body{margin:0;font:17px/22.1px system-ui}div{width:51.25px;hyphens:auto}
	</style><div>generated</div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	root := layout_document_typed_in_viewport(document, 320, 240)
	commands := root.paint_commands().filter(it.kind == 'draw_text')
	assert commands.len == 2
	assert commands[0].text == 'gen‐'
	assert commands[1].text == 'erated'
	assert commands[0].width <= 51.25
	first := commands[0].glyph_run or { panic('missing prefix run') }
	last := first.glyphs_.last()
	assert last.is_automatic_hyphen && last.length_in_code_units == 0
	mut source_length := 0
	for glyph in first.glyphs_ { source_length += glyph.length_in_code_units }
	assert source_length == 3
	body := document.body() or { panic('missing body') }
	assert (body.as_node().text_content() or { '' }) == 'generated'
}

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
