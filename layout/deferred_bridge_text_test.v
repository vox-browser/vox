module layout

import dom
import html

fn test_initial_bridge_keeps_structure_and_ordinals_without_collecting_text_chunks() {
	mut document := html.parse_document('<!doctype html><div id="host">  a   b  </div><ol start="4"><li id="first">one</li><li id="second">two</li></ol>')
	defer { document.finalize() }
	root := build_layout_tree(document) or { panic('missing layout tree') }
	_ = attach_layout_nodes_before_layout(root)
	host := document.get_element_by_id('host') or { panic('missing host') }
	text := host.as_node().first_child() or { panic('missing text') }
	initial := text.layout_node() or { panic('missing initial text association') }
	host_layout := host.as_node().layout_node() or { panic('missing initial host association') }
	assert initial.is_text_node()
	assert voidptr(initial.parent() or { panic('missing text parent') }) == voidptr(host_layout)
	assert initial.containing_block() != none
	assert initial.rendered_text_ == '  a   b  '
	assert initial.rendered_text_chunks().len == 0
	text_node := unsafe { &Node(initial.layout_handle) }.as_text_node() or { panic('missing typed text') }
	assert text_node.cached_utf16_code_units_ == none
	mut first := document.get_element_by_id('first') or { panic('missing first item') }
	mut second := document.get_element_by_id('second') or { panic('missing second item') }
	assert first.ordinal_value() == 4
	assert second.ordinal_value() == 5
	// The public no-state attachment retains its ordinary text-collection API.
	_ = attach_layout_nodes(root)
	complete := text.layout_node() or { panic('missing complete text association') }
	assert complete.rendered_text_chunks().join('') == ' a b '
	// Completed text collection also leaves shaping-only UTF-16 data lazy.
	assert text_node.cached_utf16_code_units_ == none
}

fn test_final_bridge_keeps_first_letter_inner_text_range_geometry_and_caret_stops() {
	mut document := html.parse_document('<!doctype html><style>html,body,p{margin:0}p{font:16px/20px SerenityMono}p::first-letter{font-size:24px}</style><p id="host" contenteditable>Abc</p>')
	defer { document.finalize() }
	_ = run_document_layout(document, 200, 100) or { panic('missing layout') }
	host := document.get_element_by_id('host') or { panic('missing host') }
	text := host.as_node().first_child() or { panic('missing text') }
	assert html.html_element_inner_text(unsafe { &dom.HTMLElement(host) }) == 'Abc'
	committed := text.layout_node() or { panic('missing committed text') }
	assert committed.rendered_text_ == 'Abc'
	assert committed.rendered_text_chunks().join('') == 'Abc'
	mut caret_offsets := []int{}
	for line in committed.visual_lines() {
		for stop in line.caret_stops { caret_offsets << stop.offset }
	}
	assert 0 in caret_offsets
	assert 1 in caret_offsets
	assert 3 in caret_offsets
	range := dom.Range.create_from_boundary_points(text, 0, text, 3)
	rects := range.get_client_rects()
	assert rects.length() > 0
	assert (rects.item(0) or { panic('missing glyph rect') }).height > 0
	position := dom.compute_cursor_position_on_next_character(unsafe { &dom.Text(text) }, 1,
		.downstream) or { panic('missing next-character caret') }
	assert position.offset == 2
}

fn test_final_bridge_refreshes_inner_text_search_and_geometry_after_live_mutation() {
	mut document := html.parse_document('<!doctype html><div id="host">A  B</div>')
	defer { document.finalize() }
	_ = run_document_layout(document, 200, 100) or { panic('missing layout') }
	mut host := document.get_element_by_id('host') or { panic('missing host') }
	mut text := host.as_node().first_child() or { panic('missing text') }
	assert html.html_element_inner_text(unsafe { &dom.HTMLElement(host) }) == 'A B'
	previous := text.layout_node() or { panic('missing previous text layout') }
	text.set_text_content('C   D') or { panic(err) }
	assert previous.needs_layout_update()
	assert html.html_element_inner_text(unsafe { &dom.HTMLElement(host) }) == 'C D'
	updated := text.layout_node() or { panic('missing updated text layout') }
	assert updated.rendered_text_chunks().join('') == 'C D'
	assert document.find_matching_text('C D', .case_sensitive).len == 1
	host.set_attribute_value('style', 'white-space:pre')
	assert html.html_element_inner_text(unsafe { &dom.HTMLElement(host) }) == 'C   D'
	latest := text.layout_node() or { panic('missing preserved-whitespace text layout') }
	assert latest.rendered_text_chunks().join('') == 'C   D'
	assert latest.visual_lines().len > 0
	range := dom.Range.create_from_boundary_points(text, 0, text, 5)
	assert range.get_client_rects().length() > 0
}
