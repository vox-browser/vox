module layout

import css
import dom
import html
import platform

fn test_chromium_ascii_hyphen_can_end_a_line_after_whitespace() {
	for chromium in [false, true] {
		mut document := dom.Document.create(dom.url_about_blank())
		defer { document.finalize() }
		if chromium { document.set_font_rendering_policy(.chromium) }
		style := chunk_test_style(document, 'display:block;white-space-collapse:collapse;text-wrap-mode:wrap')
		for text in ['-word', 'end. -word', 'end. -123'] {
			text_node := make_chunk_test_text_node(document, text, style)
			mut iterator := TextNodeChunkIterator.new(text_node, true, false)
			boundary := text.index('-') or { panic('hyphen') } + 1
			assert iterator.line_boundaries[boundary] == (chromium && text != 'end. -123')
		}
	}
}

fn chunk_test_style(document &dom.Document, declarations string) &css.ComputedProperties {
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	element.set_attribute_value('style', declarations)
	computer := css.css_style_computer_for(document)
	return computer.compute_style(dom.AbstractElement.new(element, none))
}

fn make_chunk_test_text_node(document &dom.Document, text string, style &css.ComputedProperties) &TextNode {
	parent := BlockContainer.new(document, none, style)
	dom_text := document.create_text_node(text).as_node()
	text_node := TextNode.new(document, dom_text, text)
	mut parent_node := unsafe { &Node(parent) }
	parent_node.append_child(unsafe { &Node(text_node) })
	return text_node
}

fn test_text_node_chunk_iterator_splits_words_and_collapsible_space() {
	document := dom.Document.create(dom.url_about_blank())
	style := chunk_test_style(document, 'display:block; white-space-collapse:collapse; text-wrap-mode:wrap; font-size:20px')
	text_node := make_chunk_test_text_node(document, 'one   two', style)
	mut iterator := TextNodeChunkIterator.new(text_node, true, false)
	first := iterator.next() or { panic('first chunk') }
	space := iterator.next() or { panic('space chunk') }
	second := iterator.next() or { panic('second chunk') }
	assert first.view == 'one'
	assert space.view == ' '
	assert space.is_all_whitespace
	assert !space.can_break_after
	assert second.view == 'two'
	assert iterator.next() == none
}

fn test_text_node_chunk_iterator_preserves_utf16_offsets_and_newline() {
	document := dom.Document.create(dom.url_about_blank())
	style := chunk_test_style(document, 'display:block; white-space-collapse:preserve; text-wrap-mode:wrap')
	text_node := make_chunk_test_text_node(document, 'A😀\nB', style)
	mut iterator := TextNodeChunkIterator.new(text_node, true, true)
	first := iterator.next() or { panic('text chunk') }
	emoji := iterator.next() or { panic('emoji chunk') }
	newline := iterator.next() or { panic('newline chunk') }
	last := iterator.next() or { panic('last chunk') }
	assert first.view == 'A'
	assert first.start == 0
	assert first.length == 1
	assert emoji.view == '😀'
	assert emoji.start == 1
	assert emoji.length == 2
	assert newline.has_breaking_newline
	assert newline.start == 3
	assert newline.length == 1
	assert last.start == 4
}

fn test_nowrap_text_chunks_keep_unicode_and_preserved_breaks_without_line_segmentation() {
	document := dom.Document.create(dom.url_about_blank())
	style := chunk_test_style(document, 'display:block; white-space-collapse:preserve; text-wrap-mode:nowrap')
	text := 'ab-cd 你好 אבג Á😀\n\tend'
	text_node := make_chunk_test_text_node(document, text, style)
	mut iterator := TextNodeChunkIterator.new(text_node, false, true)
	assert text_node.line_segmenter_ == unsafe { nil }
	mut rendered := ''
	mut end := 0
	mut newline_count := 0
	mut tab_count := 0
	for {
		chunk := iterator.next() or { break }
		assert chunk.start == end
		end += chunk.length
		rendered += chunk.view
		assert !chunk.can_break_after
		if chunk.has_breaking_newline {
			assert chunk.view == '\n'
			newline_count++
		}
		if chunk.has_breaking_tab {
			tab_count++
		}
	}
	assert rendered == text
	assert end == utf16_code_units_for_line_box(text).len
	assert newline_count == 1
	assert tab_count == 1
	assert text_node.line_segmenter_ == unsafe { nil }
}

