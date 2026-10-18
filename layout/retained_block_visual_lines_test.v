module layout

import dom
import html

fn block_visual_test_node(document &dom.Document, id string) &Node {
	element := document.get_element_by_id(id) or { panic('missing element') }
	return unsafe { &Node(element.as_node().unsafe_layout_node() or { panic('missing layout') }.real_layout_handle()) }
}

fn block_visual_assert_fresh(document &dom.Document) {
	state := document_layout_result(document) or { panic('missing result') }.state
	mut nodes := [block_visual_test_node(document, 'stable')]
	mut count := 0
	for nodes.len > 0 {
		node := nodes.pop()
		nodes << node.children()
		if !node.is_text_node() { continue }
		assert collect_dom_visual_lines(node, state) == collect_uncached_dom_visual_lines(node, state)
		count++
	}
	assert count >= 3
}

fn test_retained_block_visual_lines_keep_carets_after_atomic_inlines_and_owner_reindexing() {
	mut document := html.parse_document('<!doctype html><div id="before"></div><section id="stable" style="display:flow-root;width:140px;white-space:pre-wrap"><p id="line">office <span style="display:inline-block;width:24px">box</span> é 👨‍👩‍👧 text that wraps\n onto several lines</p></section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 300)
	stable := block_visual_test_node(document, 'stable')
	line := block_visual_test_node(document, 'line')
	styled_line := line.as_node_with_style()?
	text := line.last_child()?
	previous := document_layout_result(document)?
	assert u64(voidptr(line)) !in previous.state.inline_layouts_
	cache := previous.state.block_layouts_[u64(voidptr(stable))] or { panic('missing independent block cache') }
	assert u64(voidptr(text)) in cache.visual_lines_
	original := copy_dom_visual_lines(cache.visual_lines_[u64(voidptr(text))], styled_line.layout_index())
	old_owner := styled_line.layout_index()
	mut before := document.get_element_by_id('before')?
	before.set_inner_html('<p>expanded</p><p><strong>preceding comment</strong></p>')!
	document.update_layout(.debugging)
	current := document_layout_result(document)?
	assert voidptr(current.state.block_layouts_[u64(voidptr(stable))]) == voidptr(cache)
	assert styled_line.layout_index() != old_owner
	block_visual_assert_fresh(document)
	mut lines := collect_dom_visual_lines(text, current.state)
	assert lines.len > 1 && lines[0].caret_stops.len > 1
	assert lines[0].owner_paintable == styled_line.layout_index()
	assert lines[0].caret_stops.data != cache.visual_lines_[u64(voidptr(text))][0].caret_stops.data
	mut stops := unsafe { lines[0].caret_stops }
	stops[0] = dom.VisualCaretStop{offset: -1}
	lines[0] = dom.VisualLine{}
	assert cache.visual_lines_[u64(voidptr(text))] == original
	block_visual_assert_fresh(document)
}

fn test_retained_block_visual_lines_invalidate_for_text_font_and_available_width_changes() {
	mut document := html.parse_document('<!doctype html><section id="stable" style="display:flow-root;width:140px"><p id="line">office <span style="display:inline-block">box</span> é text that wraps onto several lines</p></section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 300)
	mut stable := document.get_element_by_id('stable')?
	for style in ['display:flow-root;width:90px', 'display:flow-root;width:180px;font-size:22px', 'display:flow-root;width:140px;direction:rtl'] {
		stable.set_attribute_value('style', style)
		document.update_layout(.debugging)
		block_visual_assert_fresh(document)
	}
	mut line := document.get_element_by_id('line')?
	line.set_inner_html('changed <span style="display:inline-block">atomic</span> trailing é text')!
	document.update_layout(.debugging)
	block_visual_assert_fresh(document)
	current := (document.record_display_list()?).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	block_visual_assert_fresh(document)
	assert (document.record_display_list()?).dump() == current
}
