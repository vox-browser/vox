// Copyright (c) 2026-present, the Ladybird developers
// SPDX-License-Identifier: BSD-2-Clause

// Mouse selection routing translated from Page/EventHandler.cpp. Selection
// offsets are DOM UTF-16 code-unit offsets, including URL-token boundaries.
module page

import css
import dom

fn node_from_hit(hit dom.HitTestResult) ?&dom.Node {
	if hit.node != unsafe { nil } {
		return hit.node
	}
	if hit.element != unsafe { nil } {
		return hit.element.as_node()
	}
	return none
}

fn caret_position_from_document_hit(document &dom.Document, position PixelPoint,
	type_ dom.HitTestType) ?CaretPosition {
	paintable := document.paintable_box() or { return none }
	hit := paintable.hit_test(position.x, position.y, type_) or { return none }
	node := node_from_hit(hit) or { return none }
	offset := if hit.index_in_node < 0 {
		0
	} else if hit.index_in_node > node.length() {
		node.length()
	} else {
		hit.index_in_node
	}
	layout_node := node.layout_node() or { unsafe { nil } }
	return CaretPosition{
		boundary: dom.BoundaryPoint{
			node: node
			offset: offset
		}
		layout_node: layout_node
		user_select_used_value: if layout_node != unsafe { nil } && layout_node.user_select_none_ {
			.none_
		} else { .auto_ }
	}
}

fn focus_candidate_from_hit(document &dom.Document, position PixelPoint) ?&dom.Node {
	paintable := document.paintable_box() or { return none }
	hit := paintable.hit_test(position.x, position.y, .exact) or { return none }
	mut candidate := ?&dom.Node(node_from_hit(hit) or { return none })
	for candidate != none {
		node := candidate or { break }
		if node_has_focus_behavior(node) {
			return node
		}
		candidate = node.parent_or_shadow_host()
	}
	return none
}

fn node_has_focus_behavior(node &dom.Node) bool {
	if node.is_editable_or_editing_host() {
		return true
	}
	element := node.as_element() or { return false }
	return element.is_focusable()
}

pub fn (mut handler EventHandler) prepare_mouse_selection(document &dom.Document,
	position PixelPoint) ?CaretPosition {
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.update_layout(.event_handler_handle_mouse_down)
	if !handler.has_committed_root_box(document) {
		return none
	}

	paintable := document.paintable_box() or { return none }
	exact_hit := paintable.hit_test(position.x, position.y, .exact)
	mut editable_hit_node_before_focus := ?&dom.Node(none)
	if hit := exact_hit {
		editable_hit_node_before_focus = node_from_hit(hit)
	}
	mut editing_host_before_focus := ?&dom.Node(none)
	if hit_node := editable_hit_node_before_focus {
		editing_host_before_focus = associated_descendant_editing_host(hit_node)
	}

	focus_candidate := editing_host_before_focus or {
		focus_candidate_from_hit(document, position) or { unsafe { nil } }
	}
	if focus_candidate != unsafe { nil } {
		mutable_document.set_focused_area(focus_candidate)
	} else if document.focused_area() != none {
		mutable_document.set_focused_area(none)
	}

	// Focusing can rebuild the layout tree, so only consume a fresh hit after
	// updating layout again.
	mutable_document.update_layout(.event_handler_handle_mouse_down)
	if !handler.has_committed_root_box(document) {
		return none
	}
	mut caret_position := caret_position_from_document_hit(document, position, .text_cursor)
	if caret_position == none {
		caret_position = caret_position_from_document_hit(document, position, .exact)
	}
	if hit_node := editable_hit_node_before_focus {
		if hit_node.is_connected() {
			if editing_host := editing_host_before_focus {
				if should_use_caret_position_from_editable_hit_node(caret_position, hit_node,
					editing_host) {
					if fallback := caret_position_from_editable_hit_node(hit_node) {
						caret_position = fallback
					}
				}
			}
		}
	}
	return caret_position
}

pub fn form_control_selection_contains_position(selection SelectionRange,
	caret_position CaretPosition) bool {
	return selection.start != selection.end && caret_position.boundary.offset >= selection.start
		&& caret_position.boundary.offset <= selection.end
}

pub fn selection_contains_position(document &dom.Document, caret_position CaretPosition) bool {
	selection := document.get_selection() or { return false }
	if selection.is_collapsed() {
		return false
	}
	range := selection.range() or { return false }
	return range.is_point_in_range(caret_position.boundary.node, caret_position.boundary.offset) or {
		false
	}
}

pub fn (mut handler EventHandler) preserve_selection_for_mousedown(position PixelPoint) {
	handler.mousedown_visual_viewport_position_ = position
	handler.mousedown_preserved_selection_ = true
}

