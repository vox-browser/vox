module layout

import dom
import html

fn unlaid_box(document &dom.Document, id string) &Node {
	element := document.get_element_by_id(id) or { panic('missing #${id}') }
	mirror := element.as_node().unsafe_layout_node() or { panic('missing layout for #${id}') }
	return unsafe { &Node(mirror.real_layout_handle()) }
}

fn unlaid_paint(document &dom.Document) string {
	return (document.record_display_list() or { panic('missing paint') }).dump()
}

// A flex container keeps an anonymous box for each whitespace-only text run
// between its items, which flex layout does not lay out. Under the same tree
// order such a box has no committed values at its index, which must not block
// the reuse of the subtrees around it.
fn test_whitespace_flex_runs_do_not_block_committed_subtree_reuse() {
	mut document := html.parse_document('<!doctype html><body><p id="changed" style="width:100px">first</p><section id="stable"><div id="row" style="display:flex"> <span>a</span> <svg width="8" height="8"></svg> <span>b</span> </div><p>tail</p></section></body>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	stable := unlaid_box(document, 'stable')
	row := unlaid_box(document, 'row')
	mut whitespace_runs := 0
	for child in row.children() {
		if child.is_anonymous() { whitespace_runs++ }
	}
	assert whitespace_runs > 0
	result := document_layout_result(document) or { panic('missing layout result') }
	assert !subtree_reuse_blocked(result.state, stable, stable)

	mut changed := document.get_element_by_id('changed') or { panic('changed') }
	changed.set_attribute_value('style', 'width:120px')
	document.update_layout(.debugging)
	assert voidptr(unlaid_box(document, 'stable')) == voidptr(stable)
	painted := unlaid_paint(document)
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert unlaid_paint(document) == painted

}
