module page

import css
import dom

fn caret_test_layout(node &dom.Node, rect dom.Rect) &dom.LayoutNode {
	layout_node := &dom.LayoutNode{
		dom_node_: node
		has_geometry_: true
		border_box_: rect
		paintables_: [&dom.Paintable{}]
	}
	mut mutable_node := unsafe { &dom.Node(node) }
	mutable_node.set_layout_node(layout_node)
	return layout_node
}

fn caret_test_append(parent &dom.Node, child &dom.Node) ! {
	mut mutable_parent := unsafe { &dom.Node(parent) }
	mutable_parent.append_child(child)!
}

fn caret_test_recompute_editability(root &dom.Node) {
	mut mutable_root := unsafe { &dom.Node(root) }
	mutable_root.recompute_editable_subtree_flag()
	for child in root.children_as_vector() {
		caret_test_recompute_editability(child)
	}
}

fn test_associated_descendant_editing_host_finds_editable_ancestor_and_unique_overlapping_host() {
	mut document := dom.Document.create_for_fragment_parsing()
	mut root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	mut host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	host.set_attribute_value('contenteditable', 'true')
	mut editable := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span')!
	caret_test_append(host.as_node(), editable.as_node())!
	caret_test_append(root.as_node(), host.as_node())!
	mut hit := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	caret_test_append(root.as_node(), hit.as_node())!
	caret_test_recompute_editability(root.as_node())
	assert voidptr(associated_descendant_editing_host(editable.as_node())?) == voidptr(host.as_node())

	caret_test_layout(hit.as_node(), dom.Rect{ x: 10, y: 10, width: 20, height: 20 })
	caret_test_layout(host.as_node(), dom.Rect{ x: 0, y: 0, width: 40, height: 40 })
	assert voidptr(associated_descendant_editing_host(hit.as_node())?) == voidptr(host.as_node())

	mut second_host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	second_host.set_attribute_value('contenteditable', 'true')
	caret_test_append(root.as_node(), second_host.as_node())!
	caret_test_recompute_editability(root.as_node())
	assert associated_descendant_editing_host(hit.as_node()) == none
}

fn test_first_editable_leaf_and_caret_fallback_use_committed_layout() {
	mut document := dom.Document.create_for_fragment_parsing()
	mut host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	host.set_attribute_value('contenteditable', 'true')
	mut wrapper := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span')!
	mut text := document.create_text_node('editable')
	caret_test_append(host.as_node(), wrapper.as_node())!
	caret_test_append(wrapper.as_node(), text.as_node())!
	caret_test_recompute_editability(host.as_node())
	assert host.as_node().is_editing_host()
	assert wrapper.as_node().is_editable()
	assert text.as_node().is_editable()
	leaf := first_editable_leaf_descendant(host.as_node()) or { panic('missing editable leaf') }
	assert voidptr(leaf) == voidptr(text.as_node())
	caret_test_layout(text.as_node(), dom.Rect{ width: 30, height: 10 })
	position := caret_position_from_editable_hit_node(text.as_node()) or { panic('missing caret') }
	assert voidptr(position.boundary.node) == voidptr(text.as_node())
	assert position.boundary.offset == 0
	assert !should_use_caret_position_from_editable_hit_node(position, text.as_node(), host.as_node())

	outside := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	assert should_use_caret_position_from_editable_hit_node(position, outside.as_node(), host.as_node())
}

fn test_caret_position_uses_hit_layout_when_editing_host_has_no_committed_box() {
	mut document := dom.Document.create_for_fragment_parsing()
	mut root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	mut host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	host.set_attribute_value('contenteditable', 'true')
	caret_test_append(root.as_node(), host.as_node())!
	caret_test_recompute_editability(root.as_node())
	caret_test_layout(root.as_node(), dom.Rect{ width: 50, height: 20 })
	position := caret_position_from_editable_hit_node(root.as_node()) or { panic('missing fallback caret') }
	assert voidptr(position.boundary.node) == voidptr(host.as_node())
	assert user_select_used_value_for_caret_position(position) == css.UserSelect.contain
}
