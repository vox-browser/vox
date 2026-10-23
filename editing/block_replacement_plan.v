// Copyright (c) 2026-present, the Ladybird developers
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the initial block-insertion planning and list integration in
// Editing/ReplaceSelection.cpp.
module editing

import dom

pub enum BlockInsertionMode {
	split_destination
	insert_after_containing_block
	insert_at_internal_paragraph_boundary
	insert_inside_list_item
	insert_inside_empty_block
}

pub struct BlockReplacementPlan {
pub:
	selection_start_was_start_of_paragraph bool
	selection_end_was_end_of_paragraph     bool
	destination_is_list_item               bool
	fragment_begins_with_list              bool
	insertion_mode                         BlockInsertionMode = .split_destination
}

fn node_has_html_name(node &dom.Node, names []string) bool {
	element := node.as_element() or { return false }
	return element.is_html_element() && element.local_name() in names
}

fn begins_with_list_content(node &dom.Node) bool {
	if node_has_html_name(node, ['li', 'ul', 'ol']) {
		return true
	}
	first_child := node.first_child() or { return false }
	return node_has_html_name(first_child, ['ul', 'ol'])
}

fn are_same_list_type(first &dom.Node, second &dom.Node) bool {
	return (node_has_html_name(first, ['ul']) && node_has_html_name(second, ['ul']))
		|| (node_has_html_name(first, ['ol']) && node_has_html_name(second, ['ol']))
}

pub fn integrate_first_pasted_list(mut inserted_content InsertedContent, destination_block &dom.Node) {
	if !node_has_html_name(destination_block, ['li']) {
		return
	}
	destination_list := destination_block.parent() or { return }
	pasted_list := inserted_content.first_node() or { return }
	if !are_same_list_type(pasted_list, destination_list) || !pasted_list.has_children() {
		return
	}

	first_item := pasted_list.first_child() or { return }
	last_item := pasted_list.last_child() or { return }
	pasted_parent := pasted_list.parent() or { return }
	for pasted_list.first_child() != none {
		item := pasted_list.first_child() or { break }
		move_node_preserving_ranges(item, pasted_parent, pasted_list.index())
	}
	remove_node(pasted_list)
	inserted_content.did_replace_node_range(pasted_list, first_item, last_item)
}

fn has_mergeable_visible_children(node &dom.Node) bool {
	if node.child_count() == 1 {
		if first_child := node.first_child() {
			if is_html_break(first_child) {
				return false
			}
		}
	}
	return has_visible_children(node)
}

fn can_merge_paragraph_contents(node &dom.Node) bool {
	return is_non_list_single_line_container(node)
}

fn restore_trailing_break(block &dom.Node, trailing_break &dom.Node) {
	if last_child := block.last_child() {
		if voidptr(last_child) == voidptr(trailing_break) {
			return
		}
	}
	if trailing_break.parent() != none {
		move_node_preserving_ranges(trailing_break, block, block.child_count())
	} else {
		insert_node_before(trailing_break, block, none)
	}
}

pub fn make_block_replacement_plan(insertion_boundary dom.BoundaryPoint, destination_block &dom.Node, inserted_content &InsertedContent) BlockReplacementPlan {
	visible_insertion_position := VisiblePosition.create(destination_block.document(), insertion_boundary)
	start_was_start_of_paragraph := visible_insertion_position.is_start_of_paragraph()
	end_was_end_of_paragraph := visible_insertion_position.is_end_of_paragraph()
	start_was_start_of_block := visible_insertion_position.is_start_of_containing_block()
	end_was_end_of_block := visible_insertion_position.is_end_of_containing_block()
	destination_is_list_item := node_has_html_name(destination_block, ['li'])
	first_inserted := inserted_content.first_node() or {
		return BlockReplacementPlan{
			selection_start_was_start_of_paragraph: start_was_start_of_paragraph
			selection_end_was_end_of_paragraph: end_was_end_of_paragraph
			destination_is_list_item: destination_is_list_item
		}
	}
	fragment_begins_with_list := begins_with_list_content(first_inserted)
	mut insertion_mode := BlockInsertionMode.split_destination
	if destination_is_list_item && !fragment_begins_with_list {
		insertion_mode = .insert_inside_list_item
	} else if !destination_is_list_item && !has_mergeable_visible_children(destination_block) {
		insertion_mode = .insert_inside_empty_block
	} else if end_was_end_of_paragraph && end_was_end_of_block {
		insertion_mode = .insert_after_containing_block
	} else if (start_was_start_of_paragraph && !start_was_start_of_block)
		|| (end_was_end_of_paragraph && !end_was_end_of_block) {
		insertion_mode = .insert_at_internal_paragraph_boundary
	}
	return BlockReplacementPlan{
		selection_start_was_start_of_paragraph: start_was_start_of_paragraph
		selection_end_was_end_of_paragraph: end_was_end_of_paragraph
		destination_is_list_item: destination_is_list_item
		fragment_begins_with_list: fragment_begins_with_list
		insertion_mode: insertion_mode
	}
}

