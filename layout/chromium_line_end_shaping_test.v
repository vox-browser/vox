module layout

import html
import platform

fn test_chromium_wrapped_line_reshapes_letter_space_kerning_before_centering() {
	$if !macos {
		return
	}
	mut document := html.parse_document('<!doctype html><style>body{margin:0}div{position:absolute;left:40px;width:150px;font:10pt Arial;text-align:center}</style><div>THERE IS CURRENTLY MORE</div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	document.set_layout_coordinate_scale(2)
	root := layout_document_typed_in_viewport(document, 800, 600)
	mut found := false
	for command in root.paint_commands() {
		if command.kind != 'draw_text' || command.text != 'THERE IS CURRENTLY' { continue }
		// Native-scale Range geometry from Brave 156.0.8078.48. Retaining the
		// Y-space kern instead centers this line at x=84.578125.
		assert command.x == 84.328125
		// The paint bound rounds to nearest; the inline item used for alignment
		// rounds upward to 291.34375 native pixels.
		assert command.width == 291.328125
		found = true
	}
	assert found
}

fn test_chromium_line_fitting_retries_before_unsafe_shaping_boundary() {
	$if !macos {
		return
	}
	// Brave's break changes exactly at the reshaped 145.671875px advance.
	for index, width in [145.0, 145.25, 145.5, 145.65625, 145.671875, 146.0, 150.0] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}div{position:absolute;left:40px;width:${width}px;font:10pt Arial;text-align:center}</style><div>THERE IS CURRENTLY MORE</div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		document.set_layout_coordinate_scale(2)
		root := layout_document_typed_in_viewport(document, 800, 600)
		mut lines := []string{}
		for command in root.paint_commands() {
			if command.kind != 'draw_text' { continue }
			lines << command.text
			assert command.width <= width * 2
		}
		assert lines == if index < 4 {
			['THERE IS', 'CURRENTLY MORE']
		} else {
			['THERE IS CURRENTLY', 'MORE']
		}, 'width=${width}'
	}
}

fn test_chromium_line_end_shape_retains_spacing_utf16_and_cached_glyphs() {
	for text in ['AV Y', 'Wé T', 'Тест Т'] {
		for spacing in ['', 'letter-spacing:0.25px;word-spacing:1px'] {
			mut document := html.parse_document('<!doctype html><style>body{margin:0}div{width:300px;font:20px Arial;${spacing}}</style><div>${text} </div><div>${text}</div>')
			defer { document.finalize() }
			document.set_font_rendering_policy(.chromium)
			root := layout_document_typed_in_viewport(document, 400, 300)
			mut runs := []&platform.GlyphRun{}
			mut widths := []f64{}
			for command in root.paint_commands() {
				if command.kind != 'draw_text' { continue }
				runs << command.glyph_run or { panic('missing text run') }
				widths << command.width
			}
			assert runs.len == 2
			assert widths[0] == widths[1], '${text}: ${spacing}'
			assert runs[0].glyphs_.len == runs[1].glyphs_.len
			for index, glyph in runs[0].glyphs_ {
				assert glyph.glyph_index == runs[1].glyphs_[index].glyph_index
				assert glyph.advance == runs[1].glyphs_[index].advance
				assert glyph.position == runs[1].glyphs_[index].position
			}
		}
	}
}

fn test_chromium_preserved_trailing_space_keeps_its_context_shape() {
	mut document := html.parse_document('<!doctype html><div style="font:20px Arial;white-space:pre">Y </div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	root := layout_document_typed_in_viewport(document, 400, 300)
	mut found := false
	for command in root.paint_commands() {
		if command.kind != 'draw_text' { continue }
		assert command.text == 'Y '
		run := command.glyph_run or { panic('missing text run') }
		expected := platform.shape_text(0, 0, 'Y ', run.font(), .ltr)
		assert run.glyphs_.len == expected.glyphs_.len
		assert run.glyphs_[0].advance == expected.glyphs_[0].advance
		found = true
	}
	assert found
}
