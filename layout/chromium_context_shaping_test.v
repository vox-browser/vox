module layout

import platform
import css
import html
import os

fn test_context_slices_keep_space_kerning_and_own_their_glyph_arrays() {
	font := &platform.Font{
		family:                'Test'
		point_size:            10
		font_rendering_policy: .chromium
	}
	mut full := platform.GlyphRun.new(font, .ltr, [
		platform.Glyph{ code_point: u32(`N`), advance: 7, length_in_code_units: 1 },
		platform.Glyph{
			code_point:           u32(` `)
			position:             platform.GlyphPosition{
				x: 7
			}
			advance:              2.25
			length_in_code_units: 1
		},
		platform.Glyph{
			code_point:           u32(`A`)
			position:             platform.GlyphPosition{
				x: 9.25
			}
			advance:              7
			length_in_code_units: 1
		},
	])
	space := chromium_context_slice(full, TextNodeChunk{ start: 1, length: 1 }) or {
		panic('space missing')
	}
	letter := chromium_context_slice(full, TextNodeChunk{ start: 2, length: 1 }) or {
		panic('letter missing')
	}
	assert space.glyph_run.width() == 2.25
	assert space.trailing_whitespace.advance == 2.25
	assert space.trailing_whitespace.length_in_code_units == 1
	assert letter.glyph_run.glyphs_[0].position.x == 0
	assert letter.glyph_run.width() == 7
	full.glyphs_[1].advance = 99
	assert space.glyph_run.glyphs_[0].advance == 2.25
	ligature := platform.GlyphRun.new(font, .ltr, [
		platform.Glyph{ code_point: u32(`f`), advance: 10, length_in_code_units: 2 },
	])
	assert chromium_context_slice(ligature, TextNodeChunk{ start: 1, length: 1 }) == none
}

// Blink sums a line's 16.16 advances exactly from its first glyph. A slice
// late in a paragraph-long run must not subtract its float pens, and keeps the
// placement HarfBuzz's split 'kern' adjustment gave its following glyph.
fn test_context_slices_sum_advances_exactly_from_their_first_glyph() {
	font := &platform.Font{ family: 'Test', point_size: 13.333333, font_rendering_policy: .chromium }
	advance := f32(485851.0 / 65536.0)
	mut glyphs := []platform.Glyph{}
	mut pen := f32(0)
	for index in 0 .. 400 {
		// The second glyph of each kern pair carries half the adjustment as its
		// placement, as HarfBuzz applies legacy 'kern' tables.
		offset := if index % 2 == 1 { f32(-3.0 / 65536.0) } else { f32(0) }
		glyphs << platform.Glyph{
			code_point:           u32(`e`)
			position:             platform.GlyphPosition{ x: pen + offset }
			advance:              advance
			offset_x:             offset
			length_in_code_units: 1
		}
		pen += advance
	}
	run := platform.GlyphRun.new(font, .ltr, glyphs)
	word := chromium_context_slice(run, TextNodeChunk{ start: 300, length: 4 }) or { panic('word missing') }
	// The slice starts at its first glyph's placement and ends at the next
	// glyph's, so a following slice continues exactly where this one ends.
	assert word.glyph_run.glyphs_[0].position.x == 0
	assert word.glyph_run.glyphs_[1].position.x == f32(f64(advance) - 3.0 / 65536.0)
	assert word.glyph_run.glyphs_[3].position.x == f32(3 * f64(advance) - 3.0 / 65536.0)
	assert word.glyph_run.width() == f32(4 * f64(advance) - 0.0)
	odd := chromium_context_slice(run, TextNodeChunk{ start: 301, length: 2 }) or { panic('odd missing') }
	assert odd.glyph_run.glyphs_[1].position.x == f32(f64(advance) + 3.0 / 65536.0)
	assert odd.glyph_run.width() == f32(2 * f64(advance) - 3.0 / 65536.0 + 3.0 / 65536.0)
}

