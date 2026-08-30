// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Complete typed entry-points for Editing/Internal/Algorithms.cpp. Ladybird's
// algorithms operate on GC DOM nodes; EditingDocument represents the same
// editable tree as block and inline-item coordinates, so EditingNode is the
// package-boundary equivalent of a DOM node reference.
module editing

pub struct EditingNode {
pub:
	block_index int
	item_index  ?int
}

pub enum SelectionDirection {
	forward
	backward
}

pub fn active_range(document &EditingDocument) ?EditingRange {
	if !document.editable || document.blocks.len == 0 {
		return none
	}
	return document.selection
}

fn valid_node(document &EditingDocument, node EditingNode) bool {
	if node.block_index < 0 || node.block_index >= document.blocks.len {
		return false
	}
	if index := node.item_index {
		return index >= 0 && index < document.blocks[node.block_index].items.len
	}
	return true
}

pub fn alignment_value_of_node(document &EditingDocument, node EditingNode) JustifyAlignment {
	if !valid_node(document, node) {
		return .left
	}
	return document.blocks[node.block_index].alignment
}

pub fn autolink(mut document EditingDocument, point Boundary) {
	boundary := document.checked_boundary(point) or { return }
	if boundary.offset == 0 {
		return
	}
	block := document.blocks[boundary.block]
	mut start := boundary.offset
	for start > 0 {
		item := block.items[start - 1]
		if item.kind != .text || item.data.runes().any(it in [` `, `\t`, `\r`, `\n`]) {
			break
		}
		start--
	}
	if start == boundary.offset {
		return
	}
	candidate := block.items[start..boundary.offset].map(it.data).join('')
	lower := candidate.to_lower()
	link := if lower.starts_with('www.') {
		'http://${candidate}'
	} else if lower.starts_with('http://') || lower.starts_with('https://')
		|| lower.starts_with('mailto:') {
		candidate
	} else {
		return
	}
	for index := start; index < boundary.offset; index++ {
		document.blocks[boundary.block].items[index].style.link = link
	}
}

pub fn block_extend_a_range(document &EditingDocument, range EditingRange) EditingRange {
	if document.blocks.len == 0 {
		return range
	}
	start_block := if range.start.block < 0 { 0 } else { range.start.block }
	end_block := if range.end.block >= document.blocks.len {
		document.blocks.len - 1
	} else {
		range.end.block
	}
	return EditingRange{
		start: Boundary{start_block, 0}
		end:   Boundary{end_block, document.blocks[end_block].items.len}
	}
}

pub fn block_node_of_node(document &EditingDocument, node EditingNode) ?EditingNode {
	if !valid_node(document, node) {
		return none
	}
	return EditingNode{block_index: node.block_index}
}

fn item_is_whitespace(item InlineItem) bool {
	return item.kind == .text && item.data != ''
		&& item.data.runes().all(it in [` `, `\t`, `\r`, `\n`, `\u00a0`])
}

pub fn canonicalize_whitespace(mut document EditingDocument, point Boundary, fix_collapsed_space bool) {
	boundary := document.checked_boundary(point) or { return }
	mut start := boundary.offset
	mut end := boundary.offset
	for start > 0 && item_is_whitespace(document.blocks[boundary.block].items[start - 1]) {
		start--
	}
	for end < document.blocks[boundary.block].items.len
		&& item_is_whitespace(document.blocks[boundary.block].items[end]) {
		end++
	}
	if start == end {
		return
	}
	style := document.blocks[boundary.block].items[start].style
	text := document.blocks[boundary.block].items[start..end].map(it.data).join('')
	normalized := canonicalize_whitespace_text(text, fix_collapsed_space && start == 0,
		fix_collapsed_space && end == document.blocks[boundary.block].items.len)
	document.blocks[boundary.block].items.delete_many(start, end - start)
	mut replacement := text_items(normalized, style)
	for index, item in replacement {
		document.blocks[boundary.block].items.insert(start + index, item)
	}
}

pub fn clear_the_value(mut document EditingDocument, command string, nodes []EditingNode) []EditingNode {
	mut cleared := []EditingNode{}
	for node in nodes {
		index := node.item_index or { continue }
		if !valid_node(document, node) {
			continue
		}
		restore_item_value(mut document.blocks[node.block_index].items[index], command, none)
		cleared << node
	}
	return cleared
}

