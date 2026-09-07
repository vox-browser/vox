// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Adapter between Document's live editing host/Selection and the translated
// EditingDocument command engine. DOM owns the entry point, while this module
// owns command state, avoiding a DOM -> Editing package cycle.
module editing

import dom

@[heap]
struct DOMEditingBridge {
mut:
	model_       &EditingDocument = unsafe { nil }
	host_id_     dom.UniqueNodeID
	last_markup_ string
}

struct DOMEditingBoundary {
	node   &dom.Node
	offset int
}

fn rune_utf16_length(character rune) int {
	return if character > rune(0xffff) { 2 } else { 1 }
}

fn rune_index_for_utf16_offset(value string, offset int) int {
	mut code_units := 0
	mut rune_index := 0
	for character in value.runes() {
		units := rune_utf16_length(character)
		if code_units + units > offset {
			break
		}
		code_units += units
		rune_index++
	}
	return rune_index
}

fn utf16_offset_for_rune_index(value string, requested_index int) int {
	mut code_units := 0
	for index, character in value.runes() {
		if index >= requested_index {
			break
		}
		code_units += rune_utf16_length(character)
	}
	return code_units
}

fn editing_text_length(node &dom.Node) int {
	return (node.text_content() or { '' }).runes().len
}

fn offset_within_editing_host(current &dom.Node, target &dom.Node, target_offset int) ?int {
	if current == target {
		if current.is_text() {
			return rune_index_for_utf16_offset(current.text_content() or { '' }, target_offset)
		}
		children := current.children_as_vector()
		limit := if target_offset < 0 {
			0
		} else if target_offset > children.len {
			children.len
		} else {
			target_offset
		}
		mut total := 0
		for child in children[..limit] {
			total += editing_text_length(child)
		}
		return total
	}
	mut total := 0
	for child in current.children_as_vector() {
		if nested_offset := offset_within_editing_host(child, target, target_offset) {
			return total + nested_offset
		}
		total += editing_text_length(child)
	}
	return none
}

fn model_boundary_for_linear_offset(document &EditingDocument, linear_offset int) Boundary {
	mut remaining := if linear_offset < 0 { 0 } else { linear_offset }
	for block_index, block in document.blocks {
		if remaining <= block.items.len {
			return Boundary{block_index, remaining}
		}
		remaining -= block.items.len
		if block_index + 1 < document.blocks.len {
			if remaining == 0 {
				return Boundary{block_index, block.items.len}
			}
			remaining--
		}
	}
	last_index := document.blocks.len - 1
	return Boundary{last_index, document.blocks[last_index].items.len}
}

fn linear_offset_for_model_boundary(document &EditingDocument, boundary Boundary) int {
	mut offset := 0
	for block_index in 0 .. boundary.block {
		offset += document.blocks[block_index].items.len + 1
	}
	return offset + boundary.offset
}

fn dom_boundary_for_linear_offset(current &dom.Node, linear_offset int) ?DOMEditingBoundary {
	if current.is_text() {
		text := current.text_content() or { '' }
		length := text.runes().len
		if linear_offset <= length {
			return DOMEditingBoundary{
				node:   current
				offset: utf16_offset_for_rune_index(text, linear_offset)
			}
		}
		return none
	}
	children := current.children_as_vector()
	if linear_offset <= 0 {
		return DOMEditingBoundary{
			node:   current
			offset: 0
		}
	}
	if linear_offset >= editing_text_length(current) {
		return DOMEditingBoundary{
			node:   current
			offset: children.len
		}
	}
	mut remaining := linear_offset
	for child in children {
		length := editing_text_length(child)
		if remaining <= length {
			if boundary := dom_boundary_for_linear_offset(child, remaining) {
				return boundary
			}
		}
		remaining -= length
	}
	if remaining <= 0 {
		return DOMEditingBoundary{
			node:   current
			offset: children.len
		}
	}
	return none
}

fn restore_dom_selection(document &dom.Document, host &dom.Node, model &EditingDocument) {
	selection_pointer := document.get_selection() or { return }
	start_offset := linear_offset_for_model_boundary(model, model.selection.start)
	end_offset := linear_offset_for_model_boundary(model, model.selection.end)
	start := dom_boundary_for_linear_offset(host, start_offset) or { return }
	end := dom_boundary_for_linear_offset(host, end_offset) or { return }
	mut selection := unsafe { &dom.Selection(selection_pointer) }
	selection.set_base_and_extent(start.node, start.offset, end.node, end.offset) or {}
}

fn dom_editing_exec_command(target voidptr, document &dom.Document, command string, value string) bool {
	if target == unsafe { nil } {
		return false
	}
	selection := document.get_selection() or { return false }
	anchor := selection.anchor_node() or { return false }
	focus := selection.focus_node() or { return false }
	host := anchor.editing_host() or { return false }
	focus_host := focus.editing_host() or { return false }
	if focus_host != host {
		return false
	}
	host_element_pointer := host.as_element() or { return false }
	current_markup := host_element_pointer.inner_html() or { return false }
	mut bridge := unsafe { &DOMEditingBridge(target) }
	if bridge.model_ == unsafe { nil } || bridge.host_id_ != host.unique_id()
		|| bridge.last_markup_ != current_markup {
		bridge.model_ = new_document(host.text_content() or { '' })
		bridge.host_id_ = host.unique_id()
		bridge.last_markup_ = current_markup
	}
	anchor_offset := offset_within_editing_host(host, anchor, selection.anchor_offset()) or {
		return false
	}
	focus_offset := offset_within_editing_host(host, focus, selection.focus_offset()) or {
		return false
	}
	mut model := unsafe { &EditingDocument(bridge.model_) }
	model.set_selection(model_boundary_for_linear_offset(model, anchor_offset), model_boundary_for_linear_offset(model,
		focus_offset)) or { return false }
	result := model.exec_command(command, false, value) or { return false }
	if !result {
		return false
	}
	new_markup := model.serialize_html()
	if new_markup != current_markup {
		mut host_element := unsafe { &dom.Element(host_element_pointer) }
		host_element.set_inner_html(new_markup) or { return false }
	}
	bridge.last_markup_ = new_markup
	restore_dom_selection(document, host, model)
	return true
}

pub fn install_dom_editing_bridge(document &dom.Document) {
	if document.editing_command_hook() != none {
		return
	}
	bridge := &DOMEditingBridge{}
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_editing_command_hook(dom.DocumentEditingCommandHook{
		target:       voidptr(bridge)
		exec_command: dom_editing_exec_command
	})
}
