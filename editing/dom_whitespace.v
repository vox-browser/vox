// Copyright (c) 2026-present, the Ladybird developers
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the DOM whitespace canonicalization used after node
// insertion in Editing/Internal/Algorithms.cpp.
module editing

import css
import dom

enum DOMWhitespaceAtomicTraversal {
	cross
	stop
}

fn dom_nodes_share_editing_host(first &dom.Node, second &dom.Node) bool {
	first_host := first.editing_host() or { return false }
	second_host := second.editing_host() or { return false }
	return first_host == second_host
}

fn dom_follows_line_break(node &dom.Node) bool {
	return VisiblePosition.create(node.document(), dom.BoundaryPoint{
		node: node
		offset: 0
	}).is_start_of_paragraph()
}

fn dom_precedes_line_break(node &dom.Node) bool {
	return VisiblePosition.create(node.document(), dom.BoundaryPoint{
		node: node
		offset: node.length()
	}).is_end_of_paragraph()
}

fn dom_parent_preserves_whitespace(node &dom.Node) bool {
	parent := node.parent() or { return false }
	element := parent.as_element() or { return false }
	return css.computed_value_for(element, .white_space_collapse) or { '' } == 'preserve'
}

fn dom_whitespace_code_unit(text &dom.Text, offset int) ?rune {
	return utf16_character_at(text, offset)
}

fn is_canonicalizable_dom_space(character rune) bool {
	return character == ` ` || character == `\u00a0`
}

fn canonicalize_dom_whitespace_after_insertion(boundary dom.BoundaryPoint, atomic_traversal DOMWhitespaceAtomicTraversal) {
	if !boundary.node.is_editable_or_editing_host() {
		return
	}

	mut start_node := boundary.node
	mut start_offset := boundary.offset
	for {
		if child := start_node.child_at_index(start_offset - 1) {
			if dom_nodes_share_editing_host(start_node, child) {
				if atomic_traversal == .stop && editing_ignores_content(child) {
					break
				}
				start_node = child
				start_offset = child.length()
				continue
			}
		}
		if start_offset == 0 && !dom_follows_line_break(start_node) {
			if parent := start_node.parent() {
				if dom_nodes_share_editing_host(start_node, parent) {
					start_offset = start_node.index()
					start_node = parent
					continue
				}
			}
		}
		if start_node.is_text() && start_offset > 0
			&& !dom_parent_preserves_whitespace(start_node) {
			text := unsafe { &dom.Text(start_node) }
			if character := dom_whitespace_code_unit(text, start_offset - 1) {
				if is_canonicalizable_dom_space(character) {
					start_offset--
					continue
				}
			}
		}
		break
	}

	mut end_node := start_node
	mut end_offset := start_offset
	mut whitespace_length := 0
	for {
		if child := end_node.child_at_index(end_offset) {
			if dom_nodes_share_editing_host(end_node, child) {
				if atomic_traversal == .stop && editing_ignores_content(child) {
					break
				}
				end_node = child
				end_offset = 0
				continue
			}
		}
		if end_offset == end_node.length() && !dom_precedes_line_break(end_node) {
			if parent := end_node.parent() {
				if dom_nodes_share_editing_host(end_node, parent) {
					end_offset = end_node.index() + 1
					end_node = parent
					continue
				}
			}
		}
		if end_node.is_text() && end_offset != end_node.length()
			&& !dom_parent_preserves_whitespace(end_node) {
			text := unsafe { &dom.Text(end_node) }
			if character := dom_whitespace_code_unit(text, end_offset) {
				if is_canonicalizable_dom_space(character) {
					end_offset++
					whitespace_length++
					continue
				}
			}
		}
		break
	}

	non_breaking_start := (start_offset == 0 && dom_follows_line_break(start_node))
		|| start_node != end_node
	replacement := canonical_space_sequence(whitespace_length,
		non_breaking_start || whitespace_length > 1,
		end_offset == end_node.length() && dom_precedes_line_break(end_node)).runes()
	mut replacement_offset := 0
	for {
		relative_position := dom.position_of_boundary_point_relative_to_other_boundary_point(dom.BoundaryPoint{
			node: start_node
			offset: start_offset
		}, dom.BoundaryPoint{
			node: end_node
			offset: end_offset
		})
		if relative_position != .before {
			break
		}
		if child := start_node.child_at_index(start_offset) {
			start_node = child
			start_offset = 0
			continue
		}
		if !start_node.is_text() || start_offset == start_node.length() {
			parent := start_node.parent() or { break }
			start_offset = start_node.index() + 1
			start_node = parent
			continue
		}

		text := unsafe { &dom.Text(start_node) }
		current := dom_whitespace_code_unit(text, start_offset) or { break }
		if replacement_offset >= replacement.len {
			break
		}
		replacement_character := replacement[replacement_offset]
		replacement_offset++
		if current != replacement_character {
			mut mutable_text := unsafe { &dom.Text(text) }
			mutable_text.insert_data(start_offset, replacement_character.str()) or { panic(err) }
			mutable_text.delete_data(start_offset + 1, 1) or { panic(err) }
		}
		start_offset++
	}
}

pub fn canonicalize_dom_whitespace_after_node_insertion(boundary dom.BoundaryPoint) {
	canonicalize_dom_whitespace_after_insertion(boundary, .stop)
}