pub fn delete_the_selection(mut document EditingDocument, block_merging bool, _ bool, _ SelectionDirection) {
	if block_merging || document.selection.start.block == document.selection.end.block {
		document.delete_selection()
		return
	}
	start := document.selection.start
	end := document.selection.end
	document.blocks[start.block].items.delete_many(start.offset,
		document.blocks[start.block].items.len - start.offset)
	document.blocks[end.block].items.delete_many(0, end.offset)
	for block_index := start.block + 1; block_index < end.block; block_index++ {
		document.blocks[block_index].items.clear()
	}
	document.selection = EditingRange{start: start, end: start}
}

pub fn effective_command_value(document &EditingDocument, node EditingNode, command string) ?string {
	index := node.item_index or { return none }
	if !valid_node(document, node) {
		return none
	}
	return effective_item_value(document.blocks[node.block_index].items[index], command)
}

// EditingDocument has no transparent wrapper nodes, so its stored boundary
// points are already the first/last equivalent points.
pub fn first_equivalent_point(_ &EditingDocument, boundary Boundary) Boundary {
	return boundary
}

pub fn last_equivalent_point(_ &EditingDocument, boundary Boundary) Boundary {
	return boundary
}

pub fn next_equivalent_point(_ &EditingDocument, _ Boundary) ?Boundary {
	return none
}

pub fn previous_equivalent_point(_ &EditingDocument, _ Boundary) ?Boundary {
	return none
}

pub fn fix_disallowed_ancestors_of_node(mut document EditingDocument, node EditingNode) {
	if !valid_node(document, node) {
		return
	}
	mut block := &document.blocks[node.block_index]
	if !is_formattable_block_name(block.tag) && is_prohibited_paragraph_child_name(block.tag) {
		block.tag = document.default_paragraph_separator
	}
}

pub fn follows_a_line_break(document &EditingDocument, node EditingNode) bool {
	index := node.item_index or { return node.block_index > 0 }
	if !valid_node(document, node) {
		return false
	}
	return index == 0 || document.blocks[node.block_index].items[index - 1].kind == .line_break
}

pub fn precedes_a_line_break(document &EditingDocument, node EditingNode) bool {
	index := node.item_index or { return node.block_index + 1 < document.blocks.len }
	if !valid_node(document, node) {
		return false
	}
	items := document.blocks[node.block_index].items
	return index + 1 == items.len || items[index + 1].kind == .line_break
}

pub fn force_the_value(mut document EditingDocument, node EditingNode, command string, value ?string) {
	index := node.item_index or { return }
	if !valid_node(document, node) {
		return
	}
	restore_item_value(mut document.blocks[node.block_index].items[index], command, value)
}

pub fn indent(mut document EditingDocument, nodes []EditingNode) {
	mut seen := map[int]bool{}
	for node in nodes {
		if valid_node(document, node) && !seen[node.block_index] {
			document.blocks[node.block_index].indent++
			seen[node.block_index] = true
		}
	}
}

pub fn is_allowed_child_of_node(child string, parent string) bool {
	child_name := child.to_lower()
	parent_name := parent.to_lower()
	if child_name == 'li' {
		return parent_name in ['ol', 'ul']
	}
	if child_name in ['dt', 'dd'] {
		return parent_name == 'dl'
	}
	if child_name == 'tr' {
		return parent_name in ['table', 'thead', 'tbody', 'tfoot']
	}
	if child_name in ['td', 'th'] {
		return parent_name == 'tr'
	}
	if parent_name == 'p' && is_prohibited_paragraph_child_name(child_name) {
		return false
	}
	return child_name !in ['html', 'head', 'body']
}

pub fn is_block_boundary_point(document &EditingDocument, boundary Boundary) bool {
	return is_block_start_point(document, boundary) || is_block_end_point(document, boundary)
}

pub fn is_block_end_point(document &EditingDocument, boundary Boundary) bool {
	checked := document.checked_boundary(boundary) or { return false }
	return checked.offset == document.blocks[checked.block].items.len
}

pub fn is_block_node(document &EditingDocument, node EditingNode) bool {
	return valid_node(document, node) && node.item_index == none
}

pub fn is_block_start_point(document &EditingDocument, boundary Boundary) bool {
	checked := document.checked_boundary(boundary) or { return false }
	return checked.offset == 0
}

pub fn is_collapsed_block_prop(document &EditingDocument, node EditingNode) bool {
	if !is_block_node(document, node) {
		return false
	}
	return !document.blocks[node.block_index].items.any(is_visible_item(it))
}

