// Copyright (c) 2024-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the whitespace canonicalization and selection deletion algorithms in
// Editing/Internal/Algorithms.cpp.
module editing

import dom

pub enum SelectionDirection {
	forwards
	backwards
}

enum PreserveLeadingSpaceAcrossNodeBoundary {
	no
	yes
}

enum AtomicContentTraversal {
	cross
	stop
}

fn editing_character_data(node &dom.Node) &dom.CharacterData {
	return node.as_character_data() or { panic('expected a CharacterData node') }
}

fn editing_parent_preserves_white_space(node &dom.Node) bool {
	parent := node.parent() or { return false }
	return resolved_keyword(parent, 'white-space-collapse') or { '' } == 'preserve'
}

// INTEROP: Chromium canonicalizes caret positions for editing into the nearest equivalent text position. An
//          element-level caret descends into adjacent editable leaf content, preferring the end of what comes before
//          it and then the start of what comes after it. Commands use the canonical point both between editing phases
//          and when recording their final selection in the editing history.
pub fn canonicalize_collapsed_selection_for_editing(mut selection dom.Selection) {
	range_ := selection.range() or { return }
	if !selection.is_collapsed() {
		return
	}
	document := range_.start_container().document()
	navigator := dom.CaretNavigator.new(document)
	canonical_location := navigator.canonical_location_for_editing(dom.CaretLocation{
		node:     range_.start_container()
		offset:   range_.start_offset()
		affinity: selection.focus_affinity()
	})
	if voidptr(canonical_location.node) != voidptr(range_.start_container())
		|| canonical_location.offset != range_.start_offset() {
		selection.collapse(canonical_location.node, canonical_location.offset) or { panic(err) }
	}
}

