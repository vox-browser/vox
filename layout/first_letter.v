// Layout/TreeBuilder.cpp factories and Rust/src/layout/tree_builder.rs:
// first-letter-pattern matching, target traversal, and text-slice placement.
module layout

import css
import dom
import platform

struct FirstLetterTarget {
	text_node     &TextNode
	letter_end    int
	source_length int
}

fn first_letter_code_point(text []u16, offset int) u32 {
	first := u32(text[offset])
	if first >= 0xd800 && first <= 0xdbff && offset + 1 < text.len {
		second := u32(text[offset + 1])
		if second >= 0xdc00 && second <= 0xdfff {
			return 0x10000 + ((first - 0xd800) << 10) + second - 0xdc00
		}
	}
	return first
}

fn first_letter_next_boundary(boundaries []int, offset int, length int) int {
	for boundary in boundaries {
		if boundary > offset { return boundary }
	}
	return length
}

fn first_letter_end(text string, preserves_segment_breaks bool) ?int {
	units := utf16_code_units_for_line_box(text)
	boundaries := text_grapheme_boundaries(text)
	mut match_start := 0
	for match_start < units.len {
		mut cursor := match_start
		starting := first_letter_code_point(units, cursor)
		if preserves_segment_breaks && starting in [u32(`\n`), u32(`\r`)] { return none }
		starting_facts := platform.code_point_category_facts(starting)
		has_preceding := starting_facts.is_punctuation
		if !(has_preceding || starting_facts.is_letter || starting_facts.is_number
			|| starting_facts.is_symbol) {
			match_start += if starting > 0xffff { 2 } else { 1 }
			continue
		}
		if has_preceding {
			cursor = first_letter_next_boundary(boundaries, cursor, units.len)
			for cursor < units.len {
				code_point := first_letter_code_point(units, cursor)
				facts := platform.code_point_category_facts(code_point)
				intervening_space := code_point != 0x3000 && facts.is_space_separator
				if !facts.is_punctuation && !intervening_space { break
				 }
				cursor = first_letter_next_boundary(boundaries, cursor, units.len)
			}
		}
		if cursor >= units.len { return cursor }
		letter_facts := platform.code_point_category_facts(first_letter_code_point(units, cursor))
		if !(letter_facts.is_letter || letter_facts.is_number || letter_facts.is_symbol) {
			match_start += if starting > 0xffff { 2 } else { 1 }
			continue
		}
		mut letter_end := first_letter_next_boundary(boundaries, cursor, units.len)
		for letter_end < units.len {
			code_point := first_letter_code_point(units, letter_end)
			facts := platform.code_point_category_facts(code_point)
			intervening_space := code_point !in [u32(0x20), 0xa0, 0x3000]
				&& facts.is_space_separator
			trailing_punctuation := facts.is_punctuation && !facts.is_open_punctuation
				&& !facts.is_dash_punctuation
			if !intervening_space && !trailing_punctuation { break
			 }
			letter_end = first_letter_next_boundary(boundaries, letter_end, units.len)
		}
		return letter_end
	}
	return none
}

fn first_letter_marker_content(node &Node) bool {
	if node.is_list_item_marker_box() { return true }
	if generated := node.generated_for_pseudo_element() { return generated == .marker }
	return false
}

fn find_first_letter_in_inline_subtree(node &Node) (?FirstLetterTarget, bool) {
	if first_letter_marker_content(node) || !node.is_in_flow() { return none, false }
	if text := node.as_text_node() {
		white_space := node.computed_values().white_space_collapse()
		preserves := white_space in [.preserve, .preserve_breaks, .break_spaces]
		if end := first_letter_end(text.source_text_, preserves) {
			return FirstLetterTarget{text, end, utf16_length_for_line_box(text.source_text_)}, true
		}
		return none, false
	}
	if !node.is_inline_node() || node.is_atomic_inline() { return none, true }
	for child in node.children() {
		target, stop := find_first_letter_in_inline_subtree(child)
		if stop { return target, true }
	}
	return none, false
}

fn find_first_letter_in_block(block &Node) ?FirstLetterTarget {
	target,_ := find_first_letter_in_block_until_boundary(block)
	return target
}

fn find_first_letter_in_block_until_boundary(block &Node) (?FirstLetterTarget,bool) {
	if block.display().is_flex_inside() || block.display().is_grid_inside() || block.display().is_table_inside() { return none,true }
	if block.children_are_inline() {
		for child in block.children() {
			target,stop := find_first_letter_in_inline_subtree(child)
			if stop { return target,true }
		}
		return none,false
	}
	for child in block.children() {
		if first_letter_marker_content(child) || !child.is_in_flow() { continue }
		if !child.is_block_container() { return none,true }
		if !child.is_anonymous() {
			if dom_node := child.dom_node() {
				if element := dom_node.as_element() {
					if css.computed_properties_for_pseudo_element(element,.first_letter) != none { return none,true }
				}
			}
		}
		target,stop := find_first_letter_in_block_until_boundary(child)
		if stop { return target,true }
		if !child.is_anonymous() { return none,true }
	}
	return none,false
}

fn create_first_letter_boxes(document &dom.Document, element &dom.Element, target FirstLetterTarget, style &css.ComputedProperties) {
	text := target.text_node
	mut first := if dom_text := text.dom_node() {
		TextNode.new(document, dom_text, text.source_text_)
	} else {
		TextNode.new_generated(document, utf16_substring_for_line_box(text.source_text_, 0,
			target.letter_end))
	}
	mut remainder := if dom_text := text.dom_node() {
		TextNode.new(document, dom_text, text.source_text_)
	} else {
		TextNode.new_generated(document, utf16_substring_for_line_box(text.source_text_,
			target.letter_end, target.source_length - target.letter_end))
	}
	if text.dom_node() != none {
		first.attach_to_dom_node_ = false
		first.source_range_length_ = target.letter_end
		remainder.source_range_start_ = target.letter_end
		remainder.source_range_length_ = target.source_length - target.letter_end
		remainder.first_letter_ = first
	}
	computed_values_in_layout_coordinates(style, document)
	mut wrapper := create_layout_node_for_generated_content(document, style)
	wrapper.set_generated_for(.first_letter, element)
	wrapper.set_children_are_inline(true)
	wrapper.append_child(unsafe { &Node(first) })
	mut parent := unsafe { &Node(text.parent() or { return }) }
	mut children := []&Node{}
	for child in parent.children() {
		if layout_nodes_same(child, unsafe { &Node(text) }) {
			children << wrapper
			children << unsafe { &Node(remainder) }
		} else {
			children << child
		}
	}
	parent.replace_children(children)
}
