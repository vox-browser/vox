// Copyright (c) 2026-present, the Ladybird developers
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the plain-text half of Editing/ClipboardSerializer.cpp.
module editing

import dom
import strings

struct ClipboardTextSerializer {
	range &dom.Range
mut:
	builder                   strings.Builder
	pending_line_breaks       int
	pending_break_is_explicit bool
}

fn ClipboardTextSerializer.create(range &dom.Range) ClipboardTextSerializer {
	return ClipboardTextSerializer{
		range: range
		builder: strings.new_builder(0)
	}
}

fn (mut serializer ClipboardTextSerializer) request_line_breaks(count int) {
	if count > serializer.pending_line_breaks {
		serializer.pending_line_breaks = count
	}
}

fn (mut serializer ClipboardTextSerializer) request_explicit_line_break() {
	serializer.flush_pending_breaks()
	serializer.pending_line_breaks = 1
	serializer.pending_break_is_explicit = true
}

fn (mut serializer ClipboardTextSerializer) flush_pending_breaks() {
	if serializer.builder.len > 0 {
		serializer.builder.write_string('\n'.repeat(serializer.pending_line_breaks))
	} else if serializer.pending_break_is_explicit {
		serializer.builder.write_u8(`\n`)
	}
	serializer.pending_line_breaks = 0
	serializer.pending_break_is_explicit = false
}

fn (mut serializer ClipboardTextSerializer) append(text string) {
	if text == '' {
		return
	}
	serializer.flush_pending_breaks()
	serializer.builder.write_string(text)
}

fn (serializer &ClipboardTextSerializer) range_fully_contains_node(node &dom.Node) bool {
	parent := node.parent() or { return false }
	before_node := dom.BoundaryPoint{
		node: parent
		offset: node.index()
	}
	after_node := dom.BoundaryPoint{
		node: parent
		offset: node.index() + 1
	}
	return dom.position_of_boundary_point_relative_to_other_boundary_point(before_node,
		serializer.range.start()) != .before
		&& dom.position_of_boundary_point_relative_to_other_boundary_point(after_node,
			serializer.range.end()) != .after
}

fn (mut serializer ClipboardTextSerializer) collect(node &dom.Node) {
	if !serializer.range.intersects_node(node) {
		return
	}

	layout_node := node.layout_node()
	mut is_rendered_block := false
	if layout := layout_node {
		display := layout.display()
		is_rendered_block = display.is_block_outside() || display.is_table_caption()
	}
	if is_rendered_block {
		serializer.request_line_breaks(if element := node.as_element() {
			if element.is_html_element() && element.local_name() == 'p' { 2 } else { 1 }
		} else {
			1
		})
	}

	if node.is_text() {
		layout := layout_node or { return }
		if layout.user_select_is_none() {
			return
		}
		text := unsafe { &dom.Text(node) }
		if dom.collect_visual_lines(text).len == 0 {
			return
		}
		data := if node == serializer.range.start_container()
			&& node == serializer.range.end_container() {
			text.substring_data(serializer.range.start_offset(), serializer.range.end_offset() - serializer.range.start_offset()) or {
				''
			}
		} else if node == serializer.range.start_container() {
			text.substring_data(serializer.range.start_offset(), text.length_in_utf16_code_units() - serializer.range.start_offset()) or {
				''
			}
		} else if node == serializer.range.end_container() {
			text.substring_data(0, serializer.range.end_offset()) or { '' }
		} else {
			text.data()
		}
		serializer.append(data)
	} else if element := node.as_element() {
		if element.is_html_element() && element.local_name() == 'br' {
			if serializer.range_fully_contains_node(node) {
				serializer.request_explicit_line_break()
			}
		} else if element.is_html_element() && element.local_name() == 'img' {
			if serializer.range_fully_contains_node(node) {
				if layout := layout_node {
					if !layout.user_select_is_none() {
						serializer.append(element.get_attribute_value('alt'))
					}
				}
			}
		} else {
			for child in node.children_as_vector() {
				serializer.collect(child)
			}
		}
	} else {
		for child in node.children_as_vector() {
			serializer.collect(child)
		}
	}

	if layout := layout_node {
		display := layout.display()
		if display.is_table_cell() && node.next_sibling() != none {
			serializer.append('\t')
		}
		if display.is_table_row() && node.next_sibling() != none {
			serializer.request_explicit_line_break()
		}
	}
	if is_rendered_block {
		if element := node.as_element() {
			serializer.request_line_breaks(if element.is_html_element()
				&& element.local_name() == 'p' { 2 } else { 1 })
		} else {
			serializer.request_line_breaks(1)
		}
	}
}

fn (mut serializer ClipboardTextSerializer) serialize() string {
	serializer.collect(serializer.range.common_ancestor_container())
	if serializer.pending_break_is_explicit {
		serializer.flush_pending_breaks()
	}
	return serializer.builder.str()
}

pub fn serialize_range_as_plain_text_for_clipboard(range &dom.Range) string {
	mut serializer := ClipboardTextSerializer.create(range)
	return serializer.serialize()
}