fn is_at_end_of(boundary dom.BoundaryPoint, ancestor &dom.Node) bool {
	if boundary.node.is_text() {
		text := unsafe { &dom.Text(boundary.node) }
		if boundary.offset != text.length_in_utf16_code_units() {
			return false
		}
	} else {
		for index := boundary.offset; index < boundary.node.child_count(); index++ {
			child := boundary.node.child_at_index(index) or { return false }
			if !is_html_break(child) {
				return false
			}
		}
	}

	mut node := boundary.node
	for voidptr(node) != voidptr(ancestor) {
		parent := node.parent() or { return false }
		mut sibling := node.next_sibling()
		for sibling != none {
			current := sibling or { break }
			if !is_html_break(current) {
				return false
			}
			sibling = current.next_sibling()
		}
		node = parent
	}
	return true
}

fn first_text_descendant(node &dom.Node) ?&dom.Text {
	if node.is_text() {
		return unsafe { &dom.Text(node) }
	}
	for child in node.children_as_vector() {
		if text := first_text_descendant(child) {
			return text
		}
	}
	return none
}

pub fn canonicalize_inserted_content_end(boundary dom.BoundaryPoint, fragment &ReplacementFragment, plan BlockReplacementPlan) dom.BoundaryPoint {
	if !fragment.has_interchange_newline_at_end() {
		return boundary
	}

	visible_end := VisiblePosition.create(boundary.node.document(), boundary)
	next := visible_end.next()
	end_position := visible_end.deep_equivalent()
	end_block := block_node_of_node(end_position.node)
	if block := end_block {
		if node_has_html_name(block, ['li']) {
			if next_position := next {
				next_equivalent := next_position.deep_equivalent()
				if next_block := block_node_of_node(next_equivalent.node) {
					if node_has_html_name(next_block, ['li']) && voidptr(next_block) != voidptr(block)
						&& optional_nodes_are_same(next_block.parent(), block.parent()) {
						return next_equivalent
					}
				}
			}
		}
	}
	if (plan.selection_end_was_end_of_paragraph || !visible_end.is_end_of_paragraph()
		|| next == none) && !visible_end.is_start_of_paragraph() {
		if block := end_block {
			if node_has_html_name(block, ['li']) {
				parent := block.parent() or { return boundary }
				new_list_item := boundary.node.document().create_element('li') or { return boundary }
				insert_node_before(new_list_item.as_node(), parent, block.next_sibling())
				return dom.BoundaryPoint{
					node: new_list_item.as_node()
					offset: 0
				}
			}
		}
	}

	mut traversal_start := boundary.node
	is_html_non_list_item := if element := boundary.node.as_element() {
		element.is_html_element() && element.local_name() != 'li'
	} else {
		false
	}
	is_empty_placeholder := boundary.offset == 0 && is_html_non_list_item
		&& (if first_child := boundary.node.first_child() {
		is_html_break(first_child)
	} else {
		false
	})
	if is_empty_placeholder && plan.selection_end_was_end_of_paragraph {
		return boundary
	}
	if !is_empty_placeholder {
		block := block_node_of_node(boundary.node) or { return boundary }
		if !is_at_end_of(boundary, block) {
			return boundary
		}
		traversal_start = block
	}

	mut ancestor := ?&dom.Node(traversal_start)
	for ancestor != none {
		current := ancestor or { break }
		if current.parent() == none || current.is_editing_host() {
			break
		}
		mut sibling := current.next_sibling()
		for sibling != none {
			candidate := sibling or { break }
			if text := first_text_descendant(candidate) {
				return dom.BoundaryPoint{
					node: text.as_node()
					offset: 0
				}
			}
			sibling = candidate.next_sibling()
		}
		ancestor = current.parent()
	}
	return boundary
}
