module layout

import html

fn test_legacy_line_clamp_keeps_fitting_glyphs_past_the_last_word_boundary() {
	$if !macos {
		return
	}
	mut document := html.parse_document('<!doctype html><html lang="en"><style>
		body{margin:0;font:13px/17px Arial}
		div{width:355px;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;
			overflow:hidden;word-break:break-word;overflow-wrap:break-word;hyphens:auto}
	</style><div>I want to use the same audit trigger across different tables without copying their generated column formulas into the trigger. The problem is that RETURNING gives me the calculated values but the ...</div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	root := layout_document_typed_in_viewport(document, 800, 600)
	commands := root.paint_commands().filter(it.kind == 'draw_text')
	assert commands.len == 2
	assert commands[0].text == 'I want to use the same audit trigger across different tables'
	assert commands[1].text == 'without copying their generated column formulas into the tri…'
	run := commands[1].glyph_run or { panic('missing clamped glyph run') }
	assert run.glyphs_.last().code_point == 0x2026
	assert !run.glyphs_.any(it.is_automatic_hyphen)
}
