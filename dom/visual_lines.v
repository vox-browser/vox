// Copyright (c) 2026-present, the Ladybird developers
// SPDX-License-Identifier: BSD-2-Clause

// Translation of LibWeb/VisualLines.{h,cpp}. Layout supplies a compact line and
// caret-stop projection on demand; all offsets remain UTF-16 units.
module dom

import math

pub struct CursorLinePosition {
pub:
	offset   int
	affinity TextAffinity = .downstream
}

pub fn (node &LayoutNode) visual_lines() []VisualLine {
	provider := node.visual_lines_callback
	if provider != unsafe { nil } {
		mut current := unsafe { &LayoutNode(node) }
		// A callback is consumed once per committed attachment. Clear it before
		// entering the provider so reentrant readers see the existing snapshot.
		current.visual_lines_callback = unsafe { nil }
		current.visual_lines_ = provider(current.layout_handle)
	}
	return node.visual_lines_
}

pub fn collect_visual_lines(dom_node &Text) []VisualLine {
	layout_node := dom_node.as_node().layout_node() or { return []VisualLine{} }
	lines := layout_node.visual_lines()
	mut result := []VisualLine{cap: lines.len}
	for line in lines {
		result << VisualLine{
			start_offset: line.start_offset
			end_offset: line.end_offset
			end_offset_with_trailing_whitespace: line.end_offset_with_trailing_whitespace
			has_fragments: line.has_fragments
			owner_paintable: line.owner_paintable
			line_index: line.line_index
			caret_stops: line.caret_stops.clone()
		}
	}
	return result
}

fn visual_lines_with_up_to_date_layout(dom_node &Text) []VisualLine {
	mut document := unsafe { &Document(dom_node.as_node().document()) }
	document.update_layout_if_needed_for_node(dom_node.as_node(), .cursor_line_navigation)
	return collect_visual_lines(dom_node)
}

fn visual_line_index_for_offset(lines []VisualLine, offset int, affinity TextAffinity) ?int {
	mut boundary_match := ?int(none)
	for index, line in lines {
		if offset < line.start_offset || offset > line.end_offset_with_trailing_whitespace {
			continue
		}
		if affinity == .downstream && offset == line.end_offset_with_trailing_whitespace {
			if boundary_match == none {
				boundary_match = index
			}
			continue
		}
		return index
	}
	if boundary_match != none {
		return boundary_match
	}
	if lines.len == 0 {
		return none
	}
	mut result := ?int(none)
	for index, line in lines {
		if line.start_offset <= offset {
			result = index
		}
	}
	return result or { 0 }
}

fn affinity_for_offset_on_line(lines []VisualLine, line_index int, offset int) TextAffinity {
	if line_index + 1 < lines.len && offset >= lines[line_index + 1].start_offset {
		return .upstream
	}
	return .downstream
}

fn offset_is_soft_wrap_boundary(lines []VisualLine, offset int) bool {
	for index := 0; index + 1 < lines.len; index++ {
		if lines[index].end_offset_with_trailing_whitespace == offset
			&& lines[index + 1].start_offset == offset {
			return true
		}
	}
	return false
}

fn affinity_for_moving_right(lines []VisualLine, new_offset int) TextAffinity {
	for index, line in lines {
		if new_offset > line.end_offset
			&& new_offset <= line.end_offset_with_trailing_whitespace {
			return .upstream
		}
		if new_offset == line.end_offset_with_trailing_whitespace && index + 1 < lines.len
			&& lines[index + 1].start_offset == new_offset {
			return .upstream
		}
	}
	return .downstream
}

fn coordinate_for_offset(stops []VisualCaretStop, offset int) ?f64 {
	if stops.len == 0 {
		return none
	}
	for stop in stops {
		if stop.offset == offset {
			return stop.inline_coordinate
		}
	}
	if offset <= stops[0].offset {
		return stops[0].inline_coordinate
	}
	for index := 1; index < stops.len; index++ {
		if offset < stops[index].offset {
			before := stops[index - 1]
			after := stops[index]
			span := after.offset - before.offset
			if span <= 0 {
				return after.inline_coordinate
			}
			progress := f64(offset - before.offset) / f64(span)
			return before.inline_coordinate + (after.inline_coordinate - before.inline_coordinate) * progress
		}
	}
	return stops.last().inline_coordinate
}

fn caret_inline_coordinate_for_line(line VisualLine, offset int) ?f64 {
	if !line.has_fragments {
		return none
	}
	return coordinate_for_offset(line.caret_stops, offset)
}

fn offset_in_visual_line_closest_to_inline_coordinate(line VisualLine,
	inline_coordinate ?f64) int {
	coordinate := inline_coordinate or { return line.start_offset }
	if !line.has_fragments || line.caret_stops.len == 0 {
		return line.start_offset
	}
	mut result := line.caret_stops[0].offset
	mut best_distance := math.abs(line.caret_stops[0].inline_coordinate - coordinate)
	for stop in line.caret_stops[1..] {
		distance := math.abs(stop.inline_coordinate - coordinate)
		// An exact midpoint resolves to the later edge, so equal distances
		// replace the earlier candidate.
		if distance <= best_distance {
			best_distance = distance
			result = stop.offset
		}
	}
	return result
}

