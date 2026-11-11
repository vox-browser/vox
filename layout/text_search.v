// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// DOM/Document.cpp and Rust/src/layout/text_queries.rs: rendered-text search.
module layout

import dom

struct SearchTextPosition {
	node &TextNode
	offset int
}

struct SearchTextRun {
mut:
	start int
	end int
	from SearchTextPosition
	to SearchTextPosition
}

struct SearchMappedText {
mut:
	units []u16
	runs []SearchTextRun
}

fn (run &SearchTextRun) is_linear() bool {
	return voidptr(run.from.node) == voidptr(run.to.node) && run.to.offset - run.from.offset == run.end - run.start
}

fn (mut text SearchMappedText) append(unit u16, from SearchTextPosition, to SearchTextPosition) {
	start := text.units.len
	text.units << unit
	if text.runs.len > 0 {
		mut last := &text.runs[text.runs.len - 1]
		if voidptr(last.to.node) == voidptr(from.node) && last.to.offset == from.offset && last.is_linear()
			&& voidptr(from.node) == voidptr(to.node) && to.offset - from.offset == 1 {
			last.end = text.units.len
			last.to = to
			return
		}
	}
	text.runs << SearchTextRun{ start: start, end: text.units.len, from: from, to: to }
}

fn (text &SearchMappedText) position(offset int, at_end bool) ?SearchTextPosition {
	if offset > text.units.len || text.runs.len == 0 { return none }
	mut index := 0
	for index < text.runs.len && if at_end { text.runs[index].end < offset } else { text.runs[index].end <= offset } {
		index++
	}
	if index == text.runs.len { index-- }
	run := text.runs[index]
	if offset == run.end { return run.to }
	return SearchTextPosition{ node: run.from.node, offset: run.from.offset + offset - run.start }
}

fn (text &SearchMappedText) dom_range(start int, end int) ?&dom.Range {
	from := text.position(start, false) or { return none }
	to := text.position(end, true) or { return none }
	start_node := from.node.dom_node() or { return none }
	end_node := to.node.dom_node() or { return none }
	start_offset := from.node.source_offset_for_rendered_text_offset(from.offset, .start)
	end_offset := to.node.source_offset_for_rendered_text_offset(to.offset, .end)
	if start_node.root() != end_node.root() || !start_node.is_connected() || !end_node.is_connected()
		|| start_offset > start_node.length() || end_offset > end_node.length() { return none }
	return dom.Range.create_from_boundary_points(start_node, start_offset, end_node, end_offset)
}

struct SearchTextBuilder {
mut:
	blocks []SearchMappedText
	current SearchMappedText
	pending_space ?SearchTextRun
}

fn (mut builder SearchTextBuilder) flush() {
	if builder.current.units.len > 0 { builder.blocks << builder.current }
	builder.current = SearchMappedText{}
	builder.pending_space = none
}

fn (mut builder SearchTextBuilder) append(node &TextNode, collapse bool) {
	for offset, unit in utf16_code_units_for_line_box(node.text_for_rendering()) {
		from := SearchTextPosition{ node: node, offset: offset }
		to := SearchTextPosition{ node: node, offset: offset + 1 }
		if collapse && unit in [u16(0x09), 0x0b, 0x0c, 0x0d, 0x20] {
			mut space := builder.pending_space or { SearchTextRun{from: from, to: to} }
			space.to = to
			builder.pending_space = space
			continue
		}
		if space := builder.pending_space {
			builder.pending_space = none
			if builder.current.units.len > 0 { builder.current.append(0x20, space.from, space.to) }
		}
		builder.current.append(unit, from, to)
	}
}

fn collect_searchable_layout_text(node &Node, mut builder SearchTextBuilder) {
	display_none := node.computed_values().display().is_none()
	if !display_none {
		mut pseudo_break := false
		if pseudo := node.generated_for_pseudo_element() { pseudo_break = pseudo != .first_letter }
		if node.is_box() || pseudo_break {
			builder.flush()
		} else if text := node.as_text_node() {
			parent := node.parent() or { return }
			style := parent.computed_values()
			if style.visibility() == .visible && style.opacity() != 0 {
				if source := text.dom_node() {
					if !source.is_inert() {
						builder.append(text, style.white_space_collapse() in [.collapse, .preserve_breaks])
					}
				}
			}
		}
	}
	for child in node.children() { collect_searchable_layout_text(child, mut builder) }
}

fn search_ascii_fold(unit u16) u16 {
	return if unit >= 0x41 && unit <= 0x5a { unit + 0x20 } else { unit }
}

fn search_text_index(text []u16, query []u16, offset int, case_sensitive bool) ?int {
	end := text.len - query.len
	mut index := offset
	for index <= end {
		mut matches := true
		for i, unit in query {
			mismatch := if case_sensitive { text[index + i] != unit } else { search_ascii_fold(text[index + i]) != search_ascii_fold(unit) }
			if mismatch {
				matches = false
				break
			}
		}
		if matches { return index }
		index += if !case_sensitive && query.len > 1 && text[index] >= 0xd800 && text[index] <= 0xdbff
			&& index + 1 < text.len && text[index + 1] >= 0xdc00 && text[index + 1] <= 0xdfff { 2 } else { 1 }
	}
	return none
}

fn find_matching_layout_text(handle voidptr, query string, sensitivity dom.CaseSensitivity) []&dom.Range {
	units := utf16_code_units_for_line_box(query)
	if units.len == 0 { return []&dom.Range{} }
	root := unsafe { &Node(handle) }
	mut builder := SearchTextBuilder{}
	collect_searchable_layout_text(root, mut builder)
	builder.flush()
	mut matches := []&dom.Range{}
	for block in builder.blocks {
		mut offset := 0
		for {
			index := search_text_index(block.units, units, offset, sensitivity == .case_sensitive) or { break }
			if mut range := block.dom_range(index, index + units.len) {
				mut repeats_previous_match := false
				if matches.len > 0 {
					previous := matches[matches.len - 1]
					// Case expansion can map consecutive matches to the same source text.
					repeats_previous_match = voidptr(previous.start_container()) == voidptr(range.start_container())
						&& previous.start_offset() == range.start_offset()
						&& voidptr(previous.end_container()) == voidptr(range.end_container())
						&& previous.end_offset() == range.end_offset()
				}
				if !repeats_previous_match {
					matches << range
				} else {
					range.finalize()
				}
			}
			offset = index + units.len
			if offset >= block.units.len { break }
		}
	}
	return matches
}
