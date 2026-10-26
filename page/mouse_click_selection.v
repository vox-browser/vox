// Copyright (c) 2026-present, the Ladybird developers
// SPDX-License-Identifier: BSD-2-Clause

module page

import dom
import editing

// The embedder supplies its word segmentation policy in DOM UTF-16 offsets.
pub type MouseWordRange = fn (string, int) SelectionRange

// Called after uncancelled primary pointerdown/mousedown default actions. Focus
// may rebuild layout, so prepare_mouse_selection obtains a fresh text hit.
pub fn (mut handler EventHandler) select_mouse_text(document &dom.Document, position PixelPoint,
	click_count int, word_range MouseWordRange) {
	caret := handler.prepare_mouse_selection(document, position) or { return }
	if user_select_used_value_for_caret_position(caret) == .none_ { return }
	node := caret.boundary.node
	mut start := caret.boundary
	mut end := start
	if click_count >= 2 {
		if !node.is_text() { return }
		text := unsafe { &dom.Text(node) }.data()
		if click_count == 2 {
			range := word_range(text, start.offset)
			start = dom.BoundaryPoint{ node: node, offset: range.start }
			end = dom.BoundaryPoint{ node: node, offset: range.end }
			handler.selection_mode_ = .word
		} else {
			scope := if target := document.active_input_events_target(node) {
				target.mouse_selection_scope()
			} else {
				?&dom.Node(none)
			}
			is_text_control := if root := scope { root.is_text() } else { false }
			if is_text_control {
				units := event_handler_utf16_code_units(text)
				mut first := start.offset
				mut last := first
				for first > 0 && units[first - 1] != 10 && units[first - 1] != 13 { first-- }
				for last < units.len && units[last] != 10 && units[last] != 13 { last++ }
				start = dom.BoundaryPoint{ node: node, offset: first }
				end = dom.BoundaryPoint{ node: node, offset: last }
			} else {
				start = mouse_paragraph_edge(start, false, scope)
				end = mouse_paragraph_edge(end, true, scope)
			}
			handler.selection_mode_ = .paragraph
		}
	} else {
		handler.selection_mode_ = .character
		if handler.platform_mouse_modifiers_ & dom.modifier_shift != 0 {
			if selection := document.get_selection() {
				if anchor := selection.anchor_node() {
					if voidptr(anchor.root()) == voidptr(node.root()) {
						start = dom.BoundaryPoint{ node: anchor, offset: selection.anchor_offset() }
					}
				}
			}
		}
	}
	handler.selection_boundary_ = start
	if target := document.active_input_events_target(node) {
		target.set_selection_anchor(start.node, start.offset, .downstream)
		target.set_selection_focus(end.node, end.offset, .downstream)
		handler.input_selection_range_ = SelectionRange{ start: start.offset, end: end.offset }
	} else if selection := document.get_selection() {
		mut mutable_selection := unsafe { &dom.Selection(selection) }
		mutable_selection.set_base_and_extent(start.node, start.offset, end.node, end.offset) or { return }
	}
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_needs_repaint_with_invalidation(.paint_commands)
}

// Traverse inline descendants in both directions, stopping at a block or br.
// A soft-wrapped visual line remains part of the same paragraph.
fn mouse_paragraph_edge(initial dom.BoundaryPoint, forward bool, scope ?&dom.Node) dom.BoundaryPoint {
	mut node := initial.node
	mut offset := initial.offset
	for {
		if node.is_text() {
			offset = if forward { node.length() } else { 0 }
		} else {
			index := if forward { offset } else { offset - 1 }
			if child := node.child_at_index(index) {
				if child.is_html_br_element() || editing.is_block_node(child) {
					return dom.BoundaryPoint{ node: node, offset: offset }
				}
				node = child
				offset = if forward { 0 } else { node.length() }
				continue
			}
			if editing.is_block_node(node) {
				return dom.BoundaryPoint{ node: node, offset: offset }
			}
		}
		if root := scope {
			if voidptr(node) == voidptr(root) {
				return dom.BoundaryPoint{ node: node, offset: offset }
			}
		}
		parent := node.parent() or { return dom.BoundaryPoint{ node: node, offset: offset } }
		offset = node.index() + if forward { 1 } else { 0 }
		node = parent
	}
}
