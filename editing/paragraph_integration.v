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
			return voidptr(left_node) == voidptr(right_node)
		}
		return false
	}
	return right == none
}

fn paragraph_integration_is_heading(node &dom.Node) bool {
	element := node.as_element() or { return false }
	return element.local_name() in ['h1', 'h2', 'h3', 'h4', 'h5', 'h6']
}

fn can_merge_paragraphs(source &VisiblePosition, destination &VisiblePosition) bool {
	source_position := source.deep_equivalent()
	destination_position := destination.deep_equivalent()
	source_block := block_node_of_node(source_position.node) or { return false }
	destination_block := block_node_of_node(destination_position.node) or { return false }

	if element := source_block.as_element() {
		if element.local_name() == 'blockquote' {
			return false
		}
	}

	// INTEROP: Blink and WebKit intentionally compare the source block's list child with the destination position's
	//          list child. The asymmetry preserves a destination caret's list context when its enclosing block is a
	//          container outside that list. Table cells, in contrast, are compared from both exact positions.
	if !optional_nodes_are_same(nearest_inclusive_ancestor_with_tag(source_block, 'li'),
		nearest_inclusive_ancestor_with_tag(destination_position.node, 'li')) {
		return false
	}
	if !optional_nodes_are_same(enclosing_table_cell(source_position.node),
		enclosing_table_cell(destination_position.node)) {
		return false
	}

	if paragraph_integration_is_heading(source_block) {
		source_element := source_block.as_element() or { return false }
		destination_element := destination_block.as_element() or { return false }
		if source_element.local_name() != destination_element.local_name() {
			return false
		}
	}

	// A position before or after a block is not a paragraph move. A block-owned position adjacent to atomic inline
	// content is an interior caret whose anchor type was lost when represented as a DOM boundary.
	return !source.is_before_or_after_containing_block()
		&& !destination.is_before_or_after_containing_block()
}

fn adjacent_position(position &VisiblePosition, direction dom.CaretNavigationDirection) ?&VisiblePosition {
	return position.move(.move, direction, .character, none)
}

fn (integration &ParagraphIntegration) should_merge_start() bool {
	if integration.boundary_state_.selection_start_was_start_of_paragraph {
		return false
	}
	boundary := integration.inserted_content_.start_boundary() or { return false }
	start := VisiblePosition.create(integration.document_, boundary)
	previous := adjacent_position(start, .backward) or { return false }
	if !start.is_start_of_paragraph() {
		return false
	}
	if is_html_break(start.deep_equivalent().node) {
		return false
	}

	if source_block := block_node_of_node(start.deep_equivalent().node) {
		if voidptr(start.deep_equivalent().node) == voidptr(source_block) && is_non_list_single_line_container(source_block)
			&& !has_visible_children(source_block) {
			// INTEROP: A boundary-only clipboard paragraph may be represented by an empty block with no rendered caret
			//          inside it. Blink folds that transport wrapper into the preceding paragraph instead of leaving an
			//          empty nested block behind.
			return true
		}
	}
	return can_merge_paragraphs(start, previous)
}

fn (integration &ParagraphIntegration) should_merge_end() bool {
	if integration.boundary_state_.selection_end_was_end_of_paragraph {
		return false
	}
	boundary := integration.inserted_content_.end_boundary() or { return false }
	end := VisiblePosition.create(integration.document_, boundary)
	next := adjacent_position(end, .forward) or { return false }
	if !end.is_end_of_paragraph() {
		return false
	}
	if is_html_break(end.deep_equivalent().node) {
		return false
	}
	return can_merge_paragraphs(end, next)
}

pub fn (integration &ParagraphIntegration) decide() ParagraphIntegrationDecision {
	merge_start := integration.should_merge_start()
	merge_end := integration.should_merge_end()
	return ParagraphIntegrationDecision{
		merge_start: merge_start
		merge_end: merge_end
	}
}
