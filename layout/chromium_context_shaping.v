module layout

import platform

struct ChromiumTextContextRun {
	start int
	end   int
	run   &platform.GlyphRun
}

// Context runs are immutable while the iterator emits a text node's chunks.
// Keep the last UTF-16 boundary so successive words visit each glyph once.
struct ChromiumContextSliceCursor {
mut:
	run    &platform.GlyphRun = unsafe { nil }
	index  int
	offset int
}

// Blink shapes across soft word boundaries, including hyphens. Shaping
// "N. America" or "Что-то" as independent chunks loses their boundary kerning.
fn (iterator &InlineLevelIterator) chromium_single_script_context_run(text_node &TextNode,
	chunks []TextNodeChunk) ?&platform.GlyphRun {
	return iterator.chromium_context_run_for_text(text_node, chunks,
		text_node.text_for_rendering(), 0)
}

fn (iterator &InlineLevelIterator) chromium_context_run_for_text(text_node &TextNode,
	chunks []TextNodeChunk, text string, text_start int) ?&platform.GlyphRun {
	if chunks.len < 2 { return none }
	if !iterator.is_unidirectional_left_to_right {
		style := text_node.Node.computed_values()
		// An LTR isolate is independent of the containing paragraph's
		// directional runs. Keep context when its punctuation became a chunk.
		if style.direction() != .ltr || style.unicode_bidi() != .isolate { return none }
	}
	font := chunks[0].font
	if font.font_rendering_policy != .chromium { return none }
	mut units := []u16{}
	if !text.is_ascii() {
		if !chromium_context_has_single_supported_script(text) { return none }
		units = utf16_code_units_for_line_box(text)
	}
	for chunk in chunks {
		if voidptr(chunk.font) != voidptr(font) || chunk.has_breaking_newline
			|| chunk.has_breaking_tab || chunk.start < text_start {
			return none
		}
		start := chunk.start - text_start
		if units.len > 0 {
			if start + chunk.length > units.len || chunk.view !=
				string_from_utf16_code_units_for_line_box(units[start..start + chunk.length]) {
				return none
			}
		} else if start + chunk.length > text.len
			|| chunk.view != text[start..start + chunk.length] {
			return none
		}
	}
	letter_spacing :=
		resolved_text_spacing_for_shaping(unsafe { &Node(text_node) }, .letter_spacing)
	word_spacing :=
		resolved_text_spacing_for_shaping(unsafe { &Node(text_node) }, .word_spacing)
	context := chromium_collapsed_context_text(text_node, text)
	run := iterator.shape_text_for_layout(text_node, 0, f32(letter_spacing), f32(word_spacing),
		context.text, font, .ltr).glyph_run
	// A cluster may emit multiple glyphs, each retaining its complete UTF-16
	// span. Summing those spans would misidentify every later chunk boundary.
	// Keep segmented shaping until the run carries explicit cluster offsets.
	mut covered_units := 0
	for glyph in run.glyphs_ { covered_units += glyph.length_in_code_units }
	if covered_units != if context.source_offsets.len > 0 {
		context.source_offsets.len
	} else if units.len > 0 {
		units.len
	} else {
		text.len
	} {
		return none
	}
	return context.restore_source_offsets(run)
}

enum ChromiumContextScript {
	common
	latin
	cyrillic
}

// Spaces, digits, punctuation and combining marks are common to both scripts.
fn chromium_context_code_point_script(code_point u32) ChromiumContextScript {
	if code_point in u32(`A`) .. u32(`Z` + 1) || code_point in u32(`a`) .. u32(`z` + 1)
		|| code_point in u32(0x00c0) .. u32(0x0300) {
		return .latin
	}
	return if code_point in u32(0x0400) .. u32(0x0530) { .cyrillic } else { .common }
}

// The script of a chunk's first Latin or Cyrillic letter.
fn chromium_context_chunk_script(view string) ChromiumContextScript {
	if view.is_ascii() {
		for character in view {
			if (character >= `A` && character <= `Z`) || (character >= `a` && character <= `z`) {
				return .latin
			}
		}
		return .common
	}
	for character in view.runes() {
		script := chromium_context_code_point_script(u32(character))
		if script != .common { return script }
	}
	return .common
}

