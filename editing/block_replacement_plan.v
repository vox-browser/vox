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

fn same_list_type(first &dom.Node, second &dom.Node) bool {
	return (node_has_html_name(first, ['ul']) && node_has_html_name(second, ['ul']))
		|| (node_has_html_name(first, ['ol']) && node_has_html_name(second, ['ol']))
}

pub fn integrate_first_pasted_list(mut inserted_content InsertedContent, destination_block &dom.Node) {
	if !node_has_html_name(destination_block, ['li']) {
		return
	}
	destination_list := destination_block.parent() or { return }
	pasted_list := inserted_content.first_node() or { return }
	if !same_list_type(pasted_list, destination_list) || !pasted_list.has_children() {
		return
	}

	first_item := pasted_list.first_child() or { return }
	last_item := pasted_list.last_child() or { return }
	pasted_parent := pasted_list.parent() or { return }
	for pasted_list.first_child() != none {
		item := pasted_list.first_child() or { break }
		move_node_preserving_ranges(item, pasted_parent, pasted_list.index())
	}
	mut mutable_pasted_list := unsafe { &dom.Node(pasted_list) }
	mutable_pasted_list.remove(false)
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
	return has_dom_visible_children(node)
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
