module layout

import dom
import html

$if gcboehm ? {
	fn C.GC_gcollect()
}

fn lazy_visual_dom_text(document &dom.Document) &dom.Text {
	element := document.get_element_by_id('text') or { panic('missing text owner') }
	node := element.as_node().first_child() or { panic('missing text') }
	assert node.is_text()
	return unsafe { &dom.Text(node) }
}

fn test_committed_text_defers_caret_projection_until_requested_and_resets_after_relayout() {
	mut document := html.parse_document('<!doctype html><div id="before"></div><section><p id="text" style="width:100px">office é 👨‍👩‍👧 text that wraps onto several lines</p>' + '<p>Unqueried paragraph <strong>text</strong>.</p>'.repeat(80) + '</section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 300)
	mut nodes := [document_layout_result(document)?.root]
	mut deferred := 0
	for nodes.len > 0 {
		node := nodes.pop()
		nodes << node.children()
		if !node.is_text_node() { continue }
		assert node.dom_layout_node_.visual_lines_callback != unsafe { nil }
		assert node.dom_layout_node_.cached_visual_lines().len == 0
		deferred++
	}
	assert deferred > 160
	text := lazy_visual_dom_text(document)
	mirror := text.as_node().layout_node()?
	typed := unsafe { &Node(mirror.real_layout_handle()) }
	lines := dom.collect_visual_lines(text)
	assert lines == collect_dom_text_visual_lines(typed, document_layout_result(document)?.state)
	assert lines.len > 1 && lines[0].caret_stops.len > 1
	assert mirror.visual_lines_callback == unsafe { nil }
	storage := mirror.visual_lines().data
	assert mirror.visual_lines().data == storage
	old := lines.str()
	mut before := document.get_element_by_id('before')?
	before.set_inner_html('<p>expanded preceding comment</p>')!
	document.update_layout(.debugging)
	assert voidptr(text.as_node().layout_node()?) == voidptr(mirror)
	assert mirror.visual_lines_callback != unsafe { nil }
	assert mirror.cached_visual_lines().len == 0
	current := dom.collect_visual_lines(text)
	assert current == collect_dom_text_visual_lines(typed, document_layout_result(document)?.state)
	assert lines.str() == old
	assert current[0].caret_stops.data != lines[0].caret_stops.data
	assert dom.compute_cursor_position_on_next_line(text, 0, .downstream) != none
}

fn test_explicit_dom_attachment_with_a_state_keeps_its_eager_projection() {
	mut document := html.parse_document('<!doctype html><p id="text" style="width:100px">Text that wraps onto more than one line.</p>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	result := document_layout_result(document)?
	_ = attach_layout_nodes_with_state(result.root, result.state)
	text := lazy_visual_dom_text(document)
	mirror := text.as_node().layout_node()?
	assert mirror.visual_lines_callback == unsafe { nil }
	assert mirror.cached_visual_lines().len > 1
	assert dom.collect_visual_lines(text) == collect_dom_text_visual_lines(unsafe { &Node(mirror.real_layout_handle()) }, result.state)
}

fn test_unmaterialized_old_text_mirror_keeps_its_committed_geometry_after_a_full_rebuild_and_collection() {
	mut document := html.parse_document('<!doctype html><p id="text" style="width:180px">office é text that wraps onto several lines with a long trailing sentence.</p>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 300)
	text := lazy_visual_dom_text(document)
	old := text.as_node().layout_node()?
	assert old.visual_lines_callback != unsafe { nil }
	expected := collect_dom_text_visual_lines(unsafe { &Node(old.real_layout_handle()) }, document_layout_result(document)?.state)
	mut element := document.get_element_by_id('text')?
	element.set_attribute_value('style', 'width:60px')
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	current := text.as_node().layout_node()?
	assert voidptr(current) != voidptr(old)
	$if gcboehm ? { C.GC_gcollect() }
	assert old.visual_lines() == expected
	assert dom.collect_visual_lines(text).len > expected.len
}