// https://w3c.github.io/editing/docs/execCommand/#canonicalize-whitespace
fn canonicalize_whitespace_impl(boundary dom.BoundaryPoint, fix_collapsed_space bool, preserve_leading_space PreserveLeadingSpaceAcrossNodeBoundary, atomic_content_traversal AtomicContentTraversal) {
	node := boundary.node
	offset := boundary.offset

	// 1. If node is neither editable nor an editing host, abort these steps.
	if !node.is_editable_or_editing_host() {
		return
	}

	// 2. Let start node equal node and let start offset equal offset.
	mut start_node := unsafe { node }
	mut start_offset := offset

	// 3. Repeat the following steps:
	for {
		// 1. If start node has a child in the same editing host with index start offset minus one,
		//    set start node to that child, then set start offset to start node's length.
		if offset_minus_one_child := start_node.child_at_index(start_offset - 1) {
			if is_in_same_editing_host(start_node, offset_minus_one_child) {
				if atomic_content_traversal == .stop && editing_ignores_content(offset_minus_one_child) {
					break
				}
				start_node = offset_minus_one_child
				start_offset = start_node.length()
				continue
			}
		}

		// 2. Otherwise, if start offset is zero and start node does not follow a line break and
		//    start node's parent is in the same editing host, set start offset to start node's
		//    index, then set start node to its parent.
		if start_offset == 0 && !follows_a_line_break(start_node) {
			if parent := start_node.parent() {
				if is_in_same_editing_host(start_node, parent) {
					start_offset = start_node.index()
					start_node = parent
					continue
				}
			}
		}

		// 3. Otherwise, if start node is a Text node and its parent's resolved value for
		//    "white-space" is neither "pre" nor "pre-wrap" and start offset is not zero and the
		//    (start offset − 1)st code unit of start node's data is a space (0x0020) or
		//    non-breaking space (0x00A0), subtract one from start offset.
		// AD-HOC: Use the white-space-collapse longhand instead of "white-space" shorthand: https://github.com/w3c/editing/issues/486.
		if start_node.is_text() && start_offset != 0 {
			offset_minus_one_code_unit := editing_code_unit_at(editing_text_data(start_node), start_offset - 1) or {
				0
			}
			if !editing_parent_preserves_white_space(start_node)
				&& (offset_minus_one_code_unit == 0x20 || offset_minus_one_code_unit == 0xa0) {
				start_offset--
				continue
			}
		}

		// 4. Otherwise, break from this loop.
		break
	}

	// 4. Let end node equal start node and end offset equal start offset.
	mut end_node := start_node
	mut end_offset := start_offset

	// 5. Let length equal zero.
	mut length := 0

	// 6. Let collapse spaces be true if start offset is zero and start node follows a line break,
	//    otherwise false.
	mut collapse_spaces := start_offset == 0 && follows_a_line_break(start_node)

	// 7. Repeat the following steps:
	for {
		// 1. If end node has a child in the same editing host with index end offset, set end node
		//    to that child, then set end offset to zero.
		if offset_child := end_node.child_at_index(end_offset) {
			if is_in_same_editing_host(end_node, offset_child) {
				if atomic_content_traversal == .stop && editing_ignores_content(offset_child) {
					break
				}
				end_node = offset_child
				end_offset = 0
				continue
			}
		}

		// 2. Otherwise, if end offset is end node's length and end node does not precede a line
		//    break and end node's parent is in the same editing host, set end offset to one plus
		//    end node's index, then set end node to its parent.
		if end_offset == end_node.length() && !precedes_a_line_break(end_node) {
			if parent := end_node.parent() {
				if is_in_same_editing_host(end_node, parent) {
					end_offset = end_node.index() + 1
					end_node = parent
					continue
				}
			}
		}

		// 3. Otherwise, if end node is a Text node and its parent's resolved value for
		//    "white-space" is neither "pre" nor "pre-wrap" and end offset is not end node's length
		//    and the end offsetth code unit of end node's data is a space (0x0020) or non-breaking
		//    space (0x00A0):
		// AD-HOC: Use the white-space-collapse longhand instead of "white-space" shorthand: https://github.com/w3c/editing/issues/486.
		if end_node.is_text() && end_offset != end_node.length() {
			offset_code_unit := editing_code_unit_at(editing_text_data(end_node), end_offset) or { 0 }
			if !editing_parent_preserves_white_space(end_node)
				&& (offset_code_unit == 0x20 || offset_code_unit == 0xa0) {
				// 1. If fix collapsed space is true, and collapse spaces is true, and the end offsetth
				//    code unit of end node's data is a space (0x0020): call deleteData(end offset, 1)
				//    on end node, then continue this loop from the beginning.
				if fix_collapsed_space && collapse_spaces && offset_code_unit == 0x20 {
					delete_data(editing_character_data(end_node), end_offset, 1) or { panic(err) }
					continue
				}

				// 2. Set collapse spaces to true if the end offsetth code unit of end node's data is a
				//    space (0x0020), false otherwise.
				collapse_spaces = offset_code_unit == 0x20

				// 3. Add one to end offset.
				end_offset++

				// 4. Add one to length.
				length++

				// NOTE: We continue the loop here since we matched every condition from step 7.3
				continue
			}
		}

		// 4. Otherwise, break from this loop.
		break
	}

	// 8. If fix collapsed space is true, then while (start node, start offset) is before (end node,
	//    end offset):
	if fix_collapsed_space {
		for {
			relative_position := dom.position_of_boundary_point_relative_to_other_boundary_point(editing_boundary(start_node, start_offset),
				editing_boundary(end_node, end_offset))
			if relative_position != .before {
				break
			}

			// 1. If end node has a child in the same editing host with index end offset − 1, set end
			//    node to that child, then set end offset to end node's length.
			if offset_minus_one_child := end_node.child_at_index(end_offset - 1) {
				if is_in_same_editing_host(end_node, offset_minus_one_child) {
					end_node = offset_minus_one_child
					end_offset = end_node.length()
					continue
				}
			}

			// 2. Otherwise, if end offset is zero and end node's parent is in the same editing host,
			//    set end offset to end node's index, then set end node to its parent.
			if end_offset == 0 {
				if parent := end_node.parent() {
					if is_in_same_editing_host(end_node, parent) {
						end_offset = end_node.index()
						end_node = parent
						continue
					}
				}
			}

			// 3. Otherwise, if end node is a Text node and its parent's resolved value for
			//    "white-space" is neither "pre" nor "pre-wrap" and end offset is end node's length and
			//    the last code unit of end node's data is a space (0x0020) and end node precedes a line
			//    break:
			// AD-HOC: Use the white-space-collapse longhand instead of "white-space" shorthand: https://github.com/w3c/editing/issues/486.
			if end_node.is_text() && end_offset == end_node.length() && precedes_a_line_break(end_node) {
				if !editing_parent_preserves_white_space(end_node) && editing_text_data(end_node).ends_with(' ') {
					// 1. Subtract one from end offset.
					end_offset--

					// 2. Subtract one from length.
					length--

					// 3. Call deleteData(end offset, 1) on end node.
					delete_data(editing_character_data(end_node), end_offset, 1) or { panic(err) }

					// NOTE: We continue the loop here since we matched every condition from step 8.3
					continue
				}
			}

			// 4. Otherwise, break from this loop.
			break
		}
	}

	// 9. Let replacement whitespace be the canonical space sequence of length length. non-breaking
	//    start is true if start offset is zero and start node follows a line break, and false
	//    otherwise. non-breaking end is true if end offset is end node's length and end node
	//    precedes a line break, and false otherwise.
	// AD-HOC: Other browsers' behavior here is to set non_breaking_start to true if length > 1, so we add that
	//         condition as well.
	// INTEROP: After deleting a selection, Chromium preserves a whitespace run that crosses an inline node boundary.
	// This matters when replacing content across wrappers or atomic inline content, where an ordinary leading space
	// would otherwise collapse against the preceding run. Ordinary insertion across the same boundary keeps the space.
	non_breaking_start := (start_offset == 0 && follows_a_line_break(start_node))
		|| (preserve_leading_space == .yes && voidptr(start_node) != voidptr(end_node))
	replacement_whitespace := canonical_space_sequence(length, non_breaking_start || length > 1,
		end_offset == end_node.length() && precedes_a_line_break(end_node)).runes()
	mut replacement_index := 0

	// 10. While (start node, start offset) is before (end node, end offset):
	for {
		relative_position := dom.position_of_boundary_point_relative_to_other_boundary_point(editing_boundary(start_node, start_offset),
			editing_boundary(end_node, end_offset))
		if relative_position != .before {
			break
		}

		// 1. If start node has a child with index start offset, set start node to that child, then
		//    set start offset to zero.
		if child := start_node.child_at_index(start_offset) {
			start_node = child
			start_offset = 0
		}

		// 2. Otherwise, if start node is not a Text node or if start offset is start node's length,
		//    set start offset to one plus start node's index, then set start node to its parent.
		else if !start_node.is_text() || start_offset == start_node.length() {
			parent := start_node.parent() or { break }
			start_offset = start_node.index() + 1
			start_node = parent
		}

		// 3. Otherwise:
		else {
			// 1. Remove the first code unit from replacement whitespace, and let element be that
			//    code unit.
			if replacement_index >= replacement_whitespace.len {
				break
			}
			element := replacement_whitespace[replacement_index]
			replacement_index++

			// 2. If element is not the same as the start offsetth code unit of start node's data:
			start_node_code_unit := editing_code_unit_at(editing_text_data(start_node), start_offset) or {
				0
			}
			if u32(element) != u32(start_node_code_unit) {
				// 1. Call insertData(start offset, element) on start node.
				start_node_character_data := editing_character_data(start_node)
				insert_data(start_node_character_data, start_offset, element.str()) or { panic(err) }

				// 2. Call deleteData(start offset + 1, 1) on start node.
				delete_data(start_node_character_data, start_offset + 1, 1) or { panic(err) }
			}

			// 3. Add one to start offset.
			start_offset++
		}
	}
}

