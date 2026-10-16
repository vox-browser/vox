module layout

import html
import math

fn chromium_text_paint_commands(policy_chromium bool) []PaintCommand {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}
		div{position:absolute;left:0;font:13px/16px system-ui}</style>
		<div style="top:4.484375px">A</div><div style="top:24.5px">B</div>')
	if policy_chromium {
		document.set_font_rendering_policy(.chromium)
	}
	mut root := layout_document_typed_in_viewport(document, 200, 100)
	return root.paint_commands().filter(it.kind == 'draw_text' && it.glyph_run != none)
}

// Brave 1.97 (Chromium 155) draws a line whose top lies k/64 px below a whole
// pixel from that pixel for k < 32 and from the next pixel otherwise; the
// fragment itself keeps its unrounded geometry.
fn test_chromium_text_paints_glyphs_from_a_rounded_box_top() {
	commands := chromium_text_paint_commands(true)
	assert commands.len == 2
	a := commands.filter(it.text == 'A')[0]
	b := commands.filter(it.text == 'B')[0]
	// Both fragments sit at the same whole-pixel half-leading below their boxes.
	assert a.y - 4.484375 == b.y - 24.5
	assert a.y != math.round(a.y)
	assert a.glyph_translation_y == math.round(a.glyph_translation_y)
	assert b.glyph_translation_y == a.glyph_translation_y + 21
	// LibWeb places each baseline at the same offset from its unrounded top.
	libweb := chromium_text_paint_commands(false)
	la := libweb.filter(it.text == 'A')[0]
	lb := libweb.filter(it.text == 'B')[0]
	assert la.glyph_translation_y - la.y == lb.glyph_translation_y - lb.y
}

// Fallback CJK fragments paint their own glyph runs instead of the raw string,
// so every glyph shares the line's baseline.
fn test_chromium_mixed_font_text_paints_glyph_runs() {
	$if macos {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}
			div{position:absolute;left:8px;top:10px;font:13px/16px system-ui;white-space:nowrap}</style>
			<div lang="zh">H条目 / 條目H</div>')
		document.set_font_rendering_policy(.chromium)
		mut root := layout_document_typed_in_viewport(document, 300, 100)
		commands := root.paint_commands().filter(it.kind == 'draw_text')
		assert commands.len > 1
		assert commands.all(it.glyph_run != none)
		assert commands.all(it.glyph_translation_y == commands[0].glyph_translation_y)
	}
}
