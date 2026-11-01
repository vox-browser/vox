module layout

import html

fn test_rejected_block_probe_avoids_rewalking_the_same_unsupported_branch() {
	mut document := html.parse_document('<!doctype html><section id="root" style="overflow:hidden;width:200px"><div><p>Ordinary text before a grid.</p><div style="display:grid">Grid content.</div></div></section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	element := document.get_element_by_id('root')?
	root := unsafe { &Node(element.as_node().unsafe_layout_node()?.real_layout_handle()) }
	mut rejected := map[u64]bool{}
	mut first := []RetainedInlineInput{}
	assert !collect_retained_block_inputs(root, mut first, mut rejected)
	assert first.len > 0 && rejected[u64(voidptr(root))]
	mut second := []RetainedInlineInput{}
	assert !collect_retained_block_inputs(root, mut second, mut rejected)
	assert second.len == 0
	assert (document_layout_result(document) or { panic('missing layout') }).state.block_layout_rejections_.len == 0
}

fn test_new_layout_reconsiders_a_branch_that_becomes_eligible() {
	mut document := html.parse_document('<!doctype html><section id="root" style="overflow:hidden;width:200px"><div id="changed" style="display:grid">Previously specialized content.</div></section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	mut changed := document.get_element_by_id('changed')?
	changed.set_attribute_value('style', 'display:block')
	document.update_layout(.debugging)
	element := document.get_element_by_id('root')?
	root := unsafe { &Node(element.as_node().unsafe_layout_node()?.real_layout_handle()) }
	result := document_layout_result(document) or { panic('missing layout') }
	assert u64(voidptr(root)) in result.state.block_layouts_
	assert result.state.block_layout_rejections_.len == 0
	before := (document.record_display_list() or { panic('missing paint') }).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list() or { panic('missing rebuilt paint') }).dump() == before
}
