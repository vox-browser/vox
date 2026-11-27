// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module dom

fn range_children_are_outside_flat_tree(node &Node) bool {
	if element := node.as_element() {
		if element.is_shadow_host() { return true }
	}
	return node.is_html_slot_element() && unsafe { &HTMLSlotElement(node) }.assigned_nodes_internal().len > 0
}

fn range_flat_tree_child_count_of_host_or_slot(node &Node) int {
	if node.is_html_slot_element() {
		return unsafe { &HTMLSlotElement(node) }.assigned_nodes_internal().len
	}
	element := node.as_element() or { return 0 }
	shadow := element.shadow_root() or { return 0 }
	return unsafe { &Node(shadow) }.child_count()
}

fn range_index_in_flat_tree(node &Node) ?int {
	if slot := node.assigned_slot_internal() {
		for index, assigned in slot.assigned_nodes_internal() {
			if voidptr(assigned) == voidptr(node) { return index }
		}
		return none
	}
	if parent := node.parent() {
		if range_children_are_outside_flat_tree(parent) { return none }
	}
	return node.index()
}

struct RangeFlatTreePosition {
	root &Node
	indices []int
}

fn range_flat_tree_position(point BoundaryPoint) ?RangeFlatTreePosition {
	mut indices := []int{}
	mut node := point.node
	if !range_children_are_outside_flat_tree(node) {
		indices << point.offset
	} else if point.offset == 0 {
		indices << 0
	} else if point.offset >= 0 && point.offset < node.children.len
		&& range_index_in_flat_tree(node.children[point.offset]) != none {
		node = node.children[point.offset]
	} else {
		indices << range_flat_tree_child_count_of_host_or_slot(node)
	}
	for {
		parent := node.flat_tree_parent() or { break }
		if !node.is_shadow_root() {
			indices << (range_index_in_flat_tree(node) or { return none })
		}
		node = parent
	}
	indices.reverse_in_place()
	return RangeFlatTreePosition{ root: node, indices: indices }
}

pub fn position_of_boundary_point_relative_to_other_boundary_point_in_flat_tree(a BoundaryPoint, b BoundaryPoint) ?RelativeBoundaryPointPosition {
	a_position := range_flat_tree_position(a) or { return none }
	b_position := range_flat_tree_position(b) or { return none }
	if voidptr(a_position.root) != voidptr(b_position.root) { return none }
	limit := if a_position.indices.len < b_position.indices.len { a_position.indices.len } else { b_position.indices.len }
	for index in 0 .. limit {
		if a_position.indices[index] != b_position.indices[index] {
			return if a_position.indices[index] < b_position.indices[index] { .before } else { .after }
		}
	}
	if a_position.indices.len == b_position.indices.len { return .equal }
	return if a_position.indices.len < b_position.indices.len { .before } else { .after }
}
