// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause
//
// Translated from Libraries/LibWeb/Selection/Selection.{h,cpp}.
module dom

fn selection_same_node(a &Node, b &Node) bool {
	return voidptr(a) == voidptr(b)
}

fn selection_same_range(a &Range, b &Range) bool {
	return voidptr(a) == voidptr(b)
}

pub fn Selection.create(document &Document) &Selection {
	return &Selection{
		document_: document
	}
}

pub fn (selection &Selection) is_empty() bool {
	return selection.range_ == unsafe { nil }
}

pub fn (selection &Selection) anchor_node() ?&Node {
	if selection.range_ == unsafe { nil } {
		return none
	}
	if selection.direction_ == .forwards {
		return selection.range_.start_container()
	}
	return selection.range_.end_container()
}

pub fn (selection &Selection) anchor_offset() int {
	if selection.range_ == unsafe { nil } {
		return 0
	}
	if selection.direction_ == .forwards {
		return selection.range_.start_offset()
	}
	return selection.range_.end_offset()
}

pub fn (selection &Selection) focus_node() ?&Node {
	if selection.range_ == unsafe { nil } {
		return none
	}
	if selection.direction_ == .forwards {
		return selection.range_.end_container()
	}
	return selection.range_.start_container()
}

pub fn (selection &Selection) focus_offset() int {
	if selection.range_ == unsafe { nil } {
		return 0
	}
	if selection.direction_ == .forwards {
		return selection.range_.end_offset()
	}
	return selection.range_.start_offset()
}

pub fn (selection &Selection) is_collapsed() bool {
	if selection.range_ == unsafe { nil } {
		return true
	}
	anchor := selection.anchor_node() or { return true }
	focus := selection.focus_node() or { return true }
	return selection_same_node(anchor, focus) && selection.range_.start_offset() == selection.range_.end_offset()
}

pub fn (selection &Selection) range_count() int {
	return if selection.range_ == unsafe { nil } { 0 } else { 1 }
}

pub fn (selection &Selection) type_() string {
	if selection.range_ == unsafe { nil } {
		return 'None'
	}
	if selection.range_.collapsed() {
		return 'Caret'
	}
	return 'Range'
}

pub fn (selection &Selection) direction() string {
	if selection.range_ == unsafe { nil } || selection.direction_ == .directionless {
		return 'none'
	}
	return if selection.direction_ == .forwards { 'forward' } else { 'backward' }
}

pub fn (selection &Selection) get_range_at(index int) !&Range {
	anchor := selection.anchor_node() or {
		return error('IndexSizeError: Selection.getRangeAt() on empty Selection')
	}
	focus := selection.focus_node() or {
		return error('IndexSizeError: Selection.getRangeAt() on empty Selection')
	}
	if index != 0 || selection.is_empty() || voidptr(anchor.document()) != voidptr(selection.document_) || voidptr(focus.document()) != voidptr(selection.document_) {
		return error('IndexSizeError: Selection.getRangeAt() on empty Selection or with invalid argument')
	}
	return selection.range_
}

pub fn (mut selection Selection) add_range(range &Range) {
	if selection.document_ == unsafe { nil } || !selection_same_node(range.start_container().root(), unsafe { &Node(selection.document_) }) || selection.range_count() != 0 {
		return
	}
	selection.set_range(range)
	selection.direction_ = .forwards
}

pub fn (mut selection Selection) remove_range(range &Range) ! {
	if selection.range_ == unsafe { nil } || !selection_same_range(selection.range_, range) {
		return error('NotFoundError: Selection.removeRange() with invalid argument')
	}
	selection.set_range(none)
}

pub fn (mut selection Selection) remove_all_ranges() {
	selection.set_range(none)
}

pub fn (mut selection Selection) empty() {
	selection.remove_all_ranges()
}