pub fn compute_cursor_position_on_next_line(dom_node &Text, current_offset int,
	affinity TextAffinity) ?CursorLinePosition {
	lines := visual_lines_with_up_to_date_layout(dom_node)
	layout_node := dom_node.as_node().layout_node() or { return none }
	if !layout_node.is_text_node() {
		return none
	}
	line_index := visual_line_index_for_offset(lines, current_offset, affinity) or {
		return CursorLinePosition{offset: dom_node.length()}
	}
	if line_index + 1 >= lines.len {
		return CursorLinePosition{offset: dom_node.length()}
	}
	inline_coordinate := caret_inline_coordinate_for_line(lines[line_index], current_offset)
	new_offset := offset_in_visual_line_closest_to_inline_coordinate(lines[line_index + 1],
		inline_coordinate)
	return CursorLinePosition{
		offset: new_offset
		affinity: affinity_for_offset_on_line(lines, line_index + 1, new_offset)
	}
}

pub fn compute_cursor_position_on_previous_line(dom_node &Text, current_offset int,
	affinity TextAffinity) ?CursorLinePosition {
	lines := visual_lines_with_up_to_date_layout(dom_node)
	layout_node := dom_node.as_node().layout_node() or { return none }
	if !layout_node.is_text_node() {
		return none
	}
	line_index := visual_line_index_for_offset(lines, current_offset, affinity) or {
		return CursorLinePosition{offset: 0}
	}
	if line_index == 0 {
		return CursorLinePosition{offset: 0}
	}
	inline_coordinate := caret_inline_coordinate_for_line(lines[line_index], current_offset)
	new_offset := offset_in_visual_line_closest_to_inline_coordinate(lines[line_index - 1],
		inline_coordinate)
	return CursorLinePosition{
		offset: new_offset
		affinity: affinity_for_offset_on_line(lines, line_index - 1, new_offset)
	}
}

pub fn compute_cursor_position_on_next_character(dom_node &Text, current_offset int,
	affinity TextAffinity) ?CursorLinePosition {
	lines := visual_lines_with_up_to_date_layout(dom_node)
	if affinity == .upstream && offset_is_soft_wrap_boundary(lines, current_offset) {
		return CursorLinePosition{offset: current_offset}
	}
	next_offset := dom_node.grapheme_segmenter().next_boundary(current_offset) or { return none }
	return CursorLinePosition{
		offset: next_offset
		affinity: affinity_for_moving_right(lines, next_offset)
	}
}

pub fn compute_cursor_position_on_previous_character(dom_node &Text, current_offset int,
	affinity TextAffinity) ?CursorLinePosition {
	lines := visual_lines_with_up_to_date_layout(dom_node)
	if affinity == .downstream && offset_is_soft_wrap_boundary(lines, current_offset) {
		return CursorLinePosition{
			offset: current_offset
			affinity: .upstream
		}
	}
	previous_offset := dom_node.grapheme_segmenter().previous_boundary(current_offset) or {
		return none
	}
	return CursorLinePosition{offset: previous_offset}
}

pub fn cursor_inline_coordinate(dom_node &Text, offset int, affinity TextAffinity) ?f64 {
	lines := visual_lines_with_up_to_date_layout(dom_node)
	line_index := visual_line_index_for_offset(lines, offset, affinity) or { return none }
	return caret_inline_coordinate_for_line(lines[line_index], offset)
}

pub fn cursor_position_at_visual_start(dom_node &Text) ?CursorLinePosition {
	lines := visual_lines_with_up_to_date_layout(dom_node)
	if lines.len == 0 {
		return none
	}
	offset := lines[0].start_offset
	return CursorLinePosition{
		offset: offset
		affinity: affinity_for_offset_on_line(lines, 0, offset)
	}
}

pub fn cursor_position_at_visual_end(dom_node &Text) ?CursorLinePosition {
	lines := visual_lines_with_up_to_date_layout(dom_node)
	if lines.len == 0 {
		return none
	}
	line_index := lines.len - 1
	offset := lines[line_index].end_offset
	return CursorLinePosition{
		offset: offset
		affinity: affinity_for_offset_on_line(lines, line_index, offset)
	}
}

pub fn cursor_position_on_first_line_closest_to(dom_node &Text,
	inline_coordinate ?f64) ?CursorLinePosition {
	lines := visual_lines_with_up_to_date_layout(dom_node)
	if lines.len == 0 {
		return none
	}
	offset := offset_in_visual_line_closest_to_inline_coordinate(lines[0], inline_coordinate)
	return CursorLinePosition{
		offset: offset
		affinity: affinity_for_offset_on_line(lines, 0, offset)
	}
}

pub fn cursor_position_on_last_line_closest_to(dom_node &Text,
	inline_coordinate ?f64) ?CursorLinePosition {
	lines := visual_lines_with_up_to_date_layout(dom_node)
	if lines.len == 0 {
		return none
	}
	line_index := lines.len - 1
	offset := offset_in_visual_line_closest_to_inline_coordinate(lines[line_index],
		inline_coordinate)
	return CursorLinePosition{
		offset: offset
		affinity: affinity_for_offset_on_line(lines, line_index, offset)
	}
}

pub fn find_visual_line_start(dom_node &Text, offset int, affinity TextAffinity) int {
	lines := visual_lines_with_up_to_date_layout(dom_node)
	if line_index := visual_line_index_for_offset(lines, offset, affinity) {
		return lines[line_index].start_offset
	}
	return find_line_start(dom_node.data(), offset)
}

pub fn find_visual_line_end(dom_node &Text, offset int,
	affinity TextAffinity) CursorLinePosition {
	lines := visual_lines_with_up_to_date_layout(dom_node)
	if line_index := visual_line_index_for_offset(lines, offset, affinity) {
		end_offset := lines[line_index].end_offset_with_trailing_whitespace
		return CursorLinePosition{
			offset: end_offset
			affinity: affinity_for_offset_on_line(lines, line_index, end_offset)
		}
	}
	return CursorLinePosition{offset: find_line_end(dom_node.data(), offset)}
}