pub fn (handler &EventHandler) mousedown_preserved_selection() bool {
	return handler.mousedown_preserved_selection_
}

pub fn (mut handler EventHandler) start_selection_from_preserved_mousedown(document &dom.Document) {
	handler.mousedown_preserved_selection_ = false
	position := handler.mousedown_visual_viewport_position_ or { return }
	caret_position := handler.prepare_mouse_selection(document, position) or { return }
	if user_select_used_value_for_caret_position(caret_position) == .none_ {
		return
	}
	handler.selection_boundary_ = caret_position.boundary
	handler.selection_anchor = position
	handler.selection_extent = position
	handler.selection_mode_ = .character
}

pub fn (mut handler EventHandler) finish_selection_from_preserved_mousedown(document &dom.Document,
	position PixelPoint) {
	handler.mousedown_preserved_selection_ = false
	mousedown_position := handler.mousedown_visual_viewport_position_ or { return }
	if mousedown_position != position {
		return
	}
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.update_layout(.event_handler_handle_mouse_up)
	if !handler.has_committed_root_box(document) {
		return
	}
	caret_position := caret_position_from_document_hit(document, position, .text_cursor) or {
		return
	}
	if target := document.active_input_events_target(caret_position.boundary.node) {
		target.set_selection_anchor(caret_position.boundary.node,
			caret_position.boundary.offset, .downstream)
		handler.selection_boundary_ = caret_position.boundary
		handler.input_selection_range_ = SelectionRange{
			start: caret_position.boundary.offset
			end: caret_position.boundary.offset
		}
		return
	}
	if selection := document.get_selection() {
		mut mutable_selection := unsafe { &dom.Selection(selection) }
		mutable_selection.remove_all_ranges()
		mutable_document.set_needs_repaint_with_invalidation(.paint_commands)
	}
}

fn input_element_has_selectable_text(element &dom.Element) bool {
	if element.local_name() != 'input' {
		return false
	}
	type_ := element.get_attribute('type') or { 'text' }.to_lower()
	return type_ in ['text', 'search', 'tel', 'url', 'email', 'password']
}

pub fn is_middle_click_paste_target(node &dom.Node) bool {
	if node.is_editable_or_editing_host() {
		return true
	}
	mut candidate := ?&dom.Node(node)
	for candidate != none {
		current := candidate or { break }
		if current.is_html_textarea_element() {
			return true
		}
		if element := current.as_element() {
			if input_element_has_selectable_text(element) {
				return true
			}
		}
		candidate = current.parent_or_shadow_host()
	}
	return false
}

pub fn choose_caret_boundary_for_selection_focus(caret_position CaretPosition,
	anchor dom.BoundaryPoint) dom.BoundaryPoint {
	secondary := caret_position.secondary_boundary or { return caret_position.boundary }
	primary := caret_position.boundary
	anchor_root := anchor.node.shadow_including_root()
	if voidptr(anchor_root) != voidptr(primary.node.shadow_including_root())
		|| voidptr(anchor_root) != voidptr(secondary.node.shadow_including_root()) {
		return primary
	}
	anchor_to_primary := dom.position_of_boundary_point_relative_to_other_boundary_point(anchor,
		primary)
	anchor_to_secondary := dom.position_of_boundary_point_relative_to_other_boundary_point(anchor,
		secondary)
	primary_to_secondary := dom.position_of_boundary_point_relative_to_other_boundary_point(primary,
		secondary)
	if anchor_to_primary == .before && anchor_to_secondary == .before {
		return if primary_to_secondary == .before { secondary } else { primary }
	}
	if anchor_to_primary == .after && anchor_to_secondary == .after {
		return if primary_to_secondary == .before { primary } else { secondary }
	}
	return primary
}

pub fn (mut handler EventHandler) maybe_request_paste_for_middle_click(document &dom.Document,
	position PixelPoint) bool {
	if !handler.primary_paste_enabled_ {
		return false
	}
	caret_position := caret_position_from_document_hit(document, position, .text_cursor) or {
		return false
	}
	hit_node := caret_position.boundary.node
	if !is_middle_click_paste_target(hit_node) {
		return false
	}
	mut mutable_document := unsafe { &dom.Document(document) }
	if focus_candidate := focus_candidate_from_hit(document, position) {
		mutable_document.set_focused_area(focus_candidate)
	} else if editing_host := hit_node.editing_host() {
		mutable_document.set_focused_area(editing_host)
	}
	target := document.active_input_events_target(hit_node)
	if target == none && !hit_node.is_editable_or_editing_host() {
		return false
	}
	if input_target := target {
		input_target.set_selection_anchor(hit_node, caret_position.boundary.offset, .downstream)
	}
	handler.selection_boundary_ = caret_position.boundary
	handler.input_selection_range_ = SelectionRange{
		start: caret_position.boundary.offset
		end: caret_position.boundary.offset
	}
	if mut client := handler.client_ {
		client.page_did_request_primary_paste()
	}
	return true
}

