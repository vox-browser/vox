// Copyright (c) 2026-present, the Ladybird developers
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Editing/InlineInsertion.{h,cpp}.
module editing

import dom

pub struct InlineInsertionBoundary {
pub:
	boundary                dom.BoundaryPoint
	split_destination_style bool
}

pub fn prepare_inline_insertion_boundary(boundary_ dom.BoundaryPoint, containing_block &dom.Node) InlineInsertionBoundary {
	assert boundary_.node == containing_block || containing_block.is_ancestor_of(boundary_.node)
	mut boundary := boundary_

	for boundary.node != containing_block {
		if boundary.offset != boundary.node.length() || boundary.node.parent() == none {
			break
		}
		node := boundary.node
		mut parent := node.parent() or { break }
		boundary = dom.BoundaryPoint{
			node: parent
			offset: node.index() + 1
		}
	}

	mut highest_styled_inline_ancestor := unsafe { &dom.Node(nil) }
	mut ancestor := ?&dom.Node(boundary.node)
	for ancestor != none {
		current := ancestor or { break }
		if current == containing_block {
			break
		}
		if element := current.as_element() {
			if element.is_html_element() && element.local_name() in ['li', 'ul', 'ol'] {
				return InlineInsertionBoundary{
					boundary: boundary
				}
			}
		}
		if is_inline_node(current) && is_modifiable_element(current) {
			highest_styled_inline_ancestor = current
		}
		ancestor = current.parent()
	}
	if highest_styled_inline_ancestor == unsafe { nil }
		|| highest_styled_inline_ancestor.parent() == none {
		return InlineInsertionBoundary{
			boundary: boundary
		}
	}

	parent := highest_styled_inline_ancestor.parent() or {
		return InlineInsertionBoundary{
			boundary: boundary
		}
	}
	return InlineInsertionBoundary{
		boundary: split_inline_ancestors_at_boundary(boundary, parent)
		split_destination_style: true
	}
}
