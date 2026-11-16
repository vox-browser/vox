module dom

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
