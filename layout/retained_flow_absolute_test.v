module layout

import dom
import html

// VOX_RETAINED_FLOW_ABSOLUTE retains absolutely positioned boxes of block
// parents in the validated flow salvage below a flagged ancestor.
fn testsuite_begin() {
	clean_subtree_reuse_suspended = true
}

fn flow_absolute_document(markup string) &dom.Document {
	address := dom.URL{value: 'https://absolute-tree.example/'}
	return html.parse_navigation_document(markup, address, address.origin(), none) or { panic(err) }
}

fn flow_absolute_handle(document &dom.Document, id string) voidptr {
	element := document.get_element_by_id(id) or { panic('element') }
	mirror := element.as_node().unsafe_layout_node() or { panic('layout') }
	return mirror.real_layout_handle()
}

fn flow_absolute_mutate_sibling(mut document dom.Document, text string) {
	mut changed := document.get_element_by_id('changed') or { panic('changed') }
	changed.set_inner_html('<p>${text}</p>') or { panic(err) }
	document.update_layout(.debugging)
}

fn flow_absolute_full_oracle(mut document dom.Document) {
	before := (document.record_display_list() or { panic('paint') }).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list() or { panic('full paint') }).dump() == before
}

fn test_absolute_boxes_of_block_parents_keep_identity_and_resolve_fresh_geometry() {
	defer { retained_flow_absolute_for_test = false }
	for enabled in [false, true] {
		retained_flow_absolute_for_test = enabled
		for rules in ['position:relative', '', 'position:relative;display:flex', 'position:relative;display:grid'] {
			mut document := flow_absolute_document('<!doctype html><div id="changed"></div><section id="stable" style="${rules}"><div id="badge" style="position:absolute;top:3px;right:4px;width:20px;height:10px;background:red">x</div><p>Stable caption</p><div><span id="tip" style="position:absolute;left:2px;bottom:1px;background:blue">tip</span></div></section>')
			_ = layout_document_typed_in_viewport(document, 400, 300)
			for round in 0 .. 2 {
				stable := flow_absolute_handle(document, 'stable')
				badge := flow_absolute_handle(document, 'badge')
				flow_absolute_mutate_sibling(mut document, 'Changed sibling ${round} with more text')
				assert (flow_absolute_handle(document, 'stable') == stable) == enabled, '${enabled} ${rules}'
				assert (flow_absolute_handle(document, 'badge') == badge) == enabled, '${enabled} ${rules}'
				assert document.layout_is_up_to_date()
				flow_absolute_full_oracle(mut document)
			}
			// A different containing block width moves the right-anchored badge.
			mut stable := document.get_element_by_id('stable') or { panic('stable') }
			stable.set_attribute_value('style', '${rules};width:240px')
			document.update_layout(.debugging)
			flow_absolute_full_oracle(mut document)
			document.finalize()
		}
	}
}

fn test_absolute_boxes_of_inline_parents_are_rebuilt() {
	defer { retained_flow_absolute_for_test = false }
	retained_flow_absolute_for_test = true
	mut document := flow_absolute_document('<!doctype html><div id="changed"></div><p id="stable" style="position:relative">Lead <span>inline <b id="badge" style="position:absolute;top:0;left:0">x</b> text</span></p>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	stable := flow_absolute_handle(document, 'stable')
	flow_absolute_mutate_sibling(mut document, 'Changed sibling')
	assert flow_absolute_handle(document, 'stable') != stable
	flow_absolute_full_oracle(mut document)
}

fn test_fixed_boxes_are_rebuilt() {
	defer { retained_flow_absolute_for_test = false }
	retained_flow_absolute_for_test = true
	mut document := flow_absolute_document('<!doctype html><div id="changed"></div><section id="stable"><div style="position:fixed;top:1px;left:1px">fixed</div><p>Caption</p></section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	stable := flow_absolute_handle(document, 'stable')
	flow_absolute_mutate_sibling(mut document, 'Changed sibling')
	assert flow_absolute_handle(document, 'stable') != stable
	flow_absolute_full_oracle(mut document)
}