// Blink itemizes text into script runs before shaping (ScriptRunIterator):
// common characters continue the preceding letter's run and, before any
// letter, join the following one. A space after Cyrillic text therefore never
// shapes, or kerns, with a following Latin word, even in a shared face.
fn chromium_context_chunk_scripts(chunks []TextNodeChunk) []ChromiumContextScript {
	mut scripts := []ChromiumContextScript{len: chunks.len}
	mut previous := ChromiumContextScript.common
	mut leading := 0
	for index, chunk in chunks {
		script := chromium_context_chunk_script(chunk.view)
		if script == .common {
			scripts[index] = previous
			continue
		}
		scripts[index] = script
		if previous == .common {
			for leading < index { scripts[leading] = script; leading++ }
		}
		previous = script
	}
	return scripts
}

// The UTF-8 byte offsets at which a new Blink script run begins in `text`,
// after its first run. Common characters continue the preceding letter's run;
// leading ones join the first letter's run.
fn chromium_script_run_starts(text string) []int {
	mut starts := []int{}
	// Only text holding both Latin and Cyrillic letters can change script.
	mut has_latin := false
	mut has_cyrillic := false
	for byte_ in text {
		has_latin = has_latin || (byte_ >= `A` && byte_ <= `Z`) || (byte_ >= `a` && byte_ <= `z`)
			|| (byte_ >= 0xc3 && byte_ <= 0xcb)
		has_cyrillic = has_cyrillic || (byte_ >= 0xd0 && byte_ <= 0xd4)
	}
	if !has_latin || !has_cyrillic { return starts }
	mut script := ChromiumContextScript.common
	mut offset := 0
	for character in text.runes() {
		current := chromium_context_code_point_script(u32(character))
		if current != .common {
			if script != .common && current != script { starts << offset }
			script = current
		}
		offset += character.length_in_bytes()
	}
	return starts
}

// Blink itemizes text into script runs before shaping (ScriptRunIterator). A
// chunk mixing Latin and Cyrillic letters, such as a preserved "й VK" or an
// unbreakable "й,VK", shapes each run apart and never kerns across their
// boundary. Each run starts at the exact sum of the advances before it.
fn chromium_script_itemized_shape(initial_x f32, letter_spacing f32, word_spacing f32,
	text string, font &platform.Font, text_type platform.GlyphRunTextType) ?platform.ShapedText {
	if font.font_rendering_policy != .chromium || text_type != .ltr || text.is_ascii() { return none }
	starts := chromium_script_run_starts(text)
	if starts.len == 0 { return none }
	mut glyphs := []platform.Glyph{}
	mut pen := f64(initial_x)
	mut face := platform.GlyphRunFace.document
	mut trailing := platform.TrailingWhitespace{}
	mut previous := 0
	for index in 0 .. starts.len + 1 {
		end := if index < starts.len { starts[index] } else { text.len }
		shaped := platform.shape_text_with_spacing(0, letter_spacing, word_spacing, text[previous..end],
			font, text_type)
		run := shaped.glyph_run
		if index == 0 {
			face = run.face()
		} else if run.face() != face {
			return none
		}
		for glyph in run.glyphs_ {
			mut placed := glyph
			placed.position.x = f32(pen + f64(glyph.position.x))
			glyphs << placed
		}
		for glyph in run.glyphs_ { pen += f64(glyph.advance) }
		trailing = shaped.trailing_whitespace
		previous = end
	}
	return platform.ShapedText{
		glyph_run:           platform.GlyphRun.new_with_face(font, text_type, glyphs, face)
		trailing_whitespace: trailing
	}
}

fn chromium_shape_text_for_layout(initial_x f32, letter_spacing f32, word_spacing f32, text string,
	font &platform.Font, text_type platform.GlyphRunTextType) platform.ShapedText {
	if shaped := chromium_script_itemized_shape(initial_x, letter_spacing, word_spacing, text, font,
		text_type) {
		return shaped
	}
	return platform.shape_text_with_spacing(initial_x, letter_spacing, word_spacing, text, font, text_type)
}

