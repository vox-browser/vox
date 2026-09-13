// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause
//
// Translated from Libraries/LibWeb/Selection/Selection.{h,cpp}.
module dom

import encoding.utf8

fn selection_same_node(a &Node, b &Node) bool {
	return voidptr(a) == voidptr(b)
}

fn selection_same_range(a &Range, b &Range) bool {
	return voidptr(a) == voidptr(b)
}

pub enum SelectionAlteration {
	move
	extend
}

pub enum CaretNavigationDirection {
	forward
	backward
}

pub enum SelectionGranularity {
	character
	word
	line
	page
	line_boundary
	document_boundary
}

pub struct CaretLocation {
pub:
	node     &Node
	offset   int
	affinity TextAffinity = .downstream
}

enum WordSegmentKind {
	word
	punctuation
	separator
}

fn word_segment_kind(segment string) WordSegmentKind {
	runes := segment.runes()
	if runes.len > 0 && runes.all(utf8.is_space(it)) {
		return .separator
	}
	if runes.len > 0 && runes.all(utf8.is_rune_global_punct(it)) {
		return .punctuation
	}
	return .word
}

fn text_node_has_rendered_text(text &Text) bool {
	return text.data().len > 0
}

fn is_empty_line_break(node &Node) bool {
	element := node.as_element() or { return false }
	return element.local_name() == 'br' && node.is_editable()
}

fn is_atomic_inline_caret_host(node &Node) bool {
	element := node.as_element() or { return false }
	return node.parent() != none && node.is_editable()
		&& element.local_name() in ['img', 'input', 'textarea', 'select', 'canvas', 'iframe',
		'video', 'audio', 'object', 'embed']
}

fn is_empty_line_host(node &Node) bool {
	if node.as_element() == none || !node.is_editable_or_editing_host() {
		return false
	}
	mut descendant := node.next_in_pre_order(node)
	for descendant != none {
		current := descendant or { break }
		if current.is_text() && text_node_has_rendered_text(unsafe { &Text(current) }) {
			return false
		}
		if is_atomic_inline_caret_host(current) {
			return false
		}
		descendant = current.next_in_pre_order(node)
	}
	return true
}

fn boundary_visual_lines_share_line(before &Text, after &Text) bool {
	before_host := before.as_node().editing_host() or { return false }
	after_host := after.as_node().editing_host() or { return false }
	return selection_same_node(before_host, after_host) && !before.data().ends_with('\n')
		&& !after.data().starts_with('\n')
}

fn boundary_visual_lines_share_inline_context(before &Text, after &Text) bool {
	before_host := before.as_node().editing_host() or { return false }
	after_host := after.as_node().editing_host() or { return false }
	return selection_same_node(before_host, after_host)
}

fn canonical_location_at_outer_edge_of_inline_content(text &Text, block &Node, direction CaretNavigationDirection) CaretLocation {
	mut node := text.as_node()
	for {
		parent := node.parent() or { break }
		offset := if direction == .forward { node.index() } else { node.index() + 1 }
		if selection_same_node(parent, block) {
			return CaretLocation{ node: parent, offset: offset }
		}
		node = parent
	}
	return CaretLocation{
		node: text.as_node()
		offset: if direction == .forward { 0 } else { text.length() }
	}
}

pub struct CaretNavigator {
pub:
	document &Document
}

pub fn CaretNavigator.new(document &Document) CaretNavigator {
	return CaretNavigator{document}
}

fn (navigator &CaretNavigator) adjacent_caret_host(from &Node, editing_host &Node, direction CaretNavigationDirection) ?&Node {
	_ = navigator
	mut node := ?&Node(from)
	for node != none {
		current := node or { break }
		node = if direction == .forward {
			current.next_in_pre_order(editing_host)
		} else {
			current.previous_in_pre_order()
		}
		candidate := node or { return none }
		if selection_same_node(candidate, editing_host)
			|| !editing_host.is_inclusive_ancestor_of(candidate) {
			return none
		}
		if candidate.is_inclusive_ancestor_of(from) {
			continue
		}
		if candidate.is_text() && candidate.is_editable()
			&& text_node_has_rendered_text(unsafe { &Text(candidate) }) {
			return candidate
		}
		if is_atomic_inline_caret_host(candidate) || is_empty_line_host(candidate)
			|| is_empty_line_break(candidate) {
			return candidate
		}
	}
	return none
}

