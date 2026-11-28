module layout

import html
import os

fn in_place_tree_order_ranges_nest(node &Node) {
	mut next := node.tree_order_start_ + 1
	for child in node.children() {
		assert voidptr(child.tree_order_) == voidptr(node.tree_order_)
		assert child.tree_order_owner_ == voidptr(child)
		assert child.tree_order_start_ == next
		in_place_tree_order_ranges_nest(child)
		next = child.tree_order_end_
	}
	assert next == node.tree_order_end_
}

// An in-place update renumbers the kept tree's order object instead of
// leaving it invalid, so the attachment index, ancestor tests and intrinsic
// seed visits keep their constant-time paths, and new boxes get ranges.
fn test_in_place_updates_keep_the_tree_order_valid() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}</style><body><div id="app"><div id="a">a</div></div><p>tail</p></body>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	first := document_layout_result(document) or { panic('layout') }
	order := first.root.tree_order_
	assert order != unsafe { nil } && order.valid
	updated_before, _ := in_place_tree_update_statistics()
	mut app := document.get_element_by_id('app') or { panic('app') }
	mut added := document.create_element('div') or { panic(err) }
	added.set_attribute_value('id', 'b')
	mut app_node := app.as_node()
	app_node.append_child(added.as_node()) or { panic(err) }
	document.update_layout(.debugging)
	if os.getenv('VOX_DISABLE_IN_PLACE_TREE_UPDATE') != '' { return }
	updated_after, _ := in_place_tree_update_statistics()
	assert updated_after == updated_before + 1
	root := (document_layout_result(document) or { panic('layout') }).root
	assert voidptr(root) == voidptr(first.root)
	assert voidptr(root.tree_order_) == voidptr(order)
	assert root.tree_order_.valid
	in_place_tree_order_ranges_nest(root)
	b := document.get_element_by_id('b') or { panic('b') }
	box := in_place_box_of(b.as_node()) or { panic('no box for b') }
	assert root.is_ancestor_of(box)
	app_box := in_place_box_of(app.as_node()) or { panic('no box for app') }
	assert app_box.is_ancestor_of(box)
	assert app_box.tree_order_start_ < box.tree_order_start_
	assert box.tree_order_end_ <= app_box.tree_order_end_
}