fn test_latin_context_slices_use_utf16_offsets_after_multibyte_punctuation() {
	font := &platform.Font{ family: 'Test', point_size: 16, font_rendering_policy: .chromium }
	run := platform.GlyphRun.new(font, .ltr, [
		platform.Glyph{ code_point: 0x2018, advance: 4, length_in_code_units: 1 },
		platform.Glyph{ code_point: u32(`W`), position: platform.GlyphPosition{ x: 4 }, advance: 12, length_in_code_units: 1 },
		platform.Glyph{ code_point: 0x00e9, position: platform.GlyphPosition{ x: 16 }, advance: 8, length_in_code_units: 1 },
	])
	word := chromium_context_slice(run, TextNodeChunk{ start: 1, length: 2 }) or { panic('word missing') }
	assert word.glyph_run.glyphs_.len == 2
	assert word.glyph_run.glyphs_[0].code_point == u32(`W`)
	assert word.glyph_run.glyphs_[1].code_point == 0x00e9
	assert word.glyph_run.glyphs_[1].position.x == 12
	assert word.glyph_run.width() == 20
}

fn test_context_shaping_accepts_latin_isolates_and_keeps_other_bidi_paths() {
	for index, text in ['‘We Pay for It’', '‘We Pay for It’', 'مرحبا بالعالم'] {
		bidi := if index == 1 { 'normal' } else { 'isolate' }
		mut document := html.parse_document('<!doctype html><div id="text" style="font:16px Arial;direction:ltr;unicode-bidi:${bidi}">${text}</div>')
		document.set_font_rendering_policy(.chromium)
		_ = layout_document_typed_in_viewport(document, 320, 100)
		element := css.query_selector(document.as_node(), '#text') or { panic('element missing') }
		child := element.as_node().first_child() or { panic('text missing') }
		bridge := child.layout_node() or { panic('layout missing') }
		node := unsafe { &Node(bridge.real_layout_handle()) }
		text_node := node.as_text_node() or { panic('text layout missing') }
		mut chunks := []TextNodeChunk{}
		mut splitter := TextNodeChunkIterator.new_with_direction(text_node, true, false, .per_code_point)
		for { chunks << splitter.next() or { break } }
		iterator := InlineLevelIterator{}
		shaped := iterator.chromium_single_script_context_run(text_node, chunks)
		assert (shaped != none) == (index == 0)
	}
}

fn test_context_script_eligibility_keeps_cyrillic_punctuation_and_combining_marks() {
	for text in ['Что-то пошло не так.', 'Приве́т, мир!', 'Ёж — Щука',
		'Җ—Ӂ Ҧ', '‘Wé Pay’', '42 — 17'] {
		assert chromium_context_has_single_supported_script(text), text
	}
	for text in ['Что-то Maps', 'Аa', 'Α—Ω', 'مرحبا بالعالم', 'а😀б',
		'а꙯б'] {
		assert !chromium_context_has_single_supported_script(text), text
	}
}

