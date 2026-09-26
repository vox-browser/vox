// Copyright (c) 2026-present, the Ladybird developers
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the plain-text half of Editing/ClipboardSerializer.cpp.
module editing

import dom
import css
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

enum StyledSelectionCoverage {
	partial
	full
}

struct SerializedClipboardText {
	source     &dom.Text
	serialized &dom.Text
}

fn styled_markup_node_is_block(node &dom.Node) bool {
	element := node.as_element() or { return false }
	return is_prohibited_paragraph_child_name(element.local_name())
}

fn should_serialize_styled_markup_node(node &dom.Node) bool {
	if node.is_text() {
		if node.layout_node() == none {
			return false
		}
		return dom.collect_visual_lines(unsafe { &dom.Text(node) }).len > 0
	}
	if node.layout_node() != none {
		return true
	}
	element := node.as_element() or { return false }
	computed := element.el_computed_properties() or { return false }
	return computed.display().is_contents()
}

fn styled_markup_node_participates(range &dom.Range, node &dom.Node) bool {
	return range.contains_node(node) || node.is_inclusive_ancestor_of(range.start_container())
		|| node.is_inclusive_ancestor_of(range.end_container())
}

fn is_trailing_caret_placeholder(range &dom.Range, source &dom.Node) bool {
	element := source.as_element() or { return false }
	if !element.is_html_element() || element.local_name() != 'br'
		|| source.previous_sibling() == none {
		return false
	}
	parent := source.parent() or { return false }
	if source != (parent.last_child() or { return false }) {
		return false
	}
	mut selected_branch := source
	for {
		branch_parent := selected_branch.parent() or { break }
		if branch_parent == range.end_container() {
			break
		}
		if selected_branch != (branch_parent.last_child() or { break }) {
			break
		}
		selected_branch = branch_parent
	}
	return (selected_branch.parent() or { return false }) == range.end_container()
		&& range.end_offset() == selected_branch.index() + 1
}

fn append_selected_styled_markup_node(range &dom.Range, source &dom.Node, mut destination_parent dom.Node, coverage StyledSelectionCoverage, mut serialized_text []SerializedClipboardText) bool {
	if !should_serialize_styled_markup_node(source) {
		return false
	}

	// A final br is the block's caret placeholder when the range ends directly
	// after its containing branch, rather than selected inline content.
	if is_trailing_caret_placeholder(range, source) {
		return false
	}

	clone := source.clone_node(none, false, none) or { return false }
	destination_parent.append_child(clone) or { return false }
	fully_selected := coverage == .full
	if source.is_character_data() {
		data := source.character_data() or { return false }
		mut clone_data := clone.character_data() or { return false }
		mut start_offset := if source == range.start_container() { range.start_offset() } else { 0 }
		mut end_offset := if source == range.end_container() { range.end_offset() } else { source.length() }
		if fully_selected {
			start_offset = 0
			end_offset = source.length()
		}
		selected_data := data.substring_data(start_offset, end_offset - start_offset) or { '' }
		clone_data.set_data(selected_data)
		if source.is_text() {
			serialized_text << SerializedClipboardText{
				source: unsafe { &dom.Text(source) }
				serialized: unsafe { &dom.Text(clone) }
			}
		}
		return selected_data != ''
	}

	mut emitted_content := false
	mut mutable_clone := unsafe { &dom.Node(clone) }
	for child in source.children_as_vector() {
		if !fully_selected && !styled_markup_node_participates(range, child) {
			continue
		}
		child_coverage := if fully_selected || range.contains_node(child) {
			StyledSelectionCoverage.full
		} else {
			StyledSelectionCoverage.partial
		}
		emitted_content = append_selected_styled_markup_node(range, child, mut mutable_clone,
			child_coverage, mut serialized_text) || emitted_content
	}

	element := source.as_element()
	is_atomic_content := if source_element := element { source_element.is_void_element() } else { false }
	is_unselected_trailing_wrapper := source.is_inclusive_ancestor_of(range.end_container())
		&& !source.is_inclusive_ancestor_of(range.start_container())
		&& range.end_container().is_character_data()
		&& if source_element := element { source_element.local_name() == 'div' } else { false }
	if coverage == .partial && element != none && !is_atomic_content && !emitted_content
		&& (is_unselected_trailing_wrapper || !styled_markup_node_is_block(source)) {
		mut mutable_clone_for_removal := unsafe { &dom.Node(clone) }
		mutable_clone_for_removal.remove(false)
		return false
	}
	return emitted_content || is_atomic_content || styled_markup_node_is_block(source)
}

fn protect_collapsible_whitespace_for_interchange(document &dom.Document, serialized_text []SerializedClipboardText) {
	for text in serialized_text {
		layout_node := text.source.as_node().layout_node() or { continue }
		if layout_node.white_space_collapse_is_not_collapse() {
			continue
		}
		data := text.serialized.data()
		if data == '' {
			continue
		}
		mut parent := unsafe { &dom.Node(text.serialized.as_node().parent() or { continue }) }
		for token in rebalance_whitespace_for_interchange(data) {
			if token.type_ == .text {
				parent.insert_before(document.create_text_node(token.text).as_node(), text.serialized.as_node(),
					false)
			} else {
				span := document.create_element('span') or { continue }
				mut span_node := span.as_node()
				span_node.append_child(document.create_text_node('\u00a0').as_node()) or { continue }
				parent.insert_before(span.as_node(), text.serialized.as_node(), false)
			}
		}
		mut serialized_node := unsafe { &dom.Node(text.serialized.as_node()) }
		serialized_node.remove(false)
	}
}