fn CaretNavigator.navigation_origin(location CaretLocation, direction CaretNavigationDirection) &Node {
	if direction == .forward && location.offset > 0 {
		if child_before := location.node.child_at_index(location.offset - 1) {
			return child_before
		}
	}
	if direction == .backward {
		if child_after := location.node.child_at_index(location.offset) {
			return child_after
		}
	}
	return location.node
}

pub fn (navigator &CaretNavigator) inline_coordinate(location CaretLocation) ?f64 {
	_ = navigator
	if location.node.is_text() {
		text := unsafe { &Text(location.node) }
		if coordinate := cursor_inline_coordinate(text, location.offset, location.affinity) {
			return coordinate
		}
		line_start := find_line_start(text.data(), location.offset)
		return f64(location.offset - line_start)
	}
	return f64(location.offset)
}

fn (navigator &CaretNavigator) move_to_adjacent_caret_host(location CaretLocation, direction CaretNavigationDirection) ?CaretLocation {
	editing_host := location.node.editing_host() or { return none }
	origin := CaretNavigator.navigation_origin(location, direction)
	mut target := ?&Node(none)
	mut adjacent_child := ?&Node(none)
	if direction == .forward {
		adjacent_child = location.node.child_at_index(location.offset)
	} else if location.offset > 0 {
		adjacent_child = location.node.child_at_index(location.offset - 1)
	}
	if child := adjacent_child {
		if child.is_text() || is_atomic_inline_caret_host(child) || is_empty_line_host(child)
			|| is_empty_line_break(child) {
			target = child
		}
	}
	if target == none {
		target = navigator.adjacent_caret_host(origin, editing_host, direction)
	}
	candidate := target or { return none }
	if is_atomic_inline_caret_host(candidate) {
		parent := candidate.parent() or { return none }
		return CaretLocation{
			node: parent
			offset: candidate.index() + if direction == .forward { 1 } else { 0 }
		}
	}
	if is_empty_line_break(candidate) {
		parent := candidate.parent() or { return none }
		return CaretLocation{ node: parent, offset: candidate.index() }
	}
	if candidate.is_text() {
		text := unsafe { &Text(candidate) }
		position := if direction == .forward {
			cursor_position_at_visual_start(text)
		} else {
			cursor_position_at_visual_end(text)
		}
		if destination := position {
			return CaretLocation{
				node: candidate
				offset: destination.offset
				affinity: destination.affinity
			}
		}
		return CaretLocation{
			node: candidate
			offset: if direction == .forward { 0 } else { text.length() }
		}
	}
	return CaretLocation{ node: candidate, offset: 0 }
}

pub fn (navigator &CaretNavigator) canonical_location_for_editing(location CaretLocation) CaretLocation {
	_ = navigator
	mut node := location.node
	mut offset := location.offset
	if node.is_comment() || node.type_() == .processing_instruction_node {
		parent := node.parent() or { return location }
		offset = node.index()
		node = parent
	} else if !node.is_element() {
		return location
	}
	for node.is_element() {
		mut before := ?&Node(none)
		if offset > 0 {
			before = node.child_at_index(offset - 1)
		}
		after := node.child_at_index(offset)
		if candidate := after {
			if candidate.is_editable() && (candidate.is_text() || candidate.has_children()) {
				node = candidate
				offset = 0
				continue
			}
		}
		if candidate := before {
			if candidate.is_editable() && (candidate.is_text() || candidate.has_children()) {
				node = candidate
				offset = candidate.length()
				continue
			}
		}
		break
	}
	return CaretLocation{ node: node, offset: offset, affinity: location.affinity }
}

pub fn (navigator &CaretNavigator) upstream_equivalent_location(location CaretLocation) CaretLocation {
	return navigator.canonical_location_for_extension(location, .backward) or { location }
}

pub fn (navigator &CaretNavigator) canonical_location_for_extension(location CaretLocation, direction CaretNavigationDirection) ?CaretLocation {
	if !location.node.is_text() {
		return none
	}
	text := unsafe { &Text(location.node) }
	if (direction == .forward && location.offset != text.length())
		|| (direction == .backward && location.offset != 0) {
		return none
	}
	editing_host := location.node.editing_host() or { return none }
	target := navigator.adjacent_caret_host(location.node, editing_host, direction) or { return none }
	if is_atomic_inline_caret_host(target) {
		parent := target.parent() or { return none }
		return CaretLocation{
			node: parent
			offset: target.index() + if direction == .backward { 1 } else { 0 }
		}
	}
	if !target.is_text() {
		return none
	}
	target_text := unsafe { &Text(target) }
	shares_line := if direction == .forward {
		boundary_visual_lines_share_line(text, target_text)
	} else {
		boundary_visual_lines_share_line(target_text, text)
	}
	if !shares_line {
		return none
	}
	return CaretLocation{
		node: target
		offset: if direction == .forward { 0 } else { target_text.length() }
	}
}

