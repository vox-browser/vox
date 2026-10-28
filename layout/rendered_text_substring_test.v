module layout

import css
import dom
import html

fn verify_rendered_text_range_cache(node &TextNode, value string) {
	assert node.text_for_rendering() == value
	units := utf16_code_units_for_line_box(value)
	for start in -2 .. units.len + 3 {
		for length in -2 .. units.len + 3 {
			assert node.rendered_substring_for_line_box(start, length) ==
				utf16_substring_for_line_box(value, start, length)
		}
	}
}

fn test_rendered_text_ranges_use_the_same_utf16_boundaries_with_and_without_cache() {
	for value in ['', 'AV To Wa', 'aé “quoted”', 'Тест', 'a\u0301', 'A😀B', '👩‍💻',
		[ u8(0xff), `a`, 0xc3 ].bytestr()] {
		mut node := &TextNode{
			text_for_rendering_: value
			text_for_rendering_valid_: true
			rendered_text_is_ascii_: value.is_ascii()
		}
		verify_rendered_text_range_cache(node, value)
		units := utf16_code_units_for_line_box(value)
		node.cached_utf16_code_units_ = units.clone()
		verify_rendered_text_range_cache(node, value)
		assert node.cached_utf16_code_units_ or { panic('lost units') } == units
	}
}

fn test_rendered_text_range_cache_follows_transforms_source_ranges_and_invalidation() {
	mut document := html.parse_document('<!doctype html><p id="target" style="text-transform:uppercase">aß😀bc</p>')
	defer { document.finalize() }
	target := document.get_element_by_id('target') or { panic('missing target') }
	style := css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(target, none))
	mut parent := BlockContainer.new(document, none, style)
	mut node := TextNode.new_generated(document, 'aß😀bc')
	parent.append_child(unsafe { &Node(node) })
	for range in [[0, 6], [1, 1], [1, 3], [4, 2], [2, 2], [0, 0], [0, 6]] {
		node.source_range_start_ = range[0]
		node.source_range_length_ = range[1]
		node.invalidate_text_for_rendering()
		assert node.cached_utf16_code_units_ == none
		value := node.text_for_rendering()
		verify_rendered_text_range_cache(node, value)
		node.cached_utf16_code_units_ = utf16_code_units_for_line_box(value)
		verify_rendered_text_range_cache(node, value)
	}
}
