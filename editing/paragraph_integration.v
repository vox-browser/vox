// Copyright (c) 2026-present, the Ladybird developers
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Editing/ParagraphIntegration.{h,cpp}.
module editing

import dom

pub struct ParagraphBoundaryState {
pub:
	selection_start_was_start_of_paragraph bool
	selection_end_was_end_of_paragraph     bool
}

pub struct ParagraphIntegrationDecision {
pub:
	merge_start bool
	merge_end   bool
}

pub struct ParagraphIntegration {
	document_         &dom.Document
	inserted_content_ &InsertedContent
	boundary_state_   ParagraphBoundaryState
}

pub fn ParagraphIntegration.new(document &dom.Document, inserted_content &InsertedContent, boundary_state ParagraphBoundaryState) ParagraphIntegration {
	return ParagraphIntegration{
		document_: document
		inserted_content_: inserted_content
		boundary_state_: boundary_state
	}
}

fn nearest_inclusive_ancestor_with_tag(node &dom.Node, tag_name string) ?&dom.Node {
	mut ancestor := ?&dom.Node(node)
	for ancestor != none {
		current := ancestor or { break }
		if element := current.as_element() {
			if element.local_name() == tag_name {
				return current
			}
		}
		ancestor = current.parent()
	}
	return none
}

fn enclosing_table_cell(node &dom.Node) ?&dom.Node {
	mut ancestor := ?&dom.Node(node)
	for ancestor != none {
		current := ancestor or { break }
		if element := current.as_element() {
			if element.local_name() in ['td', 'th'] {
				return current
			}
		}
		ancestor = current.parent()
	}
	return none
}

fn optional_nodes_are_same(left ?&dom.Node, right ?&dom.Node) bool {
	if left_node := left {
		if right_node := right {
			return left_node == right_node
		}
		return false
	}
	return right == none
}

fn dom_node_is_heading(node &dom.Node) bool {
	element := node.as_element() or { return false }
	return element.local_name() in ['h1', 'h2', 'h3', 'h4', 'h5', 'h6']
}

fn can_merge_paragraph_with_destination(source_node &dom.Node, source_block &dom.Node, source_is_before_or_after_block bool, destination &VisiblePosition) bool {
	destination_position := destination.deep_equivalent()
	destination_block := block_node_of_dom_node(destination_position.node) or { return false }
	if element := source_block.as_element() {
		if element.local_name() == 'blockquote' {
			return false
		}
	}
	if !optional_nodes_are_same(nearest_inclusive_ancestor_with_tag(source_block, 'li'),
		nearest_inclusive_ancestor_with_tag(destination_position.node, 'li')) {
		return false
	}
	if !optional_nodes_are_same(enclosing_table_cell(source_node),
		enclosing_table_cell(destination_position.node)) {
		return false
	}
	if dom_node_is_heading(source_block) {
		source_element := source_block.as_element() or { return false }
		destination_element := destination_block.as_element() or { return false }
		if source_element.local_name() != destination_element.local_name() {
			return false
		}
	}
	return !source_is_before_or_after_block && !destination.is_before_or_after_containing_block()
}

fn adjacent_position(position &VisiblePosition, direction dom.CaretNavigationDirection) ?&VisiblePosition {
	return position.move(.move, direction, .character, none)
}

fn is_dom_non_list_single_line_container(node &dom.Node) bool {
	element := node.as_element() or { return false }
	return element.is_html_element() && is_non_list_single_line_container(element.local_name())
}

fn node_is_visible_for_paragraph_integration(node &dom.Node) bool {
	if element := node.as_element() {
		if computed := element.el_computed_properties() {
			if computed.display().is_none() {
				return false
			}
		}
		if is_dom_block_node(node) || element.local_name() in ['img', 'br'] {
			return true
		}
	}
	if node.is_text() {
		return has_rendered_text_after(unsafe { &dom.Text(node) }, 0)
	}
	for child in node.children_as_vector() {
		if node_is_visible_for_paragraph_integration(child) {
			return true
		}
	}
	return false
}

fn has_dom_visible_children(node &dom.Node) bool {
	for child in node.children_as_vector() {
		if node_is_visible_for_paragraph_integration(child) {
			return true
		}
	}
	return false
}

fn (integration &ParagraphIntegration) should_merge_start() bool {
	if integration.boundary_state_.selection_start_was_start_of_paragraph {
		return false
	}
	boundary := integration.inserted_content_.start_boundary() or { return false }
	start := VisiblePosition.create(integration.document_, boundary)
	if !start.is_start_of_paragraph() || is_html_break(start.deep_equivalent().node) {
		return false
	}
	source_position := start.deep_equivalent()
	source_is_before_or_after_block := start.is_before_or_after_containing_block()
	source_node := source_position.node
	source_block := block_node_of_dom_node(source_node) or { return false }
	if source_node == source_block && is_dom_non_list_single_line_container(source_block)
		&& !has_dom_visible_children(source_block) {
		return true
	}
	previous := adjacent_position(start, .backward) or { return false }
	return can_merge_paragraph_with_destination(source_node, source_block,
		source_is_before_or_after_block, previous)
}

fn (integration &ParagraphIntegration) should_merge_end() bool {
	if integration.boundary_state_.selection_end_was_end_of_paragraph {
		return false
	}
	boundary := integration.inserted_content_.end_boundary() or { return false }
	end := VisiblePosition.create(integration.document_, boundary)
	if !end.is_end_of_paragraph() || is_html_break(end.deep_equivalent().node) {
		return false
	}
	source_position := end.deep_equivalent()
	source_is_before_or_after_block := end.is_before_or_after_containing_block()
	source_node := source_position.node
	source_block := block_node_of_dom_node(source_node) or { return false }
	next := adjacent_position(end, .forward) or { return false }
	return can_merge_paragraph_with_destination(source_node, source_block,
		source_is_before_or_after_block, next)
}

pub fn (integration &ParagraphIntegration) decide() ParagraphIntegrationDecision {
	merge_start := integration.should_merge_start()
	merge_end := integration.should_merge_end()
	return ParagraphIntegrationDecision{
		merge_start: merge_start
		merge_end: merge_end
	}
}