fn (_ &CaretNavigator) location_after_atomic_inline(atomic_inline &Node) ?CaretLocation {
	parent := atomic_inline.parent() or { return none }
	return CaretLocation{ node: parent, offset: atomic_inline.index() + 1 }
}

fn (navigator &CaretNavigator) location_before_atomic_inline(atomic_inline &Node, alteration SelectionAlteration) ?CaretLocation {
	parent := atomic_inline.parent() or { return none }
	if alteration == .extend {
		return CaretLocation{ node: parent, offset: atomic_inline.index() }
	}
	editing_host := atomic_inline.editing_host() or {
		return CaretLocation{ node: parent, offset: atomic_inline.index() }
	}
	previous := navigator.adjacent_caret_host(atomic_inline, editing_host, .backward) or {
		return CaretLocation{ node: parent, offset: atomic_inline.index() }
	}
	if previous.is_text() {
		return CaretLocation{ node: previous, offset: previous.length() }
	}
	return CaretLocation{ node: parent, offset: atomic_inline.index() }
}

fn (navigator &CaretNavigator) canonicalize_backward_word_location(location CaretLocation, alteration SelectionAlteration) ?CaretLocation {
	if alteration == .extend || location.offset != 0 || !location.node.is_text() {
		return location
	}
	text := unsafe { &Text(location.node) }
	editing_host := location.node.editing_host() or { return location }
	previous := navigator.adjacent_caret_host(location.node, editing_host, .backward) or {
		return location
	}
	if !previous.is_text() {
		return location
	}
	previous_text := unsafe { &Text(previous) }
	if !boundary_visual_lines_share_inline_context(previous_text, text) {
		return location
	}
	return CaretLocation{ node: previous, offset: previous.length() }
}

fn (navigator &CaretNavigator) move_by_word(initial_location CaretLocation, alteration SelectionAlteration, direction CaretNavigationDirection) ?CaretLocation {
	mut location := initial_location
	if !location.node.is_text() {
		return navigator.move_to_adjacent_caret_host(location, direction)
	}
	mut text := unsafe { &Text(location.node) }
	for {
		next_offset := if direction == .forward {
			text.word_segmenter().next_boundary(location.offset)
		} else {
			text.word_segmenter().previous_boundary(location.offset)
		}
		if offset := next_offset {
			segment := if direction == .forward {
				selection_utf16_substring(text.data(), location.offset, offset)
			} else {
				selection_utf16_substring(text.data(), offset, location.offset)
			}
			location = CaretLocation{ node: text.as_node(), offset: offset }
			if word_segment_kind(segment) != .separator {
				if direction == .backward {
					return navigator.canonicalize_backward_word_location(location, alteration)
				}
				return location
			}
			continue
		}
		editing_host := text.as_node().editing_host() or { return location }
		adjacent := navigator.adjacent_caret_host(text.as_node(), editing_host, direction) or {
			return location
		}
		if is_atomic_inline_caret_host(adjacent) {
			if direction == .forward {
				return navigator.location_after_atomic_inline(adjacent)
			}
			return navigator.location_before_atomic_inline(adjacent, alteration)
		}
		if !adjacent.is_text() {
			return location
		}
		adjacent_text := unsafe { &Text(adjacent) }
		if !boundary_visual_lines_share_inline_context(text, adjacent_text) {
			return location
		}
		text = adjacent_text
		location = CaretLocation{
			node: adjacent
			offset: if direction == .forward { 0 } else { adjacent.length() }
		}
	}
	return none
}

fn (navigator &CaretNavigator) move_to_editing_host_boundary(location CaretLocation, direction CaretNavigationDirection) ?CaretLocation {
	editing_host := location.node.editing_host() or { return none }
	mut target := navigator.adjacent_caret_host(editing_host, editing_host, .forward) or {
		return none
	}
	if direction == .forward {
		for {
			next := navigator.adjacent_caret_host(target, editing_host, .forward) or { break }
			target = next
		}
	}
	if target.is_text() {
		return CaretLocation{
			node: target
			offset: if direction == .forward { target.length() } else { 0 }
		}
	}
	if is_atomic_inline_caret_host(target) {
		parent := target.parent() or { return none }
		return CaretLocation{
			node: parent
			offset: target.index() + if direction == .forward { 1 } else { 0 }
		}
	}
	return CaretLocation{ node: target, offset: 0 }
}

