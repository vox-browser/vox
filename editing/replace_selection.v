// Copyright (c) 2026-present, the Ladybird developers
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the inline replacement path in Editing/ReplaceSelection.cpp.
module editing

import dom

fn dom_collapsed_block_prop(node &dom.Node) bool {
	if is_html_break(node) {
		return true
	}
	element := node.as_element() or { return false }
	if !element.is_html_element() || !is_dom_inline_node(node) {
		return false
	}
	mut has_collapsed_prop := false
	for child in node.children_as_vector() {
		if dom_collapsed_block_prop(child) {
			has_collapsed_prop = true
			continue
		}
		if node_is_visible_for_paragraph_integration(child) {
			return false
		}
	}
	return has_collapsed_prop
}

fn remove_collapsed_block_props_at_boundary(boundary dom.BoundaryPoint) {
	if !is_dom_block_node(boundary.node) {
		return
	}
	mut collapsed_props := []&dom.Node{}
	for child in boundary.node.children_as_vector() {
		if child.index() >= boundary.offset && child.is_editable() && dom_collapsed_block_prop(child) {
			collapsed_props << child
		}
	}
	for node in collapsed_props {
		mut mutable_node := unsafe { &dom.Node(node) }
		mutable_node.remove(false)
	}
}

fn text_ends_in_protected_whitespace(text &dom.Text) bool {
	characters := text.data().runes()
	return characters.all(is_ascii_space_character(it) || it == `\u00a0`)
}

pub fn replace_selection_with_inline_fragment(document &dom.Document, range_pointer &dom.Range, replacement_fragment &ReplacementFragment, mut inserted_content InsertedContent) !dom.BoundaryPoint {
	selection_pointer := document.get_selection() or { return error('document has no selection') }
	mut selection := unsafe { &dom.Selection(selection_pointer) }
	mut range_ := unsafe { &dom.Range(range_pointer) }
	inserted_content.track_replacement_boundary(range_.start(), .inline_)
	remove_collapsed_block_props_at_boundary(range_.start())

	containing_block := block_node_of_dom_node(range_.start_container()) or {
		return error('inline replacement has no containing block')
	}
	insertion := prepare_inline_insertion_boundary(range_.start(), containing_block)
	range_.set_start(insertion.boundary.node, insertion.boundary.offset)!
	range_.collapse(true)

	inserted_content.insert_into_range(mut range_, replacement_fragment.fragment())!
	remove_redundant_styles_from_inserted_content(mut inserted_content)
	inserted_content.begin_tracking_content_boundaries()
	first_inserted := inserted_content.first_node() or {
		return error('inline replacement lost its first node')
	}
	if insertion.split_destination_style {
		canonicalize_dom_whitespace_after_node_insertion(dom.BoundaryPoint{
			node: first_inserted
			offset: 0
		})
	}
	if !first_inserted.is_text() {
		canonicalize_dom_whitespace_after_node_insertion(dom.BoundaryPoint{
			node: first_inserted
			offset: 0
		})
	}
	if end_boundary := inserted_content.end_boundary() {
		canonicalize_dom_whitespace_after_node_insertion(end_boundary)
	}

	mut caret := inserted_content.end_boundary() or {
		return error('inline replacement lost its end boundary')
	}
	if last_inserted := inserted_content.last_node() {
		if last_inserted.is_text() && !replacement_fragment.has_interchange_newline_at_start() {
			last_text := unsafe { &dom.Text(last_inserted) }
			if !text_ends_in_protected_whitespace(last_text)
				|| replacement_fragment.contains_only_text() {
				inserted_content.require_end_text_seam_normalization()
			}
		}
	}
	caret = finalize_inserted_content(mut inserted_content, caret)

	if is_dom_block_node(range_.start_container())
		&& !has_dom_visible_children(range_.start_container())
		&& !replacement_node_has_renderable_descendant(range_.start_container()) {
		line_break := document.create_element('br')!
		mut container := unsafe { &dom.Node(range_.start_container()) }
		container.append_child(line_break.as_node())!
	}
	selection.collapse(caret.node, caret.offset)!
	return caret
}

pub fn replace_collapsed_selection_with_inline_html(document &dom.Document, value string) !dom.BoundaryPoint {
	selection := document.get_selection() or { return error('document has no selection') }
	range_ := selection.range() or { return error('document has no active range') }
	if !range_.collapsed() {
		return error('inline replacement requires a collapsed selection')
	}
	replacement_fragment := ReplacementFragment.new(range_, value)!
	mut inserted_content := InsertedContent.new(replacement_fragment.children())
	if inserted_content.is_empty() {
		return range_.start()
	}
	defer {
		inserted_content.release()
	}
	return replace_selection_with_inline_fragment(document, range_, replacement_fragment,
		mut inserted_content)
}