pub fn (mut selection Selection) collapse(node_ ?&Node, offset int) ! {
	node := node_ or {
		selection.remove_all_ranges()
		return
	}

	if node.is_document_type() {
		return error('InvalidNodeTypeError: Selection.collapse() with DocumentType node')
	}
	if offset < 0 || offset > node.length() {
		return error('IndexSizeError: Selection.collapse() offset is out of range')
	}
	if selection.document_ == unsafe { nil } || voidptr(node.document()) != voidptr(selection.document_) || !unsafe { &Node(selection.document_) }.is_shadow_including_inclusive_ancestor_of(node) {
		return
	}
	mut new_range := Range.create(selection.document_)
	new_range.set_start(node, offset)!
	selection.set_range(new_range)
}

pub fn (mut selection Selection) collapse_to_none() {
	selection.remove_all_ranges()
}

pub fn (mut selection Selection) set_position(node ?&Node, offset int) ! {
	selection.collapse(node, offset)!
}

pub fn (mut selection Selection) collapse_to_start() ! {
	if selection.range_ == unsafe { nil } {
		return error('InvalidStateError: Selection.collapseToStart() on empty selection')
	}
	mut new_range := Range.create(selection.document_)
	new_range.set_start(selection.range_.start_container(), selection.range_.start_offset())!
	new_range.set_end(selection.range_.start_container(), selection.range_.start_offset())!
	selection.set_range(new_range)
}

pub fn (mut selection Selection) collapse_to_end() ! {
	if selection.range_ == unsafe { nil } {
		return error('InvalidStateError: Selection.collapseToEnd() on empty selection')
	}
	mut new_range := Range.create(selection.document_)
	new_range.set_start(selection.range_.end_container(), selection.range_.end_offset())!
	new_range.set_end(selection.range_.end_container(), selection.range_.end_offset())!
	selection.set_range(new_range)
}

pub fn (mut selection Selection) extend(node &Node, offset int) ! {
	if selection.document_ == unsafe { nil } || voidptr(node.document()) != voidptr(selection.document_) || !unsafe { &Node(selection.document_) }.is_shadow_including_inclusive_ancestor_of(node) {
		return
	}
	if selection.range_ == unsafe { nil } {
		return error('InvalidStateError: Selection.extend() on empty selection')
	}
	if offset < 0 || offset > node.length() {
		return error('IndexSizeError: Selection.extend() offset is out of range')
	}
	old_anchor_node := selection.anchor_node() or {
		return error('InvalidStateError: Selection.extend() has no anchor')
	}
	old_anchor_offset := selection.anchor_offset()
	mut new_range := Range.create(selection.document_)
	if !selection_same_node(node.root(), selection.range_.start_container().root()) {
		new_range.set_start(node, offset)!
		new_range.set_end(node, offset)!
	} else {
		position := position_of_boundary_point_relative_to_other_boundary_point(BoundaryPoint{
			node: old_anchor_node
			offset: old_anchor_offset
		}, BoundaryPoint{
			node: node
			offset: offset
		})
		if position != .after {
			new_range.set_start(old_anchor_node, old_anchor_offset)!
			new_range.set_end(node, offset)!
		} else {
			new_range.set_start(node, offset)!
			new_range.set_end(old_anchor_node, old_anchor_offset)!
		}
	}
	selection.set_range(new_range)
	new_focus_position := position_of_boundary_point_relative_to_other_boundary_point(BoundaryPoint{
		node: node
		offset: offset
	}, BoundaryPoint{
		node: old_anchor_node
		offset: old_anchor_offset
	})
	selection.direction_ = if new_focus_position == .before { .backwards } else { .forwards }
}

