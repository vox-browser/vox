module layout

import platform

// Blink shapes across soft word boundaries, including hyphens. Shaping
// "N. America" or "Что-то" as independent chunks loses their boundary kerning.
fn (iterator &InlineLevelIterator) chromium_single_script_context_run(text_node &TextNode,
	chunks []TextNodeChunk) ?&platform.GlyphRun {
	if chunks.len < 2 { return none }
	if !iterator.is_unidirectional_left_to_right {
		style := text_node.Node.computed_values()
		// An LTR isolate is independent of the containing paragraph's
		// directional runs. Keep context when its punctuation became a chunk.
		if style.direction() != .ltr || style.unicode_bidi() != .isolate { return none }
	}
	font := chunks[0].font
	if font.font_rendering_policy != .chromium { return none }
	text := text_node.text_for_rendering()
	mut units := []u16{}
	if !text.is_ascii() {
		if !chromium_context_has_single_supported_script(text) { return none }
		units = utf16_code_units_for_line_box(text)
	}
	for chunk in chunks {
		if voidptr(chunk.font) != voidptr(font) || chunk.has_breaking_newline
			|| chunk.has_breaking_tab || chunk.start < 0 {
			return none
		}
		if units.len > 0 {
			if chunk.start + chunk.length > units.len || chunk.view !=
				string_from_utf16_code_units_for_line_box(units[chunk.start..chunk.start + chunk.length]) {
				return none
			}
		} else if chunk.start + chunk.length > text.len
			|| chunk.view != text[chunk.start..chunk.start + chunk.length] {
			return none
		}
	}
	letter_spacing :=
		resolved_text_spacing_for_node(unsafe { &Node(text_node) }, .letter_spacing).to_double()
	word_spacing :=
		resolved_text_spacing_for_node(unsafe { &Node(text_node) }, .word_spacing).to_double()
	run := iterator.shape_text_for_layout(text_node, 0, f32(letter_spacing), f32(word_spacing),
		text, font, .ltr).glyph_run
	// A cluster may emit multiple glyphs, each retaining its complete UTF-16
	// span. Summing those spans would misidentify every later chunk boundary.
	// Keep segmented shaping until the run carries explicit cluster offsets.
	mut covered_units := 0
	for glyph in run.glyphs_ { covered_units += glyph.length_in_code_units }
	if covered_units != if units.len > 0 { units.len } else { text.len } { return none }
	return run
}

fn chromium_context_has_single_supported_script(text string) bool {
	mut has_latin := false
	mut has_cyrillic := false
	for character in text.runes() {
		code_point := u32(character)
		if code_point in u32(`A`) .. u32(`Z` + 1) || code_point in u32(`a`) .. u32(`z` + 1)
			|| code_point in u32(0x00c0) .. u32(0x0300) {
			has_latin = true
		} else if code_point in u32(0x0400) .. u32(0x0530) {
			has_cyrillic = true
		} else if code_point > 0x036f && code_point !in u32(0x2000) .. u32(0x2070) {
			return false
		}
		// Common punctuation and combining marks can share either script's
		// context. Mixed scripts need itemization and keep segmented shaping.
		if has_latin && has_cyrillic { return false }
	}
	return true
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
	// Blink sums the 16.16 advances of a line's part of an item exactly from
	// its first glyph, then converts each sum to float. Subtracting the float
	// pens of a paragraph-long run instead moves glyphs hundreds of pixels in
	// by a few ULPs, enough to change their quarter-pixel raster position.
	// The slice starts at its first glyph's placement, which HarfBuzz's split
	// 'kern' adjustments can move, and ends at the next glyph's.
	mut glyphs := run.glyphs_[first..end].clone()
	origin := f64(glyphs[0].offset_x)
	mut local := f64(0)
	for mut glyph in glyphs {
		glyph.position.x = f32(local + f64(glyph.offset_x) - origin)
		local += f64(glyph.advance)
	}
	next_offset := if end < run.glyphs_.len { f64(run.glyphs_[end].offset_x) } else { f64(0) }
	mut sliced := platform.GlyphRun.new_with_face(run.font(), .ltr, glyphs, run.face())
	sliced.width_ = f32(local + next_offset - origin)
	sliced.space_width = run.space_width
	mut trailing_length := 0
	mut trailing_advance := f32(0)
	for index := glyphs.len - 1; index >= 0; index-- {
		glyph := glyphs[index]
		if glyph.code_point != u32(` `) {
			break
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