fn (navigator &CaretNavigator) move_by_page(location CaretLocation, direction CaretNavigationDirection, inline_coordinate f64) ?CaretLocation {
	mut current := location
	mut moved := false
	for _ in 0 .. 10 {
		next := navigator.move(current, .move, direction, .line, inline_coordinate) or { break }
		if selection_same_node(next.node, current.node) && next.offset == current.offset {
			break
		}
		current = next
		moved = true
	}
	if moved {
		return current
	}
	return none
}

pub fn (navigator &CaretNavigator) move(location CaretLocation, alteration SelectionAlteration, direction CaretNavigationDirection, granularity SelectionGranularity, preferred_inline_coordinate ?f64) ?CaretLocation {
	if granularity == .document_boundary {
		return navigator.move_to_editing_host_boundary(location, direction)
	}
	if granularity == .page {
		coordinate := preferred_inline_coordinate or { return none }
		return navigator.move_by_page(location, direction, coordinate)
	}
	if granularity == .word {
		return navigator.move_by_word(location, alteration, direction)
	}
	if granularity == .line_boundary && location.node.is_text() {
		text := unsafe { &Text(location.node) }
		position := if direction == .forward {
			find_visual_line_end(text, location.offset, location.affinity)
		} else {
			CursorLinePosition{
				offset: find_visual_line_start(text, location.offset, location.affinity)
			}
		}
		return CaretLocation{
			node: location.node
			offset: position.offset
			affinity: position.affinity
		}
	}
	if granularity == .line && location.node.is_text() {
		text := unsafe { &Text(location.node) }
		position := if direction == .forward {
			compute_cursor_position_on_next_line(text, location.offset, location.affinity)
		} else {
			compute_cursor_position_on_previous_line(text, location.offset, location.affinity)
		}
		if destination := position {
			if destination.offset != location.offset || destination.affinity != location.affinity {
				return CaretLocation{
					node: location.node
					offset: destination.offset
					affinity: destination.affinity
				}
			}
		}
		return navigator.move_to_adjacent_caret_host(location, direction)
	}
	if granularity == .character && location.node.is_text() {
		text := unsafe { &Text(location.node) }
		position := if direction == .forward {
			compute_cursor_position_on_next_character(text, location.offset, location.affinity)
		} else {
			compute_cursor_position_on_previous_character(text, location.offset, location.affinity)
		}
		if destination := position {
			return CaretLocation{
				node: location.node
				offset: destination.offset
				affinity: destination.affinity
			}
		}
	}
	adjacent := navigator.move_to_adjacent_caret_host(location, direction) or { return none }
	if granularity == .character && location.node.is_text() && adjacent.node.is_text() {
		origin_text := unsafe { &Text(location.node) }
		adjacent_text := unsafe { &Text(adjacent.node) }
		shares_line := if direction == .forward {
			boundary_visual_lines_share_line(origin_text, adjacent_text)
		} else {
			boundary_visual_lines_share_line(adjacent_text, origin_text)
		}
		if shares_line {
			position := if direction == .forward {
				compute_cursor_position_on_next_character(adjacent_text, adjacent.offset,
					adjacent.affinity)
			} else {
				compute_cursor_position_on_previous_character(adjacent_text, adjacent.offset,
					adjacent.affinity)
			}
			if destination := position {
				return CaretLocation{
					node: adjacent.node
					offset: destination.offset
					affinity: destination.affinity
				}
			}
		}
	}
	return adjacent
}

pub struct SelectionModifier {
pub:
	selection &Selection
}

pub fn SelectionModifier.new(selection &Selection) SelectionModifier {
	return SelectionModifier{selection}
}

