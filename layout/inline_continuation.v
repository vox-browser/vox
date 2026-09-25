// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module layout

import dom

fn clone_inline_node_as_continuation(node &Node, continuation_of &NodeWithStyleAndBoxModelMetrics) &Node {
	inline := node.as_inline_node() or { panic('inline continuation source is not InlineNode') }
	mut clone := unsafe {
		&Node(InlineNode.new(node.document(), node.dom_node(), inline.computed_values()))
	}
	clone.anonymous_ = node.anonymous_
	clone.generated_for_ = node.generated_for_
	clone.pseudo_element_generator_ = node.pseudo_element_generator_
	mut metrics := clone.as_node_with_style_and_box_model_metrics() or {
		panic('inline continuation has no box metrics')
	}
	metrics.continuation_of_node_ = continuation_of
	return clone
}

fn inline_part_is_block(part &Node) bool {
	return !part.is_inline()
}

// Return the inline segments and block children produced by splitting one
// inline subtree around in-flow block descendants.
fn split_inline_around_blocks(mut inline_node Node) ([]&Node, bool) {
	original_children := inline_node.children_.clone()
	inline_node.replace_children([]&Node{})
	mut output := []&Node{}
	mut current := unsafe { &Node(inline_node) }
	mut current_is_active := true
	mut previous_metrics := current.as_node_with_style_and_box_model_metrics() or {
		return [current], false
	}
	mut found_block := false
	for child in original_children {
		mut child_parts := [child]
		mut child_had_block := false
		if child.is_inline_node() {
			mut mutable_child := unsafe { &Node(child) }
			child_parts, child_had_block = split_inline_around_blocks(mut mutable_child)
		}
		for part in child_parts {
			if inline_part_is_block(part) {
				// Upstream calls should_create_inline_continuation() while inserting
				// each node. This port repairs the completed subtree, so out-of-flow
				// and generated pseudo boxes must still trigger restructuring here;
				// the caller below keeps them out of the middle wrapper.
				if !part.is_out_of_flow() && !part.is_generated_for_pseudo_element()
					&& !is_inline_flow_interrupting_block_with_parent(part, unsafe { &Node(inline_node) }) {
					current.append_child(part)
					continue
				}
				found_block = true
				if current_is_active {
					output << current
					current_is_active = false
				}
				output << part
			} else {
				if !current_is_active {
					current = clone_inline_node_as_continuation(inline_node, previous_metrics)
					previous_metrics = current.as_node_with_style_and_box_model_metrics() or {
						previous_metrics
					}
					current_is_active = true
				}
				current.append_child(part)
			}
		}
		if child_had_block {
			found_block = true
		}
	}
	if found_block {
		if current_is_active {
			output << current
		}
		return output, true
	}
	return [unsafe { &Node(inline_node) }], false
}

fn fixup_inline_continuations(mut node Node, document &dom.Document) {
	for child in node.children_.clone() {
		mut mutable_child := unsafe { &Node(child) }
		fixup_inline_continuations(mut mutable_child, document)
	}
	if !node.is_block_container() || !node.children_are_inline() {
		return
	}
	mut parts := []&Node{}
	mut found_block := false
	for child in node.children_.clone() {
		if child.is_inline_node() {
			mut mutable_child := unsafe { &Node(child) }
			child_parts, child_had_block := split_inline_around_blocks(mut mutable_child)
			if child_had_block {
				found_block = true
				for index, part in child_parts {
					if !inline_part_is_block(part) {
						parts << part
						continue
					}
					// A block-level pseudo-element is inserted into the nearest non-inline
					// ancestor by TreeBuilder::insert_node_into_inline_or_block_ancestor;
					// it is already the anonymous block visible in the layout tree and
					// must not acquire an additional continuation wrapper here.
					if part.is_out_of_flow() || part.is_generated_for_pseudo_element() {
						parts << part
						continue
					}
					mut middle := create_anonymous_block_wrapper(document, node.computed_values())
					middle.set_children_are_inline(false)
					if index > 0 {
						if previous_metrics := child_parts[index - 1].as_node_with_style_and_box_model_metrics() {
							if mut middle_metrics := middle.as_node_with_style_and_box_model_metrics() {
								middle_metrics.continuation_of_node_ = previous_metrics
							}
						}
					}
					middle.append_child(part)
					parts << middle
					if index + 1 < child_parts.len {
						if mut next_metrics := child_parts[index + 1].as_node_with_style_and_box_model_metrics() {
							if middle_metrics := middle.as_node_with_style_and_box_model_metrics() {
								next_metrics.continuation_of_node_ = middle_metrics
							}
						}
					}
				}
			} else {
				parts << child_parts
			}
		} else {
			parts << child
		}
	}
	if !found_block {
		return
	}
	// An anonymous inline wrapper is only an insertion aid. When a block is
	// found inside one of its inline descendants, upstream restructures at the
	// nearest non-anonymous block ancestor, making the before/middle/after
	// wrappers siblings there rather than nesting the whole continuation chain
	// inside the original wrapper.
	if node.is_anonymous() {
		if parent_node := node.parent() {
			if parent_node.is_block_container() {
				mut expanded := []&Node{}
				for sibling in parent_node.children_.clone() {
					if layout_nodes_same(sibling, unsafe { &Node(node) }) {
						expanded << parts
					} else {
						expanded << sibling
					}
				}
				mut parent := unsafe { &Node(parent_node) }
				parent.replace_children([]&Node{})
				parent_style := parent.as_node_with_style() or { return }
				attach_children_maintaining_inline_invariant(mut parent, expanded, document,
					parent_style.computed_values())
				return
			}
		}
	}
	node.replace_children([]&Node{})
	parent_style := node.as_node_with_style() or { return }
	attach_children_maintaining_inline_invariant(mut node, parts, document,
		parent_style.computed_values())
}