pub fn is_collapsed_line_break(document &EditingDocument, node EditingNode) bool {
	index := node.item_index or { return false }
	if !valid_node(document, node)
		|| document.blocks[node.block_index].items[index].kind != .line_break {
		return false
	}
	return index + 1 == document.blocks[node.block_index].items.len
}

pub fn is_collapsed_whitespace_node(document &EditingDocument, node EditingNode) bool {
	index := node.item_index or { return false }
	if !valid_node(document, node) || !item_is_whitespace(document.blocks[node.block_index].items[index]) {
		return false
	}
	return index == 0 || index + 1 == document.blocks[node.block_index].items.len
		|| item_is_whitespace(document.blocks[node.block_index].items[index - 1])
}

pub fn is_effectively_contained_in_range(document &EditingDocument, node EditingNode, range EditingRange) bool {
	if !valid_node(document, node) {
		return false
	}
	if index := node.item_index {
		point := Boundary{node.block_index, index}
		after := Boundary{node.block_index, index + 1}
		return !boundary_less(point, range.start) && !boundary_less(range.end, after)
	}
	return (node.block_index > range.start.block && node.block_index < range.end.block)
		|| (node.block_index == range.start.block && range.start.offset == 0
		&& node.block_index == range.end.block
		&& range.end.offset == document.blocks[node.block_index].items.len)
}

pub fn is_element_with_inline_contents(document &EditingDocument, node EditingNode) bool {
	return is_block_node(document, node)
		&& is_name_of_an_element_with_inline_contents(document.blocks[node.block_index].tag)
}

pub fn is_extraneous_line_break(document &EditingDocument, node EditingNode) bool {
	return is_collapsed_line_break(document, node)
}

pub fn is_formattable_node(document &EditingDocument, node EditingNode) bool {
	index := node.item_index or { return false }
	if !valid_node(document, node) {
		return false
	}
	return document.blocks[node.block_index].items[index].kind in [.text, .line_break, .image]
}

pub fn is_in_same_editing_host(document &EditingDocument, a EditingNode, b EditingNode) bool {
	return valid_node(document, a) && valid_node(document, b)
}

pub fn is_indentation_element(document &EditingDocument, node EditingNode) bool {
	return is_block_node(document, node) && document.blocks[node.block_index].indent > 0
}

fn is_visible_item(item InlineItem) bool {
	return match item.kind {
		.text, .html { item.data != '' }
		else { true }
	}
}

pub fn is_invisible_node(document &EditingDocument, node EditingNode) bool {
	return !is_visible_node(document, node)
}

pub fn is_modifiable_element(document &EditingDocument, node EditingNode) bool {
	if !valid_node(document, node) {
		return false
	}
	return node.item_index != none
}

pub fn is_prohibited_paragraph_child(document &EditingDocument, node EditingNode) bool {
	return is_block_node(document, node)
		&& is_prohibited_paragraph_child_name(document.blocks[node.block_index].tag)
}

pub fn is_simple_indentation_element(document &EditingDocument, node EditingNode) bool {
	return is_indentation_element(document, node)
		&& document.blocks[node.block_index].list_kind == .none
}

pub fn is_simple_modifiable_element(document &EditingDocument, node EditingNode) bool {
	return is_modifiable_element(document, node)
}

pub fn is_visible_node(document &EditingDocument, node EditingNode) bool {
	if !valid_node(document, node) {
		return false
	}
	if index := node.item_index {
		return is_visible_item(document.blocks[node.block_index].items[index])
	}
	return document.blocks[node.block_index].items.any(is_visible_item(it))
}

pub fn is_whitespace_node(document &EditingDocument, node EditingNode) bool {
	index := node.item_index or { return false }
	return valid_node(document, node)
		&& item_is_whitespace(document.blocks[node.block_index].items[index])
}

pub fn justify_the_selection(mut document EditingDocument, alignment JustifyAlignment) {
	document.justify(alignment)
}

fn shift_boundary_for_item_removal(boundary Boundary, block int, index int) Boundary {
	if boundary.block == block && boundary.offset > index {
		return Boundary{block, boundary.offset - 1}
	}
	return boundary
}

fn shift_boundary_for_item_insertion(boundary Boundary, block int, index int) Boundary {
	if boundary.block == block && boundary.offset > index {
		return Boundary{block, boundary.offset + 1}
	}
	return boundary
}

