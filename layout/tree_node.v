// Copyright (c) 2018-2022, Andreas Kling <andreas@ladybird.org>
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the remaining Libraries/LibWeb/TreeNode.h operations for the
// array-backed Layout::Node tree.
module layout

import dom

// One shared validity flag lets every child mutation invalidate a tree's
// preorder ranges in constant work. Geometry indices still count styled nodes
// only; these ranges include text and other unstyled nodes as well.
@[heap]
struct LayoutTreeOrder {
mut:
	valid      bool
	next_index u32
}

fn (n &Node) invalidate_tree_order() {
	if n.tree_order_ != unsafe { nil } {
		mut order := unsafe { &LayoutTreeOrder(n.tree_order_) }
		order.valid = false
	}
}

pub fn (n &Node) index() int {
	return if n.parent_ == none { 0 } else { n.index_in_parent_ }
}

pub fn (n &Node) root() &Node {
	mut root := unsafe { &Node(n) }
	for {
		root = root.parent() or { break }
	}
	return root
}

pub fn (n &Node) is_ancestor_of(other &Node) bool {
	order := n.tree_order_
	if order != unsafe { nil } && order.valid
		&& voidptr(order) == voidptr(other.tree_order_)
		&& n.tree_order_owner_ == voidptr(n) && other.tree_order_owner_ == voidptr(other) {
		// A copied Node carries its old range too. Check physical ownership so
		// value copies keep the same pointer-identity semantics as a parent walk.
		return n.tree_order_start_ < other.tree_order_start_
			&& other.tree_order_start_ < n.tree_order_end_
	}
	mut ancestor := other.parent()
	for {
		candidate := ancestor or { return false }
		if layout_nodes_same(candidate, n) {
			return true
		}
		ancestor = candidate.parent()
	}
	return false
}

pub fn (n &Node) is_inclusive_ancestor_of(other &Node) bool {
	return layout_nodes_same(n, other) || n.is_ancestor_of(other)
}

pub fn (n &Node) is_descendant_of(other &Node) bool {
	return other.is_ancestor_of(n)
}

pub fn (n &Node) is_inclusive_descendant_of(other &Node) bool {
	return other.is_inclusive_ancestor_of(n)
}

pub fn (n &Node) contains(other ?&Node) bool {
	target := other or { return false }
	return n.is_inclusive_ancestor_of(target)
}

pub fn (n &Node) is_parent_of(other &Node) bool {
	parent := other.parent() or { return false }
	return layout_nodes_same(n, parent)
}

// C++ TreeNode's *_of_type templates become predicate-based helpers in V,
// where the layout hierarchy uses discriminant flags instead of RTTI.
pub fn (n &Node) has_preceding_node_matching(predicate fn (&Node) bool) bool {
	mut current := n.previous_in_pre_order()
	for {
		candidate := current or { return false }
		if predicate(candidate) {
			return true
		}
		current = candidate.previous_in_pre_order()
	}
	return false
}

pub fn (n &Node) has_following_node_matching(predicate fn (&Node) bool) bool {
	mut current := n.next_in_pre_order(none)
	for {
		candidate := current or { return false }
		if predicate(candidate) {
			return true
		}
		current = candidate.next_in_pre_order(none)
	}
	return false
}

pub fn (mut n Node) prepend_child(child &Node) {
	assert child.parent() == none
	n.invalidate_tree_order()
	child.invalidate_tree_order()
	mut mutable_child := unsafe { &Node(child) }
	mutable_child.parent_ = &n
	n.children_.prepend(child)
	for index, current in n.children_ {
		mut mutable_current := unsafe { &Node(current) }
		mutable_current.index_in_parent_ = index
	}
}

pub fn (mut n Node) insert_before(child &Node, reference ?&Node) {
	if reference_node := reference {
		assert child.parent() == none
		assert reference_node.parent() != none
		assert layout_nodes_same(reference_node.parent() or { return }, &n)
		n.invalidate_tree_order()
		child.invalidate_tree_order()
		mut mutable_child := unsafe { &Node(child) }
		mutable_child.parent_ = &n
		index := reference_node.index()
		n.children_.insert(index, child)
		for child_index := index; child_index < n.children_.len; child_index++ {
			mut current := unsafe { &Node(n.children_[child_index]) }
			current.index_in_parent_ = child_index
		}
		return
	}
	n.append_child(child)
}