pub fn canonicalize_whitespace(boundary dom.BoundaryPoint, fix_collapsed_space bool) {
	canonicalize_whitespace_impl(boundary, fix_collapsed_space, .no, .cross)
}

pub fn canonicalize_whitespace_after_selection_replacement(boundary dom.BoundaryPoint) {
	// INTEROP: Chromium preserves a leading collapsible space when replacing a selection exposes it across an
	//          inline node boundary. The execCommand draft does not distinguish this case from ordinary insertion.
	canonicalize_whitespace_impl(boundary, false, .yes, .cross)
}

pub fn canonicalize_whitespace_after_node_insertion(boundary dom.BoundaryPoint) {
	// INTEROP: Inserting an inline node can strand a collapsible space at the new node boundary. Chromium preserves
	//          that space with the same non-breaking-space canonicalization used after replacing a selection.
	// Clipboard serialization has already protected whitespace adjacent to atomic content. Normalize the insertion
	// seam up to that content, but do not rewrite a separate whitespace seam on its other side.
	canonicalize_whitespace_impl(boundary, false, .yes, .stop)
}

fn editing_collapse_by_direction(mut selection dom.Selection, direction SelectionDirection) {
	// If direction is "forward", call collapseToStart() on the context object's selection. Otherwise, call
	// collapseToEnd() on the context object's selection.
	if direction == .forwards {
		selection.collapse_to_start() or { panic(err) }
	} else {
		selection.collapse_to_end() or { panic(err) }
	}
}