pub fn move_node_preserving_ranges(mut document EditingDocument, node EditingNode, new_parent EditingNode, new_index int) {
	item_index := node.item_index or { return }
	if !valid_node(document, node) || !is_block_node(document, new_parent) {
		return
	}
	if new_index < 0 || new_index > document.blocks[new_parent.block_index].items.len {
		return
	}
	item := document.blocks[node.block_index].items[item_index]
	document.blocks[node.block_index].items.delete(item_index)
	mut insertion_index := new_index
	if node.block_index == new_parent.block_index && item_index < insertion_index {
		insertion_index--
	}
	start_after_remove := shift_boundary_for_item_removal(document.selection.start,
		node.block_index, item_index)
	end_after_remove := shift_boundary_for_item_removal(document.selection.end, node.block_index,
		item_index)
	document.blocks[new_parent.block_index].items.insert(insertion_index, item)
	document.selection = EditingRange{
		start: shift_boundary_for_item_insertion(start_after_remove, new_parent.block_index,
			insertion_index)
		end:   shift_boundary_for_item_insertion(end_after_remove, new_parent.block_index,
			insertion_index)
	}
}

pub fn normalize_sublists_in_node(mut document EditingDocument, node EditingNode) {
	if is_block_node(document, node) && document.blocks[node.block_index].list_kind != .none {
		// Nested list containers collapse into the block's single list marker in
		// the typed representation, so normalization is idempotent.
		document.blocks[node.block_index].indent = if document.blocks[node.block_index].indent < 0 {
			0
		} else {
			document.blocks[node.block_index].indent
		}
	}
}

pub fn outdent(mut document EditingDocument, node EditingNode) {
	if !valid_node(document, node) {
		return
	}
	if document.blocks[node.block_index].indent > 0 {
		document.blocks[node.block_index].indent--
	} else {
		document.blocks[node.block_index].list_kind = .none
	}
}

pub fn push_down_values(mut document EditingDocument, command string, node EditingNode, value ?string) {
	force_the_value(mut document, node, command, value)
}

pub fn record_current_states_and_values(document &EditingDocument) []RecordedOverride {
	return record_current_overrides(document)
}

pub fn record_the_values_of_nodes(document &EditingDocument, nodes []EditingNode, command string) []RecordedNodeValue {
	mut values := []RecordedNodeValue{}
	for node in nodes {
		index := node.item_index or { continue }
		if !valid_node(document, node) || !is_formattable_node(document, node) {
			continue
		}
		values << RecordedNodeValue{
			block_index: node.block_index
			item_index:  index
			command:     command
			value:       effective_item_value(document.blocks[node.block_index].items[index],
				command)
		}
	}
	return values
}

pub fn remove_extraneous_line_breaks_at_the_end_of_node(mut document EditingDocument, node EditingNode) {
	if !is_block_node(document, node) {
		return
	}
	for document.blocks[node.block_index].items.len > 0
		&& document.blocks[node.block_index].items.last().kind == .line_break {
		document.blocks[node.block_index].items.delete_last()
	}
}

pub fn remove_extraneous_line_breaks_before_node(mut document EditingDocument, node EditingNode) {
	index := node.item_index or { return }
	if !valid_node(document, node) {
		return
	}
	mut cursor := index
	for cursor > 0 && document.blocks[node.block_index].items[cursor - 1].kind == .line_break {
		document.blocks[node.block_index].items.delete(cursor - 1)
		cursor--
	}
}

pub fn remove_extraneous_line_breaks_from_a_node(mut document EditingDocument, node EditingNode) {
	if is_block_node(document, node) {
		remove_extraneous_line_breaks_at_the_end_of_node(mut document, node)
		return
	}
	if is_extraneous_line_break(document, node) {
		index := node.item_index or { return }
		document.blocks[node.block_index].items.delete(index)
	}
}

pub fn remove_node_preserving_its_descendants(mut document EditingDocument, node EditingNode) {
	if !valid_node(document, node) {
		return
	}
	if index := node.item_index {
		document.blocks[node.block_index].items.delete(index)
		return
	}
	if document.blocks.len == 1 {
		document.blocks[0].tag = document.default_paragraph_separator
		return
	}
	items := document.blocks[node.block_index].items.clone()
	target := if node.block_index > 0 { node.block_index - 1 } else { 1 }
	document.blocks[target].items << items
	document.blocks.delete(node.block_index)
}

