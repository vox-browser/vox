module layout

import css
import dom
import html
import platform

fn test_rendered_length_cache_tracks_expanding_transforms_and_source_range_changes() {
	mut document := html.parse_document('<!doctype html><p id="target" style="text-transform:uppercase">aß😀bc</p>')
	defer { document.finalize() }
	target := document.get_element_by_id('target') or { panic('missing target') }
	style := css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(target, none))
	parent := BlockContainer.new(document, none, style)
	mut text := TextNode.new_generated(document, 'aß😀bc')
	mut parent_node := unsafe { &Node(parent) }
	parent_node.append_child(unsafe { &Node(text) })
	text.source_range_start_ = 1
	text.source_range_length_ = 3
	for _ in 0 .. 4 {
		assert text.rendered_utf16_length() == 4
		assert text.text_for_rendering() == 'SS😀'
		assert text.source_offset_for_rendered_text_offset(1, .start) == 1
		assert text.source_offset_for_rendered_text_offset(1, .end) == 2
		assert text.source_offset_for_rendered_text_offset(99, .end) == 4
		assert text.rendered_text_offset_for_source_offset(99, .end) == 4
	}
	text.source_range_start_ = 4
	text.source_range_length_ = 2
	text.invalidate_text_for_rendering()
	assert text.rendered_text_offset_for_source_offset(99, .end) == 2
	assert text.text_for_rendering() == 'BC'
	assert text.source_offset_for_rendered_text_offset(99, .end) == 6
}

fn test_rendered_length_cache_refreshes_from_live_dom_text_without_a_geometry_pass() {
	mut document := html.parse_document('<!doctype html><p id="target">A😀B</p>')
	defer { document.finalize() }
	result := run_document_layout(document, 300, 100) or { panic('missing layout') }
	assert result.root.is_viewport()
	target := document.get_element_by_id('target') or { panic('missing target') }
	mut source := (target.first_child() or { panic('missing text') }).as_character_data() or { panic('not text') }
	bridge := source.layout_node() or { panic('missing boundary') }
	text := unsafe { &TextNode(bridge.layout_handle) }
	for value in ['é', '👩‍💻', '', 'long ASCII text', 'a\u0301'] {
		source.set_data(value)
		expected := utf16_code_units_for_line_box(value).len
		for boundary in [platform.TextMappingBoundary.start, .end] {
			assert text.source_offset_for_rendered_text_offset(999, boundary) == expected
			assert text.rendered_text_offset_for_source_offset(999, boundary) == expected
		}
		assert text.text_for_rendering() == value
	}
}