// A fallback symbol must not remove the kerning context of later words in
// the primary face. Keep each compatible, contiguous font segment independent;
// unsupported scripts, bidi paths and multi-glyph clusters still fall back.
// A script run boundary also ends a segment.
fn (iterator &InlineLevelIterator) chromium_segmented_context_runs(text_node &TextNode,
	chunks []TextNodeChunk) []ChromiumTextContextRun {
	mut runs := []ChromiumTextContextRun{}
	text := text_node.text_for_rendering()
	units := if text.is_ascii() { []u16{} } else { utf16_code_units_for_line_box(text) }
	scripts := chromium_context_chunk_scripts(chunks)
	mut first := 0
	for index, chunk in chunks {
		eligible := chunk.font.font_rendering_policy == .chromium
			&& !chunk.has_breaking_newline && !chunk.has_breaking_tab
			&& chromium_context_has_single_supported_script(chunk.view)
		boundary := !eligible || (index > first
			&& (voidptr(chunk.font) != voidptr(chunks[first].font)
				|| scripts[index] != scripts[first]
				|| chunk.start != chunks[index - 1].start + chunks[index - 1].length))
		if boundary {
			if run := iterator.chromium_context_segment(text_node, chunks[first..index], text, units) {
				runs << run
			}
			first = if eligible { index } else { index + 1 }
		}
	}
	if run := iterator.chromium_context_segment(text_node, chunks[first..], text, units) {
		runs << run
	}
	return runs
}

fn (iterator &InlineLevelIterator) chromium_context_segment(text_node &TextNode,
	chunks []TextNodeChunk, text string, units []u16) ?ChromiumTextContextRun {
	if chunks.len < 2 { return none }
	start := chunks[0].start
	end := chunks.last().start + chunks.last().length
	if start < 0 || end < start { return none }
	segment := if units.len > 0 {
		if end > units.len { return none }
		string_from_utf16_code_units_for_line_box(units[start..end])
	} else {
		if end > text.len { return none }
		text[start..end]
	}
	run := iterator.chromium_context_run_for_text(text_node, chunks, segment, start)?
	return ChromiumTextContextRun{start, end, run}
}

$if test {
	fn chromium_segmented_context_slice(runs []ChromiumTextContextRun,
		chunk TextNodeChunk) ?platform.ShapedText {
		mut cursor := ChromiumContextSliceCursor{}
		return chromium_segmented_context_slice_with_cursor(runs, chunk, mut cursor)
	}
}

fn chromium_segmented_context_slice_with_cursor(runs []ChromiumTextContextRun,
	chunk TextNodeChunk, mut cursor ChromiumContextSliceCursor) ?platform.ShapedText {
	for segment in runs {
		if chunk.start >= segment.start && chunk.start + chunk.length <= segment.end {
			return chromium_context_slice_with_cursor(segment.run, TextNodeChunk{
				...chunk
				start: chunk.start - segment.start
			}, mut cursor)
		}
	}
	return none
}

fn chromium_context_has_single_supported_script(text string) bool {
	if text.is_ascii() { return true }
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
	mut cursor := ChromiumContextSliceCursor{}
	return chromium_context_slice_with_cursor(run, chunk, mut cursor)
}

fn chromium_context_slice_with_cursor(run &platform.GlyphRun, chunk TextNodeChunk,
	mut cursor ChromiumContextSliceCursor) ?platform.ShapedText {
	if voidptr(cursor.run) != voidptr(run) || chunk.start < cursor.offset {
		cursor = ChromiumContextSliceCursor{ run: run }
	}
	mut offset := cursor.offset
	mut first := -1
	mut end := -1
	for index := cursor.index; index < run.glyphs_.len; index++ {
		glyph := run.glyphs_[index]
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
	cursor.index = end
	cursor.offset = offset
	return run.ltr_context_slice_for_layout(first, end)
}