pub fn reorder_modifiable_descendants(mut document EditingDocument, node EditingNode, command string, value ?string) {
	if !valid_node(document, node) {
		return
	}
	if node.item_index != none {
		force_the_value(mut document, node, command, value)
		return
	}
	for index := 0; index < document.blocks[node.block_index].items.len; index++ {
		force_the_value(mut document, EditingNode{node.block_index, index}, command, value)
	}
}

pub fn restore_the_values_of_nodes(mut document EditingDocument, values []RecordedNodeValue) {
	restore_the_values_of_selection(mut document, values)
}

pub fn set_the_selections_value(mut document EditingDocument, command string, value ?string) {
	actual := value or { '' }
	match command {
		command_bold { document.set_inline_bool(command, actual in ['bold', '700']) }
		command_italic { document.set_inline_bool(command, actual in ['italic', 'oblique']) }
		command_underline { document.set_inline_bool(command, actual == 'underline') }
		command_strikethrough { document.set_inline_bool(command, actual == 'line-through') }
		command_subscript {
			document.set_script(if actual == 'subscript' { .subscript } else { .normal })
		}
		command_superscript {
			document.set_script(if actual == 'superscript' { .superscript } else { .normal })
		}
		else { document.set_inline_value(command, actual) }
	}
}

pub fn set_the_tag_name(mut document EditingDocument, node EditingNode, new_name string) ?EditingNode {
	if !is_block_node(document, node) {
		return none
	}
	document.blocks[node.block_index].tag = new_name.to_lower()
	return node
}

pub fn specified_command_value(document &EditingDocument, node EditingNode, command string) ?string {
	return effective_command_value(document, node, command)
}

pub fn split_the_parent_of_nodes(mut document EditingDocument, nodes []EditingNode) {
	if nodes.len == 0 {
		return
	}
	first := nodes[0]
	last := nodes.last()
	if first.block_index != last.block_index || first.item_index == none || last.item_index == none {
		return
	}
	start := first.item_index or { return }
	end := (last.item_index or { return }) + 1
	block := document.blocks[first.block_index]
	if start == 0 && end == block.items.len {
		return
	}
	mut replacement := []Block{}
	if start > 0 {
		replacement << Block{
			tag:       block.tag
			items:     block.items[..start].clone()
			alignment: block.alignment
			list_kind: block.list_kind
			indent:    block.indent
		}
	}
	replacement << Block{
		tag:       block.tag
		items:     block.items[start..end].clone()
		alignment: block.alignment
		list_kind: block.list_kind
		indent:    block.indent
	}
	if end < block.items.len {
		replacement << Block{
			tag:       block.tag
			items:     block.items[end..].clone()
			alignment: block.alignment
			list_kind: block.list_kind
			indent:    block.indent
		}
	}
	document.blocks.delete(first.block_index)
	for index, replacement_block in replacement {
		document.blocks.insert(first.block_index + index, replacement_block)
	}
}

pub fn toggle_lists(mut document EditingDocument, tag_name string) {
	document.toggle_list(if tag_name.to_lower() == 'ol' { .ordered } else { .unordered })
}

pub fn first_formattable_node_effectively_contained(document &EditingDocument, range ?EditingRange) ?EditingNode {
	actual := range or { return none }
	for block_index := actual.start.block; block_index <= actual.end.block; block_index++ {
		start := if block_index == actual.start.block { actual.start.offset } else { 0 }
		end := if block_index == actual.end.block {
			actual.end.offset
		} else {
			document.blocks[block_index].items.len
		}
		for item_index := start; item_index < end; item_index++ {
			node := EditingNode{block_index, item_index}
			if is_formattable_node(document, node) {
				return node
			}
		}
	}
	return none
}

pub fn for_each_node_effectively_contained_in_range(document &EditingDocument, range ?EditingRange, callback fn (EditingNode) bool) {
	actual := range or { return }
	for block_index := actual.start.block; block_index <= actual.end.block; block_index++ {
		start := if block_index == actual.start.block { actual.start.offset } else { 0 }
		end := if block_index == actual.end.block {
			actual.end.offset
		} else {
			document.blocks[block_index].items.len
		}
		for item_index := start; item_index < end; item_index++ {
			if !callback(EditingNode{block_index, item_index}) {
				return
			}
		}
	}
}

pub fn has_visible_children(document &EditingDocument, node EditingNode) bool {
	return is_block_node(document, node)
		&& document.blocks[node.block_index].items.any(is_visible_item(it))
}

