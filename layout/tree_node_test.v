module layout

import dom

fn tree_test_ptr_push[T](pointer &[]T, item T) {
	unsafe {
		mut items := *pointer
		items << item
		*pointer = items
	}
}

fn test_tree_node_mutation_and_tree_order() {
	document := dom.Document.create(dom.URL{'about:blank'})
	mut root := Node.new(document, none)
	first := Node.new(document, none)
	second := Node.new(document, none)
	grandchild := Node.new(document, none)
	root.append_child(first)
	root.append_child(second)
	mut mutable_first := unsafe { &Node(first) }
	mutable_first.append_child(grandchild)

	assert first.index() == 0
	assert second.index() == 1
	assert root.is_ancestor_of(grandchild)
	assert grandchild.is_descendant_of(root)
	assert first.is_before(second)
	assert second.is_following(first)
	assert layout_nodes_same(grandchild.previous_in_pre_order() or { panic('missing') }, first)
	assert layout_nodes_same(grandchild.next_in_pre_order(root) or { panic('missing') }, second)

	replacement := Node.new(document, none)
	root.replace_child(replacement, first)
	assert first.parent() == none
	assert first.index_in_parent_ == -1
	assert replacement.index() == 0
	assert layout_nodes_same(root.first_child() or { panic('missing') }, replacement)
	root.remove_child(second)
	assert second.parent() == none
	assert second.index_in_parent_ == -1

	prepended := Node.new(document, none)
	root.prepend_child(prepended)
	assert prepended.index() == 0
	assert replacement.index() == 1
}

fn test_tree_node_skip_children_traversal() {
	document := dom.Document.create(dom.URL{'about:blank'})
	mut root := Node.new(document, none)
	first := Node.new(document, none)
	second := Node.new(document, none)
	grandchild := Node.new(document, none)
	root.append_child(first)
	root.append_child(second)
	mut mutable_first := unsafe { &Node(first) }
	mutable_first.append_child(grandchild)

	mut visited := []&Node{}
	visited_ptr := &visited
	root.for_each_in_inclusive_subtree(fn [visited_ptr, first] (node &Node) dom.TraversalDecision {
		tree_test_ptr_push(visited_ptr, node)
		if layout_nodes_same(node, first) {
			return .skip_children_and_continue
		}
		return .@continue
	})
	assert visited.len == 3
	assert layout_nodes_same(visited[0], root)
	assert layout_nodes_same(visited[1], first)
	assert layout_nodes_same(visited[2], second)
}

fn test_tree_node_predicate_helpers_replace_cpp_type_templates() {
	document := dom.Document.create(dom.URL{'about:blank'})
	mut root := Node.new(document, none)
	first := Node.new(document, none)
	second := Node.new(document, none)
	grandchild := Node.new(document, none)
	root.append_child(first)
	root.append_child(second)
	mut mutable_first := unsafe { &Node(first) }
	mutable_first.is_box_ = true
	mutable_first.append_child(grandchild)
	mut mutable_grandchild := unsafe { &Node(grandchild) }
	mutable_grandchild.is_text_node_ = true
	is_box := fn (node &Node) bool {
		return node.is_box_
	}
	is_text := fn (node &Node) bool {
		return node.is_text_node_
	}
	assert layout_nodes_same(root.first_child_matching(is_box) or { panic('missing box') }, first)
	assert root.has_child_matching(is_box)
	assert second.has_preceding_node_matching(is_text)
	assert first.has_following_node_matching(is_text)
	assert layout_nodes_same(grandchild.first_ancestor_matching(is_box) or {
		panic('missing ancestor')
	}, first)
}
