module layout

import dom
import html

fn attachment_selection_assert_tree(document &dom.Document) {
	result := document_layout_result(document) or { panic('missing layout') }
	result.root.for_each_in_inclusive_subtree(fn (node &Node) dom.TraversalDecision {
		mirror := node.dom_layout_node_
		assert mirror != unsafe { nil }
		if mirror.user_select_none_ != (node.user_select_used_value() == .none_) {
			eprintln('selection mismatch: ${node.debug_description()} computed=${node.computed_values().user_select()} used=${node.user_select_used_value()} attached_none=${mirror.user_select_none_}')
		}
		assert mirror.user_select_none_ == (node.user_select_used_value() == .none_)
		return .@continue
	})
}

fn test_attachment_resolves_selection_once_in_tree_order_and_observes_later_style_and_editability() {
	mut document := html.parse_document('<!doctype html><style>#outer::before{content:"before"}#outer::after{content:"after"}</style><section id="outer" style="user-select:none"><div><p id="text">Inherited selection <strong>nested</strong></p><p style="user-select:text">Explicit text</p><div id="editor" contenteditable="true"><span>Editable text</span></div><input id="control"><textarea>Mutable</textarea><input readonly></div></section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	attachment_selection_assert_tree(document)
	mut outer := document.get_element_by_id('outer')?
	for style in ['user-select:all', 'user-select:text', 'user-select:none'] {
		outer.set_attribute_value('style', style)
		document.set_needs_full_layout_tree_update(true)
		document.update_layout(.debugging)
		attachment_selection_assert_tree(document)
	}
	mut editor := document.get_element_by_id('editor')?
	editor.set_attribute_value('contenteditable', 'false')
	mut control := document.get_element_by_id('control')?
	control.set_attribute_value('readonly', '')
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	attachment_selection_assert_tree(document)
}

fn test_attachment_of_a_subtree_still_resolves_its_existing_layout_parent_selection() {
	mut document := html.parse_document('<!doctype html><section style="user-select:none"><p id="subtree">Inherited <span>selection</span></p></section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	element := document.get_element_by_id('subtree')?
	node := unsafe { &Node(element.as_node().unsafe_layout_node()?.real_layout_handle()) }
	attached := attach_layout_nodes(node)
	assert attached.user_select_none_
	assert attached.children_.len > 0
	for child in attached.children_ {
		assert child.user_select_none_
	}
}