pub fn (mut n Node) remove_child(child &Node) {
	parent := child.parent() or { panic('layout child has no parent') }
	assert layout_nodes_same(parent, &n)
	index := child.index()
	n.invalidate_tree_order()
	child.invalidate_tree_order()
	n.children_.delete(index)
	mut mutable_child := unsafe { &Node(child) }
	mutable_child.parent_ = none
	mutable_child.index_in_parent_ = -1
	for child_index := index; child_index < n.children_.len; child_index++ {
		mut current := unsafe { &Node(n.children_[child_index]) }
		current.index_in_parent_ = child_index
	}
}

pub fn (mut n Node) replace_child(new_child &Node, old_child &Node) {
	assert !layout_nodes_same(new_child, old_child)
	assert new_child.parent() == none
	parent := old_child.parent() or { panic('layout child has no parent') }
	assert layout_nodes_same(parent, &n)
	index := old_child.index()
	n.invalidate_tree_order()
	new_child.invalidate_tree_order()
	old_child.invalidate_tree_order()
	n.children_[index] = new_child
	mut mutable_new_child := unsafe { &Node(new_child) }
	mutable_new_child.parent_ = &n
	mutable_new_child.index_in_parent_ = index
	mut mutable_old_child := unsafe { &Node(old_child) }
	mutable_old_child.parent_ = none
	mutable_old_child.index_in_parent_ = -1
}

pub fn (mut n Node) remove() {
	mut parent := unsafe { &Node(n.parent() or { panic('layout node has no parent') }) }
	parent.remove_child(&n)
}

pub fn (n &Node) child_at_index(index int) ?&Node {
	if index < 0 || index >= n.children_.len {
		return none
	}
	return n.children_[index]
}

pub fn (n &Node) next_in_pre_order(stay_within ?&Node) ?&Node {
	if first := n.first_child() {
		return first
	}
	mut current := unsafe { &Node(n) }
	for {
		if boundary := stay_within {
			if layout_nodes_same(current, boundary) {
				return none
			}
		}
		if sibling := current.next_sibling() {
			return sibling
		}
		current = current.parent() or { return none }
	}
	return none
}

pub fn (n &Node) previous_in_pre_order() ?&Node {
	if previous := n.previous_sibling() {
		mut candidate := unsafe { &Node(previous) }
		for {
			candidate = candidate.last_child() or { break }
		}
		return candidate
	}
	return n.parent()
}

pub fn (n &Node) is_following(other &Node) bool {
	return other.is_before(n)
}

pub fn (n &Node) is_before(other &Node) bool {
	if layout_nodes_same(n, other) {
		return false
	}
	// Compare the ancestor chains instead of scanning the preorder distance
	// between the nodes. Tree depth bounds this work even for distant nodes.
	mut my_chain := []&Node{cap: 32}
	mut current := ?&Node(n)
	for {
		candidate := current or { break }
		my_chain << candidate
		current = candidate.parent()
	}
	mut other_chain := []&Node{cap: 32}
	current = other
	for {
		candidate := current or { break }
		other_chain << candidate
		current = candidate.parent()
	}
	if !layout_nodes_same(my_chain.last(), other_chain.last()) {
		return false
	}
	mut my_depth := my_chain.len
	mut other_depth := other_chain.len
	for my_depth > 0 && other_depth > 0
		&& layout_nodes_same(my_chain[my_depth - 1], other_chain[other_depth - 1]) {
		my_depth--
		other_depth--
	}
	if my_depth == 0 {
		return true
	}
	if other_depth == 0 {
		return false
	}
	mut sibling := my_chain[my_depth - 1].next_sibling()
	for {
		candidate := sibling or { return false }
		if layout_nodes_same(candidate, other_chain[other_depth - 1]) {
			return true
		}
		sibling = candidate.next_sibling()
	}
	return false
}