pub fn (mut selection Selection) set_base_and_extent(anchor_node &Node, anchor_offset int, focus_node &Node, focus_offset int) ! {
	if anchor_offset < 0 || anchor_offset > anchor_node.length() {
		return error('IndexSizeError: Selection anchor offset is out of range')
	}
	if focus_offset < 0 || focus_offset > focus_node.length() {
		return error('IndexSizeError: Selection focus offset is out of range')
	}
	if selection.document_ == unsafe { nil } {
		return
	}
	document_node := unsafe { &Node(selection.document_) }
	if voidptr(anchor_node.document()) != voidptr(selection.document_) || voidptr(focus_node.document()) != voidptr(selection.document_) || !document_node.is_shadow_including_inclusive_ancestor_of(anchor_node) || !document_node.is_shadow_including_inclusive_ancestor_of(focus_node) {
		return
	}
	position := position_of_boundary_point_relative_to_other_boundary_point(BoundaryPoint{
		node: anchor_node
		offset: anchor_offset
	}, BoundaryPoint{
		node: focus_node
		offset: focus_offset
	})
	mut new_range := Range.create(selection.document_)
	if position == .before {
		new_range.set_start(anchor_node, anchor_offset)!
		new_range.set_end(focus_node, focus_offset)!
	} else {
		new_range.set_start(focus_node, focus_offset)!
		new_range.set_end(anchor_node, anchor_offset)!
	}
	selection.set_range(new_range)
	selection.direction_ = if position == .after { .backwards } else { .forwards }
}

pub fn (mut selection Selection) select_all_children(node &Node) ! {
	if node.is_document_type() {
		return error('InvalidNodeTypeError: Selection.selectAllChildren() with DocumentType node')
	}
	if selection.document_ == unsafe { nil } || !selection_same_node(node.root(), unsafe { &Node(selection.document_) }) {
		return
	}
	mut new_range := Range.create(selection.document_)
	new_range.set_start(node, 0)!
	new_range.set_end(node, node.child_count())!
	selection.set_range(new_range)
	selection.direction_ = .forwards
}

pub fn (mut selection Selection) modify(alter ?string, direction ?string, granularity ?string) ! {
	anchor := selection.anchor_node() or { return }
	if !anchor.is_text() {
		return
	}
	alter_value := alter or { return }.to_lower()
	direction_value := direction or { return }.to_lower()
	granularity_value := granularity or { return }.to_lower()
	if alter_value != 'extend' && alter_value != 'move' {
		return
	}
	if direction_value !in ['forward', 'backward', 'left', 'right'] {
		return
	}
	if granularity_value !in ['character', 'word', 'sentence', 'line', 'paragraph', 'lineboundary',
		'sentenceboundary', 'paragraphboundary', 'documentboundary'] {
		return
	}
	if selection.is_empty() {
		return
	}
	text_node := unsafe { &Text(anchor) }
	text_direction := text_node.directionality() or { Directionality.ltr }
	mut forwards := direction_value == 'forward'
	if direction_value == 'right' && text_direction == .ltr {
		forwards = true
	}
	if direction_value == 'left' && text_direction == .rtl {
		forwards = true
	}
	collapse_selection := alter_value == 'move'
	if forwards {
		match granularity_value {
			'character' { selection.move_offset_to_next_character(collapse_selection) }
			'word' { selection.move_offset_to_next_word(collapse_selection) }
			else {}
		}
	} else {
		match granularity_value {
			'character' { selection.move_offset_to_previous_character(collapse_selection) }
			'word' { selection.move_offset_to_previous_word(collapse_selection) }
			else {}
		}
	}
}

pub fn (mut selection Selection) delete_from_document() ! {
	if selection.range_ != unsafe { nil } {
		mut range := unsafe { &Range(selection.range_) }
		range.delete_contents()!
	}
}

