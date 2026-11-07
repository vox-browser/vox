module layout

import html
import math
import platform

fn test_chromium_fractional_spacing_reaches_retained_glyphs_without_box_rounding() {
	for declarations in ['letter-spacing:-.04em', 'letter-spacing:-1.2px', 'letter-spacing:.0001px;word-spacing:.075px'] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}div{font:30px/40px Arial;'+declarations+'}</style><div>Ultra fast compilation speed</div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		root := layout_document_typed_in_viewport(document, 260, 240)
		mut checked := 0
		for command in root.paint_commands() {
			if command.kind != 'draw_text' || command.text.len == 0 { continue }
			run := command.glyph_run or { panic('missing retained glyphs') }
			letter := if declarations.starts_with('letter-spacing:.') { f32(.0001) } else { f32(-1.2) }
			word := if declarations.contains('word-spacing') { f32(.075) } else { f32(0) }
			expected := platform.shape_text_with_spacing(0, letter, word, command.text, run.font(), run.text_type()).glyph_run
			actual_glyphs := run.glyphs()
			expected_glyphs := expected.glyphs()
			assert actual_glyphs.len == expected_glyphs.len
			origin := actual_glyphs[0].position.x - expected_glyphs[0].position.x
			for index, glyph in actual_glyphs {
				assert math.abs(f64(glyph.position.x - origin - expected_glyphs[index].position.x)) < .001
			}
			checked++
		}
		assert checked >= 2
	}
}

fn text_spacing_test_width(declarations string, chromium bool) f64 {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}span{font:30px/40px Arial;' +
		declarations + '}</style><span>Ultra fast</span>')
	defer { document.finalize() }
	if chromium {
		document.set_font_rendering_policy(.chromium)
	}
	root := layout_document_typed_in_viewport(document, 400, 240)
	mut right := 0.0
	for command in root.paint_commands() {
		if command.kind != 'draw_text' || command.text.len == 0 { continue }
		run := command.glyph_run or { continue }
		glyphs := run.glyphs()
		right = math.max(right, f64(glyphs[glyphs.len - 1].position.x))
	}
	return right
}

// Percentages, which transitions between lengths and percentages produce, are
// relative to the font size.
fn test_text_spacing_percentages_resolve_against_the_font_size() {
	for chromium in [false, true] {
		percentage := text_spacing_test_width('letter-spacing:10%;word-spacing:20%', chromium)
		length := text_spacing_test_width('letter-spacing:3px;word-spacing:6px', chromium)
		assert math.abs(percentage - length) < .01, '${chromium} ${percentage} ${length}'
		assert percentage > text_spacing_test_width('', chromium)
	}
}
