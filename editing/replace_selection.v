// Copyright (c) 2026-present, the Ladybird developers
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the inline replacement path in Editing/ReplaceSelection.cpp.
module editing

import dom

fn collect_subtree_descendants(node &dom.Node, mut descendants []&dom.Node) {
	for child in node.children_as_vector() {
		descendants << child
		collect_subtree_descendants(child, mut descendants)
	}
}

fn remove_collapsed_block_props_at_boundary(boundary dom.BoundaryPoint) {
	if !is_block_node(boundary.node) {
		return
	}
	mut collapsed_props := []&dom.Node{}
	for child in boundary.node.children_as_vector() {
		if child.index() >= boundary.offset && child.is_editable() && is_collapsed_block_prop(child) {
			collapsed_props << child
		}
	}
	for node in collapsed_props {
		remove_node(node)
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
	collect_subtree_descendants(replacement_fragment.fragment().as_node(), mut descendants)
	inserted_content.track_replacement_boundary(range_.start(), .inline_)
	remove_collapsed_block_props_at_boundary(range_.start())

	containing_block := block_node_of_node(range_.start_container()) or {
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
		canonicalize_whitespace_after_node_insertion(dom.BoundaryPoint{
			node: first_inserted
			offset: 0
		})
	}
	if !first_inserted.is_text() {
		canonicalize_whitespace_after_node_insertion(dom.BoundaryPoint{
			node: first_inserted
			offset: 0
		})
	}
	if end_boundary := inserted_content.end_boundary() {
		canonicalize_whitespace_after_node_insertion(end_boundary)
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

	current_range := editing_active_range(document)
	if is_block_node(current_range.start_container())
		&& !has_visible_children(current_range.start_container()) {
		line_break := document.create_element('br')!
		append_node(line_break.as_node(), current_range.start_container())!
	}
	selection.collapse(caret.node, caret.offset)!
	for descendant in descendants {
		fix_disallowed_ancestors_of_node(descendant)
	}
	final_range := selection.range() or { return caret }
	return final_range.start()
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
			inserted_content.insert_before(destination_block,
				destination_block.child_at_index(insertion.offset))
		}
		.insert_inside_empty_block {
			mut removed_placeholder := false
			if destination_block.child_count() == 1 {
				if first_child := destination_block.first_child() {
					if is_html_break(first_child) {
						remove_node(first_child)
						removed_placeholder = true
					}
				}
			}
			if !removed_placeholder {
				remove_extraneous_line_breaks_at_the_end_of_node(destination_block)
			}
			inserted_content.insert_before(destination_block, none)
		}
		.insert_at_internal_paragraph_boundary {
			insertion := split_inline_ancestors_at_boundary(range_.start(), destination_block)
			inserted_content.insert_before(destination_block,
				destination_block.child_at_index(insertion.offset))
		}
		.insert_after_containing_block {
			parent := destination_block.parent() or {
				return error('destination block has no parent')
			}
			inserted_content.insert_before(parent, destination_block.next_sibling())
		}
		.split_destination {
			right := split_containing_block_at_boundary(range_.start(), destination_block)
			right_block = right
			parent := destination_block.parent() or {
				return error('split destination block has no parent')
			}
			inserted_content.insert_before(parent, right)
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
			remove_node(trailing_break)
		}
	}

	first_inserted := inserted_content.first_node() or {
		return error('block replacement lost its first node')
	}
	if !integration.merge_start {
		if insertion_boundary := inserted_content.insertion_boundary() {
			canonicalize_whitespace_after_node_insertion(insertion_boundary)
		}
	}
	if integration.merge_start {
		if plan.insertion_mode == .insert_after_containing_block {
			if trailing_break := destination_trailing_break {
				remove_node(trailing_break)
			}
		}
		merge_offset := destination_block.child_count()
		if has_visible_children(destination_block) {
			remove_extraneous_line_breaks_at_the_end_of_node(first_inserted)
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
		canonicalize_whitespace_after_node_insertion(dom.BoundaryPoint{
			node: destination_block
			offset: merge_offset
		})
		inserted_content.did_replace_node(first_inserted, destination_block)
		inserted_content.did_move_start_paragraph(transferred.start)
		if plan.insertion_mode == .insert_after_containing_block {
			if trailing_break := destination_trailing_break {
				restore_trailing_break(destination_block, trailing_break)
			}
		}
	} else if !has_visible_children(destination_block) {
		remove_node(destination_block)
	}

	last_inserted := inserted_content.last_node() or {
		return error('block replacement lost its last node')
	}
	can_merge_end_with_suffix := plan.insertion_mode in [.split_destination,
		.insert_at_internal_paragraph_boundary]
	if plan.insertion_mode == .insert_inside_list_item && integration.merge_end
		&& last_inserted.parent() != none && can_merge_paragraph_contents(last_inserted)
		&& has_mergeable_visible_children(last_inserted) {
		if has_visible_children(destination_block) {
			remove_extraneous_line_breaks_at_the_end_of_node(last_inserted)
		}
		inserted_content.will_integrate_end_paragraph(last_inserted)
		transferred := transfer_paragraph_contents(last_inserted, dom.BoundaryPoint{
			node: destination_block
			offset: last_inserted.index()
		}, ParagraphTransferOptions{})
		inserted_content.did_replace_node(last_inserted, destination_block)
		caret := finalize_inserted_content(mut inserted_content, transferred.end)
		if trailing_break := destination_trailing_break {
			restore_trailing_break(destination_block, trailing_break)
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
			canonicalize_whitespace_after_node_insertion(boundary)
		} else {
			canonicalize_whitespace_after_node_insertion(dom.BoundaryPoint{
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
		if !has_visible_children(right) {
			remove_node(right)
		} else if leading_text := first_text_descendant(right) {
			characters := leading_text.data().runes()
			if characters.len > 0 && is_ascii_space_character(characters[0]) {
				contains_only_whitespace := characters.all(is_ascii_space_character(it))
				leading_data := editing_character_data(leading_text.as_node())
				if contains_only_whitespace {
					insert_data(leading_data, 0, '\u00a0')!
				} else {
					replace_data(leading_data, 0, 1, '\u00a0')!
				}
			} else {
				canonicalize_whitespace_after_node_insertion(dom.BoundaryPoint{
					node: right
					offset: 0
				})
			}
		} else {
			canonicalize_whitespace_after_node_insertion(dom.BoundaryPoint{
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

// ReplaceSelection.cpp's replace_selection_with_fragment(): parse the markup relative to the collapsed active range and
// insert it as inline or block content.
pub fn replace_selection_with_fragment(document &dom.Document, value string) !dom.BoundaryPoint {
	selection := document.get_selection() or { return error('document has no selection') }
	range_ := selection.range() or { return error('document has no active range') }
	if !range_.collapsed() {
		return error('replacement requires a collapsed selection')
	}
	history := begin_editing_proxy_mutation(range_.start_container())
	fragment := range_.create_contextual_fragment(value) or {
		end_editing_proxy_mutation(history)
		return err
	}
	end_editing_proxy_mutation(history)
	return replace_selection_with_document_fragment(document, fragment)
}

pub fn replace_selection_with_document_fragment(document &dom.Document, fragment &dom.DocumentFragment) !dom.BoundaryPoint {
	selection := document.get_selection() or { return error('document has no selection') }
	range_ := selection.range() or { return error('document has no active range') }
	if !range_.collapsed() {
		return error('replacement requires a collapsed selection')
	}
	replacement_fragment := ReplacementFragment.from_fragment(range_, fragment)
	mut inserted_content := InsertedContent.new(replacement_fragment.children())
	if inserted_content.is_empty() {
		return range_.start()
	}
	defer {
		inserted_content.release()
	}
	destination_block := block_node_of_node(range_.start_container())
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