pub fn (selection &Selection) contains_node(node &Node, allow_partial_containment bool) bool {
	if selection.range_ == unsafe { nil } || selection.document_ == unsafe { nil } || !selection_same_node(node.root(), unsafe { &Node(selection.document_) }) {
		return false
	}
	if !allow_partial_containment {
		start_position := position_of_boundary_point_relative_to_other_boundary_point(selection.range_.start(), BoundaryPoint{
			node: node
			offset: 0
		})
		end_position := position_of_boundary_point_relative_to_other_boundary_point(selection.range_.end(), BoundaryPoint{
			node: node
			offset: node.length()
		})
		return start_position in [.before, .equal] && end_position in [.equal, .after]
	}
	start_position := position_of_boundary_point_relative_to_other_boundary_point(selection.range_.start(), BoundaryPoint{
		node: node
		offset: node.length()
	})
	end_position := position_of_boundary_point_relative_to_other_boundary_point(selection.range_.end(), BoundaryPoint{
		node: node
		offset: 0
	})
	return start_position in [.before, .equal] && end_position in [.equal, .after]
}

pub fn (selection &Selection) try_form_control_selected_text_for_stringifier() ?string {
	if selection.document_ != unsafe { nil } {
		if selected_text := selection.document_.selected_text_for_active_form_control() {
			return selected_text
		}
	}
	return none
}

pub fn (selection &Selection) to_string() string {
	if selected_text := selection.try_form_control_selected_text_for_stringifier() {
		return selected_text
	}
	if selection.range_ == unsafe { nil } {
		return ''
	}
	return selection.range_.to_string()
}

pub fn (selection &Selection) document() &Document {
	return selection.document_
}

pub fn (selection &Selection) range() ?&Range {
	if selection.range_ == unsafe { nil } {
		return none
	}
	return selection.range_
}

pub fn (mut selection Selection) set_range(range ?&Range) {
	new_range := range or { unsafe { &Range(nil) } }
	if (selection.range_ == unsafe { nil } && new_range == unsafe { nil }) || (selection.range_ != unsafe { nil } && new_range != unsafe { nil } && selection_same_range(selection.range_, new_range)) {
		return
	}
	if selection.range_ != unsafe { nil } {
		mut old_range := unsafe { &Range(selection.range_) }
		old_range.set_associated_selection(none)
	}
	selection.range_ = new_range
	if new_range != unsafe { nil } {
		mut mutable_range := unsafe { &Range(new_range) }
		mutable_range.set_associated_selection(&selection)
	}
	if selection.document_ != unsafe { nil } {
		mut document := unsafe { &Document(selection.document_) }
		document.reset_command_state_overrides()
		document.reset_command_value_overrides()
	}
}

pub fn (selection &Selection) cursor_position() ?&Position {
	if selection.range_ == unsafe { nil } || !selection.is_collapsed() {
		return none
	}
	return Position.create(selection.range_.start_container(), selection.range_.start_offset())
}

fn selection_utf16_substring(text string, start int, end int) string {
	units := utf16_code_units_from_string(text)
	safe_start := if start < 0 {
		0
	} else if start > units.len {
		units.len
	} else {
		start
	}
	safe_end := if end < safe_start {
		safe_start
	} else if end > units.len {
		units.len
	} else {
		end
	}
	return string_from_utf16_code_units(units[safe_start..safe_end])
}

pub fn (mut selection Selection) move_offset_to_next_character(collapse_selection bool) {
	anchor := selection.anchor_node() or { return }
	if !anchor.is_text() {
		return
	}
	text_node := unsafe { &Text(anchor) }
	if collapse_selection && !selection.is_collapsed() {
		anchor_offset := selection.anchor_offset()
		focus_offset := selection.focus_offset()
		selection.collapse(anchor, if anchor_offset > focus_offset {
			anchor_offset
		} else {
			focus_offset
		}) or { return }
		selection.reset_cursor_blink_cycle()
	} else if offset := text_node.grapheme_segmenter().next_boundary(selection.focus_offset()) {
		selection.move_focus_with_optional_collapse(anchor, offset, collapse_selection)
	}
	selection.scroll_focus_into_view()
}