pub fn (modifier &SelectionModifier) modify(alteration SelectionAlteration, direction CaretNavigationDirection, granularity SelectionGranularity) {
	mut selection := unsafe { &Selection(modifier.selection) }
	range := selection.range() or { return }
	focus := selection.focus_node() or { return }
	origin := CaretLocation{
		node: focus
		offset: selection.focus_offset()
		affinity: selection.focus_affinity()
	}
	vertical := granularity in [.line, .page]
	mut preferred := selection.preferred_inline_coordinate_
	navigator := CaretNavigator.new(selection.document())
	if vertical && preferred == none {
		preferred = navigator.inline_coordinate(origin)
	} else if !vertical {
		selection.preferred_inline_coordinate_ = none
	}

	mut destination := ?CaretLocation(none)
	mut canonical_anchor := ?CaretLocation(none)
	if alteration == .move && granularity == .character && !selection.is_collapsed() {
		boundary := if direction == .forward { range.end() } else { range.start() }
		destination = CaretLocation{ node: boundary.node, offset: boundary.offset }
	} else {
		if alteration == .extend && selection.is_collapsed() {
			canonical_anchor = navigator.canonical_location_for_extension(origin, direction)
		}
		destination = navigator.move(origin, alteration, direction, granularity, preferred)
	}
	target := destination or { return }
	if alteration == .move {
		selection.collapse(target.node, target.offset) or { return }
		selection.reset_cursor_blink_cycle()
	} else {
		anchor := canonical_anchor or {
			anchor_node := selection.anchor_node() or { return }
			CaretLocation{ node: anchor_node, offset: selection.anchor_offset() }
		}
		selection.set_base_and_extent(anchor.node, anchor.offset, target.node, target.offset) or {
			return
		}
	}
	selection.set_focus_affinity(target.affinity)
	if vertical {
		selection.preferred_inline_coordinate_ = preferred
	}
	selection.scroll_focus_into_view()
}

pub fn (modifier &SelectionModifier) select_all() {
	mut selection := unsafe { &Selection(modifier.selection) }
	focus := selection.focus_node() or { return }
	origin := CaretLocation{
		node: focus
		offset: selection.focus_offset()
		affinity: selection.focus_affinity()
	}
	navigator := CaretNavigator.new(selection.document())
	start := navigator.move(origin, .move, .backward, .document_boundary, none) or { return }
	end := navigator.move(origin, .move, .forward, .document_boundary, none) or { return }
	selection.set_base_and_extent(start.node, start.offset, end.node, end.offset) or { return }
	selection.preferred_inline_coordinate_ = none
	selection.reset_cursor_blink_cycle()
	selection.scroll_focus_into_view()
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
	focus := selection.focus_node() or { return }
	text_direction := if focus.is_text() {
		unsafe { &Text(focus) }.directionality() or { Directionality.ltr }
	} else if element := focus.as_element() {
		element.directionality()
	} else {
		Directionality.ltr
	}
	mut forwards := direction_value == 'forward'
	if direction_value == 'right' && text_direction == .ltr {
		forwards = true
	}
	if direction_value == 'left' && text_direction == .rtl {
		forwards = true
	}
	selection.direction_ = if forwards { .forwards } else { .backwards }
	mut granularity_kind := ?SelectionGranularity(none)
	match granularity_value {
		'character' { granularity_kind = .character }
		'word' { granularity_kind = .word }
		'line' { granularity_kind = .line }
		'lineboundary' { granularity_kind = .line_boundary }
		else {}
	}
	if kind := granularity_kind {
		modifier := SelectionModifier.new(&selection)
		modifier.modify(if alter_value == 'move' { .move } else { .extend },
			if forwards { .forward } else { .backward }, kind)
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
	if !selection_same_node(selection.range_.start_container().shadow_including_root(),
		unsafe { &Node(selection.document_) }) {
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

pub fn (selection &Selection) focus_affinity() TextAffinity {
	return selection.focus_affinity_
}

pub fn (mut selection Selection) set_focus_affinity(affinity TextAffinity) {
	selection.focus_affinity_ = affinity
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
	selection.focus_affinity_ = .downstream
	selection.preferred_inline_coordinate_ = none
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
	SelectionModifier.new(&selection).modify(if collapse_selection { .move } else { .extend },
		.forward, .character)
}

pub fn (mut selection Selection) move_offset_to_previous_character(collapse_selection bool) {
	SelectionModifier.new(&selection).modify(if collapse_selection { .move } else { .extend },
		.backward, .character)
}

pub fn (mut selection Selection) move_offset_to_next_word(collapse_selection bool) {
	SelectionModifier.new(&selection).modify(if collapse_selection { .move } else { .extend },
		.forward, .word)
}

pub fn (mut selection Selection) move_offset_to_previous_word(collapse_selection bool) {
	SelectionModifier.new(&selection).modify(if collapse_selection { .move } else { .extend },
		.backward, .word)
}

pub fn (mut selection Selection) move_offset_to_next_line(collapse_selection bool) {
	SelectionModifier.new(&selection).modify(if collapse_selection { .move } else { .extend },
		.forward, .line)
}

pub fn (mut selection Selection) move_offset_to_previous_line(collapse_selection bool) {
	SelectionModifier.new(&selection).modify(if collapse_selection { .move } else { .extend },
		.backward, .line)
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
	focus := selection.focus_node() or { return }
	paintable := focus.paintable() or { return }
	paintable.scroll_ancestor_to_offset_into_view(selection.focus_offset())
}
