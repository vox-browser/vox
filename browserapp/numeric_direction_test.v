module main

import dom
import html
import layout
import platform

fn numeric_rendered_direction(policy dom.FontRenderingPolicy, declarations string, source string) platform.GlyphRunTextType {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}div{font:13px Arial;direction:rtl}</style><div style="${declarations}">${source}</div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(policy)
	_ = layout.layout_document_typed_in_viewport(document, 240, 100)
	commands := layout.display_list_commands(document.record_display_list() or { panic('display list') })
	for command in commands {
		if command.kind != 'draw_text' || command.text.trim_space() == '' { continue }
		if run := command.glyph_run { return run.text_type() }
	}
	panic('numeric paint run missing')
}

fn test_chromium_arabic_numbers_shape_left_to_right_in_an_rtl_paragraph() {
	for source in ['۱٬۱۰۲٬۰۰۰+ ', '١٢٣٬٤٥٦', '۱۲3٬۴۵۶'] {
		assert numeric_rendered_direction(.chromium, '', source) == .ltr
	}
}

fn test_numeric_direction_preserves_the_translation_policy_and_explicit_override() {
	assert numeric_rendered_direction(.libweb, '', '۱٬۱۰۲٬۰۰۰+ ') == .context_dependent
	assert numeric_rendered_direction(.chromium, 'unicode-bidi:bidi-override', '۱٬۱۰۲٬۰۰۰+ ') == .context_dependent
}

fn test_chromium_rtl_orders_separate_inline_text_fragments() {
	mut document := html.parse_document('<!doctype html><div style="font:16px Arial;direction:rtl"><span>فارسی</span><span>مقاله</span></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout.layout_document_typed_in_viewport(document, 240, 100)
	commands := layout.display_list_commands(document.record_display_list() or { panic('display list') })
	mut positions := []f64{}
	for command in commands {
		if command.kind == 'draw_text' && command.text.trim_space() != '' { positions << command.x }
	}
	assert positions.len == 2
	assert positions[0] > positions[1]
}

fn test_chromium_rtl_keeps_adjacent_ltr_spans_in_logical_order() {
	mut document := html.parse_document('<!doctype html><div style="font:16px Arial;direction:rtl"><span>abc</span><span>def</span></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout.layout_document_typed_in_viewport(document, 240, 100)
	commands := layout.display_list_commands(document.record_display_list() or { panic('display list') })
	mut positions := []f64{}
	for command in commands {
		if command.kind == 'draw_text' && command.text.trim_space() != '' { positions << command.x }
	}
	assert positions.len == 2
	assert positions[0] < positions[1]
}
