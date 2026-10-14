module layout

import css
import dom

fn tree_order_walk_is_ancestor(ancestor &Node, node &Node) bool {
	mut current := node.parent()
	for {
		parent := current or { return false }
		if layout_nodes_same(ancestor, parent) {
			return true
		}
		current = parent.parent()
	}
	return false
}

fn tree_order_assert_matches_walk(nodes []&Node) {
	for ancestor in nodes {
		for node in nodes {
			assert ancestor.is_ancestor_of(node) == tree_order_walk_is_ancestor(ancestor, node)
			assert ancestor.is_inclusive_ancestor_of(node) == (layout_nodes_same(ancestor, node)
				|| tree_order_walk_is_ancestor(ancestor, node))
		}
	}
}

fn test_tree_order_ranges_match_parent_identity_for_all_pairs() {
	document := dom.Document.create(dom.url_about_blank())
	mut nodes := []&Node{}
	for _ in 0 .. 128 {
		nodes << Node.new(document, none)
	}
	for index in 1 .. nodes.len {
		mut parent := nodes[(index - 1) / 2]
		parent.append_child(nodes[index])
	}
	assert assign_layout_indexes(nodes[0]) == 0
	assert nodes[0].tree_order_.valid
	assert nodes[0].tree_order_end_ == 128
	tree_order_assert_matches_walk(nodes)
}

fn test_tree_order_mutations_fall_back_until_reindexed() {
	document := dom.Document.create(dom.url_about_blank())
	mut root := Node.new(document, none)
	mut branch := Node.new(document, none)
	leaf := Node.new(document, none)
	root.append_child(branch)
	branch.append_child(leaf)
	mut nodes := [root, branch, leaf]
	for operation in 0 .. 4 {
		assign_layout_indexes(root)
		assert root.tree_order_.valid
		child := Node.new(document, none)
		nodes << child
		match operation {
			0 { branch.append_child(child) }
			1 { branch.prepend_child(child) }
			2 { branch.insert_before(child, leaf) }
			else { branch.insert_before(child, none) }
		}
		assert !root.tree_order_.valid
		tree_order_assert_matches_walk(nodes)
	}
	assign_layout_indexes(root)
	branch.remove_child(leaf)
	assert !root.tree_order_.valid
	assert !root.is_ancestor_of(leaf)
	tree_order_assert_matches_walk(nodes)
	assign_layout_indexes(root)
	branch.remove()
	assert !root.tree_order_.valid
	assert !root.is_ancestor_of(nodes[3])
	tree_order_assert_matches_walk(nodes)
	assign_layout_indexes(root)
	assign_layout_indexes(branch)
	tree_order_assert_matches_walk(nodes)
}

fn test_tree_order_replacements_invalidate_removed_and_inserted_subtrees() {
	document := dom.Document.create(dom.url_about_blank())
	mut root := Node.new(document, none)
	mut old := Node.new(document, none)
	old_leaf := Node.new(document, none)
	old.append_child(old_leaf)
	root.append_child(old)
	mut replacement := Node.new(document, none)
	new_leaf := Node.new(document, none)
	replacement.append_child(new_leaf)
	assign_layout_indexes(root)
	assign_layout_indexes(replacement)
	root.replace_child(replacement, old)
	assert !root.tree_order_.valid
	assert !replacement.tree_order_.valid
	assert !root.is_ancestor_of(old_leaf)
	assert root.is_ancestor_of(new_leaf)
	tree_order_assert_matches_walk([root, old, old_leaf, replacement, new_leaf])
	assign_layout_indexes(root)
	assign_layout_indexes(old)
	root.replace_children([old])
	assert !root.tree_order_.valid
	assert !old.tree_order_.valid
	assert root.is_ancestor_of(old_leaf)
	assert !root.is_ancestor_of(new_leaf)
	tree_order_assert_matches_walk([root, old, old_leaf, replacement, new_leaf])
}

