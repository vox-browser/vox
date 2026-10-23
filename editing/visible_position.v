// Copyright (c) 2026-present, the Ladybird developers
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Editing/VisiblePosition.{h,cpp}.
module editing

import dom

enum AdjacentContent {
	block_boundary
	paragraph_boundary
	rendered_content
}

enum VisibleScanDirection {
	backward
	forward
}

@[heap]
pub struct VisiblePosition {
	document_        &dom.Document
	boundary_        dom.CaretLocation
	deep_equivalent_ dom.CaretLocation
}

pub fn VisiblePosition.create(document &dom.Document, boundary dom.BoundaryPoint) &VisiblePosition {
	return VisiblePosition.create_with_affinity(document, boundary, .downstream)
}

pub fn VisiblePosition.create_with_affinity(document &dom.Document, boundary dom.BoundaryPoint, affinity dom.TextAffinity) &VisiblePosition {
	location := dom.CaretLocation{
		node: boundary.node
		offset: boundary.offset
		affinity: affinity
	}
	navigator := dom.CaretNavigator.new(document)
	canonical := navigator.canonical_location_for_editing(location)
	return &VisiblePosition{
		document_: document
		boundary_: location
		deep_equivalent_: navigator.upstream_equivalent_location(canonical)
	}
}

pub fn (position &VisiblePosition) boundary() dom.BoundaryPoint {
	return dom.BoundaryPoint{
		node: position.boundary_.node
		offset: position.boundary_.offset
	}
}

pub fn (position &VisiblePosition) deep_equivalent() dom.BoundaryPoint {
	return dom.BoundaryPoint{
		node: position.deep_equivalent_.node
		offset: position.deep_equivalent_.offset
	}
}

pub fn (position &VisiblePosition) affinity() dom.TextAffinity {
	return position.boundary_.affinity
}

pub fn (position &VisiblePosition) move(alteration dom.SelectionAlteration, direction dom.CaretNavigationDirection, granularity dom.SelectionGranularity, preferred_inline_coordinate ?f64) ?&VisiblePosition {
	navigator := dom.CaretNavigator.new(position.document_)
	destination := navigator.move(position.boundary_, alteration, direction, granularity,
		preferred_inline_coordinate) or { return none }
	canonical := navigator.canonical_location_for_editing(destination)
	return &VisiblePosition{
		document_: position.document_
		boundary_: destination
		deep_equivalent_: navigator.upstream_equivalent_location(canonical)
	}
}

fn adjacent_visible_position(document &dom.Document, deep_equivalent dom.CaretLocation, direction dom.CaretNavigationDirection) ?&VisiblePosition {
	navigator := dom.CaretNavigator.new(document)
	destination := navigator.move(deep_equivalent, .move, direction, .character, none) or {
		return none
	}
	return VisiblePosition.create_with_affinity(document, dom.BoundaryPoint{
		node: destination.node
		offset: destination.offset
	}, destination.affinity)
}

pub fn (position &VisiblePosition) next() ?&VisiblePosition {
	return adjacent_visible_position(position.document_, position.deep_equivalent_, .forward)
}

pub fn (position &VisiblePosition) previous() ?&VisiblePosition {
	return adjacent_visible_position(position.document_, position.deep_equivalent_, .backward)
}

pub fn (position &VisiblePosition) inline_coordinate() ?f64 {
	navigator := dom.CaretNavigator.new(position.document_)
	return navigator.inline_coordinate(position.boundary_)
}

pub fn (position &VisiblePosition) canonical_boundary_for_extension(direction dom.CaretNavigationDirection) ?dom.BoundaryPoint {
	navigator := dom.CaretNavigator.new(position.document_)
	location := navigator.canonical_location_for_extension(position.boundary_, direction) or {
		return none
	}
	return dom.BoundaryPoint{
		node: location.node
		offset: location.offset
	}
}

fn has_rendered_text_before(text &dom.Text, offset int) bool {
	for line in dom.collect_visual_lines(text) {
		if line.has_fragments && line.end_offset > line.start_offset && line.start_offset < offset {
			return true
		}
	}
	return false
}

fn has_rendered_text_after(text &dom.Text, offset int) bool {
	for line in dom.collect_visual_lines(text) {
		if line.has_fragments && line.end_offset > line.start_offset && line.end_offset > offset {
			return true
		}
	}
	return false
}

fn is_rendered_atomic_inline(node &dom.Node) bool {
	layout_node := node.layout_node() or { return false }
	return layout_node.is_atomic_inline()
}

