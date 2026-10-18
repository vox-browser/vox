module layout

import html
import dom

fn retained_visual_line_handle(document &dom.Document) &Node {
	return unsafe { &Node(document.get_element_by_id('stable') or { panic('missing stable') }.as_node().unsafe_layout_node() or { panic('missing layout') }.real_layout_handle()) }
}

fn test_retained_inline_visual_lines_preserve_caret_mapping_across_comment_changes() {
	mut document := html.parse_document('<!doctype html><div id="changed"></div><p id="stable" style="width:130px">office é 👨‍👩‍👧 text that wraps onto several lines</p>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	root := retained_visual_line_handle(document)
	text := root.first_child()?
	previous := document_layout_result(document)?
	cache := previous.state.inline_layouts_[u64(voidptr(root))] or { panic('missing cache') }
	assert u64(voidptr(text)) in cache.visual_lines_
	mut changed := document.get_element_by_id('changed')?
	changed.set_inner_html('<p>new preceding content</p>')!
	document.update_layout(.debugging)
	current := document_layout_result(document)?
	assert voidptr(current.state.inline_layouts_[u64(voidptr(root))]) == voidptr(cache)
	mut lines := collect_dom_visual_lines(text, current.state)
	assert lines == collect_uncached_dom_visual_lines(text, current.state)
	assert lines.len > 1 && lines[0].caret_stops.len > 1
	assert lines[0].caret_stops.data != cache.visual_lines_[u64(voidptr(text))][0].caret_stops.data
	lines[0] = dom.VisualLine{}
	assert collect_dom_visual_lines(text, current.state) == collect_uncached_dom_visual_lines(text, current.state)
	mut stable := document.get_element_by_id('stable')?
	stable.set_inner_html('changed text with different stops')!
	document.update_layout(.debugging)
	updated := document_layout_result(document)?
	new_text := retained_visual_line_handle(document).first_child()?
	assert collect_dom_visual_lines(new_text, updated.state) == collect_uncached_dom_visual_lines(new_text, updated.state)
}
