// Copyright (c) 2026-present, the Ladybird developers
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Editing/StyledMarkupSelection.{h,cpp}.
module editing

import dom

// Capture the rendered boundaries used by annotated clipboard serialization. DOM range endpoints alone cannot
// describe a selected paragraph break because formatting whitespace does not participate in the rendered tree.
// Blink and WebKit likewise derive traversal and interchange boundaries from immutable visible positions.
pub struct StyledMarkupSelection {
	visible_start        &VisiblePosition
	visible_end          &VisiblePosition
	previous_visible_end ?&VisiblePosition
	serialization_range  &dom.Range
}

fn needs_interchange_newline_after(position &VisiblePosition) bool {
	next := position.next() or { return false }
	if !position.is_end_of_paragraph() || !next.is_start_of_paragraph() {
		return false
	}

	upstream_node := next.deep_equivalent().node
	downstream_node := position.deep_equivalent().node
	return !upstream_node.is_html_br_element() || upstream_node != downstream_node
}

fn create_serialization_range(source_range &dom.Range, visible_end &VisiblePosition) &dom.Range {
	start := source_range.start()
	mut end := source_range.end()
	rendered_end := visible_end.deep_equivalent()
	// INTEROP: Blink and WebKit serialize an element boundary through the DOM position which represents the visible
	//          end of the selection. This includes structurally empty containers reached by the rendered selection,
	//          even when the raw Range ends at a child offset before them. Keep CharacterData endpoints exact because
	//          canonicalizing a text offset can cross into an adjacent formatting ancestor at the same visual point.
	if !end.node.is_character_data() {
		end = rendered_end
	}
	// INTEROP: A visible selection which reaches the start of an empty paragraph includes the paragraph break.
	//          Keep its placeholder br inside the traversal range so serializing and reinserting the selection
	//          recreates an empty paragraph instead of an empty block with no caret position.
	if rendered_end.offset == 0 && is_prohibited_paragraph_child(rendered_end.node)
		&& rendered_end.node.child_count() == 1 {
		if first_child := rendered_end.node.first_child() {
			if first_child.is_html_br_element() {
				end = dom.BoundaryPoint{
					node:   rendered_end.node
					offset: 1
				}
			}
		}
	}
	return dom.Range.create_from_boundary_points(start.node, start.offset, end.node, end.offset)
}

pub fn StyledMarkupSelection.new(range_ &dom.Range) StyledMarkupSelection {
	document := range_.start_container().document()
	visible_end := VisiblePosition.create(document, range_.end())
	return StyledMarkupSelection{
		visible_start:        VisiblePosition.create(document, range_.start())
		visible_end:          visible_end
		previous_visible_end: visible_end.previous()
		serialization_range:  create_serialization_range(range_, visible_end)
	}
}

pub fn (selection &StyledMarkupSelection) serialization_range() &dom.Range {
	return selection.serialization_range
}

pub fn (selection &StyledMarkupSelection) contains_only_interchange_newline() bool {
	if !needs_interchange_newline_after(selection.visible_start) {
		return false
	}
	previous_visible_end := selection.previous_visible_end or { return false }
	start := selection.visible_start.deep_equivalent()
	previous_end := previous_visible_end.deep_equivalent()
	return start.node == previous_end.node && start.offset == previous_end.offset
}

pub fn (selection &StyledMarkupSelection) has_leading_interchange_newline() bool {
	return needs_interchange_newline_after(selection.visible_start)
}

pub fn (selection &StyledMarkupSelection) has_trailing_interchange_newline() bool {
	previous_visible_end := selection.previous_visible_end or { return false }
	return needs_interchange_newline_after(previous_visible_end)
}
