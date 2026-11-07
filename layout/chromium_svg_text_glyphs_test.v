module layout

import html
import math

fn svg_text_glyph_commands(markup string) []PaintCommand {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}</style>' + markup)
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 400, 300)
	commands := display_list_commands(document.record_display_list() or { panic('paint') })
	return commands
}

// Brave 156 places Arial 20px "OOOO" with textLength=200 at 20, 81.479,
// 142.958 and 204.438. Blink shapes SVG text with the screen-scaled font and
// draws glyphs, so the same text inside scale(.5) at 40px lands identically.
fn test_chromium_svg_text_paints_screen_scaled_glyphs() {
	commands := svg_text_glyph_commands('<svg width="400" height="100"><g transform="scale(.5)">' +
		'<text x="40" y="100" font-size="40" font-family="Arial" fill="#123456" fill-opacity=".5" textLength="400">OOOO</text></g></svg>')
	assert commands.filter(it.kind == 'draw_svg_path').len == 0
	texts := commands.filter(it.kind == 'draw_text')
	assert texts.len == 1, commands.map(it.kind).str()
	text := texts[0]
	assert text.font_size == 20
	assert text.glyph_translation_x == 20 && text.glyph_translation_y == 50
	assert text.opacity == 1
	color := text.srgb_color_data
	assert color != unsafe { nil } && color.components[3] == 0.5 && text.color == color.serialized
	run := text.glyph_run or { panic('no glyphs') }
	expected := [0.0, 61.479, 122.958, 184.438]
	for index, glyph in run.glyphs() {
		assert math.abs(f64(glyph.position.x) - expected[index]) < 0.01, '${index}: ${glyph.position.x}'
	}
}

// Rotated text and stroked text keep their outline paths.
fn test_chromium_svg_text_keeps_outlines_when_glyphs_cannot_match() {
	rotated := svg_text_glyph_commands('<svg width="400" height="100"><text x="40" y="50" transform="rotate(10)">OO</text></svg>')
	assert rotated.filter(it.kind == 'draw_text').len == 0
	assert rotated.filter(it.kind == 'draw_svg_path').len == 1
	stroked := svg_text_glyph_commands('<svg width="400" height="100"><text x="40" y="50" stroke="red">OO</text></svg>')
	assert stroked.filter(it.kind == 'draw_text').len == 0
}