fn has_sibling_toward(node &dom.Node, block &dom.Node, direction VisibleScanDirection) bool {
	mut ancestor := ?&dom.Node(node)
	for ancestor != none {
		current := ancestor or { return false }
		if voidptr(current) == voidptr(block) {
			break
		}
		if direction == .forward {
			if current.next_sibling() != none {
				return true
			}
		} else if current.previous_sibling() != none {
			return true
		}
		ancestor = current.parent()
	}
	return false
}

fn is_html_break(node &dom.Node) bool {
	element := node.as_element() or { return false }
	return element.is_html_element() && element.local_name() == 'br'
}

fn scan_adjacent_content(position dom.CaretLocation, block &dom.Node, direction VisibleScanDirection) AdjacentContent {
	scan_backward := direction == .backward
	if position.node.is_text() {
		text := unsafe { &dom.Text(position.node) }
		if (scan_backward && has_rendered_text_before(text, position.offset))
			|| (!scan_backward && has_rendered_text_after(text, position.offset)) {
			return .rendered_content
		}
	}

	mut node := ?&dom.Node(none)
	if !position.node.is_text() {
		if scan_backward && position.offset > 0 {
			node = position.node.child_at_index(position.offset - 1)
			for node != none {
				current := node or { break }
				last := current.last_child() or { break }
				node = last
			}
		} else if !scan_backward && position.offset < position.node.child_count() {
			node = position.node.child_at_index(position.offset)
		}
	}
	if node == none && scan_backward {
		node = position.node.previous_in_pre_order()
	} else if node == none {
		mut ancestor := ?&dom.Node(position.node)
		for ancestor != none {
			current := ancestor or { break }
			if voidptr(current) == voidptr(block) {
				break
			}
			if sibling := current.next_sibling() {
				node = sibling
				break
			}
			ancestor = current.parent()
		}
	}

	for node != none {
		current := node or { break }
		if voidptr(current) == voidptr(block) || !block.is_inclusive_ancestor_of(current) {
			break
		}
		if is_html_break(current) {
			if !has_sibling_toward(current, block, direction) {
				return .block_boundary
			}
			return .paragraph_boundary
		}
		if is_block_node(current) {
			return .paragraph_boundary
		}
		if current.is_text() {
			text := unsafe { &dom.Text(current) }
			if (scan_backward && has_rendered_text_before(text, text.length_in_utf16_code_units()))
				|| (!scan_backward && has_rendered_text_after(text, 0)) {
				return .rendered_content
			}
		}
		if is_rendered_atomic_inline(current) {
			return .rendered_content
		}
		node = if scan_backward {
			current.previous_in_pre_order()
		} else {
			current.next_in_pre_order(block)
		}
	}
	return .block_boundary
}

fn (position &VisiblePosition) adjacent_content(direction VisibleScanDirection) ?AdjacentContent {
	mut document := unsafe { &dom.Document(position.document_) }
	document.update_layout_if_needed_for_node(position.boundary_.node, .cursor_line_navigation)
	block := block_node_of_node(position.boundary_.node) or { return none }
	return scan_adjacent_content(position.boundary_, block, direction)
}

pub fn (position &VisiblePosition) is_start_of_paragraph() bool {
	return position.adjacent_content(.backward) or { return false } != .rendered_content
}

pub fn (position &VisiblePosition) is_end_of_paragraph() bool {
	return position.adjacent_content(.forward) or { return false } != .rendered_content
}

pub fn (position &VisiblePosition) is_start_of_containing_block() bool {
	return position.adjacent_content(.backward) or { return false } == .block_boundary
}

pub fn (position &VisiblePosition) is_end_of_containing_block() bool {
	return position.adjacent_content(.forward) or { return false } == .block_boundary
}

pub fn (position &VisiblePosition) is_before_or_after_containing_block() bool {
	block := block_node_of_node(position.deep_equivalent_.node) or { return false }
	if voidptr(position.deep_equivalent_.node) != voidptr(block) {
		return false
	}
	child_after := block.child_at_index(position.deep_equivalent_.offset)
	mut child_before := ?&dom.Node(none)
	if position.deep_equivalent_.offset > 0 {
		child_before = block.child_at_index(position.deep_equivalent_.offset - 1)
	}
	before_is_atomic := if child := child_before { is_rendered_atomic_inline(child) } else { false }
	after_is_atomic := if child := child_after { is_rendered_atomic_inline(child) } else { false }
	return !before_is_atomic && !after_is_atomic
}
