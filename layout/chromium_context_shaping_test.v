module layout

import platform
import css
import html

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

fn test_latin_context_slices_use_utf16_offsets_after_multibyte_punctuation() {
	font := &platform.Font{family: 'Test', point_size: 16, font_rendering_policy: .chromium}
	run := platform.GlyphRun.new(font, .ltr, [
		platform.Glyph{code_point: 0x2018, advance: 4, length_in_code_units: 1},
		platform.Glyph{code_point: u32(`W`), position: platform.GlyphPosition{x: 4}, advance: 12, length_in_code_units: 1},
		platform.Glyph{code_point: 0x00e9, position: platform.GlyphPosition{x: 16}, advance: 8, length_in_code_units: 1},
	])
	word := chromium_context_slice(run, TextNodeChunk{start: 1, length: 2}) or { panic('word missing') }
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
		shaped := iterator.chromium_latin_context_run(text_node, chunks)
		assert (shaped != none) == (index == 0)
	}
}
