module layout

import css
import dom

fn reusable_units_test_node(document &dom.Document, source string, declarations string) &TextNode {
	mut element := document.create_element('div') or { panic(err) }
	element.set_attribute_value('style', 'white-space-collapse:preserve; text-wrap-mode:wrap; ${declarations}')
	style := css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none))
	parent := BlockContainer.new(document, none, style)
	text := TextNode.new_generated(document, source)
	mut parent_node := unsafe { &Node(parent) }
	parent_node.append_child(unsafe { &Node(text) })
	return text
}

fn test_chunk_iterators_share_existing_rendered_units_across_wrap_modes_and_collection() {
	document := dom.Document.create(dom.url_about_blank())
	inputs := ['ASCII\r\ntext', 'A😀中文אבג', 'A\u0301👩‍👩‍👧‍👦', '',
		[u8(0xff), 0xed, 0xa0, 0x80, 0x41].bytestr()]
	for input in inputs {
		text := reusable_units_test_node(document, input, '')
		assert text.cached_utf16_code_units_ == none
		first := TextNodeChunkIterator.new(text, false, true)
		expected := utf16_code_units_for_line_box(first.view)
		assert first.code_units == expected
		for wrap in [false, true, false] {
			second := TextNodeChunkIterator.new(text, wrap, true)
			gc_collect()
			assert second.code_units == expected
			assert voidptr(second.code_units.data) == voidptr(first.code_units.data)
			cached := text.cached_utf16_code_units_ or { panic('missing units') }
			assert voidptr(cached.data) == voidptr(first.code_units.data)
		}
	}
}

fn test_rendered_unit_invalidation_keeps_old_iterators_and_rebuilds_for_new_text() {
	document := dom.Document.create(dom.url_about_blank())
	mut text := reusable_units_test_node(document, 'A😀B', '')
	mut first := TextNodeChunkIterator.new(text, false, true)
	original := first.code_units.clone()
	text.source_text_ = 'אב Ć\nD'
	text.invalidate_text_for_rendering()
	assert text.cached_utf16_code_units_ == none
	second := TextNodeChunkIterator.new(text, true, true)
	for _ in 0 .. 3 { gc_collect() }
	assert first.code_units == original
	assert second.code_units == utf16_code_units_for_line_box(second.view)
	assert second.view == 'אב Ć\nD'
	assert voidptr(first.code_units.data) != voidptr(second.code_units.data)
	mut old_chunks := []string{}
	for {
		chunk := first.next() or { break }
		old_chunks << chunk.view
	}
	assert old_chunks.join('') == 'A😀B'
}

fn test_rendered_unit_cache_rebuilds_after_first_letter_source_range_changes() {
	document := dom.Document.create(dom.url_about_blank())
	mut text := reusable_units_test_node(document, 'a😀bc', 'text-transform:uppercase')
	text.source_range_start_ = 1
	text.source_range_length_ = 2
	first := TextNodeChunkIterator.new(text, false, false)
	assert first.view == '😀'
	assert first.code_units.len == 2
	text.source_range_start_ = 3
	text.source_range_length_ = 2
	text.invalidate_text_for_rendering()
	assert text.cached_utf16_code_units_ == none
	second := TextNodeChunkIterator.new(text, false, false)
	gc_collect()
	assert second.view == 'BC'
	assert second.code_units == [u16(`B`), u16(`C`)]
	assert first.view == '😀'
	assert first.code_units == [u16(0xd83d), u16(0xde00)]
}