fn test_nowrap_text_collection_collapses_space_before_wrapped_layout_initializes_segmenter() {
	document := dom.Document.create(dom.url_about_blank())
	style := chunk_test_style(document, 'display:block; white-space-collapse:collapse; text-wrap-mode:wrap')
	text_node := make_chunk_test_text_node(document, 'one   two-three', style)
	mut collection_iterator := TextNodeChunkIterator.new(text_node, false, false)
	mut collected := ''
	for {
		chunk := collection_iterator.next() or { break }
		collected += chunk.view
		assert !chunk.can_break_after
	}
	assert collected == 'one two-three'
	assert text_node.line_segmenter_ == unsafe { nil }
	mut layout_iterator := TextNodeChunkIterator.new(text_node, true, false)
	assert text_node.line_segmenter_ != unsafe { nil }
	mut found_hyphen_break := false
	for {
		chunk := layout_iterator.next() or { break }
		if chunk.view == '-' {
			assert chunk.can_break_after
			found_hyphen_break = true
		}
	}
	assert found_hyphen_break
}

fn test_text_node_chunk_iterator_uses_a_file_backed_face_on_its_first_shape() {
	$if macos {
		document := html.parse_document('<!doctype html><style>@font-face { font-family: Fixture; src: url("file:///System/Library/Fonts/Supplemental/Arial.ttf") } span { font: 20px Fixture }</style><span id="first">X</span><span id="second">X</span>')
		css.sync_document_style_elements(document)
		first := css.query_selector(unsafe { &dom.Node(document) }, '#first') or {
			panic('missing first target')
		}
		second := css.query_selector(unsafe { &dom.Node(document) }, '#second') or {
			panic('missing second target')
		}
		computer := css.css_style_computer_for(document)
		first_style := computer.compute_style(dom.AbstractElement.new(first,
			none))
		second_style := computer.compute_style(dom.AbstractElement.new(second,
			none))
		first_text := make_chunk_test_text_node(document, 'X', first_style)
		second_text := make_chunk_test_text_node(document, 'X', second_style)
		mut first_iterator := TextNodeChunkIterator.new(first_text, true, false)
		first_chunk := first_iterator.next() or { panic('missing first text chunk') }
		assert first_chunk.font.family == 'Fixture'
		assert first_chunk.font.source_path == '/System/Library/Fonts/Supplemental/Arial.ttf'
		// Both computed styles cached the pending cascade before the first shape
		// loaded it. The second style must notice the new font generation rather
		// than retaining its fallback-only cascade.
		mut second_iterator := TextNodeChunkIterator.new(second_text, true, false)
		second_chunk := second_iterator.next() or { panic('missing second text chunk') }
		assert second_chunk.font.family == 'Fixture'
		assert second_chunk.font.source_path == '/System/Library/Fonts/Supplemental/Arial.ttf'
	}
}

fn test_text_node_chunk_iterator_uses_fallback_for_missing_space_glyph() {
	letters_font := &platform.Font{
		family: 'Verdemerona'
		point_size: 16
		source_path: 'pixel_tests/sites/css-zen-garden/www.csszengarden.com/214/verdemoderna.ttf'
	}
	space_font := &platform.Font{
		family: 'Glyphicons Halflings'
		point_size: 16
		source_path: 'pixel_tests/sites/uclibc-ng/uclibc-ng.org/fonts/glyphicons-halflings-regular.ttf'
	}
	assert letters_font.contains_glyph(u32(`A`))
	assert !letters_font.contains_glyph(u32(` `))
	assert space_font.contains_glyph(u32(` `))

	mut iterator := TextNodeChunkIterator{
		view: 'A A'
		code_units: utf16_code_units_for_line_box('A A')
		grapheme_boundaries: [0, 1, 2, 3]
		font: space_font
		font_cascade_fonts: [letters_font, space_font]
		font_cascade_ranges: [[css.UnicodeRange{ start: u32(`A`), end: u32(`A`) }],
			[]css.UnicodeRange{}]
	}
	first := iterator.next() or { panic('first letter') }
	space := iterator.next() or { panic('space') }
	last := iterator.next() or { panic('last letter') }
	assert first.font == letters_font
	assert space.font == space_font
	assert last.font == letters_font
}