fn editing_block_for_deletion(input_block &dom.Node) ?&dom.Node {
	mut block := unsafe { input_block }

	// While block's parent is in the same editing host and block is an inline node, set block to its parent.
	for {
		parent := block.parent() or { break }
		if !is_in_same_editing_host(parent, block) || !is_inline_node(block) {
			break
		}
		block = parent
	}

	// If block is neither a block node nor an editing host, or "span" is not an allowed child of block, or block is a
	// td or th, set block to null.
	if (!is_block_node(block) && !block.is_editing_host())
		|| !is_allowed_child_of_node(allowed_child_name('span'), allowed_child_node(block))
		|| block.is_html_table_cell_element() {
		return none
	}
	return block
}

// https://w3c.github.io/editing/docs/execCommand/#delete-the-selection
pub fn delete_the_selection(mut selection dom.Selection, block_merging bool, strip_wrappers bool, direction SelectionDirection) {
	range_ := selection.range() or { return }
	mut document := unsafe { &dom.Document(range_.start_container().document()) }

	// 1. If the active range is null, abort these steps and do nothing.
	// NOTE: The selection is collapsed often in this algorithm, so we shouldn't store the active range in a variable.
	if active_range(document) == none {
		return
	}

	// 2. Canonicalize whitespace at the active range's start.
	canonicalize_whitespace((active_range(document) or { return }).start(), true)

	// 3. Canonicalize whitespace at the active range's end.
	canonicalize_whitespace((active_range(document) or { return }).end(), true)

	// 4. Let (start node, start offset) be the last equivalent point for the active range's start.
	mut start := last_equivalent_point((active_range(document) or { return }).start())

	// 5. Let (end node, end offset) be the first equivalent point for the active range's end.
	mut end := first_equivalent_point((active_range(document) or { return }).end())

	// 6. If (end node, end offset) is not after (start node, start offset):
	relative_position := dom.position_of_boundary_point_relative_to_other_boundary_point(end, start)
	if relative_position != .after {
		// 1. If direction is "forward", call collapseToStart() on the context object's selection.
		// 2. Otherwise, call collapseToEnd() on the context object's selection.
		editing_collapse_by_direction(mut selection, direction)

		// 3. Abort these steps.
		return
	}

	// 7. If start node is a Text node and start offset is 0, set start offset to the index of start node, then set
	//    start node to its parent.
	if start.node.is_text() && start.offset == 0 {
		if parent := start.node.parent() {
			start = editing_boundary(parent, start.node.index())
		}
	}

	// 8. If end node is a Text node and end offset is its length, set end offset to one plus the index of end node,
	//    then set end node to its parent.
	if end.node.is_text() && end.offset == end.node.length() {
		if parent := end.node.parent() {
			end = editing_boundary(parent, end.node.index() + 1)
		}
	}

	// 9. Call collapse(start node, start offset) on the context object's selection.
	selection.collapse(start.node, start.offset) or { panic(err) }

	// 10. Call extend(end node, end offset) on the context object's selection.
	selection.extend(end.node, end.offset) or { panic(err) }

	// 12. Let start block be the active range's start node.
	// 13. While start block's parent is in the same editing host and start block is an inline node, set start block to
	//     its parent.
	// 14. If start block is neither a block node nor an editing host, or "span" is not an allowed child of start block,
	//     or start block is a td or th, set start block to null.
	mut start_block := editing_block_for_deletion((active_range(document) or { return }).start_container())

	// 15. Let end block be the active range's end node.
	// 16. While end block's parent is in the same editing host and end block is an inline node, set end block to its
	//     parent.
	// 17. If end block is neither a block node nor an editing host, or "span" is not an allowed child of end block, or
	//     end block is a td or th, set end block to null.
	mut end_block := editing_block_for_deletion((active_range(document) or { return }).end_container())

	// 19. Record current states and values, and let overrides be the result.
	overrides := record_current_states_and_values(document)

	// 21. If start node and end node are the same, and start node is an editable Text node:
	if voidptr(start.node) == voidptr(end.node) && start.node.is_text() && start.node.is_editable() {
		// 1. Call deleteData(start offset, end offset − start offset) on start node.
		delete_data(editing_character_data(start.node), start.offset, end.offset - start.offset) or {
			panic(err)
		}

		// 2. Canonicalize whitespace at (start node, start offset), with fix collapsed space false.
		canonicalize_whitespace(start, false)

		// 3. If direction is "forward", call collapseToStart() on the context object's selection.
		// 4. Otherwise, call collapseToEnd() on the context object's selection.
		editing_collapse_by_direction(mut selection, direction)

		// 5. Restore states and values from overrides.
		restore_states_and_values(mut document, overrides)

		// 6. Abort these steps.
		return
	}

	// 22. If start node is an editable Text node, call deleteData() on it, with start offset as the first argument and
	//     (length of start node − start offset) as the second argument.
	if start.node.is_text() && start.node.is_editable() {
		delete_data(editing_character_data(start.node), start.offset, start.node.length() - start.offset) or {
			panic(err)
		}
	}

	// 23. Let node list be a list of nodes, initially empty.
	mut node_list := []&dom.Node{}

	// 24. For each node contained in the active range, append node to node list if the last member of node list (if
	//     any) is not an ancestor of node; node is editable; and node is not a thead, tbody, tfoot, tr, th, or td.
	for node in (active_range(document) or { return }).contained_nodes() {
		if node_list.len > 0 && node_list.last().is_ancestor_of(node) {
			continue
		}
		if !node.is_editable() {
			continue
		}
		// Preserve the document's body/head and the head's content. The body's
		// editable children are visited separately and can still be removed.
		if node.is_html_body_element() {
			continue
		}
		mut ancestor := ?&dom.Node(node)
		mut is_in_head := false
		for {
			current := ancestor or { break }
			if current.is_html_head_element() {
				is_in_head = true
				break
			}
			ancestor = current.parent()
		}
		if is_in_head {
			continue
		}
		if !node.is_html_table_section_element() && !node.is_html_table_row_element()
			&& !node.is_html_table_cell_element() {
			node_list << node
		}
	}

	// 25. For each node in node list:
	for node in node_list {
		// 1. Let parent be the parent of node.
		// NOTE: All nodes in node_list are descendants of common_ancestor and as such, always have a parent.
		mut parent := node.parent() or { continue }

		// 2. Remove node from parent.
		remove_node(node)

		// 3. If the block node of parent has no visible children, and parent is editable or an editing host, call
		//    createElement("br") on the context object and append the result as the last child of parent.
		if block_node_of_parent := block_node_of_node(parent) {
			if !has_visible_children(block_node_of_parent) && parent.is_editable_or_editing_host() {
				append_node(editing_create_html_element(document, 'br').as_node(), parent) or { panic(err) }
			}
		}

		// 4. If strip wrappers is true or parent is not an inclusive ancestor of start node, while parent is an
		//    editable inline node with length 0, let grandparent be the parent of parent, then remove parent from
		//    grandparent, then set parent to grandparent.
		if strip_wrappers || !parent.is_inclusive_ancestor_of(start.node) {
			for parent.is_editable() && is_inline_node(parent) && parent.length() == 0 {
				grandparent := parent.parent() or { break }
				remove_node(parent)
				parent = grandparent
			}
		}
	}

	// 26. If end node is an editable Text node, call deleteData(0, end offset) on it.
	if end.node.is_editable() && end.node.is_text() {
		delete_data(editing_character_data(end.node), 0, end.offset) or { panic(err) }
	}

	// 27. Canonicalize whitespace at the active range's start, with fix collapsed space false.
	canonicalize_whitespace((active_range(document) or { return }).start(), false)

	// 28. Canonicalize whitespace at the active range's end, with fix collapsed space false.
	canonicalize_whitespace((active_range(document) or { return }).end(), false)

	// 30. If block merging is false, or start block or end block is null, or start block is not in the same editing
	//     host as end block, or start block and end block are the same:
	start_block_node := start_block or { unsafe { &dom.Node(nil) } }
	end_block_node := end_block or { unsafe { &dom.Node(nil) } }
	if !block_merging || start_block == none || end_block == none
		|| !is_in_same_editing_host(start_block_node, end_block_node)
		|| voidptr(start_block_node) == voidptr(end_block_node) {
		// 1. If direction is "forward", call collapseToStart() on the context object's selection.
		// 2. Otherwise, call collapseToEnd() on the context object's selection.
		editing_collapse_by_direction(mut selection, direction)

		// 3. Restore states and values from overrides.
		restore_states_and_values(mut document, overrides)

		// 4. Abort these steps.
		return
	}
	mut start_block_ref := unsafe { start_block_node }
	mut end_block_ref := unsafe { end_block_node }

	// 31. If start block has one child, which is a collapsed block prop, remove its child from it.
	if start_block_ref.child_count() == 1 {
		if first_child := start_block_ref.first_child() {
			if is_collapsed_block_prop(first_child) {
				remove_node(first_child)
			}
		}
	}

	// 32. If start block is an ancestor of end block:
	mut values := []RecordedNodeValue{}
	mut recorded_white_space := []RecordedWhiteSpace{}
	if start_block_ref.is_ancestor_of(end_block_ref) {
		// 1. Let reference node be end block.
		mut reference_node := end_block_ref

		// 2. While reference node is not a child of start block, set reference node to its parent.
		for {
			parent := reference_node.parent() or { break }
			if voidptr(parent) == voidptr(start_block_ref) {
				break
			}
			reference_node = parent
		}

		// 3. Call collapse() on the context object's selection, with first argument start block and second argument the
		//    index of reference node.
		selection.collapse(start_block_ref, reference_node.index()) or { panic(err) }

		// 4. If end block has no children:
		if !end_block_ref.has_children() {
			// 1. While end block is editable and is the only child of its parent and is not a child of start block, let
			//    parent equal end block, then remove end block from parent, then set end block to parent.
			for end_block_ref.is_editable() {
				// AD-HOC: Set end_block's parent instead of end_block itself.
				//         See: https://github.com/w3c/editing/issues/473
				parent := end_block_ref.parent() or { break }
				if parent.child_count() != 1 || voidptr(parent) == voidptr(start_block_ref) {
					break
				}
				remove_node(end_block_ref)
				end_block_ref = parent
			}

			// 2. If end block is editable and is not an inline node, and its previousSibling and nextSibling are both
			//    inline nodes, call createElement("br") on the context object and insert it into end block's parent
			//    immediately after end block.
			if end_block_ref.is_editable() && !is_inline_node(end_block_ref) {
				if previous_sibling := end_block_ref.previous_sibling() {
					if next_sibling := end_block_ref.next_sibling() {
						if is_inline_node(previous_sibling) && is_inline_node(next_sibling) {
							br := editing_create_html_element(document, 'br').as_node()
							if parent := end_block_ref.parent() {
								insert_node_before(br, parent, next_sibling)
							}
						}
					}
				}
			}

			// 3. If end block is editable, remove it from its parent.
			if end_block_ref.is_editable() {
				remove_node(end_block_ref)
			}

			// 4. Restore states and values from overrides.
			restore_states_and_values(mut document, overrides)

			// 5. Abort these steps.
			return
		}

		// 5. If end block's firstChild is not an inline node, restore states and values from record, then abort these
		//    steps.
		end_first_child := end_block_ref.first_child() or { return }
		if !is_inline_node(end_first_child) {
			restore_states_and_values(mut document, overrides)
			return
		}

		mut children := isolate_first_line_of_inline_run(end_block_ref, end_first_child)
		if children.len == 0 {
			if !end_block_ref.has_children() && end_block_ref.is_editable() {
				remove_node(end_block_ref)
			}
			restore_states_and_values(mut document, overrides)
			return
		}

		// 9. Record the values of children, and let values be the result.
		recorded_white_space = record_white_space_of_nodes(mut children)
		values = record_the_values_of_nodes(children)

		// 10. While children's first member's parent is not start block, split the parent of children.
		for !editing_same_node(children[0].parent(), start_block_ref) {
			previous_parent := children[0].parent()
			split_the_parent_of_nodes(children)
			if editing_same_node(children[0].parent(), previous_parent) {
				break
			}
		}

		// 11. If children's first member's previousSibling is an editable br, remove that br from its parent.
		if previous_sibling := children[0].previous_sibling() {
			if previous_sibling.is_html_br_element() && previous_sibling.is_editable() {
				remove_node(previous_sibling)
			}
		}
	}

	// 33. Otherwise, if start block is a descendant of end block:
	else if start_block_ref.is_descendant_of(end_block_ref) {
		// 1. Call collapse() on the context object's selection, with first argument start block and second argument
		//    start block's length.
		selection.collapse(start_block_ref, start_block_ref.length()) or { panic(err) }

		// 2. Let reference node be start block.
		mut reference_node := start_block_ref

		// 3. While reference node is not a child of end block, set reference node to its parent.
		for {
			parent := reference_node.parent() or { break }
			if voidptr(parent) == voidptr(end_block_ref) {
				break
			}
			reference_node = parent
		}

		// 4. If reference node's nextSibling is an inline node and start block's lastChild is a br, remove start
		//    block's lastChild from it.
		if next_sibling := reference_node.next_sibling() {
			if is_inline_node(next_sibling) {
				if last_child := start_block_ref.last_child() {
					if last_child.is_html_br_element() {
						remove_node(last_child)
					}
				}
			}
		}

		// 5. Let nodes to move be a list of nodes, initially empty.
		mut nodes_to_move := []&dom.Node{}

		// 6. If reference node's nextSibling is neither null nor a block node, append it to nodes to move.
		if next_sibling := reference_node.next_sibling() {
			if !is_block_node(next_sibling) {
				nodes_to_move = isolate_first_line_of_inline_run(end_block_ref, next_sibling)
			}
		}

		// 8. Record the values of nodes to move, and let values be the result.
		recorded_white_space = record_white_space_of_nodes(mut nodes_to_move)
		values = record_the_values_of_nodes(nodes_to_move)

		// 9. For each node in nodes to move, append node as the last child of start block, preserving ranges.
		mut new_position := start_block_ref.length()
		for node in nodes_to_move {
			move_node_preserving_ranges(node, start_block_ref, new_position)
			new_position++
		}
	}

	// 34. Otherwise:
	else {
		// 1. Call collapse() on the context object's selection, with first argument start block and second argument
		//    start block's length.
		selection.collapse(start_block_ref, start_block_ref.length()) or { panic(err) }

		// 2. If end block's firstChild is an inline node and start block's lastChild is a br, remove start block's
		//    lastChild from it.
		if end_first_child := end_block_ref.first_child() {
			if is_inline_node(end_first_child) {
				if last_child := start_block_ref.last_child() {
					if last_child.is_html_br_element() {
						remove_node(last_child)
					}
				}
			}
		}

		mut children := end_block_ref.children_as_vector()
		if first := end_block_ref.first_child() {
			if is_inline_node(first) && resolved_white_space(start_block_ref) != resolved_white_space(end_block_ref) {
				children = isolate_first_line_of_inline_run(end_block_ref, first)
			}
		}
		recorded_white_space = record_white_space_of_nodes(mut children)
		values = record_the_values_of_nodes(children)

		// Move the isolated line, retaining any subsequent lines in end block.
		mut new_position := start_block_ref.length()
		for child in children {
			move_node_preserving_ranges(child, start_block_ref, new_position)
			new_position++
		}

		// 5. While end block has no children, let parent be the parent of end block, then remove end block from parent,
		//    then set end block to parent.
		for !end_block_ref.has_children() {
			parent := end_block_ref.parent() or { break }
			remove_node(end_block_ref)
			end_block_ref = parent
		}
	}

	// 36. Let ancestor be start block.
	mut ancestor := start_block_ref

	// 37. While ancestor has an inclusive ancestor ol in the same editing host whose nextSibling is also an ol in the
	//     same editing host, or an inclusive ancestor ul in the same editing host whose nextSibling is also a ul in the
	//     same editing host:
	for editing_has_mergeable_list_ancestor(ancestor) {
		// 1. While ancestor and its nextSibling are not both ols in the same editing host, and are also not both uls in
		//    the same editing host, set ancestor to its parent.
		for {
			if next_sibling := ancestor.next_sibling() {
				if is_in_same_editing_host(ancestor, next_sibling)
					&& ((ancestor.is_html_olist_element() && next_sibling.is_html_olist_element())
					|| (ancestor.is_html_ulist_element() && next_sibling.is_html_ulist_element())) {
					break
				}
			}
			ancestor = ancestor.parent() or { break }
		}

		// 2. While ancestor's nextSibling has children, append ancestor's nextSibling's firstChild as the last child of
		//    ancestor, preserving ranges.
		next_list := ancestor.next_sibling() or { break }
		mut new_position := ancestor.length()
		for {
			child := next_list.first_child() or { break }
			move_node_preserving_ranges(child, ancestor, new_position)
			new_position++
		}

		// 3. Remove ancestor's nextSibling from its parent.
		remove_node(next_list)
	}

	// 38. Restore the values from values.
	restore_the_values_of_nodes(values)
	restore_white_space_of_nodes(recorded_white_space)

	// 39. If start block has no children, call createElement("br") on the context object and append the result as the
	//     last child of start block.
	if !start_block_ref.has_children() {
		append_node(editing_create_html_element(document, 'br').as_node(), start_block_ref) or { panic(err) }
	}

	// 40. Remove extraneous line breaks at the end of start block.
	remove_extraneous_line_breaks_at_the_end_of_node(start_block_ref)

	// 41. Restore states and values from overrides.
	restore_states_and_values(mut document, overrides)
}

fn editing_has_mergeable_list_ancestor(ancestor &dom.Node) bool {
	mut inclusive_ancestor := ?&dom.Node(ancestor)
	for {
		current := inclusive_ancestor or { break }
		if next_sibling := current.next_sibling() {
			if is_in_same_editing_host(ancestor, current) && is_in_same_editing_host(current, next_sibling)
				&& ((current.is_html_olist_element() && next_sibling.is_html_olist_element())
				|| (current.is_html_ulist_element() && next_sibling.is_html_ulist_element())) {
				return true
			}
		}
		inclusive_ancestor = current.parent()
	}
	return false
}
