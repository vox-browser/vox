module layout

import css
import dom

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

fn test_common_latin_punctuation_uses_code_point_boundaries() {
	assert text_grapheme_boundaries('a –’b') == [0, 1, 2, 3, 4, 5]
	assert text_grapheme_boundaries('áb') == [0, 2, 3]
}
