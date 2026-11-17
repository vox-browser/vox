module dom

import platform

fn test_collection_walk_matches_callback_adapter_in_tree_order_and_scope() {
	doc := Document.create(url_about_blank())
	mut root := doc.create_element('div')!
	mut parent := root.as_node()
	a := doc.create_element('span')!
	mut a_node := a.as_node()
	a_node.append_child(doc.create_element('b')!.as_node())!
	parent.append_child(a_node)!
	parent.append_child(doc.create_text_node('text').as_node())!
	parent.append_child(doc.create_element('i')!.as_node())!
	for scope in [CollectionScope.children, .descendants] {
		set_direct_collection_walk_for_testing(false)
		control := collect_elements_for_scope(parent, scope, fn (e &Element) bool { return true })
		set_direct_collection_walk_for_testing(true)
		candidate := collect_elements_for_scope(parent, scope, fn (e &Element) bool { return true })
		assert candidate.len == control.len
		for index, element in candidate { assert voidptr(element) == voidptr(control[index]) }
		assert candidate.len == if scope == .children { 2 } else { 3 }
	}
}

fn test_node_list_reads_keep_snapshots_independent_without_copying_on_each_read() {
	doc := Document.create(url_about_blank())
	mut parent := doc.create_element('div')!.as_node()
	first := doc.create_text_node('first').as_node()
	second := doc.create_element('span')!.as_node()
	parent.append_child(first)!
	parent.append_child(second)!
	live := parent.child_nodes()
	saved := StaticNodeList.create(parent.children_as_vector())
	filtered := LiveNodeList.create(parent, .children, fn (node &Node) bool { return node.is_element() })
	mut copy := live.collection()
	copy[0] = second
	assert voidptr(live.item(0)?) == voidptr(first)
	assert filtered.length() == 1 && voidptr(filtered.item(0)?) == voidptr(second)
	mut workspace := platform.new_arena('node list reads')
	entry := workspace.enter()
	before := workspace.usage().used
	for _ in 0 .. 64 {
		assert live.length() == 2 && saved.length() == 2
		assert voidptr(live.item(1)?) == voidptr(second)
		assert voidptr(saved.item(0)?) == voidptr(first)
	}
	after := workspace.usage().used
	workspace.leave(entry)
	workspace.release()
	$if prealloc { assert after == before }
	parent.remove_child(first)!
	assert live.length() == 1 && voidptr(live.item(0)?) == voidptr(second)
	assert saved.length() == 2 && voidptr(saved.item(0)?) == voidptr(first)
}