pub fn (mut selection Selection) move_offset_to_previous_character(collapse_selection bool) {
	anchor := selection.anchor_node() or { return }
	if !anchor.is_text() {
		return
	}
	text_node := unsafe { &Text(anchor) }
	if collapse_selection && !selection.is_collapsed() {
		anchor_offset := selection.anchor_offset()
		focus_offset := selection.focus_offset()
		selection.collapse(anchor, if anchor_offset < focus_offset {
			anchor_offset
		} else {
			focus_offset
		}) or { return }
		selection.reset_cursor_blink_cycle()
	} else if offset := text_node.grapheme_segmenter().previous_boundary(selection.focus_offset()) {
		selection.move_focus_with_optional_collapse(anchor, offset, collapse_selection)
	}
	selection.scroll_focus_into_view()
}

pub fn (mut selection Selection) move_offset_to_next_word(collapse_selection bool) {
	anchor := selection.anchor_node() or { return }
	if !anchor.is_text() {
		return
	}
	text_node := unsafe { &Text(anchor) }
	for selection.focus_offset() < text_node.length() {
		old_offset := selection.focus_offset()
		offset := text_node.word_segmenter().next_boundary(old_offset) or { break }
		selection.move_focus_with_optional_collapse(anchor, offset, collapse_selection)
		word := selection_utf16_substring(text_node.data(), old_offset, offset)
		if !segmenter_should_continue_beyond_word(word) {
			break
		}
	}
	selection.scroll_focus_into_view()
}

pub fn (mut selection Selection) move_offset_to_previous_word(collapse_selection bool) {
	anchor := selection.anchor_node() or { return }
	if !anchor.is_text() {
		return
	}
	text_node := unsafe { &Text(anchor) }
	for selection.focus_offset() > 0 {
		old_offset := selection.focus_offset()
		offset := text_node.word_segmenter().previous_boundary(old_offset) or { break }
		selection.move_focus_with_optional_collapse(anchor, offset, collapse_selection)
		word := selection_utf16_substring(text_node.data(), offset, old_offset)
		if !segmenter_should_continue_beyond_word(word) {
			break
		}
	}
	selection.scroll_focus_into_view()
}

pub fn (mut selection Selection) move_offset_to_next_line(collapse_selection bool) {
	anchor := selection.anchor_node() or { return }
	if !anchor.is_text() {
		return
	}
	text_node := unsafe { &Text(anchor) }
	new_offset := compute_cursor_position_on_next_line(text_node.data(), selection.focus_offset()) or {
		return
	}
	selection.move_focus_with_optional_collapse(anchor, new_offset, collapse_selection)
	selection.scroll_focus_into_view()
}

pub fn (mut selection Selection) move_offset_to_previous_line(collapse_selection bool) {
	anchor := selection.anchor_node() or { return }
	if !anchor.is_text() {
		return
	}
	text_node := unsafe { &Text(anchor) }
	new_offset := compute_cursor_position_on_previous_line(text_node.data(), selection.focus_offset()) or { return }
	selection.move_focus_with_optional_collapse(anchor, new_offset, collapse_selection)
	selection.scroll_focus_into_view()
}

fn (mut selection Selection) move_focus_with_optional_collapse(node &Node, offset int, collapse_selection bool) {
	if collapse_selection {
		selection.collapse(node, offset) or { return }
		selection.reset_cursor_blink_cycle()
		return
	}
	anchor := selection.anchor_node() or { return }
	selection.set_base_and_extent(anchor, selection.anchor_offset(), node, offset) or { return }
}

fn (selection &Selection) reset_cursor_blink_cycle() {
	if selection.document_ != unsafe { nil } {
		mut document := unsafe { &Document(selection.document_) }
		document.reset_cursor_blink_cycle()
	}
}

pub fn (selection &Selection) scroll_focus_into_view() {
	if selection.focus_node() == none || selection.document_ == unsafe { nil } {
		return
	}
	mut document := unsafe { &Document(selection.document_) }
	document.update_layout(.scroll_cursor_into_view)
	// The translated paint layer does not yet expose Paintable's offset-scrolling hook.
}
