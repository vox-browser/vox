// Copyright (c) 2026-present, the Ladybird developers
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the range-preserving DOM helpers in
// Editing/Internal/Algorithms.cpp.
module editing

import dom

struct PreservedEditingRange {
	range_ &dom.Range
	start  dom.BoundaryPoint
	end    dom.BoundaryPoint
}

fn append_preserved_range(mut preserved []PreservedEditingRange, range_ &dom.Range, document &dom.Document) {
	if range_.start_container().document() != document {
		return
	}
	for existing in preserved {
		if existing.range_ == range_ {
			return
		}
	}
	preserved << PreservedEditingRange{
		range_: range_
		start: range_.start()
		end: range_.end()
	}
}

fn adjust_boundary_after_preserving_move(boundary dom.BoundaryPoint, old_parent &dom.Node, old_index int, new_parent &dom.Node, new_index int) dom.BoundaryPoint {
	mut adjusted := boundary
	if adjusted.node == new_parent && adjusted.offset > new_index {
		adjusted.offset++
	}
	if old_parent != unsafe { nil } && adjusted.node == old_parent
		&& (adjusted.offset == old_index || adjusted.offset == old_index + 1) {
		adjusted.node = new_parent
		adjusted.offset = new_index + (adjusted.offset - old_index)
	}
	if old_parent != unsafe { nil } && adjusted.node == old_parent
		&& adjusted.offset > old_index + 1 {
		adjusted.offset--
	}
	return adjusted
}

// https://w3c.github.io/editing/docs/execCommand/#preserving-ranges
pub fn move_node_preserving_ranges(node &dom.Node, new_parent &dom.Node, new_index int) {
	document := node.document()
	mut preserved := []PreservedEditingRange{}
	if selection := document.get_selection() {
		if active := selection.range() {
			append_preserved_range(mut preserved, active, document)
		}
	}
	for range_ in MutationTrackedRange.ranges() {
		append_preserved_range(mut preserved, range_, document)
	}

	old_parent := node.parent() or { unsafe { &dom.Node(nil) } }
	old_index := node.index()
	if old_parent != unsafe { nil } {
		mut mutable_node := unsafe { &dom.Node(node) }
		mutable_node.remove(false)
	}

	new_next_sibling := new_parent.child_at_index(new_index)
	mut mutable_new_parent := unsafe { &dom.Node(new_parent) }
	mutable_new_parent.insert_before(node, new_next_sibling, false)

	for saved in preserved {
		start := adjust_boundary_after_preserving_move(saved.start, old_parent, old_index,
			new_parent, new_index)
		end := adjust_boundary_after_preserving_move(saved.end, old_parent, old_index,
			new_parent, new_index)
		mut range_ := unsafe { &dom.Range(saved.range_) }
		range_.set_start(start.node, start.offset) or { panic(err) }
		range_.set_end(end.node, end.offset) or { panic(err) }
	}
}

pub fn unwrap_node_preserving_ranges(node &dom.Node) {
	parent := node.parent() or { return }
	for node.first_child() != none {
		child := node.first_child() or { break }
		move_node_preserving_ranges(child, parent, node.index())
	}
	mut mutable_node := unsafe { &dom.Node(node) }
	mutable_node.remove(false)
}