fn is_html_list_element(node &dom.Node) bool {
	element := node.as_element() or { return false }
	return element.is_html_element() && element.local_name() in ['ol', 'ul']
}

fn is_html_list_item_element(node &dom.Node) bool {
	element := node.as_element() or { return false }
	return element.is_html_element() && element.local_name() == 'li'
}

fn wrap_cloned_list_items(range &dom.Range, mut fragment_node dom.Node) {
	children := fragment_node.children_as_vector()
	if children.len == 0 || children.any(!is_html_list_item_element(it)) {
		return
	}

	mut source_list := ?&dom.Node(range.common_ancestor_container())
	for source_list != none {
		current := source_list or { return }
		if is_html_list_element(current) {
			wrapper := current.clone_node(none, false, none) or { return }
			mut wrapper_node := unsafe { &dom.Node(wrapper) }
			for child in children {
				wrapper_node.append_child(child) or { return }
			}
			fragment_node.append_child(wrapper) or { return }
			return
		}
		source_list = current.parent()
	}
}

fn has_renderable_styled_markup_content(node &dom.Node) bool {
	if node.is_text() {
		return (node.text_content() or { '' }) != ''
	}
	if element := node.as_element() {
		if element.is_void_element()
			&& !(element.is_html_element() && element.local_name() == 'br') {
			return true
		}
	}
	for child in node.children_as_vector() {
		if has_renderable_styled_markup_content(child) {
			return true
		}
	}
	return false
}

fn is_empty_or_clipped_styled_paragraph(node &dom.Node) bool {
	return styled_markup_node_is_block(node) && !has_renderable_styled_markup_content(node)
}

fn create_interchange_newline(document &dom.Document) ?&dom.Node {
	mut line_break := document.create_element('br') or { return none }
	line_break.set_attribute_value('class', 'Apple-interchange-newline')
	return line_break.as_node()
}

fn encode_empty_list_item_boundaries(document &dom.Document, mut fragment_node dom.Node) {
	for list in fragment_node.children_as_vector() {
		if !is_html_list_element(list) {
			continue
		}
		first_item := list.first_child()
		if first := first_item {
			if following := first.next_sibling() {
				if is_html_list_item_element(first) && is_html_list_item_element(following)
					&& is_empty_or_clipped_styled_paragraph(first) {
					marker := create_interchange_newline(document) or { continue }
					mut following_node := unsafe { &dom.Node(following) }
					following_node.insert_before(marker, following.first_child(), false)
					mut first_node := unsafe { &dom.Node(first) }
					first_node.remove(false)
				}
			}
		}

		last_item := list.last_child() or { continue }
		if !is_html_list_item_element(last_item)
			|| !is_empty_or_clipped_styled_paragraph(last_item) {
			continue
		}
		marker := create_interchange_newline(document) or { continue }
		fragment_node.insert_before(marker, list.next_sibling(), false)
		mut last_node := unsafe { &dom.Node(last_item) }
		last_node.remove(false)
	}
}

fn materialize_partial_text_style(range &dom.Range, document &dom.Document, mut fragment_node dom.Node) {
	source := range.start_container()
	if source != range.end_container() || !source.is_text()
		|| (range.start_offset() == 0 && range.end_offset() == source.length()) {
		return
	}
	selected_element := source.parent_element() or { return }
	host := source.editing_host() or { return }
	host_element := host.as_element() or { return }

	properties := [
		css.PropertyID.color,
		.background_color,
		.font_family,
		.font_size,
		.font_style,
		.font_weight,
		.text_decoration_line,
	]
	mut style := strings.new_builder(0)
	for property_id in properties {
		selected_value := css.computed_value_for(selected_element, property_id) or { continue }
		host_value := css.computed_value_for(host_element, property_id) or { continue }
		if selected_value == host_value {
			continue
		}
		style.write_string('${css.string_from_property_id(property_id)}: ${selected_value};')
	}
	if style.len == 0 {
		return
	}

	mut span := document.create_element('span') or { return }
	span.set_attribute_value('style', style.str())
	mut span_node := span.as_node()
	for child in fragment_node.children_as_vector() {
		span_node.append_child(child) or { return }
	}
	fragment_node.append_child(span.as_node()) or { return }
}

pub fn serialize_range_as_html_for_clipboard(range &dom.Range) string {
	if range.collapsed() {
		return ''
	}
	mut document := unsafe { &dom.Document(range.start_container().document()) }
	document.update_layout_if_needed_for_node(range.common_ancestor_container(),
		.navigable_selected_text)
	fragment := document.create_document_fragment()
	mut fragment_node := fragment.as_node()
	mut serialized_text := []SerializedClipboardText{}
	common_ancestor := range.common_ancestor_container()
	if common_ancestor.is_character_data() {
		append_selected_styled_markup_node(range, common_ancestor, mut fragment_node, .partial,
			mut serialized_text)
	} else {
		for child in common_ancestor.children_as_vector() {
			if !styled_markup_node_participates(range, child) {
				continue
			}
			coverage := if range.contains_node(child) {
				StyledSelectionCoverage.full
			} else {
				StyledSelectionCoverage.partial
			}
			append_selected_styled_markup_node(range, child, mut fragment_node, coverage,
				mut serialized_text)
		}
	}
	wrap_cloned_list_items(range, mut fragment_node)
	encode_empty_list_item_boundaries(document, mut fragment_node)
	materialize_partial_text_style(range, document, mut fragment_node)
	protect_collapsible_whitespace_for_interchange(document, serialized_text)
	if serialized_text.len > 0 {
		materialize_single_run_legacy_font_style_from_rendered_source(fragment_node,
			serialized_text[0].source.as_node())
	}
	return fragment_node.serialize_fragment(.no, .inner) or { '' }
}
