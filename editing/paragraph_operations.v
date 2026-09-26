// Copyright (c) 2026-present, the Ladybird developers
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Editing/ParagraphOperations.{h,cpp}.
module editing

import dom

fn boundary_outside_text(boundary dom.BoundaryPoint) dom.BoundaryPoint {
	if !boundary.node.is_text() {
		return boundary
	}
	text := unsafe { &dom.Text(boundary.node) }
	parent := text.as_node().parent() or { return boundary }
	if boundary.offset == 0 {
		return dom.BoundaryPoint{
			node: parent
			offset: text.as_node().index()
		}
	}
	if boundary.offset == text.length_in_utf16_code_units() {
		return dom.BoundaryPoint{
			node: parent
			offset: text.as_node().index() + 1
		}
	}
	right_text := split_text(text, boundary.offset) or { panic(err) }
	return dom.BoundaryPoint{
		node: parent
		offset: right_text.as_node().index()
	}
}

pub fn split_inline_ancestors_at_boundary(boundary_ dom.BoundaryPoint, containing_block &dom.Node) dom.BoundaryPoint {
	assert boundary_.node == containing_block || containing_block.is_ancestor_of(boundary_.node)
	mut boundary := boundary_outside_text(boundary_)

	for boundary.node != containing_block {
		container := boundary.node
		mut parent := container.parent() or { panic('inline container has no parent') }
		if boundary.offset == 0 {
			boundary = dom.BoundaryPoint{
				node: parent
				offset: container.index()
			}
			continue
		}
		if boundary.offset == container.child_count() {
			boundary = dom.BoundaryPoint{
				node: parent
				offset: container.index() + 1
			}
			continue
		}

		container_clone := clone_node_for_editing(container, false) or { panic(err) }
		insert_node_before(container_clone, parent, container.next_sibling())
		for boundary.offset < container.child_count() {
			child := container.child_at_index(boundary.offset) or { break }
			move_node_preserving_ranges(child, container_clone, container_clone.child_count())
		}
		boundary = dom.BoundaryPoint{
			node: parent
			offset: container_clone.index()
		}
	}
	return boundary
}

pub fn split_containing_block_at_boundary(boundary dom.BoundaryPoint, containing_block &dom.Node) &dom.Node {
	block_boundary := split_inline_ancestors_at_boundary(boundary, containing_block)
	right_block := clone_node_for_editing(containing_block, false) or { panic(err) }
	parent := containing_block.parent() or { panic('containing block has no parent') }
	insert_node_before(right_block, parent, containing_block.next_sibling())
	for block_boundary.offset < containing_block.child_count() {
		child := containing_block.child_at_index(block_boundary.offset) or { break }
		move_node_preserving_ranges(child, right_block, right_block.child_count())
	}
	return right_block
}