fn test_line_box_utf16_helpers_preserve_ascii_and_surrogate_offsets() {
	assert utf16_code_units_for_line_box('plain text') == [u16(112), 108, 97, 105, 110, 32, 116,
		101, 120, 116]
	assert utf16_substring_for_line_box('plain text', 6, 4) == 'text'
	assert utf16_substring_for_line_box('plain text', -2, 5) == 'plain'
	assert utf16_substring_for_line_box('A😀B', 1, 2) == '😀'
	assert utf16_substring_for_line_box('A😀B', 3, 1) == 'B'
}

fn test_text_node_chunk_iterator_break_all_splits_typographic_units() {
	document := dom.Document.create(dom.url_about_blank())
	style := chunk_test_style(document, 'display:block; word-break:break-all; text-wrap-mode:wrap')
	text_node := make_chunk_test_text_node(document, 'abc', style)
	mut iterator := TextNodeChunkIterator.new(text_node, true, false)
	assert (iterator.next() or { panic('a') }).view == 'a'
	assert (iterator.next() or { panic('b') }).view == 'b'
	assert (iterator.next() or { panic('c') }).view == 'c'
}

fn test_text_node_chunk_iterator_preserves_break_across_text_type_boundary() {
	document := dom.Document.create(dom.url_about_blank())
	style := chunk_test_style(document, 'display:block; text-wrap-mode:wrap')
	text_node := make_chunk_test_text_node(document, 'min-content', style)
	mut iterator := TextNodeChunkIterator.new(text_node, true, false)
	word_before := iterator.next() or { panic('word before hyphen') }
	hyphen := iterator.next() or { panic('hyphen') }
	word_after := iterator.next() or { panic('word after hyphen') }
	assert word_before.view == 'min'
	assert !word_before.can_break_after
	assert hyphen.view == '-'
	assert hyphen.can_break_after
	assert word_after.view == 'content'
	assert iterator.next() == none
}

fn test_non_breaking_space_is_context_dependent_interword_text() {
	assert is_interword_space(u32(` `))
	assert is_interword_space(0x00a0)
	assert !is_interword_space(u32(`\t`))
	assert text_type_for_code_point(0x00a0) == .context_dependent
}

fn test_text_type_uses_unicode_bidirectional_class() {
	assert text_type_for_code_point(0x2013) == .common // EN DASH, ON
	assert text_type_for_code_point(0x2019) == .common // RIGHT SINGLE QUOTATION MARK, ON
	assert text_type_for_code_point(0x0661) == .context_dependent // ARABIC-INDIC DIGIT ONE, AN
	assert text_type_for_code_point(0x037e) == .common // GREEK QUESTION MARK, ON
	assert text_type_for_code_point(0x03b1) == .ltr // GREEK SMALL LETTER ALPHA, L
	assert text_type_for_code_point(0x05d0) == .rtl // HEBREW LETTER ALEF, R
}

fn test_ascii_grapheme_boundaries_keep_crlf_together() {
	assert text_grapheme_boundaries('a\r\nb') == [0, 1, 3, 4]
}

fn test_text_node_repicks_ascii_line_segmenter_for_rendered_text() {
	document := dom.Document.create(dom.url_about_blank())
	style := chunk_test_style(document, 'display:block; text-wrap-mode:wrap')
	mut text_node := make_chunk_test_text_node(document, 'ab cd', style)
	first := text_node.line_segmenter()
	assert first.is_ascii_line_fast_path()
	assert first.boundaries() == [0, 3, 5]

	dom_text := text_node.dom_node() or { panic('missing DOM text source') }
	mut character_data := dom_text.as_character_data() or { panic('missing character data') }
	character_data.replace_data_with_mutation_steps(0, 5, '你好') or { panic(err) }
	text_node.invalidate_text_for_rendering()
	second := text_node.line_segmenter()
	assert voidptr(second) != voidptr(first)
	assert !second.is_ascii_line_fast_path()
	assert second.boundaries() == [0, 1, 2]
}

fn test_common_latin_punctuation_uses_code_point_boundaries() {
	assert text_grapheme_boundaries('a –’b') == [0, 1, 2, 3, 4, 5]
	assert text_grapheme_boundaries('áb') == [0, 2, 3]
}