fn test_tree_order_cross_tree_moves_and_equal_ranges_keep_distinct_identity() {
	document := dom.Document.create(dom.url_about_blank())
	mut first := Node.new(document, none)
	mut second := Node.new(document, none)
	mut branch := Node.new(document, none)
	leaf := Node.new(document, none)
	branch.append_child(leaf)
	first.append_child(branch)
	other := Node.new(document, none)
	second.append_child(other)
	assign_layout_indexes(first)
	assign_layout_indexes(second)
	assert first.tree_order_start_ == second.tree_order_start_
	assert voidptr(first.tree_order_) != voidptr(second.tree_order_)
	tree_order_assert_matches_walk([first, second, branch, leaf, other])
	branch.remove()
	second.append_child(branch)
	assert !first.tree_order_.valid
	assert !second.tree_order_.valid
	assert !first.is_ancestor_of(leaf)
	assert second.is_ancestor_of(leaf)
	tree_order_assert_matches_walk([first, second, branch, leaf, other])
	assign_layout_indexes(first)
	assign_layout_indexes(second)
	tree_order_assert_matches_walk([first, second, branch, leaf, other])
}

fn test_tree_order_partial_reindex_invalidates_enclosing_ranges() {
	document := dom.Document.create(dom.url_about_blank())
	mut root := Node.new(document, none)
	mut branch := Node.new(document, none)
	leaf := Node.new(document, none)
	root.append_child(branch)
	branch.append_child(leaf)
	assign_layout_indexes(root)
	assign_layout_indexes(branch)
	assert !root.tree_order_.valid
	assert branch.tree_order_.valid
	assert voidptr(root.tree_order_) != voidptr(branch.tree_order_)
	tree_order_assert_matches_walk([root, branch, leaf])
	assign_layout_indexes(root)
	assert root.tree_order_.valid
	assert voidptr(root.tree_order_) == voidptr(leaf.tree_order_)
	tree_order_assert_matches_walk([root, branch, leaf])
}

fn test_tree_order_copied_nodes_keep_parent_walk_identity() {
	document := dom.Document.create(dom.url_about_blank())
	mut root := Node.new(document, none)
	mut branch := Node.new(document, none)
	leaf := Node.new(document, none)
	root.append_child(branch)
	branch.append_child(leaf)
	assign_layout_indexes(root)
	mut copied_root := *root
	mut copied_branch := *branch
	mut copied_leaf := *leaf
	assert !copied_root.is_ancestor_of(leaf)
	assert !copied_branch.is_ancestor_of(leaf)
	assert root.is_ancestor_of(&copied_leaf)
	assert branch.is_ancestor_of(&copied_leaf)
	tree_order_assert_matches_walk([root, branch, leaf, &copied_root, &copied_branch, &copied_leaf])
}

fn test_tree_order_includes_unstyled_nodes_without_consuming_geometry_indices() {
	document := dom.Document.create(dom.url_about_blank())
	style := css.ComputedProperties.new()
	mut root := NodeWithStyle.new(document, none, style)
	mut unstyled := Node.new(document, none)
	child := NodeWithStyle.new(document, none, style)
	root.append_child(unstyled)
	unstyled.append_child(unsafe { &Node(child) })
	assert assign_layout_indexes(unsafe { &Node(root) }) == 2
	assert root.layout_index() == 0
	assert child.layout_index() == 1
	assert root.tree_order_start_ == 0
	assert unstyled.tree_order_start_ == 1
	assert child.tree_order_start_ == 2
	tree_order_assert_matches_walk([unsafe { &Node(root) }, unstyled, unsafe { &Node(child) }])
}

@[noinline]
fn tree_order_make_retained_tree() &Node {
	document := dom.Document.create(dom.url_about_blank())
	mut root := Node.new(document, none)
	mut child := Node.new(document, none)
	child.append_child(Node.new(document, none))
	root.append_child(child)
	assign_layout_indexes(root)
	return root
}

fn test_tree_order_metadata_survives_collection_with_retained_tree() {
	root := tree_order_make_retained_tree()
	for _ in 0 .. 3 {
		$if gcboehm ? {
			C.GC_gcollect()
		}
	}
	child := root.first_child() or { panic('missing child') }
	leaf := child.first_child() or { panic('missing leaf') }
	assert root.tree_order_.valid
	tree_order_assert_matches_walk([root, child, leaf])
}