fn test_cyrillic_context_shaping_retains_hyphen_kerning_through_utf16_chunks() {
	mut document := html.parse_document('<!doctype html><div id="text" style="font:16px Arial;direction:ltr;unicode-bidi:isolate">Что-то пошло не так.</div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 320, 100)
	element := css.query_selector(document.as_node(), '#text') or { panic('element missing') }
	child := element.as_node().first_child() or { panic('text missing') }
	bridge := child.layout_node() or { panic('layout missing') }
	node := unsafe { &Node(bridge.real_layout_handle()) }
	text_node := node.as_text_node() or { panic('text layout missing') }
	mut chunks := []TextNodeChunk{}
	mut splitter := TextNodeChunkIterator.new_with_direction(text_node, true, false, .unidirectional_left_to_right)
	for { chunks << splitter.next() or { break } }
	assert chunks.len > 2
	assert chunks[0].view == 'Что-'
	iterator := InlineLevelIterator{}
	run := iterator.chromium_single_script_context_run(text_node, chunks) or { panic('context missing') }
	font := chunks[0].font
	whole := platform.shape_text(0, 0, text_node.text_for_rendering(), font, .ltr)
	assert run.width() == whole.width()
	assert run.glyphs_.len == whole.glyphs_.len
	for index, glyph in run.glyphs_ {
		assert glyph.advance == whole.glyphs_[index].advance
		assert glyph.position.x == whole.glyphs_[index].position.x
	}
	first := chromium_context_slice(run, chunks[0]) or { panic('hyphen chunk missing') }
	second := chromium_context_slice(run, chunks[1]) or { panic('following chunk missing') }
	assert first.glyph_run.glyphs_.len == 4
	assert second.glyph_run.glyphs_[0].code_point == u32(`т`)
	assert first.glyph_run.width() == run.glyphs_[4].position.x
	// Different faces, explicit newlines, and tabs cannot share this run.
	mut incompatible := chunks.clone()
	incompatible[1] = TextNodeChunk{ ...chunks[1], font: &platform.Font{ family: 'Other', point_size: 16, font_rendering_policy: .chromium } }
	assert iterator.chromium_single_script_context_run(text_node, incompatible) == none
	incompatible = chunks.clone()
	incompatible[0] = TextNodeChunk{ ...chunks[0], has_breaking_newline: true }
	assert iterator.chromium_single_script_context_run(text_node, incompatible) == none
	incompatible = chunks.clone()
	incompatible[0] = TextNodeChunk{ ...chunks[0], has_breaking_tab: true }
	assert iterator.chromium_single_script_context_run(text_node, incompatible) == none
}

fn test_cyrillic_context_keeps_segmented_shaping_for_multi_glyph_clusters() {
	mut document := html.parse_document('<!doctype html><div id="text" style="font:16px Arial;direction:ltr;unicode-bidi:isolate">Приве́т, мир!</div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 320, 100)
	element := css.query_selector(document.as_node(), '#text') or { panic('element missing') }
	child := element.as_node().first_child() or { panic('text missing') }
	bridge := child.layout_node() or { panic('layout missing') }
	node := unsafe { &Node(bridge.real_layout_handle()) }
	text_node := node.as_text_node() or { panic('text layout missing') }
	mut chunks := []TextNodeChunk{}
	mut splitter := TextNodeChunkIterator.new_with_direction(text_node, true, false, .unidirectional_left_to_right)
	for { chunks << splitter.next() or { break } }
	assert chunks.len > 2
	iterator := InlineLevelIterator{}
	assert iterator.chromium_single_script_context_run(text_node, chunks) == none
}

fn test_cyrillic_context_keeps_cross_chunk_kerning_from_a_file_backed_face() {
	mut document := html.parse_document('<!doctype html><div id="text" style="direction:ltr;unicode-bidi:isolate">Т-то Т-то</div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 320, 100)
	element := css.query_selector(document.as_node(), '#text') or { panic('element missing') }
	child := element.as_node().first_child() or { panic('text missing') }
	bridge := child.layout_node() or { panic('layout missing') }
	node := unsafe { &Node(bridge.real_layout_handle()) }
	text_node := node.as_text_node() or { panic('text layout missing') }
	font := &platform.Font{
		family:                'Vox Cyrillic Context Test'
		source_path:           os.join_path(os.dir(os.dir(@FILE)), 'Tests/Browser/Brave/resources/cyrillic-context.ttf')
		point_size:            20
		font_rendering_policy: .chromium
	}
	mut chunks := []TextNodeChunk{}
	mut splitter := TextNodeChunkIterator.new_with_direction(text_node, true, false, .unidirectional_left_to_right)
	for {
		chunk := splitter.next() or { break }
		chunks << TextNodeChunk{ ...chunk, font: font }
	}
	assert chunks[0].view == 'Т-'
	iterator := InlineLevelIterator{}
	run := iterator.chromium_single_script_context_run(text_node, chunks) or { panic('context missing') }
	mut segmented_width := f32(0)
	mut context_width := f32(0)
	for chunk in chunks {
		segmented_width += platform.shape_text(0, 0, chunk.view, font, .ltr).width()
		sliced := chromium_context_slice(run, chunk) or { panic('chunk missing') }
		context_width += sliced.glyph_run.width()
	}
	// Two -180/1000 em kern pairs must survive the soft break after '-'.
	assert segmented_width - run.width() > 7.19
	assert segmented_width - run.width() < 7.21
	assert context_width == run.width()
}
