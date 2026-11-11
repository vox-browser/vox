// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// Rust/src/layout/text_queries.rs: words spanning ordinary inline elements.
module layout

import dom

fn inline_word_containing_box(node &Node) ?&Node {
	mut current := node.parent()
	for {
		ancestor := current or { break }
		if ancestor.is_box() { return ancestor }
		current = ancestor.parent()
	}
	return none
}

struct InlineWordRuns {
mut:
	runs [][]&TextNode
	current []&TextNode
}

fn (mut runs InlineWordRuns) finish_run() {
	if runs.current.len == 0 { return }
	runs.runs << runs.current
	runs.current = []&TextNode{}
}

fn collect_inline_word_nodes(node &Node, mut runs InlineWordRuns) {
	if node.computed_values().display().is_none() { return }
	if pseudo := node.generated_for_pseudo_element() {
		// Read the first-letter slice through its primary text node, including
		// its source mapping, instead of adding the generated wrapper twice.
		if pseudo != .first_letter { runs.finish_run() }
		return
	}
	if node.is_break_node() || node.is_box() {
		runs.finish_run()
		return
	}
	if text := node.as_text_node() {
		if text.attach_to_dom_node_ && text.dom_node() != none { runs.current << text }
	}
	for child in node.children() { collect_inline_word_nodes(child, mut runs) }
}

fn append_inline_word_fragment(mut text SearchMappedText, fragment &TextNode,
	primary bool, dom_offset int, hit_offset ?int) ?int {
	units := utf16_code_units_for_line_box(fragment.text_for_rendering())
	mut hit := hit_offset
	if primary && hit_offset == none && dom_offset >= fragment.source_range_start_
		&& dom_offset <= fragment.source_range_start_ + fragment.rendered_source_length_ {
		hit = text.units.len + fragment.rendered_text_offset_for_source_offset(dom_offset, .start)
	}
	for offset, unit in units {
		text.append(unit, SearchTextPosition{ node: fragment, offset: offset },
			SearchTextPosition{ node: fragment, offset: offset + 1 })
	}
	return hit
}

fn layout_inline_word_range(handle voidptr, dom_offset int) ?&dom.Range {
	primary := unsafe { &Node(handle) }.as_text_node() or { return none }
	source := primary.dom_node() or { return none }
	if !source.is_text() || unsafe { &dom.Text(source) }.is_password_input() { return none }
	container := inline_word_containing_box(unsafe { &Node(primary) }) or { return none }
	mut runs := InlineWordRuns{}
	for child in container.children() { collect_inline_word_nodes(child, mut runs) }
	runs.finish_run()
	mut run := []&TextNode{}
	for candidate in runs.runs {
		for node in candidate {
			if voidptr(node) == voidptr(primary) {
				run = candidate.clone()
				break
			}
		}
		if run.len > 0 { break }
	}
	if run.len < 2 { return none }
	mut text := SearchMappedText{}
	mut hit_offset := ?int(none)
	for node in run {
		is_primary := voidptr(node) == voidptr(primary)
		if first := node.first_letter_ {
			hit_offset = append_inline_word_fragment(mut text, first, is_primary, dom_offset, hit_offset)
		}
		hit_offset = append_inline_word_fragment(mut text, node, is_primary, dom_offset, hit_offset)
	}
	if text.units.len == 0 { return none }
	hit := hit_offset or { return none }
	index := if hit < 0 { 0 } else if hit >= text.units.len { text.units.len - 1 } else { hit }
	segmenter := dom.Segmenter{
		segmented_text: string_from_utf16_code_units_for_line_box(text.units)
		granularity: .word
	}
	boundaries := segmenter.boundaries()
	for i in 1 .. boundaries.len {
		if boundaries[i] <= index { continue }
		mut range := text.dom_range(boundaries[i - 1], boundaries[i]) or { return none }
		start := range.start_container()
		end := range.end_container()
		if voidptr(start) == voidptr(end) || !end.is_following(start) {
			range.finalize()
			return none
		}
		return range
	}
	return none
}