pub fn (n &Node) for_each_in_inclusive_subtree(callback fn (&Node) dom.TraversalDecision) dom.TraversalDecision {
	decision := callback(n)
	if decision == .@break {
		return .@break
	}
	if decision == .skip_children_and_continue {
		return .@continue
	}
	return n.for_each_in_subtree(callback)
}

pub fn (n &Node) for_each_in_subtree(callback fn (&Node) dom.TraversalDecision) dom.TraversalDecision {
	for child in n.children_ {
		if child.for_each_in_inclusive_subtree(callback) == .@break {
			return .@break
		}
	}
	return .@continue
}

pub fn (n &Node) for_each_in_inclusive_subtree_matching(predicate fn (&Node) bool, callback fn (&Node) dom.TraversalDecision) dom.TraversalDecision {
	return n.for_each_in_inclusive_subtree(fn [predicate, callback] (node &Node) dom.TraversalDecision {
		if predicate(node) {
			return callback(node)
		}
		return .@continue
	})
}

pub fn (n &Node) for_each_in_subtree_matching(predicate fn (&Node) bool, callback fn (&Node) dom.TraversalDecision) dom.TraversalDecision {
	return n.for_each_in_subtree(fn [predicate, callback] (node &Node) dom.TraversalDecision {
		if predicate(node) {
			return callback(node)
		}
		return .@continue
	})
}

pub fn (n &Node) for_each_child(callback fn (&Node) bool) {
	for child in n.children_ {
		if !callback(child) {
			return
		}
	}
}

pub fn (n &Node) for_each_child_matching(predicate fn (&Node) bool, callback fn (&Node) bool) {
	for child in n.children_ {
		if predicate(child) && !callback(child) {
			return
		}
	}
}

pub fn (n &Node) next_sibling_matching(predicate fn (&Node) bool) ?&Node {
	mut sibling := n.next_sibling()
	for {
		candidate := sibling or { return none }
		if predicate(candidate) {
			return candidate
		}
		sibling = candidate.next_sibling()
	}
	return none
}

pub fn (n &Node) previous_sibling_matching(predicate fn (&Node) bool) ?&Node {
	mut sibling := n.previous_sibling()
	for {
		candidate := sibling or { return none }
		if predicate(candidate) {
			return candidate
		}
		sibling = candidate.previous_sibling()
	}
	return none
}

pub fn (n &Node) first_child_matching(predicate fn (&Node) bool) ?&Node {
	for child in n.children_ {
		if predicate(child) {
			return child
		}
	}
	return none
}

pub fn (n &Node) last_child_matching(predicate fn (&Node) bool) ?&Node {
	for index := n.children_.len - 1; index >= 0; index-- {
		if predicate(n.children_[index]) {
			return n.children_[index]
		}
	}
	return none
}

pub fn (n &Node) has_child_matching(predicate fn (&Node) bool) bool {
	return n.first_child_matching(predicate) != none
}

pub fn (n &Node) first_ancestor_matching(predicate fn (&Node) bool) ?&Node {
	mut ancestor := n.parent()
	for {
		candidate := ancestor or { return none }
		if predicate(candidate) {
			return candidate
		}
		ancestor = candidate.parent()
	}
	return none
}

pub fn (n &Node) for_each_ancestor(callback fn (&Node) bool) {
	mut ancestor := n.parent()
	for {
		candidate := ancestor or { return }
		if !callback(candidate) {
			return
		}
		ancestor = candidate.parent()
	}
}

pub fn (n &Node) for_each_inclusive_ancestor(callback fn (&Node) bool) {
	mut ancestor := ?&Node(n)
	for {
		candidate := ancestor or { return }
		if !callback(candidate) {
			return
		}
		ancestor = candidate.parent()
	}
}

pub fn (n &Node) for_each_inclusive_ancestor_matching(predicate fn (&Node) bool, callback fn (&Node) bool) {
	mut ancestor := ?&Node(n)
	for {
		candidate := ancestor or { return }
		if predicate(candidate) && !callback(candidate) {
			return
		}
		ancestor = candidate.parent()
	}
}