pub fn property_in_style_attribute(document &EditingDocument, node EditingNode, property string) ?string {
	index := node.item_index or { return none }
	if !valid_node(document, node) {
		return none
	}
	style := document.blocks[node.block_index].items[index].style
	return match property.to_lower() {
		'color' { if style.color == '' { none } else { style.color } }
		'background-color' { if style.background == '' { none } else { style.background } }
		'font-family' { if style.font_name == '' { none } else { style.font_name } }
		'font-size' { if style.font_size == '' { none } else { style.font_size } }
		'font-weight' { if style.bold { 'bold' } else { none } }
		'font-style' { if style.italic { 'italic' } else { none } }
		'text-decoration-line' {
			if style.underline && style.strikethrough {
				'underline line-through'
			} else if style.underline {
				'underline'
			} else if style.strikethrough {
				'line-through'
			} else {
				none
			}
		}
		else { none }
	}
}

pub fn resolved_display(document &EditingDocument, node EditingNode) ?string {
	if !valid_node(document, node) {
		return none
	}
	if node.item_index == none {
		return 'block'
	}
	index := node.item_index or { return none }
	return if document.blocks[node.block_index].items[index].kind in [.image, .horizontal_rule] {
		'inline-block'
	} else {
		'inline'
	}
}

pub fn resolved_keyword(document &EditingDocument, node EditingNode, property string) ?string {
	return property_in_style_attribute(document, node, property)
}

pub fn resolved_value(document &EditingDocument, node EditingNode, property string) ?string {
	return property_in_style_attribute(document, node, property)
}

pub fn take_the_action_for_command(mut document EditingDocument, command string, value string) {
	document.take_the_action_for_command(command, value)
}

pub fn value_contains_keyword(value string, keyword string) bool {
	return value.to_lower().replace(',', ' ').fields().any(it == keyword.to_lower())
}

// Typed counterpart of wrap(). Blocks are EditingDocument's parent nodes, so
// wrapping a contiguous item list either reuses a matching adjacent block or
// inserts the requested parent block and moves the items while retaining the
// live selection's logical boundaries.
pub fn wrap(mut document EditingDocument, input_nodes []EditingNode, sibling_criteria fn (Block) bool, requested_parent Block) ?EditingNode {
	if input_nodes.len == 0 {
		return none
	}
	block_index := input_nodes[0].block_index
	if input_nodes.any(it.block_index != block_index || it.item_index == none)
		|| block_index < 0 || block_index >= document.blocks.len {
		return none
	}
	mut indices := input_nodes.map(it.item_index or { -1 })
	indices.sort()
	if indices[0] < 0 {
		return none
	}
	mut first := indices[0]
	mut last := indices.last()
	if !indices.any(is_visible_item(document.blocks[block_index].items[it])
		|| document.blocks[block_index].items[it].kind == .line_break) {
		return none
	}
	for first > 0 && !is_visible_item(document.blocks[block_index].items[first - 1]) {
		first--
	}
	for last + 1 < document.blocks[block_index].items.len
		&& !is_visible_item(document.blocks[block_index].items[last + 1]) {
		last++
	}

	mut target_index := -1
	mut source_index := block_index
	mut append_to_target := false
	if block_index > 0 && sibling_criteria(document.blocks[block_index - 1]) {
		target_index = block_index - 1
		append_to_target = true
	} else if block_index + 1 < document.blocks.len
		&& sibling_criteria(document.blocks[block_index + 1]) {
		target_index = block_index + 1
	} else {
		document.blocks.insert(block_index, requested_parent)
		target_index = block_index
		source_index++
		if document.selection.start.block >= block_index {
			document.selection = EditingRange{
				start: Boundary{document.selection.start.block + 1, document.selection.start.offset}
				end:   Boundary{document.selection.end.block + 1, document.selection.end.offset}
			}
		}
	}

	count := last - first + 1
	mut moved := document.blocks[source_index].items[first..first + count].clone()
	document.blocks[source_index].items.delete_many(first, count)
	insertion_index := if append_to_target { document.blocks[target_index].items.len } else { 0 }
	for offset, item in moved {
		document.blocks[target_index].items.insert(insertion_index + offset, item)
	}
	if document.blocks[source_index].items.len == 0 && document.blocks.len > 1 {
		document.blocks.delete(source_index)
		if source_index < target_index {
			target_index--
		}
	}
	remove_extraneous_line_breaks_at_the_end_of_node(mut document,
		EditingNode{block_index: target_index})
	return EditingNode{block_index: target_index}
}
