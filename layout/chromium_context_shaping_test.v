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
	assert iterator.chromium_segmented_context_runs(text_node, chunks).len == 0
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

fn test_fallback_symbols_preserve_following_font_context_and_utf16_offsets() {
	for prefix in ['▶', '😀'] {
		mut document := html.parse_document('<!doctype html><div id="text" style="font:20px Arial">${prefix}Т-то Т-то</div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout_document_typed_in_viewport(document, 320, 100)
		element := css.query_selector(document.as_node(), '#text') or { panic('element') }
		child := element.as_node().first_child() or { panic('text') }
		bridge := child.layout_node() or { panic('layout') }
		node := unsafe { &Node(bridge.real_layout_handle()) }
		text_node := node.as_text_node() or { panic('text layout') }
		font := &platform.Font{
			family: 'Vox Cyrillic Context Test'
			source_path: os.join_path(os.dir(os.dir(@FILE)), 'Tests/Browser/Brave/resources/cyrillic-context.ttf')
			point_size: 20
			font_rendering_policy: .chromium
		}
		mut chunks := []TextNodeChunk{}
		mut splitter := TextNodeChunkIterator.new_with_direction(text_node, true, false, .unidirectional_left_to_right)
		for {
			chunk := splitter.next() or { break }
			chunks << if chunk.view.contains(prefix) { chunk } else { TextNodeChunk{ ...chunk, font: font } }
		}
		iterator := InlineLevelIterator{ is_unidirectional_left_to_right: true }
		assert iterator.chromium_single_script_context_run(text_node, chunks) == none
		runs := iterator.chromium_segmented_context_runs(text_node, chunks)
		assert runs.len == 1, prefix
		assert runs[0].start == if prefix == '😀' { 2 } else { 1 }
		assert runs[0].end == runs[0].start + 9
		whole := platform.shape_text(0, 0, 'Т-то Т-то', font, .ltr)
		assert runs[0].run.width() == whole.width()
		mut segmented_width := f32(0)
		mut context_width := f32(0)
		for chunk in chunks {
			if shaped := chromium_segmented_context_slice(runs, chunk) {
				assert voidptr(shaped.glyph_run.font()) == voidptr(font)
				assert shaped.glyph_run.glyphs_[0].position.x == 0
				context_width += shaped.glyph_run.width()
				segmented_width += platform.shape_text(0, 0, chunk.view, font, .ltr).width()
			} else {
				assert chunk.view.contains(prefix)
			}
		}
		assert segmented_width - context_width > 7.19
		assert segmented_width - context_width < 7.21
		assert context_width == whole.width()
	}
}

fn test_fallback_symbols_separate_contexts_without_enabling_bidi_shaping() {
	// A div's UA style is an isolate; use an ordinary inline run to exercise
	// the paragraph bidi gate rather than the deliberately supported isolate.
	mut document := html.parse_document('<!doctype html><span id="text" style="font:20px Arial;unicode-bidi:normal">Т-то▶Т-то</span>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 320, 100)
	element := css.query_selector(document.as_node(), '#text') or { panic('element') }
	child := element.as_node().first_child() or { panic('text') }
	bridge := child.layout_node() or { panic('layout') }
	node := unsafe { &Node(bridge.real_layout_handle()) }
	text_node := node.as_text_node() or { panic('text layout') }
	font := &platform.Font{
		family: 'Vox Cyrillic Context Test'
		source_path: os.join_path(os.dir(os.dir(@FILE)), 'Tests/Browser/Brave/resources/cyrillic-context.ttf')
		point_size: 20
		font_rendering_policy: .chromium
	}
	mut chunks := []TextNodeChunk{}
	mut splitter := TextNodeChunkIterator.new_with_direction(text_node, true, false, .unidirectional_left_to_right)
	for {
		chunk := splitter.next() or { break }
		chunks << if chunk.view.contains('▶') { chunk } else { TextNodeChunk{ ...chunk, font: font } }
	}
	iterator := InlineLevelIterator{ is_unidirectional_left_to_right: true }
	runs := iterator.chromium_segmented_context_runs(text_node, chunks)
	assert runs.len == 2
	assert runs[0].start == 0 && runs[0].end == 4
	assert runs[1].start == 5 && runs[1].end == 9
	for run in runs {
		assert run.run.width() == platform.shape_text(0, 0, 'Т-то', font, .ltr).width()
	}
	bidi_iterator := InlineLevelIterator{}
	assert bidi_iterator.chromium_segmented_context_runs(text_node, chunks).len == 0
}

fn test_context_chunk_scripts_follow_blink_script_runs() {
	views := [' ', '(V', 'й,', ' ', '12', 'A.', ' ']
	chunks := views.map(TextNodeChunk{ view: it })
	assert chromium_context_chunk_scripts(chunks) == [ChromiumContextScript.latin, .latin, .cyrillic,
		.cyrillic, .cyrillic, .latin, .latin]
	assert chromium_context_chunk_scripts([TextNodeChunk{ view: ' ' }, TextNodeChunk{ view: '42' }]) == [
		ChromiumContextScript.common, .common]
}

// 2ch.su's catalog: PT Sans ships its Cyrillic and Latin subsets as separate
// faces, so the space in "подразделений VK" selects the Latin face of "VK".
// Blink still shapes that space in the preceding Cyrillic script run, without
// the Latin face's space-V kern; a space after Latin text keeps its context.
fn test_spaces_after_cyrillic_do_not_share_a_latin_words_context() {
	mut document := html.parse_document('<!doctype html><div id="text" style="font:20px Arial">VA й VA</div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 320, 100)
	element := css.query_selector(document.as_node(), '#text') or { panic('element') }
	child := element.as_node().first_child() or { panic('text') }
	bridge := child.layout_node() or { panic('layout') }
	node := unsafe { &Node(bridge.real_layout_handle()) }
	text_node := node.as_text_node() or { panic('text layout') }
	cyrillic := &platform.Font{
		family: 'Vox Cyrillic Context Test'
		source_path: os.join_path(os.dir(os.dir(@FILE)), 'Tests/Browser/Brave/resources/cyrillic-context.ttf')
		point_size: 20
		font_rendering_policy: .chromium
	}
	latin := &platform.Font{
		family: 'Times New Roman'
		source_path: '/System/Library/Fonts/Supplemental/Times New Roman.ttf'
		point_size: 20
		font_rendering_policy: .chromium
	}
	if !os.exists(latin.source_path) { return }
	mut chunks := []TextNodeChunk{}
	mut splitter := TextNodeChunkIterator.new_with_direction(text_node, true, false, .unidirectional_left_to_right)
	for {
		chunk := splitter.next() or { break }
		chunks << TextNodeChunk{ ...chunk, font: if chunk.view == 'й' { cyrillic } else { latin } }
	}
	assert chunks.map(it.view) == ['VA', ' ', 'й', ' ', 'VA']
	// The face does kern space-V when both share a context.
	assert platform.shape_text(0, 0, ' V', latin, .ltr).width() < platform.shape_text(0, 0, ' ', latin, .ltr).width()
		+ platform.shape_text(0, 0, 'V', latin, .ltr).width()
	iterator := InlineLevelIterator{ is_unidirectional_left_to_right: true }
	runs := iterator.chromium_segmented_context_runs(text_node, chunks)
	assert runs.len == 1
	assert runs[0].start == 0 && runs[0].end == 3
	mut cursor := ChromiumContextSliceCursor{}
	assert chromium_segmented_context_slice_with_cursor(runs, chunks[3], mut cursor) == none
	assert chromium_segmented_context_slice_with_cursor(runs, chunks[4], mut cursor) == none
}

// 2ch.su's catalog with white-space: pre keeps "й VK" in one chunk. Blink
// itemizes it into the script runs "й " and "VK" before shaping, so the
// face's space-V kern never applies; one-script text still shapes whole.
fn test_mixed_script_chunks_shape_each_blink_script_run_apart() {
	assert chromium_script_run_starts('й VK', .common) == [3]
	assert chromium_script_run_starts(' VK й,', .common) == [4]
	assert chromium_script_run_starts('й,VKи', .common) == [3, 5]
	for text in ['VK', 'Что-то', '42 й', 'Wé Pay', 'й 😀 й', ''] {
		assert chromium_script_run_starts(text, .common) == [], text
	}
	// Leading common characters continue the script before the text.
	assert chromium_script_run_starts(' VK', .cyrillic) == [1]
	assert chromium_script_run_starts(' VK', .latin) == []
	assert chromium_script_run_starts(', й', .latin) == [2]
	assert chromium_script_run_starts('VK', .cyrillic) == []
	for text in [' VK', ', й', '42 V', ' й'] {
		assert chromium_text_starts_with_common_character(text), text
	}
	for text in ['VK', 'й ', 'é', ''] {
		assert !chromium_text_starts_with_common_character(text), text
	}
	times := '/System/Library/Fonts/Supplemental/Times New Roman.ttf'
	if !os.exists(times) { return }
	mut document := html.parse_document('<!doctype html><style>@font-face { font-family:Fixture; src:url("file://${times}") }</style><div id="text" style="font:20px Fixture;white-space:pre">й VK</div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 320, 100)
	element := css.query_selector(document.as_node(), '#text') or { panic('element') }
	child := element.as_node().first_child() or { panic('text') }
	bridge := child.layout_node() or { panic('layout') }
	node := unsafe { &Node(bridge.real_layout_handle()) }
	text_node := node.as_text_node() or { panic('text layout') }
	mut splitter := TextNodeChunkIterator.new_with_direction(text_node, false, true, .unidirectional_left_to_right)
	chunk := splitter.next() or { panic('chunk') }
	assert chunk.view == 'й VK'
	font := chunk.font
	assert font.font_rendering_policy == .chromium
	// The face kerns space-V when they share a shaping run.
	whole := platform.shape_text(0, 0, 'й VK', font, .ltr)
	cyrillic := platform.shape_text_with_spacing(0, 0, 0, 'й ', font, .ltr).glyph_run
	latin := platform.shape_text_with_spacing(0, 0, 0, 'VK', font, .ltr).glyph_run
	assert platform.shape_text(0, 0, ' V', font, .ltr).width() < platform.shape_text(0, 0, ' ', font, .ltr).width()
		+ platform.shape_text(0, 0, 'V', font, .ltr).width()
	iterator := InlineLevelIterator{ is_unidirectional_left_to_right: true }
	for initial_x in [f32(0), f32(7.25)] {
		shaped := iterator.shape_text_for_layout(text_node, initial_x, 0, 0, 'й VK', font, .ltr).glyph_run
		assert shaped.glyphs_.len == cyrillic.glyphs_.len + latin.glyphs_.len
		mut pen := f64(initial_x)
		for glyph in cyrillic.glyphs_ { pen += f64(glyph.advance) }
		for index, glyph in latin.glyphs_ {
			placed := shaped.glyphs_[cyrillic.glyphs_.len + index]
			assert placed.glyph_index == glyph.glyph_index
			assert placed.advance == glyph.advance
			assert placed.position.x == f32(pen + f64(glyph.position.x))
		}
		assert shaped.glyphs_[0].position.x == f32(f64(initial_x) + f64(cyrillic.glyphs_[0].position.x))
		assert shaped.width() > whole.width()
	}
	// Other policies and right-to-left runs keep their single shaping run.
	libweb := &platform.Font{ ...font, font_rendering_policy: .libweb }
	assert chromium_script_itemized_shape(0, 0, 0, 'й VK', libweb, .ltr, .common) == none
	assert chromium_script_itemized_shape(0, 0, 0, 'й VK', font, .rtl, .common) == none
	assert chromium_script_itemized_shape(0, 0, 0, 'Что-то', font, .ltr, .common) == none
}

// 2ch.su's catalog: PT Sans splits "подразделений VK" into a Cyrillic-subset
// "подразделений" and a Latin-subset " VK" chunk under white-space: pre. The
// space continues the Cyrillic script run, so it shapes apart from "VK".
fn test_a_chunks_leading_space_continues_the_script_before_it() {
	times := '/System/Library/Fonts/Supplemental/Times New Roman.ttf'
	if !os.exists(times) { return }
	latin := &platform.Font{
		family: 'Times New Roman'
		source_path: times
		point_size: 20
		font_rendering_policy: .chromium
	}
	space := platform.shape_text_with_spacing(0, 0, 0, ' ', latin, .ltr).glyph_run
	vk := platform.shape_text_with_spacing(0, 0, 0, 'VK', latin, .ltr).glyph_run
	whole := platform.shape_text_with_spacing(0, 0, 0, ' VK', latin, .ltr).glyph_run
	assert whole.width() < space.width() + vk.width()
	for prefix in ['й', 'a'] {
		mut document := html.parse_document('<!doctype html><div id="text" style="font:20px Arial;white-space:pre">${prefix} VK</div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout_document_typed_in_viewport(document, 320, 100)
		element := css.query_selector(document.as_node(), '#text') or { panic('element') }
		child := element.as_node().first_child() or { panic('text') }
		bridge := child.layout_node() or { panic('layout') }
		node := unsafe { &Node(bridge.real_layout_handle()) }
		text_node := node.as_text_node() or { panic('text layout') }
		assert chromium_script_before_offset(text_node, 1) == if prefix == 'й' { ChromiumContextScript.cyrillic } else { .latin }
		iterator := InlineLevelIterator{ is_unidirectional_left_to_right: true }
		shaped := iterator.shape_chunk_text_for_layout(text_node, utf16_code_units_for_line_box(prefix).len,
			0, 0, 0, ' VK', latin, .ltr).glyph_run
		if prefix == 'a' {
			assert shaped.width() == whole.width()
			continue
		}
		assert shaped.glyphs_.len == space.glyphs_.len + vk.glyphs_.len
		assert shaped.glyphs_[0].advance == space.glyphs_[0].advance
		for index, glyph in vk.glyphs_ {
			placed := shaped.glyphs_[space.glyphs_.len + index]
			assert placed.advance == glyph.advance
			assert placed.position.x == f32(f64(space.glyphs_[0].advance) + f64(glyph.position.x))
		}
		// The first chunk of the node and a leading letter keep one run.
		assert iterator.shape_chunk_text_for_layout(text_node, 0, 0, 0, 0, ' VK', latin, .ltr).glyph_run.width() == whole.width()
	}
}
