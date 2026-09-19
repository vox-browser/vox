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
	mut descendants := []&dom.Node{}
	collect_dom_descendants(replacement_fragment.fragment().as_node(), mut descendants)
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
	for descendant in descendants {
		fix_disallowed_ancestors_of_dom_node(descendant)
	}
	current_range := selection.range() or { return caret }
	return current_range.start()
}

pub fn replace_selection_with_block_fragment(document &dom.Document, range_pointer &dom.Range, destination_block &dom.Node, replacement_fragment &ReplacementFragment, mut inserted_content InsertedContent) !dom.BoundaryPoint {
	selection_pointer := document.get_selection() or { return error('document has no selection') }
	mut selection := unsafe { &dom.Selection(selection_pointer) }
	mut range_ := unsafe { &dom.Range(range_pointer) }
	inserted_content.track_replacement_boundary(range_.start(), .block)
	plan := make_block_replacement_plan(range_.start(), destination_block, inserted_content)
	mut destination_trailing_break := ?&dom.Node(none)
	if trailing_break := destination_block.last_child() {
		if is_html_break(trailing_break) {
			destination_trailing_break = trailing_break
		}
	}
	mut right_block := ?&dom.Node(none)

	match plan.insertion_mode {
		.insert_inside_list_item {
			insertion := split_inline_ancestors_at_boundary(range_.start(), destination_block)
			mut mutable_destination := unsafe { &dom.Node(destination_block) }
			inserted_content.insert_before(mut mutable_destination,
				destination_block.child_at_index(insertion.offset))
		}
		.insert_inside_empty_block {
			mut removed_placeholder := false
			if destination_block.child_count() == 1 {
				if first_child := destination_block.first_child() {
					if is_html_break(first_child) {
						mut mutable_break := unsafe { &dom.Node(first_child) }
						mutable_break.remove(false)
						removed_placeholder = true
					}
				}
			}
			if !removed_placeholder {
				remove_dom_extraneous_line_break_at_end(destination_block)
			}
			mut mutable_destination := unsafe { &dom.Node(destination_block) }
			inserted_content.insert_before(mut mutable_destination, none)
		}
		.insert_at_internal_paragraph_boundary {
			insertion := split_inline_ancestors_at_boundary(range_.start(), destination_block)
			mut mutable_destination := unsafe { &dom.Node(destination_block) }
			inserted_content.insert_before(mut mutable_destination,
				destination_block.child_at_index(insertion.offset))
		}
		.insert_after_containing_block {
			parent := destination_block.parent() or {
				return error('destination block has no parent')
			}
			mut mutable_parent := unsafe { &dom.Node(parent) }
			inserted_content.insert_before(mut mutable_parent, destination_block.next_sibling())
		}
		.split_destination {
			right := split_containing_block_at_boundary(range_.start(), destination_block)
			right_block = right
			parent := destination_block.parent() or {
				return error('split destination block has no parent')
			}
			mut mutable_parent := unsafe { &dom.Node(parent) }
			inserted_content.insert_before(mut mutable_parent, right)
		}
	}

	remove_redundant_styles_from_inserted_content(mut inserted_content)
	integrate_first_pasted_list(mut inserted_content, destination_block)
	inserted_content.begin_tracking_content_boundaries()
	integration := ParagraphIntegration.new(document, inserted_content, ParagraphBoundaryState{
		selection_start_was_start_of_paragraph: plan.selection_start_was_start_of_paragraph
		selection_end_was_end_of_paragraph: plan.selection_end_was_end_of_paragraph
	}).decide()
	if plan.insertion_mode == .insert_inside_list_item
		&& plan.selection_end_was_end_of_paragraph
		&& !replacement_fragment.has_interchange_newline_at_end() {
		if trailing_break := destination_trailing_break {
			mut mutable_break := unsafe { &dom.Node(trailing_break) }
			mutable_break.remove(false)
		}
	}

	first_inserted := inserted_content.first_node() or {
		return error('block replacement lost its first node')
	}
	if !integration.merge_start {
		if insertion_boundary := inserted_content.insertion_boundary() {
			canonicalize_dom_whitespace_after_node_insertion(insertion_boundary)
		}
	}
	if integration.merge_start {
		if plan.insertion_mode == .insert_after_containing_block {
			if trailing_break := destination_trailing_break {
				mut mutable_break := unsafe { &dom.Node(trailing_break) }
				mutable_break.remove(false)
			}
		}
		merge_offset := destination_block.child_count()
		if has_dom_visible_children(destination_block) {
			remove_dom_extraneous_line_break_at_end(first_inserted)
		}
		destination := if plan.insertion_mode in [.insert_inside_list_item,
			.insert_at_internal_paragraph_boundary] {
			dom.BoundaryPoint{
				node: destination_block
				offset: first_inserted.index()
			}
		} else {
			dom.BoundaryPoint{
				node: destination_block
				offset: merge_offset
			}
		}
		transfer_options := ParagraphTransferOptions{
			source_style: if node_has_html_name(destination_block, ['li']) {
				ParagraphTransferStyle.match_destination
			} else {
				ParagraphTransferStyle.preserve_visual_appearance
			}
		}
		transferred := transfer_paragraph_contents(first_inserted, destination, transfer_options)
		canonicalize_dom_whitespace_after_node_insertion(dom.BoundaryPoint{
			node: destination_block
			offset: merge_offset
		})
		inserted_content.did_replace_node(first_inserted, destination_block)
		inserted_content.did_move_start_paragraph(transferred.start)
		if plan.insertion_mode == .insert_after_containing_block {
			if trailing_break := destination_trailing_break {
				restore_replacement_trailing_break(destination_block, trailing_break)
			}
		}
	} else if !has_dom_visible_children(destination_block)
		&& !replacement_node_has_renderable_descendant(destination_block) {
		mut mutable_destination := unsafe { &dom.Node(destination_block) }
		mutable_destination.remove(false)
	}

	last_inserted := inserted_content.last_node() or {
		return error('block replacement lost its last node')
	}
	can_merge_end_with_suffix := plan.insertion_mode in [.split_destination,
		.insert_at_internal_paragraph_boundary]
	if plan.insertion_mode == .insert_inside_list_item && integration.merge_end
		&& last_inserted.parent() != none && can_merge_paragraph_contents(last_inserted)
		&& has_mergeable_visible_children(last_inserted) {
		if has_dom_visible_children(destination_block) {
			remove_dom_extraneous_line_break_at_end(last_inserted)
		}
		inserted_content.will_integrate_end_paragraph(last_inserted)
		transferred := transfer_paragraph_contents(last_inserted, dom.BoundaryPoint{
			node: destination_block
			offset: last_inserted.index()
		}, ParagraphTransferOptions{})
		inserted_content.did_replace_node(last_inserted, destination_block)
		caret := finalize_inserted_content(mut inserted_content, transferred.end)
		if trailing_break := destination_trailing_break {
			restore_replacement_trailing_break(destination_block, trailing_break)
		}
		selection.collapse(caret.node, caret.offset)!
		return caret
	}

	if can_merge_end_with_suffix && integration.merge_end && last_inserted.parent() != none
		&& can_merge_paragraph_contents(last_inserted)
		&& has_mergeable_visible_children(last_inserted) {
		merge_end_text_seam := plan.fragment_begins_with_list && last_inserted.child_count() == 1
			&& (if child := last_inserted.first_child() { child.is_text() } else { false })
		if merge_end_text_seam {
			inserted_content.require_end_text_seam_normalization()
		}
		mut caret := inserted_content.end_boundary() or {
			return error('block replacement lost its end boundary')
		}
		merge_offset := last_inserted.child_count()
		mut whitespace_boundary := ?dom.BoundaryPoint(none)
		inserted_content.will_integrate_end_paragraph(last_inserted)
		if plan.insertion_mode == .insert_at_internal_paragraph_boundary {
			insertion_offset := last_inserted.index()
			transferred := transfer_paragraph_contents(last_inserted, dom.BoundaryPoint{
				node: destination_block
				offset: insertion_offset
			}, ParagraphTransferOptions{
				source_style: .preserve_visual_appearance
			})
			inserted_content.did_replace_node_range(last_inserted, transferred.first_node,
				transferred.last_node)
			caret = transferred.end
			whitespace_boundary = dom.BoundaryPoint{
				node: unsafe { &dom.Node(destination_block) }
				offset: insertion_offset + merge_offset
			}
		} else {
			right := right_block or { return error('replacement suffix block is missing') }
			seam := if last_inserted.child_count() == 1
				&& (if child := last_inserted.first_child() { child.is_text() } else { false }) {
				ParagraphTransferSeam.coalesce_destination_text
			} else {
				ParagraphTransferSeam.preserve
			}
			transferred := transfer_paragraph_contents(right, dom.BoundaryPoint{
				node: last_inserted
				offset: merge_offset
			}, ParagraphTransferOptions{
				destination_style: .preserve_visual_appearance
				seam: seam
			})
			if destination_seam := transferred.destination_text_seam {
				caret = destination_seam
				whitespace_boundary = destination_seam
			}
		}
		if boundary := whitespace_boundary {
			canonicalize_dom_whitespace_after_node_insertion(boundary)
		} else {
			canonicalize_dom_whitespace_after_node_insertion(dom.BoundaryPoint{
				node: last_inserted
				offset: merge_offset
			})
		}
		caret = finalize_inserted_content(mut inserted_content, caret)
		caret = canonicalize_inserted_content_end(caret, replacement_fragment, plan)
		selection.collapse(caret.node, caret.offset)!
		return caret
	}

	mut caret := inserted_content.end_boundary() or {
		return error('block replacement lost its end boundary')
	}
	if plan.insertion_mode == .split_destination {
		right := right_block or { return error('replacement suffix block is missing') }
		if !has_dom_visible_children(right) && !replacement_node_has_renderable_descendant(right) {
			mut mutable_right := unsafe { &dom.Node(right) }
			mutable_right.remove(false)
		} else if leading_text := first_replacement_text_descendant(right) {
			characters := leading_text.data().runes()
			if characters.len > 0 && is_ascii_space_character(characters[0]) {
				contains_only_whitespace := characters.all(is_ascii_space_character(it))
				mut mutable_leading := unsafe { &dom.Text(leading_text) }
				if contains_only_whitespace {
					mutable_leading.insert_data(0, '\u00a0')!
				} else {
					mutable_leading.replace_data(0, 1, '\u00a0')!
				}
			} else {
				canonicalize_dom_whitespace_after_node_insertion(dom.BoundaryPoint{
					node: right
					offset: 0
				})
			}
		} else {
			canonicalize_dom_whitespace_after_node_insertion(dom.BoundaryPoint{
				node: right
				offset: 0
			})
		}
	}
	caret = finalize_inserted_content(mut inserted_content, caret)
	caret = canonicalize_inserted_content_end(caret, replacement_fragment, plan)
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

pub fn replace_collapsed_selection_with_html(document &dom.Document, value string) !dom.BoundaryPoint {
	selection := document.get_selection() or { return error('document has no selection') }
	range_ := selection.range() or { return error('document has no active range') }
	if !range_.collapsed() {
		return error('replacement requires a collapsed selection')
	}
	replacement_fragment := ReplacementFragment.new(range_, value)!
	mut inserted_content := InsertedContent.new(replacement_fragment.children())
	if inserted_content.is_empty() {
		return range_.start()
	}
	defer {
		inserted_content.release()
	}
	destination_block := block_node_of_dom_node(range_.start_container())
	if replacement_fragment.contains_block_content() {
		if block := destination_block {
			is_editing_host := if editing_host := range_.start_container().editing_host() {
				block == editing_host
			} else {
				false
			}
			if !is_editing_host {
				return replace_selection_with_block_fragment(document, range_, block,
					replacement_fragment, mut inserted_content)
			}
		}
	}
	return replace_selection_with_inline_fragment(document, range_, replacement_fragment,
		mut inserted_content)
}