fn event_handler_utf16_code_units(value string) []u16 {
	mut units := []u16{cap: value.len}
	for code_point in value.runes() {
		scalar := u32(code_point)
		if scalar <= 0xffff {
			units << u16(scalar)
			continue
		}
		value_above_bmp := scalar - 0x10000
		units << u16(0xd800 + (value_above_bmp >> 10))
		units << u16(0xdc00 + (value_above_bmp & 0x3ff))
	}
	return units
}

fn is_url_code_unit(code_unit u16) bool {
	if code_unit > 0x7f
		|| code_unit in [u16(0x20), u16(0x09), u16(0x0a), u16(0x0d), u16(0x0c)] {
		return false
	}
	return code_unit !in [u16(0x22), u16(0x27), u16(0x60), u16(0x3c), u16(0x3e)]
}

fn is_url_leading_punctuation(code_unit u16) bool {
	return code_unit in [u16(0x22), u16(0x27), u16(0x60), u16(0x28), u16(0x5b),
		u16(0x7b), u16(0x3c)]
}

fn is_url_trailing_punctuation(code_unit u16) bool {
	return code_unit in [u16(0x22), u16(0x27), u16(0x60), u16(0x2e), u16(0x2c),
		u16(0x3b), u16(0x3a), u16(0x21), u16(0x3f), u16(0x29), u16(0x5d), u16(0x7d),
		u16(0x3e)]
}

fn set_context_selection(mut handler EventHandler, document &dom.Document, node &dom.Node,
	start int, end int, _ css.UserSelect) {
	handler.input_selection_range_ = SelectionRange{
		start: start
		end: end
	}
	if target := document.active_input_events_target(node) {
		target.set_selection_anchor(node, start, .downstream)
		target.set_selection_focus(node, end, .downstream)
	} else if selection := document.get_selection() {
		mut mutable_selection := unsafe { &dom.Selection(selection) }
		mutable_selection.set_base_and_extent(node, start, node, end) or { return }
		mut mutable_document := unsafe { &dom.Document(document) }
		mutable_document.set_needs_repaint_with_invalidation(.paint_commands)
	}
}

pub fn (mut handler EventHandler) select_context_menu_url_token(document &dom.Document,
	caret_position CaretPosition, user_select css.UserSelect) bool {
	hit_node := caret_position.boundary.node
	if !hit_node.is_text() {
		return false
	}
	text_node := unsafe { &dom.Text(hit_node) }
	if text_node.is_password_input() {
		return false
	}
	units := event_handler_utf16_code_units(text_node.data())
	if units.len == 0 {
		return false
	}
	hit_index := if caret_position.boundary.offset < 0 {
		0
	} else if caret_position.boundary.offset > units.len {
		units.len
	} else {
		caret_position.boundary.offset
	}
	mut token_start := hit_index
	for token_start > 0 && is_url_code_unit(units[token_start - 1]) {
		token_start--
	}
	mut token_end := hit_index
	for token_end < units.len && is_url_code_unit(units[token_end]) {
		token_end++
	}
	for token_start < token_end && is_url_leading_punctuation(units[token_start]) {
		token_start++
	}
	for token_end > token_start && is_url_trailing_punctuation(units[token_end - 1]) {
		token_end--
	}
	if token_start == token_end {
		return false
	}
	mut contains_url_punctuation := false
	for code_unit in units[token_start..token_end] {
		if code_unit in [u16(0x2e), u16(0x3a), u16(0x2f), u16(0x40)] {
			contains_url_punctuation = true
			break
		}
	}
	if !contains_url_punctuation {
		return false
	}
	set_context_selection(mut handler, document, hit_node, token_start, token_end, user_select)
	return true
}

pub fn (mut handler EventHandler) select_context_menu_text(document &dom.Document,
	position PixelPoint) bool {
	caret_position := caret_position_from_document_hit(document, position, .text_cursor) or {
		return false
	}
	if selection_contains_position(document, caret_position) {
		return false
	}
	user_select := user_select_used_value_for_caret_position(caret_position)
	if user_select == .none_ {
		return false
	}
	if handler.select_context_menu_url_token(document, caret_position, user_select) {
		handler.stop_updating_selection()
		return true
	}
	node := caret_position.boundary.node
	text := node.text_content() or { return false }
	range := dictionary_word_range(text, caret_position.boundary.offset) or { return false }
	set_context_selection(mut handler, document, node, range.start, range.end, user_select)
	handler.stop_updating_selection()
	return true
}
