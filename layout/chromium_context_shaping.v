module layout

import platform

// Blink shapes across soft word boundaries. In particular, Arial kerns a
// space followed by A, so shaping "N. America" as three independent chunks
// changes both its width and the position of the second word.
fn (iterator &InlineLevelIterator) chromium_ascii_context_run(text_node &TextNode,
	chunks []TextNodeChunk) ?&platform.GlyphRun {
	if !iterator.is_unidirectional_left_to_right || chunks.len < 2 { return none }
	font := chunks[0].font
	if font.font_rendering_policy != .chromium { return none }
	text := text_node.text_for_rendering()
	if !text.is_ascii() { return none }
	for chunk in chunks {
		if voidptr(chunk.font) != voidptr(font) || chunk.has_breaking_newline
			|| chunk.has_breaking_tab || chunk.start < 0 || chunk.start + chunk.length > text.len
			|| chunk.view != text[chunk.start..chunk.start + chunk.length] {
			return none
		}
	}
	letter_spacing :=
		resolved_text_spacing_for_node(unsafe { &Node(text_node) }, .letter_spacing).to_double()
	word_spacing :=
		resolved_text_spacing_for_node(unsafe { &Node(text_node) }, .word_spacing).to_double()
	return iterator.shape_text_for_layout(text_node, 0, f32(letter_spacing), f32(word_spacing),
		text, font, .ltr).glyph_run
}

fn chromium_context_slice(run &platform.GlyphRun, chunk TextNodeChunk) ?platform.ShapedText {
	mut offset := 0
	mut first := -1
	mut end := -1
	for index, glyph in run.glyphs_ {
		if offset == chunk.start { first = index }
		if offset == chunk.start + chunk.length {
			end = index
			break
		}
		offset += glyph.length_in_code_units
	}
	if offset == chunk.start + chunk.length && end < 0 { end = run.glyphs_.len }
	// Never cut a ligature or a cluster at a line-break chunk boundary.
	if first < 0 || end <= first { return none }
	origin := run.glyphs_[first].position.x
	limit := if end < run.glyphs_.len { run.glyphs_[end].position.x } else { run.width() }
	mut glyphs := run.glyphs_[first..end].clone()
	for mut glyph in glyphs {
		glyph.position.translate_by(-origin, 0)
	}
	mut sliced := platform.GlyphRun.new_with_face(run.font(), .ltr, glyphs, run.face())
	sliced.width_ = limit - origin
	sliced.space_width = run.space_width
	mut trailing_length := 0
	mut trailing_advance := f32(0)
	for index := glyphs.len - 1; index >= 0; index-- {
		glyph := glyphs[index]
		if glyph.code_point != u32(` `) { break
		 }
		trailing_length += glyph.length_in_code_units
		trailing_advance += glyph.advance
	}
	return platform.ShapedText{
		glyph_run:           sliced
		trailing_whitespace: platform.TrailingWhitespace{
			length_in_code_units: trailing_length
			advance:              trailing_advance
		}
	}
}
