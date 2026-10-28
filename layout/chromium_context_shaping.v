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
		resolved_text_spacing_for_node(unsafe { &Node(text_node) }, .letter_spacing).to_double()
	word_spacing :=
		resolved_text_spacing_for_node(unsafe { &Node(text_node) }, .word_spacing).to_double()
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

// A fallback symbol must not remove the kerning context of later words in
// the primary face. Keep each compatible, contiguous font segment independent;
// unsupported scripts, bidi paths and multi-glyph clusters still fall back.
fn (iterator &InlineLevelIterator) chromium_segmented_context_runs(text_node &TextNode,
	chunks []TextNodeChunk) []ChromiumTextContextRun {
	mut runs := []ChromiumTextContextRun{}
	text := text_node.text_for_rendering()
	units := if text.is_ascii() { []u16{} } else { utf16_code_units_for_line_box(text) }
	mut first := 0
	for index, chunk in chunks {
		eligible := chunk.font.font_rendering_policy == .chromium
			&& !chunk.has_breaking_newline && !chunk.has_breaking_tab
			&& chromium_context_has_single_supported_script(chunk.view)
		boundary := !eligible || (index > first
			&& (voidptr(chunk.font) != voidptr(chunks[first].font)
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

fn chromium_segmented_context_slice(runs []ChromiumTextContextRun,
	chunk TextNodeChunk) ?platform.ShapedText {
	mut cursor := ChromiumContextSliceCursor{}
	return chromium_segmented_context_slice_with_cursor(runs, chunk, mut cursor)
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
