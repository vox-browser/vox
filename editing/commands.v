// Copyright (c) 2024-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Editing/Commands.{h,cpp}: the command definitions of the execCommand specification, operating on
// the live DOM.
module editing

import color
import dom
import infra

pub type CommandActionCallback = fn (mut document dom.Document, value string) bool

pub type CommandBooleanCallback = fn (document &dom.Document) bool

pub type CommandValueCallback = fn (document &dom.Document) string

pub struct CommandDefinition {
pub:
	command                 string
	action                  CommandActionCallback  = unsafe { nil }
	indeterminate           CommandBooleanCallback = unsafe { nil }
	state                   CommandBooleanCallback = unsafe { nil }
	value                   CommandValueCallback   = unsafe { nil }
	relevant_css_property   ?string
	inline_activated_values []string
	preserves_overrides     bool
	mapped_value            ?string
}

fn editing_selection(document &dom.Document) &dom.Selection {
	selection := document.get_selection() or { panic('editing commands require a selection') }
	return unsafe { &dom.Selection(selection) }
}

fn editing_active_range(document &dom.Document) &dom.Range {
	return active_range(document) or { panic('editing commands require an active range') }
}

fn editing_valid_command_color(value string) ?string {
	// 1. If value is not a valid CSS color, prepend "#" to it.
	if color.from_string(value) != none {
		return value
	}
	prefixed := '#${value}'

	// 2. If value is still not a valid CSS color, or if it is currentColor, return false.
	// AD-HOC: No browser does this. They always return true.
	if color.from_string(prefixed) == none {
		// FIXME: Also return true in case of currentColor.
		return none
	}
	return prefixed
}

// https://w3c.github.io/editing/docs/execCommand/#the-backcolor-command
pub fn command_back_color_action(mut document dom.Document, value string) bool {
	// 1. If value is not a valid CSS color, prepend "#" to it.
	// 2. If value is still not a valid CSS color, or if it is currentColor, return false.
	resulting_value := editing_valid_command_color(value) or { return true }

	// 3. Set the selection's value to value.
	set_the_selections_value(mut document, command_back_color, resulting_value)

	// 4. Return true.
	return true
}

// https://w3c.github.io/editing/docs/execCommand/#the-backcolor-command
fn command_back_color_indeterminate(document &dom.Document) bool {
	return standard_inline_indeterminate(document, command_back_color)
}

// https://w3c.github.io/editing/docs/execCommand/#the-backcolor-command
fn command_back_color_value(document &dom.Document) string {
	return standard_inline_value(document, command_back_color)
}

// https://w3c.github.io/editing/docs/execCommand/#the-bold-command
pub fn command_bold_action(mut document dom.Document, _ string) bool {
	// If queryCommandState("bold") returns true, set the selection's value to "normal".
	if query_command_state(document, command_bold) or { false } {
		set_the_selections_value(mut document, command_bold, 'normal')
	}

	// Otherwise set the selection's value to "bold".
	else {
		set_the_selections_value(mut document, command_bold, 'bold')
	}

	// Either way, return true.
	return true
}

// https://w3c.github.io/editing/docs/execCommand/#the-createlink-command
pub fn command_create_link_action(mut document dom.Document, value string) bool {
	// 1. If value is the empty string, return false.
	if value == '' {
		return false
	}

	// 2. For each editable a element that has an href attribute and is an ancestor of some node effectively contained
	//    in the active range, set that a element's href attribute to value.
	mut visited_ancestors := map[voidptr]bool{}
	for descendant in nodes_effectively_contained_in_range(active_range(document)) {
		mut ancestor := descendant.parent()
		for {
			current := ancestor or { break }
			if voidptr(current) in visited_ancestors {
				break
			}
			if current.is_html_anchor_element() && current.is_editable() {
				if anchor := current.as_element() {
					if anchor.has_attribute('href') {
						set_attribute_value(anchor, 'href', value)
					}
				}
			}
			visited_ancestors[voidptr(current)] = true
			ancestor = current.parent()
		}
	}

	// 3. Set the selection's value to value.
	set_the_selections_value(mut document, command_create_link, value)

	// 4. Return true.
	return true
}

// https://w3c.github.io/editing/docs/execCommand/#the-defaultparagraphseparator-command
pub fn command_default_paragraph_separator_action(mut document dom.Document, input_value string) bool {
	// Let value be converted to ASCII lowercase.
	value := command_ascii_lowercase(input_value)

	// If value is then equal to "p" or "div", set the context object's default single-line
	// container name to value, then return true.
	if value in ['p', 'div'] {
		document.set_default_single_line_container_name(value)
		return true
	}

	// Otherwise, return false.
	return false
}

// https://w3c.github.io/editing/docs/execCommand/#the-defaultparagraphseparator-command
pub fn command_default_paragraph_separator_value(document &dom.Document) string {
	// Return the context object's default single-line container name.
	return document.get_default_single_line_container_name()
}

fn editing_is_li_dt_or_dd(node &dom.Node) bool {
	element := node.as_element() or { return false }
	return element.local_name() in ['li', 'dt', 'dd']
}

// https://w3c.github.io/editing/docs/execCommand/#the-delete-command
pub fn command_delete_action(mut document dom.Document, _ string) bool {
	// 1. If the active range is not collapsed, delete the selection and return true.
	mut selection := editing_selection(document)
	range_ := editing_active_range(document)
	if !range_.collapsed() {
		delete_the_selection(mut selection, true, true, .forwards)
		return true
	}

	// 2. Canonicalize whitespace at the active range's start.
	canonicalize_whitespace(range_.start(), true)

	// 3. Let node and offset be the active range's start node and offset.
	mut node := editing_active_range(document).start_container()
	mut offset := editing_active_range(document).start_offset()

	// 4. Repeat the following steps:
	for {
		offset_minus_one_child := node.child_at_index(offset - 1)

		// 1. If offset is zero and node's previousSibling is an editable invisible node, remove
		//    node's previousSibling from its parent.
		if previous_sibling := node.previous_sibling() {
			if offset == 0 && previous_sibling.is_editable() && is_invisible_node(previous_sibling) {
				remove_node(previous_sibling)
				continue
			}
		}

		// 2. Otherwise, if node has a child with index offset − 1 and that child is an editable
		//    invisible node, remove that child from node, then subtract one from offset.
		if child := offset_minus_one_child {
			if child.is_editable() && is_invisible_node(child) {
				remove_node(child)
				offset--
				continue
			}
		}

		// 3. Otherwise, if offset is zero and node is an inline node, or if node is an invisible
		//    node, set offset to the index of node, then set node to its parent.
		if (offset == 0 && is_inline_node(node)) || is_invisible_node(node) {
			parent := node.parent() or { break }
			offset = node.index()
			node = parent
			continue
		}

		// 4. Otherwise, if node has a child with index offset − 1 and that child is an editable a,
		//    remove that child from node, preserving its descendants. Then return true.
		if child := offset_minus_one_child {
			if child.is_html_anchor_element() && child.is_editable() {
				remove_node_preserving_its_descendants(child)
				return true
			}

			// 5. Otherwise, if node has a child with index offset − 1 and that child is not a block
			//    node or a br or an img, set node to that child, then set offset to the length of node.
			if !is_block_node(child) && !child.is_html_br_element() && !child.is_html_image_element() {
				node = child
				offset = node.length()
				continue
			}
		}

		// 6. Otherwise, break from this loop.
		break
	}

	// 5. If node is a Text node and offset is not zero, or if node is a block node that has a child
	//    with index offset − 1 and that child is a br or hr or img:
	mut block_node_child_is_relevant_type := false
	if is_block_node(node) {
		if child_node := node.child_at_index(offset - 1) {
			block_node_child_is_relevant_type = is_html_element_named(child_node, ['br', 'hr', 'img'])
		}
	}
	if (node.is_text() && offset != 0) || block_node_child_is_relevant_type {
		start_offset := if node.is_text() {
			character_data := editing_character_data(node)
			character_data.grapheme_segmenter().previous_boundary(offset) or { offset - 1 }
		} else {
			offset - 1
		}

		// 1. Call collapse(node, offset) on the context object's selection.
		selection.collapse(node, offset) or { panic(err) }

		// 2. Call extend(node, offset − 1) on the context object's selection.
		selection.extend(node, start_offset) or { panic(err) }

		// 3. Delete the selection.
		delete_the_selection(mut selection, true, true, .forwards)

		// 4. Return true.
		return true
	}

	// 6. If node is an inline node, return true.
	if is_inline_node(node) {
		return true
	}

	// 7. If node is an li or dt or dd and is the first child of its parent, and offset is zero:
	if offset == 0 && node.index() == 0 && editing_is_li_dt_or_dd(node) {
		// 1. Let items be a list of all lis that are ancestors of node.
		mut items := []&dom.Node{}
		mut ancestor := node.parent()
		for {
			current := ancestor or { break }
			if current.is_html_li_element() {
				items << current
			}
			ancestor = current.parent()
		}

		// 2. Normalize sublists of each item in items.
		for item in items {
			normalize_sublists_in_node(item)
		}

		// 3. Record the values of the one-node list consisting of node, and let values be the
		//    result.
		values := record_the_values_of_nodes([node])

		// 4. Split the parent of the one-node list consisting of node.
		split_the_parent_of_nodes([node])

		// 5. Restore the values from values.
		restore_the_values_of_nodes(values)

		// 6. If node is a dd or dt, and it is not an allowed child of any of its ancestors in the
		//    same editing host, set the tag name of node to the default single-line container name
		//    and let node be the result.
		if is_html_element_named(node, ['dd', 'dt'])
			&& !editing_is_allowed_child_of_some_ancestor_in_same_editing_host(node) {
			if element := node.as_element() {
				node = set_the_tag_name(element, document.get_default_single_line_container_name()).as_node()
			}
		}

		// 7. Fix disallowed ancestors of node.
		fix_disallowed_ancestors_of_node(node)

		// 8. Return true.
		return true
	}

	// 8. Let start node equal node and let start offset equal offset.
	mut start_node := node
	mut start_offset := offset

	// 9. Repeat the following steps:
	for {
		// Do not climb into the Document and later collapse the selection into a doctype.
		if start_node.is_document() {
			return false
		}

		// 1. If start offset is zero, set start offset to the index of start node and then set
		//    start node to its parent.
		if start_offset == 0 {
			parent := start_node.parent() or { return false }
			start_offset = start_node.index()
			start_node = parent
			continue
		}

		// 2. Otherwise, if start node has an editable invisible child with index start offset minus
		//    one, remove it from start node and subtract one from start offset.
		if child := start_node.child_at_index(start_offset - 1) {
			if child.is_editable() && is_invisible_node(child) {
				remove_node(child)
				start_offset--
				continue
			}
		}

		// 3. Otherwise, break from this loop.
		break
	}

	// 10. If offset is zero, and node has an editable inclusive ancestor in the same editing host
	//     that's an indentation element:
	if offset == 0 {
		mut has_matching_inclusive_ancestor := false
		mut ancestor := ?&dom.Node(node)
		for {
			current := ancestor or { break }
			if current.is_editable() && is_in_same_editing_host(current, node) && is_indentation_element(current) {
				has_matching_inclusive_ancestor = true
				break
			}
			ancestor = current.parent()
		}
		if has_matching_inclusive_ancestor {
			// 1. Block-extend the range whose start and end are both (node, 0), and let new range be
			//    the result.
			new_range := block_extend_a_range(dom.Range.create_from_boundary_points(node, 0, node, 0))

			// 2. Let node list be a list of nodes, initially empty.
			mut node_list := []&dom.Node{}

			// 3. For each node current node contained in new range, append current node to node list if
			//    the last member of node list (if any) is not an ancestor of current node, and current
			//    node is editable but has no editable descendants.
			for current_node in new_range.contained_nodes() {
				if node_list.len > 0 && node_list.last().is_ancestor_of(current_node) {
					continue
				}
				if !current_node.is_editable() {
					continue
				}
				if !editing_has_editable_descendant(current_node) {
					node_list << current_node
				}
			}

			// 4. Outdent each node in node list.
			for current_node in node_list {
				outdent(current_node)
			}

			// 5. Return true.
			return true
		}
	}

	// 11. If the child of start node with index start offset is a table, return true.
	if child := start_node.child_at_index(start_offset) {
		if child.is_html_table_element() {
			return true
		}
	}

	// 12. If start node has a child with index start offset − 1, and that child is a table:
	offset_minus_one_child := start_node.child_at_index(start_offset - 1)
	if child := offset_minus_one_child {
		if child.is_html_table_element() {
			// 1. Call collapse(start node, start offset − 1) on the context object's selection.
			selection.collapse(start_node, start_offset - 1) or { panic(err) }

			// 2. Call extend(start node, start offset) on the context object's selection.
			selection.extend(start_node, start_offset) or { panic(err) }

			// 3. Return true.
			return true
		}
	}

	// 13. If offset is zero; and either the child of start node with index start offset minus one
	//     is an hr, or the child is a br whose previousSibling is either a br or not an inline
	//     node:
	if offset == 0 {
		if child := offset_minus_one_child {
			if child.is_element() {
				previous_is_br_or_block := if previous_sibling := child.previous_sibling() {
					previous_sibling.is_html_br_element() || !is_inline_node(previous_sibling)
				} else {
					false
				}
				if is_html_element_named(child, ['hr']) || (child.is_html_br_element() && previous_is_br_or_block) {
					// 1. Call collapse(start node, start offset − 1) on the context object's selection.
					selection.collapse(start_node, start_offset - 1) or { panic(err) }

					// 2. Call extend(start node, start offset) on the context object's selection.
					selection.extend(start_node, start_offset) or { panic(err) }

					// 3. Delete the selection.
					delete_the_selection(mut selection, true, true, .forwards)

					// 4. Call collapse(node, offset) on the selection.
					selection.collapse(node, offset) or { panic(err) }

					// 5. Return true.
					return true
				}
			}
		}
	}

	// 14. If the child of start node with index start offset is an li or dt or dd, and that child's
	//     firstChild is an inline node, and start offset is not zero:
	// NOTE: step 9 above guarantees start_offset cannot be 0 here.
	start_offset_child := start_node.child_at_index(start_offset)
	if child := start_offset_child {
		if editing_is_li_dt_or_dd(child) {
			if first_child := child.first_child() {
				if is_inline_node(first_child) {
					// 1. Let previous item be the child of start node with index start offset minus one.
					if previous_item := start_node.child_at_index(start_offset - 1) {
						// 2. If previous item's lastChild is an inline node other than a br, call
						//    createElement("br") on the context object and append the result as the last child of
						//    previous item.
						previous_item_last_child := previous_item.last_child()
						if last_child := previous_item_last_child {
							if is_inline_node(last_child) && !last_child.is_html_br_element() {
								append_node(editing_create_html_element(document, 'br').as_node(), previous_item) or {
									panic(err)
								}
							}

							// 3. If previous item's lastChild is an inline node, call createElement("br") on the
							//    context object and append the result as the last child of previous item.
							if is_inline_node(last_child) {
								append_node(editing_create_html_element(document, 'br').as_node(), previous_item) or {
									panic(err)
								}
							}
						}
					}
				}
			}
		}
	}

	// 15. If start node's child with index start offset is an li or dt or dd, and that child's
	//     previousSibling is also an li or dt or dd:
	if child := start_offset_child {
		if editing_is_li_dt_or_dd(child) {
			if previous_sibling := child.previous_sibling() {
				if editing_is_li_dt_or_dd(previous_sibling) {
					// 1. Call cloneRange() on the active range, and let original range be the result.
					original_range := editing_active_range(document).clone_range()

					// 2. Set start node to its child with index start offset − 1.
					start_node = start_node.child_at_index(start_offset - 1) or { return true }

					// 3. Set start offset to start node's length.
					start_offset = start_node.length()

					// 4. Set node to start node's nextSibling.
					node = start_node.next_sibling() or { return true }

					// 5. Call collapse(start node, start offset) on the context object's selection.
					selection.collapse(start_node, start_offset) or { panic(err) }

					// 6. Call extend(node, 0) on the context object's selection.
					selection.extend(node, 0) or { panic(err) }

					// 7. Delete the selection.
					delete_the_selection(mut selection, true, true, .forwards)

					// 8. Call removeAllRanges() on the context object's selection.
					selection.remove_all_ranges()

					// 9. Call addRange(original range) on the context object's selection.
					selection.add_range(original_range)

					// 10. Return true.
					return true
				}
			}
		}
	}

	// 16. While start node has a child with index start offset minus one:
	for {
		child := start_node.child_at_index(start_offset - 1) or { break }

		// 1. If start node's child with index start offset minus one is editable and invisible,
		//    remove it from start node, then subtract one from start offset.
		if child.is_editable() && is_invisible_node(child) {
			remove_node(child)
			start_offset--
		}

		// 2. Otherwise, set start node to its child with index start offset minus one, then set
		//    start offset to the length of start node.
		else {
			start_node = child
			start_offset = start_node.length()
		}
	}

	// 17. Call collapse(start node, start offset) on the context object's selection.
	selection.collapse(start_node, start_offset) or { panic(err) }

	// 18. Call extend(node, offset) on the context object's selection.
	selection.extend(node, offset) or { panic(err) }

	// 19. Delete the selection, with direction "backward".
	delete_the_selection(mut selection, true, true, .backwards)

	// 20. Return true.
	return true
}

fn editing_has_editable_descendant(node &dom.Node) bool {
	mut current := node.next_in_pre_order(node)
	for {
		descendant := current or { break }
		if descendant.is_editable() {
			return true
		}
		current = descendant.next_in_pre_order(node)
	}
	return false
}

// https://w3c.github.io/editing/docs/execCommand/#the-fontname-command
pub fn command_font_name_action(mut document dom.Document, value string) bool {
	// Set the selection's value to value, then return true.
	set_the_selections_value(mut document, command_font_name, value)
	return true
}

// https://w3c.github.io/editing/docs/execCommand/#the-fontname-command
fn command_font_name_indeterminate(document &dom.Document) bool {
	return standard_inline_indeterminate(document, command_font_name)
}

// https://w3c.github.io/editing/docs/execCommand/#the-fontname-command
fn command_font_name_value(document &dom.Document) string {
	return standard_inline_value(document, command_font_name)
}

// https://w3c.github.io/editing/docs/execCommand/#the-fontsize-command
pub fn command_font_size_action(mut document dom.Document, value string) bool {
	// 1. Strip leading and trailing whitespace from value.
	mut resulting_value := value.trim(' \t\n\f\r')

	// 2. If value is not a valid floating point number, and would not be a valid floating point number if a single
	//    leading "+" character were stripped, return false.
	if !infra.is_valid_floating_point_number(resulting_value) {
		if !resulting_value.starts_with('+') || !infra.is_valid_floating_point_number(resulting_value[1..]) {
			return false
		}
	}

	// 3. If the first character of value is "+", delete the character and let mode be "relative-plus".
	// 4. Otherwise, if the first character of value is "-", delete the character and let mode be "relative-minus".
	// 5. Otherwise, let mode be "absolute".
	mut mode := 0
	if resulting_value.starts_with('+') {
		resulting_value = resulting_value[1..]
		mode = 1
	} else if resulting_value.starts_with('-') {
		resulting_value = resulting_value[1..]
		mode = -1
	}

	// 6. Apply the rules for parsing non-negative integers to value, and let number be the result.
	mut number := i64(infra.parse_non_negative_integer(resulting_value) or { return false })

	// 7. If mode is "relative-plus", add three to number.
	if mode == 1 {
		number += 3
	}

	// 8. If mode is "relative-minus", negate number, then add three to it.
	if mode == -1 {
		number = -number + 3
	}

	// 9. If number is less than one, let number equal 1.
	if number < 1 {
		number = 1
	}

	// 10. If number is greater than seven, let number equal 7.
	if number > 7 {
		number = 7
	}

	// 11. Set value to the string here corresponding to number:
	// 1: x-small
	// 2: small
	// 3: medium
	// 4: large
	// 5: x-large
	// 6: xx-large
	// 7: xxx-large
	resulting_value = named_font_sizes()[int(number) - 1]

	// 12. Set the selection's value to value.
	set_the_selections_value(mut document, command_font_size, resulting_value)

	// 13. Return true.
	return true
}

// https://w3c.github.io/editing/docs/execCommand/#the-fontsize-command
pub fn command_font_size_value(document &dom.Document) string {
	// 1. If the active range is null, return the empty string.
	range_ := active_range(document) or { return '' }

	// 2. Let pixel size be the effective command value of the first formattable node that is effectively contained in
	//    the active range, or if there is no such node, the effective command value of the active range's start node,
	//    in either case interpreted as a number of pixels.
	node := first_formattable_node_effectively_contained(range_) or { range_.start_container() }
	value := effective_command_value(node, command_font_size)
	pixel_size := font_size_to_pixel_size(value or { '' })

	// 3. Return the legacy font size for pixel size.
	return legacy_font_size(pixel_size.to_int())
}

// https://w3c.github.io/editing/docs/execCommand/#the-forecolor-command
pub fn command_fore_color_action(mut document dom.Document, value string) bool {
	// 1. If value is not a valid CSS color, prepend "#" to it.
	// 2. If value is still not a valid CSS color, or if it is currentColor, return false.
	resulting_value := editing_valid_command_color(value) or { return true }

	// 3. Set the selection's value to value.
	set_the_selections_value(mut document, command_fore_color, resulting_value)

	// 4. Return true.
	return true
}

// https://w3c.github.io/editing/docs/execCommand/#the-forecolor-command
fn command_fore_color_indeterminate(document &dom.Document) bool {
	return standard_inline_indeterminate(document, command_fore_color)
}

// https://w3c.github.io/editing/docs/execCommand/#the-forecolor-command
fn command_fore_color_value(document &dom.Document) string {
	return standard_inline_value(document, command_fore_color)
}

fn editing_is_ancestor_of_prohibited_paragraph_child(node &dom.Node) bool {
	mut current := node.next_in_pre_order(node)
	for {
		descendant := current or { break }
		if is_prohibited_paragraph_child(descendant) {
			return true
		}
		current = descendant.next_in_pre_order(node)
	}
	return false
}

// https://w3c.github.io/editing/docs/execCommand/#the-formatblock-command
pub fn command_format_block_action(mut document dom.Document, value string) bool {
	// 1. If value begins with a "<" character and ends with a ">" character, remove the first and last characters from
	//    it.
	mut resulting_value := value
	if value.starts_with('<') && value.ends_with('>') && value.len >= 2 {
		resulting_value = value[1..value.len - 1]
	}

	// 2. Let value be converted to ASCII lowercase.
	resulting_value = command_ascii_lowercase(resulting_value)

	// 3. If value is not a formattable block name, return false.
	local_name := formattable_block_name_from_utf16(resulting_value) or { return false }

	// 4. Block-extend the active range, and let new range be the result.
	new_range := block_extend_a_range(editing_active_range(document))

	// 5. Let node list be an empty list of nodes.
	mut node_list := []&dom.Node{}

	// 6. For each node node contained in new range, append node to node list if it is editable, the last member of
	//    original node list (if any) is not an ancestor of node, node is either a non-list single-line container or an
	//    allowed child of "p" or a dd or dt, and node is not the ancestor of a prohibited paragraph child.
	for node in new_range.contained_nodes() {
		is_dd_or_dt := if element := node.as_element() {
			element.local_name() in ['dd', 'dt']
		} else {
			false
		}
		if node.is_editable() && (node_list.len == 0 || !node_list.last().is_ancestor_of(node))
			&& (is_non_list_single_line_container(node)
			|| is_allowed_child_of_node(allowed_child_node(node), allowed_child_name('p')) || is_dd_or_dt)
			&& !editing_is_ancestor_of_prohibited_paragraph_child(node) {
			node_list << node
		}
	}

	// 7. Record the values of node list, and let values be the result.
	values := record_the_values_of_nodes(node_list)

	// 8. For each node in node list, while node is the descendant of an editable HTML element in the same editing host,
	//    whose local name is a formattable block name, and which is not the ancestor of a prohibited paragraph child,
	//    split the parent of the one-node list consisting of node.
	for node in node_list {
		for {
			mut is_matching_descendant := false
			mut ancestor := node.parent()
			for {
				current := ancestor or { break }
				if current.is_editable() && is_in_same_editing_host(node, current) {
					if name := editing_html_local_name(current) {
						if is_formattable_block_name(name) && !editing_is_ancestor_of_prohibited_paragraph_child(current) {
							is_matching_descendant = true
							break
						}
					}
				}
				ancestor = current.parent()
			}
			if !is_matching_descendant {
				break
			}
			previous_parent := node.parent()
			split_the_parent_of_nodes([node])
			if editing_same_node(node.parent(), previous_parent) {
				break
			}
		}
	}

	// 9. Restore the values from values.
	restore_the_values_of_nodes(values)

	// 10. While node list is not empty:
	for node_list.len > 0 {
		mut sublist := []&dom.Node{}

		// 1. If the first member of node list is a single-line container:
		if is_single_line_container(node_list[0]) {
			// AD-HOC: The spec makes note of single-line containers without children, and how they should probably
			//         disappear given that Firefox and Opera did this at the time. We're going to follow their lead and
			//         remove the node if it has no children.
			if !node_list[0].has_children() {
				remove_node(node_list[0])
				node_list.delete(0)
				continue
			}

			// 1. Let sublist be the children of the first member of node list.
			sublist = node_list[0].children_as_vector()

			// 2. Record the values of sublist, and let values be the result.
			sublist_values := record_the_values_of_nodes(sublist)

			// 3. Remove the first member of node list from its parent, preserving its descendants.
			remove_node_preserving_its_descendants(node_list[0])

			// 4. Restore the values from values.
			restore_the_values_of_nodes(sublist_values)

			// 5. Remove the first member from node list.
			node_list.delete(0)
		}

		// 2. Otherwise:
		else {
			// 1. Let sublist be an empty list of nodes.
			// 2. Remove the first member of node list and append it to sublist.
			sublist << node_list[0]
			node_list.delete(0)

			// 3. While node list is not empty, and the first member of node list is the nextSibling of the last member
			//    of sublist, and the first member of node list is not a single-line container, and the last member of
			//    sublist is not a br, remove the first member of node list and append it to sublist.
			for node_list.len > 0 && editing_same_node(node_list[0], sublist.last().next_sibling())
				&& !is_single_line_container(node_list[0]) && !sublist.last().is_html_br_element() {
				sublist << node_list[0]
				node_list.delete(0)
			}
		}

		// 3. Wrap sublist. If value is "div" or "p", sibling criteria returns false; otherwise it returns true for an
		//    HTML element with local name value and no attributes, and false otherwise. New parent instructions return
		//    the result of running createElement(value) on the context object. Then fix disallowed ancestors of the
		//    result.
		if sublist.len == 0 {
			continue
		}
		result := wrap(sublist, fn [resulting_value] (sibling &dom.Node) bool {
			if resulting_value in ['div', 'p'] {
				return false
			}
			name := editing_html_local_name(sibling) or { return false }
			element := sibling.as_element() or { return false }
			return name == resulting_value && !element.has_attributes()
		}, fn [document, local_name] () ?&dom.Node {
			return editing_create_html_element(document, local_name).as_node()
		})
		if wrapped := result {
			fix_disallowed_ancestors_of_node(wrapped)
		}
	}

	// 11. Return true.
	return true
}

fn editing_lift_to_formattable_block(input_node &dom.Node) &dom.Node {
	mut node := unsafe { input_node }
	for {
		parent := node.parent() or { break }
		if !parent.is_editable() || !is_in_same_editing_host(node, parent) {
			break
		}
		if name := editing_html_local_name(node) {
			if is_formattable_block_name(name) {
				break
			}
		}
		node = parent
	}
	return node
}

// https://w3c.github.io/editing/docs/execCommand/#the-formatblock-command
pub fn command_format_block_indeterminate(document &dom.Document) bool {
	// 1. If the active range is null, return the empty string.
	// AD-HOC: We're returning false instead. See https://github.com/w3c/editing/issues/474
	range_ := active_range(document) or { return false }

	// 2. Block-extend the active range, and let new range be the result.
	new_range := block_extend_a_range(range_)

	// 3. Let node list be all visible editable nodes that are contained in new range and have no children.
	node_list := new_range.contained_nodes().filter(is_visible_node(it) && it.is_editable() && !it.has_children())

	// 4. If node list is empty, return false.
	if node_list.len == 0 {
		return false
	}

	// 5. Let type be null.
	mut type_ := ?string(none)

	// 6. For each node in node list:
	for input_node in node_list {
		// 1. While node's parent is editable and in the same editing host as node, and node is not an HTML element
		//    whose local name is a formattable block name, set node to its parent.
		node := editing_lift_to_formattable_block(input_node)

		// 2. Let current type be the empty string.
		mut current_type := ''

		// 3. If node is an editable HTML element whose local name is a formattable block name, and node is not the
		//    ancestor of a prohibited paragraph child, set current type to node's local name.
		if node.is_editable() {
			if name := editing_html_local_name(node) {
				if is_formattable_block_name(name) {
					current_type = name
				}
			}
		}

		// 4. If type is null, set type to current type.
		if existing := type_ {
			// 5. Otherwise, if type does not equal current type, return true.
			if existing != current_type {
				return true
			}
		} else {
			type_ = current_type
		}
	}

	// 7. Return false.
	return false
}

// https://w3c.github.io/editing/docs/execCommand/#the-formatblock-command
pub fn command_format_block_value(document &dom.Document) string {
	// 1. If the active range is null, return the empty string.
	range_ := active_range(document) or { return '' }

	// 2. Block-extend the active range, and let new range be the result.
	new_range := block_extend_a_range(range_)

	// 3. Let node be the first visible editable node that is contained in new range and has no children. If there is no
	//    such node, return the empty string.
	mut first_node := ?&dom.Node(none)
	for contained_node in new_range.contained_nodes() {
		if is_visible_node(contained_node) && contained_node.is_editable() && !contained_node.has_children() {
			first_node = contained_node
			break
		}
	}
	input_node := first_node or { return '' }

	// 4. While node's parent is editable and in the same editing host as node, and node is not an HTML element whose
	//    local name is a formattable block name, set node to its parent.
	node := editing_lift_to_formattable_block(input_node)

	// 5. If node is an editable HTML element whose local name is a formattable block name, and node is not the ancestor
	//    of a prohibited paragraph child, return node's local name, converted to ASCII lowercase.
	if node.is_editable() {
		if name := editing_html_local_name(node) {
			if is_formattable_block_name(name) && !editing_is_ancestor_of_prohibited_paragraph_child(node) {
				return command_ascii_lowercase(name)
			}
		}
	}

	// 6. Return the empty string.
	return ''
}

fn editing_code_point_at(data string, index int) u32 {
	unit := editing_code_unit_at(data, index) or { return 0 }
	if unit >= 0xd800 && unit <= 0xdbff {
		if low := editing_code_unit_at(data, index + 1) {
			if low >= 0xdc00 && low <= 0xdfff {
				return 0x10000 + ((u32(unit) - 0xd800) << 10) + (u32(low) - 0xdc00)
			}
		}
	}
	return u32(unit)
}

// https://w3c.github.io/editing/docs/execCommand/#the-forwarddelete-command
pub fn command_forward_delete_action(mut document dom.Document, _ string) bool {
	// 1. If the active range is not collapsed, delete the selection and return true.
	mut selection := editing_selection(document)
	range_ := editing_active_range(document)
	if !range_.collapsed() {
		delete_the_selection(mut selection, true, true, .forwards)
		return true
	}

	// 2. Canonicalize whitespace at the active range's start.
	canonicalize_whitespace(range_.start(), true)

	// 3. Let node and offset be the active range's start node and offset.
	mut node := editing_active_range(document).start().node
	mut offset := editing_active_range(document).start().offset

	// 4. Repeat the following steps:
	for {
		// 1. If offset is the length of node and node's nextSibling is an editable invisible node, remove node's
		//    nextSibling from its parent.
		if offset == node.length() {
			if next_sibling := node.next_sibling() {
				if next_sibling.is_editable() && is_invisible_node(next_sibling) {
					remove_node(next_sibling)
					continue
				}
			}
		}

		// 2. Otherwise, if node has a child with index offset and that child is an editable invisible node, remove that
		//    child from node.
		child_at_offset := node.child_at_index(offset)
		if child := child_at_offset {
			if child.is_editable() && is_invisible_node(child) {
				remove_node(child)
				continue
			}
		}

		// 3. Otherwise, if offset is the length of node and node is an inline node, or if node is invisible, set offset
		//    to one plus the index of node, then set node to its parent.
		if parent := node.parent() {
			if (offset == node.length() && is_inline_node(node)) || is_invisible_node(node) {
				offset = node.index() + 1
				node = parent
				continue
			}
		}

		// 4. Otherwise, if node has a child with index offset and that child is neither a block node nor a br nor an
		//    img nor a collapsed block prop, set node to that child, then set offset to zero.
		if child := child_at_offset {
			if !is_block_node(child) && !child.is_html_br_element() && !child.is_html_image_element()
				&& !is_collapsed_block_prop(child) {
				node = child
				offset = 0
				continue
			}
		}

		// 5. Otherwise, break from this loop.
		break
	}

	// 5. If node is a Text node and offset is not node's length:
	if node.is_text() && offset != node.length() {
		// 1. Let end offset be offset plus one.
		character_data := editing_character_data(node)
		grapheme_segmenter := character_data.grapheme_segmenter()
		mut end_offset := grapheme_segmenter.next_boundary(offset) or { offset + 1 }

		// 2. While end offset is not node's length and the end offsetth code unit of node's data has general category M
		//    when interpreted as a Unicode code point, add one to end offset.
		for end_offset != node.length()
			&& infra.code_point_has_mark_general_category(editing_code_point_at(character_data.data(), end_offset)) {
			end_offset = grapheme_segmenter.next_boundary(end_offset) or { end_offset + 1 }
		}

		// 3. Call collapse(node, offset) on the context object's selection.
		selection.collapse(node, offset) or { panic(err) }

		// 4. Call extend(node, end offset) on the context object's selection.
		selection.extend(node, end_offset) or { panic(err) }

		// 5. Delete the selection.
		delete_the_selection(mut selection, true, true, .forwards)

		// 6. Return true.
		return true
	}

	// 6. If node is an inline node, return true.
	if is_inline_node(node) {
		return true
	}

	// 7. If node has a child with index offset and that child is a br or hr or img, but is not a collapsed block prop:
	if child := node.child_at_index(offset) {
		if is_html_element_named(child, ['br', 'hr', 'img']) && !is_collapsed_block_prop(child) {
			// 1. Call collapse(node, offset) on the context object's selection.
			selection.collapse(node, offset) or { panic(err) }

			// 2. Call extend(node, offset + 1) on the context object's selection.
			selection.extend(node, offset + 1) or { panic(err) }

			// 3. Delete the selection.
			delete_the_selection(mut selection, true, true, .forwards)

			// 4. Return true.
			return true
		}
	}

	// 8. Let end node equal node and let end offset equal offset.
	mut end_node := node
	mut end_offset := offset

	// 9. If end node has a child with index end offset, and that child is a collapsed block prop, add one to end
	//    offset.
	if child := end_node.child_at_index(end_offset) {
		if is_collapsed_block_prop(child) {
			end_offset++
		}
	}

	// 10. Repeat the following steps:
	for {
		// 1. If end offset is the length of end node, set end offset to one plus the index of end node and then set end
		//    node to its parent.
		if end_offset == end_node.length() {
			if parent := end_node.parent() {
				end_offset = end_node.index() + 1
				end_node = parent
				continue
			}
		}

		// 2. Otherwise, if end node has an editable invisible child with index end offset, remove it from end node.
		if child := end_node.child_at_index(end_offset) {
			if child.is_editable() && is_invisible_node(child) {
				remove_node(child)
				continue
			}
		}

		// 3. Otherwise, break from this loop.
		break
	}

	// 11. If the child of end node with index end offset minus one is a table, return true.
	if child := end_node.child_at_index(end_offset - 1) {
		if child.is_html_table_element() {
			return true
		}
	}

	// 12. If the child of end node with index end offset is a table:
	if child := end_node.child_at_index(end_offset) {
		if child.is_html_table_element() {
			// 1. Call collapse(end node, end offset) on the context object's selection.
			selection.collapse(end_node, end_offset) or { panic(err) }

			// 2. Call extend(end node, end offset + 1) on the context object's selection.
			selection.extend(end_node, end_offset + 1) or { panic(err) }

			// 3. Return true.
			return true
		}
	}

	// 13. If offset is the length of node, and the child of end node with index end offset is an hr or br:
	if child := end_node.child_at_index(end_offset) {
		if offset == node.length() && is_html_element_named(child, ['hr', 'br']) {
			// 1. Call collapse(end node, end offset) on the context object's selection.
			selection.collapse(end_node, end_offset) or { panic(err) }

			// 2. Call extend(end node, end offset + 1) on the context object's selection.
			selection.extend(end_node, end_offset + 1) or { panic(err) }

			// 3. Delete the selection.
			delete_the_selection(mut selection, true, true, .forwards)

			// 4. Call collapse(node, offset) on the selection.
			selection.collapse(node, offset) or { panic(err) }

			// 5. Return true.
			return true
		}
	}

	// 14. While end node has a child with index end offset:
	for {
		child := end_node.child_at_index(end_offset) or { break }

		// 1. If end node's child with index end offset is editable and invisible, remove it from end node.
		if child.is_editable() && is_invisible_node(child) {
			remove_node(child)
		}

		// 2. Otherwise, set end node to its child with index end offset and set end offset to zero.
		else {
			end_node = child
			end_offset = 0
		}
	}

	// 15. Call collapse(node, offset) on the context object's selection.
	selection.collapse(node, offset) or { panic(err) }

	// 16. Call extend(end node, end offset) on the context object's selection.
	selection.extend(end_node, end_offset) or { panic(err) }

	// 17. Delete the selection.
	delete_the_selection(mut selection, true, true, .forwards)

	// AD-HOC: Return true.
	return true
}

fn editing_list_items_of_active_range(document &dom.Document) []&dom.Node {
	mut items := []&dom.Node{}
	range_ := active_range(document) or { return items }
	for boundary_node in [range_.start_container(), range_.end_container()] {
		mut ancestor := ?&dom.Node(boundary_node)
		for {
			current := ancestor or { break }
			if current.is_html_li_element() && !editing_node_list_contains(items, current) {
				items << current
			}
			ancestor = current.parent()
		}
	}
	return items
}

// https://w3c.github.io/editing/docs/execCommand/#the-indent-command
pub fn command_indent_action(mut document dom.Document, _ string) bool {
	// 1. Let items be a list of all lis that are inclusive ancestors of the active range's start and/or end node.
	items := editing_list_items_of_active_range(document)

	// 2. For each item in items, normalize sublists of item.
	for item in items {
		normalize_sublists_in_node(item)
	}

	// 3. Block-extend the active range, and let new range be the result.
	new_range := block_extend_a_range(editing_active_range(document))

	// 4. Let node list be a list of nodes, initially empty.
	mut node_list := []&dom.Node{}

	// 5. For each node node contained in new range, if node is editable and is an allowed child of "div" or "ol" and if
	//    the last member of node list (if any) is not an ancestor of node, append node to node list.
	for node in new_range.contained_nodes() {
		if node.is_editable()
			&& (is_allowed_child_of_node(allowed_child_node(node), allowed_child_name('div'))
			|| is_allowed_child_of_node(allowed_child_node(node), allowed_child_name('ol')))
			&& (node_list.len == 0 || !node_list.last().is_ancestor_of(node)) {
			node_list << node
		}
	}

	// 6. If the first visible member of node list is an li whose parent is an ol or ul:
	mut first_visible := ?&dom.Node(none)
	for node in node_list {
		if is_visible_node(node) {
			first_visible = node
			break
		}
	}
	if visible := first_visible {
		if visible.is_html_li_element() {
			if parent := visible.parent() {
				if editing_is_ol_or_ul(parent) {
					// 1. Let sibling be node list's first visible member's previousSibling.
					mut sibling := visible.previous_sibling()

					// 2. While sibling is invisible, set sibling to its previousSibling.
					for {
						current := sibling or { break }
						if !is_invisible_node(current) {
							break
						}
						sibling = current.previous_sibling()
					}

					// 3. If sibling is an li, normalize sublists of sibling.
					if current := sibling {
						if current.is_html_li_element() {
							normalize_sublists_in_node(current)
						}
					}
				}
			}
		}
	}

	// 7. While node list is not empty:
	for node_list.len > 0 {
		// 1. Let sublist be a list of nodes, initially empty.
		// 2. Remove the first member of node list and append it to sublist.
		mut sublist := [node_list[0]]
		node_list.delete(0)

		// 3. While the first member of node list is the nextSibling of the last member of sublist, remove the first
		//    member of node list and append it to sublist.
		for node_list.len > 0 && editing_same_node(node_list[0], sublist.last().next_sibling()) {
			sublist << node_list[0]
			node_list.delete(0)
		}

		// 4. Indent sublist.
		indent(sublist)
	}

	// AD-HOC: Return true.
	return true
}

// https://w3c.github.io/editing/docs/execCommand/#the-inserthorizontalrule-command
pub fn command_insert_horizontal_rule_action(mut document dom.Document, _ string) bool {
	// 1. Let start node, start offset, end node, and end offset be the active range's start and end nodes and offsets.
	range_ := editing_active_range(document)
	mut start := range_.start()
	mut end := range_.end()

	// 2. While start offset is 0 and start node's parent is not null, set start offset to start node's index, then set
	//    start node to its parent.
	for start.offset == 0 {
		parent := start.node.parent() or { break }
		start = editing_boundary(parent, start.node.index())
	}

	// 3. While end offset is end node's length, and end node's parent is not null, set end offset to one plus end
	//    node's index, then set end node to its parent.
	for end.offset == end.node.length() {
		parent := end.node.parent() or { break }
		end = editing_boundary(parent, end.node.index() + 1)
	}

	// 4. Call collapse(start node, start offset) on the context object's selection.
	mut selection := editing_selection(document)
	selection.collapse(start.node, start.offset) or { panic(err) }

	// 5. Call extend(end node, end offset) on the context object's selection.
	selection.extend(end.node, end.offset) or { panic(err) }

	// 6. Delete the selection, with block merging false.
	delete_the_selection(mut selection, false, true, .forwards)

	// 7. If the active range's start node is neither editable nor an editing host, return true.
	start = editing_active_range(document).start()
	if !start.node.is_editable_or_editing_host() {
		return true
	}

	// 8. If the active range's start node is a Text node and its start offset is zero, call collapse() on the context
	//    object's selection, with first argument the active range's start node's parent and second argument the active
	//    range's start node's index.
	if start.node.is_text() && start.offset == 0 {
		selection.collapse(start.node.parent(), start.node.index()) or { panic(err) }
	}

	// 9. If the active range's start node is a Text node and its start offset is the length of its start node, call
	//    collapse() on the context object's selection, with first argument the active range's start node's parent, and
	//    the second argument one plus the active range's start node's index.
	start = editing_active_range(document).start()
	if start.node.is_text() && start.offset == start.node.length() {
		selection.collapse(start.node.parent(), start.node.index() + 1) or { panic(err) }
	}

	// 10. Let hr be the result of calling createElement("hr") on the context object.
	hr := editing_create_html_element(document, 'hr').as_node()

	// 11. Run insertNode(hr) on the active range.
	insert_node_into_range(editing_active_range(document), hr) or { panic(err) }

	// 12. Fix disallowed ancestors of hr.
	fix_disallowed_ancestors_of_node(hr)

	// 13. Run collapse() on the context object's selection, with first argument hr's parent and the second argument
	//     equal to one plus hr's index.
	selection.collapse(hr.parent(), hr.index() + 1) or { panic(err) }

	// 14. Return true.
	return true
}

// https://w3c.github.io/editing/docs/execCommand/#the-inserthtml-command
pub fn command_insert_html_action(mut document dom.Document, value string) bool {
	// 1. Set value to the result of invoking get trusted types compliant string with TrustedHTML, this's relevant
	//    global object, value, "Document execCommand", and "script".
	resulting_value := document.trusted_types_compliant_html(value, 'document-exec-command') or {
		return false
	}
	return insert_html(mut document, resulting_value, none)
}

pub fn insert_pasted_fragment_action(mut document dom.Document, fragment &dom.DocumentFragment) bool {
	return insert_html(mut document, '', fragment)
}

fn insert_html(mut document dom.Document, value string, pasted_fragment ?&dom.DocumentFragment) bool {

	// 2. Delete the selection.
	mut selection := editing_selection(document)
	delete_the_selection(mut selection, true, true, .forwards)

	// 3. If the active range's start node is neither editable nor an editing host, return true.
	range_ := editing_active_range(document)
	if !range_.start_container().is_editable_or_editing_host() {
		return true
	}

	// INTEROP: Blink and WebKit route both inline and block rich paste through their selection-replacement command.
	//          Keeping fragment parsing, inserted-range tracking, and completion in that command prevents the two
	//          structural cases from acquiring different whitespace and caret behavior.
	// INTEROP: Chromium preserves a collapsible space immediately before pasted inline content by converting it to a
	//          non-breaking space, just as it does when inserting text at the same boundary.
	canonicalize_whitespace(range_.start(), true)
	if fragment := pasted_fragment {
		replace_selection_with_document_fragment(document, fragment) or { return false }
	} else {
		replace_selection_with_fragment(document, value) or { return false }
	}
	return true
}

// https://w3c.github.io/editing/docs/execCommand/#the-insertimage-command
pub fn command_insert_image_action(mut document dom.Document, value string) bool {
	// 1. If value is the empty string, return false.
	if value == '' {
		return false
	}

	// 2. Delete the selection, with strip wrappers false.
	// AD-HOC: Delete the selection, with strip wrappers *true*. Gecko/WebKit/Blink all remove inline elements that the
	//         deletion leaves empty around the insertion point — instead of keeping them as wrappers. WPT expectations
	//         follow the Gecko/WebKit/Blink behavior. The spec hasn't yet been updated to match.
	//         https://github.com/web-platform-tests/wpt/commit/38a8c54e7095713f7c290318480c68bb6f2322ef
	//         https://github.com/w3c/editing/issues/543
	mut selection := editing_selection(document)
	delete_the_selection(mut selection, true, true, .forwards)

	// 3. Let range be the active range.
	range_ := editing_active_range(document)

	// 4. If the active range's start node is neither editable nor an editing host, return true.
	if !range_.start_container().is_editable_or_editing_host() {
		return true
	}

	// 5. If range's start node is a block node whose sole child is a br, and its start offset is 0, remove its start
	//    node's child from it.
	start_node := range_.start_container()
	if is_block_node(start_node) && start_node.child_count() == 1 && range_.start_offset() == 0 {
		if first_child := start_node.first_child() {
			if first_child.is_html_br_element() {
				remove_node(first_child)
			}
		}
	}

	// 6. Let img be the result of calling createElement("img") on the context object.
	img_element := editing_create_html_element(document, 'img')
	img := img_element.as_node()

	// 7. Run setAttribute("src", value) on img.
	set_attribute_value(img_element, 'src', value)

	// AD-HOC: Gecko/WebKit/Blink all split ancestor inline elements around the insertion point, instead of inserting
	//         the image into them as the spec's step 8 specifies. WPT expectations follow the Gecko/WebKit/Blink
	//         behavior. The spec hasn't yet been updated to match.
	//         https://github.com/web-platform-tests/wpt/commit/38a8c54e7095713f7c290318480c68bb6f2322ef
	//         https://github.com/w3c/editing/issues/543
	mut topmost_inline_element := ?&dom.Node(none)
	mut candidate := ?&dom.Node(range_.start_container())
	for {
		current := candidate or { break }
		if current.is_editing_host() || is_block_node(current) {
			break
		}
		if current.is_element() {
			topmost_inline_element = current
		}
		candidate = current.parent()
	}
	if topmost := topmost_inline_element {
		mut current := range_.start_container()
		mut offset := range_.start_offset()
		for {
			parent := current.parent() or { break }
			mut gap_offset := 0
			if current.is_text() {
				if offset > 0 && offset < current.length() {
					split_text(unsafe { &dom.Text(current) }, offset) or { panic(err) }
				}
				gap_offset = current.index() + (if offset > 0 { 1 } else { 0 })
			} else if !current.is_element() {
				// Nodes that can't be split and can't contain children to redistribute — such as comments — are kept
				// intact, and the gap is placed before them.
				gap_offset = current.index()
			} else if offset > 0 && offset < current.child_count() {
				left_part := clone_node_for_editing(current, false) or { panic(err) }
				insert_node_before(left_part, parent, current)
				for index in 0 .. offset {
					first_child := current.first_child() or { break }
					move_node_preserving_ranges(first_child, left_part, index)
				}
				gap_offset = current.index()
			} else {
				gap_offset = current.index() + (if offset > 0 { 1 } else { 0 })
			}
			if voidptr(current) == voidptr(topmost) {
				insert_node_before(img, parent, parent.child_at_index(gap_offset))
				break
			}
			current = parent
			offset = gap_offset
		}
	} else {
		// 8. Run insertNode(img) on range.
		insert_node_into_range(range_, img) or { panic(err) }
	}

	// 9. Let selection be the result of calling getSelection() on the context object.
	// NOTE: Already done so in step 2.

	// 10. Run collapse() on selection, with first argument equal to the parent of img and the second argument equal to
	//     one plus the index of img.
	selection.collapse(img.parent(), img.index() + 1) or { panic(err) }

	// 11. Return true.
	return true
}

// https://w3c.github.io/editing/docs/execCommand/#the-insertlinebreak-command
pub fn command_insert_linebreak_action(mut document dom.Document, _ string) bool {
	// 1. Delete the selection, with strip wrappers false.
	mut selection := editing_selection(document)
	delete_the_selection(mut selection, true, false, .forwards)

	// 2. If the active range's start node is neither editable nor an editing host, return true.
	// NB: We keep a reference to the range here to preserve the original boundary points even after collapse operations
	//     in steps 5 and 6. This is intentional behavior that affects where the <br> is inserted in step 8.
	range_ := selection.range() or { return true }
	start_node := range_.start_container()
	start_offset := range_.start_offset()
	if !start_node.is_editable_or_editing_host() {
		return true
	}

	// 3. If the active range's start node is an Element, and "br" is not an allowed child of it, return true.
	if start_node.is_element()
		&& !is_allowed_child_of_node(allowed_child_name('br'), allowed_child_node(start_node)) {
		return true
	}

	// 4. If the active range's start node is not an Element, and "br" is not an allowed child of the active range's
	//    start node's parent, return true.
	if !start_node.is_element() {
		if parent := start_node.parent() {
			if !is_allowed_child_of_node(allowed_child_name('br'), allowed_child_node(parent)) {
				return true
			}
		}
	}

	// 5. If the active range's start node is a Text node and its start offset is zero, call collapse() on the context
	//    object's selection, with first argument equal to the active range's start node's parent and second argument
	//    equal to the active range's start node's index.
	if start_node.is_text() && start_offset == 0 {
		selection.collapse(start_node.parent(), start_node.index()) or { panic(err) }
	}

	// 6. If the active range's start node is a Text node and its start offset is the length of its start node, call
	//    collapse() on the context object's selection, with first argument equal to the active range's start node's
	//    parent and second argument equal to one plus the active range's start node's index.
	if start_node.is_text() && start_offset == start_node.length() {
		selection.collapse(start_node.parent(), start_node.index() + 1) or { panic(err) }
	}

	// AD-HOC: In preformatted white-space contexts, use newlines instead of <br> for line breaks. This matches
	//         Chrome behavior and WPT expectations. The white-space: pre, pre-wrap, and pre-line styles all preserve
	//         newlines, so inserting a literal newline character is more appropriate than a <br> element.
	//         However, padding line breaks (needed for empty last lines) should still be <br> because they won't
	//         appear in .textContent, making the content easier to work with programmatically.
	if white_space_collapse := resolved_keyword(start_node, 'white-space-collapse') {
		if white_space_collapse in ['preserve', 'preserve-breaks']
			&& !white_space_is_from_default_style(start_node) {
			if start_node.is_text() {
				insert_data(editing_character_data(start_node), start_offset, '\n') or { panic(err) }
				selection.collapse(start_node, start_offset + 1) or { panic(err) }
				if editing_active_range(document).start_offset() == start_node.length() {
					selection.collapse(start_node.parent(), start_node.index() + 1) or { panic(err) }
					br := editing_create_html_element(document, 'br').as_node()
					insert_node_into_range(editing_active_range(document), br) or { panic(err) }
					// The range insertion spans the padding br; restore the caret after the newline.
					selection.collapse(start_node, start_node.length()) or { panic(err) }
				}
				return true
			}
			if start_node.editing_host_is_plaintext_only() {
				text := document.create_text_node('\n').as_node()
				insert_node_into_range(editing_active_range(document), text) or { panic(err) }
				selection.collapse(text, 1) or { panic(err) }
				return true
			}
			// At an element boundary, insert a newline text node and, if needed,
			// a padding br that makes the empty last line visible.
			if start_node.is_element() {
				text := document.create_text_node('\n').as_node()
				insert_node_into_range(range_, text) or { panic(err) }
				selection.collapse(text.parent(), text.index() + 1) or { panic(err) }
				if text.next_sibling() == none {
					br := editing_create_html_element(document, 'br').as_node()
					insert_node_into_range(editing_active_range(document), br) or { panic(err) }
				}
				selection.collapse(text, 1) or { panic(err) }
				return true
			}
		}
	}

	// 7. Let br be the result of calling createElement("br") on the context object.
	br := editing_create_html_element(document, 'br').as_node()

	// 8. Call insertNode(br) on the active range.
	// NB: We use range from step 2 here; see the comment there for why.
	insert_node_into_range(range_, br) or { panic(err) }

	// 9. Call collapse() on the context object's selection, with br's parent as the first argument and one plus br's
	//    index as the second argument.
	selection.collapse(br.parent(), br.index() + 1) or { panic(err) }

	// 10. If br is a collapsed line break, call createElement("br") on the context object and let extra br be the
	//     result, then call insertNode(extra br) on the active range.
	if is_collapsed_line_break(br) {
		extra_br := editing_create_html_element(document, 'br').as_node()
		insert_node_into_range(editing_active_range(document), extra_br) or { panic(err) }

		// INTEROP: The range insertion leaves the range spanning extra br; Chromium keeps the caret collapsed
		//          between the two line breaks.
		selection.collapse(extra_br.parent(), extra_br.index()) or { panic(err) }
	}

	// 11. Return true.
	return true
}

// https://w3c.github.io/editing/docs/execCommand/#the-insertorderedlist-command
pub fn command_insert_ordered_list_action(mut document dom.Document, _ string) bool {
	// Toggle lists with tag name "ol", then return true.
	toggle_lists(document, 'ol')
	return true
}

// https://w3c.github.io/editing/docs/execCommand/#the-insertorderedlist-command
pub fn command_insert_ordered_list_indeterminate(document &dom.Document) bool {
	// True if the selection's list state is "mixed" or "mixed ol", false otherwise.
	return selections_list_state(document) in [.mixed, .mixed_ol]
}

// https://w3c.github.io/editing/docs/execCommand/#the-insertorderedlist-command
pub fn command_insert_ordered_list_state(document &dom.Document) bool {
	// True if the selection's list state is "ol", false otherwise.
	return selections_list_state(document) == .ol
}

// https://w3c.github.io/editing/docs/execCommand/#the-insertparagraph-command
pub fn command_insert_paragraph_action(mut document dom.Document, _ string) bool {
	// 1. Delete the selection.
	mut selection := editing_selection(document)
	delete_the_selection(mut selection, true, true, .forwards)

	// 2. If the active range's start node is neither editable nor an editing host, return true.
	mut active := selection.range() or { return true }
	mut node := active.start_container()
	if !node.is_editable_or_editing_host() {
		return true
	}

	// 3. Let node and offset be the active range's start node and offset.
	// NOTE: node is set in step 2
	mut offset := active.start_offset()

	// 4. If node is a Text node, and offset is neither 0 nor the length of node, call splitText(offset) on node.
	if node.is_text() && offset != 0 && offset != node.length() {
		split_text(unsafe { &dom.Text(node) }, offset) or { panic(err) }
	}

	// 5. If node is a Text node and offset is its length, set offset to one plus the index of node, then set node to
	//    its parent.
	if node.is_text() && offset == node.length() {
		parent := node.parent() or { return true }
		offset = node.index() + 1
		node = parent
	}

	// 6. If node is a Text or Comment node, set offset to the index of node, then set node to its parent.
	if node.is_text() || node.is_comment() {
		parent := node.parent() or { return true }
		offset = node.index()
		node = parent
	}

	// 7. Call collapse(node, offset) on the context object's selection.
	selection.collapse(node, offset) or { panic(err) }
	active = selection.range() or { return true }

	// 8. Let container equal node.
	mut container := node

	// 9. While container is not a single-line container, and container's parent is editable and in the same editing
	//    host as node, set container to its parent.
	for !is_single_line_container(container) {
		container_parent := container.parent() or { break }
		if !container_parent.is_editable() || !is_in_same_editing_host(node, container_parent) {
			break
		}
		container = container_parent
	}

	// 10. If container is an editable single-line container in the same editing host as node, and its local name is "p"
	//     or "div":
	if container.is_editable() && is_single_line_container(container) && is_in_same_editing_host(container, node)
		&& is_html_element_named(container, ['p', 'div']) {
		// 1. Let outer container equal container.
		mut outer_container := container

		// 2. While outer container is not a dd or dt or li, and outer container's parent is editable, set outer
		//    container to its parent.
		for !editing_is_li_dt_or_dd(outer_container) {
			outer_container_parent := outer_container.parent() or { break }
			if !outer_container_parent.is_editable() {
				break
			}
			outer_container = outer_container_parent
		}

		// 3. If outer container is a dd or dt or li, set container to outer container.
		if editing_is_li_dt_or_dd(outer_container) {
			container = outer_container
		}
	}

	// 11. If container is not editable or not in the same editing host as node or is not a single-line container:
	if !container.is_editable() || !is_in_same_editing_host(container, node) || !is_single_line_container(container) {
		// 1. Let tag be the default single-line container name.
		tag := document.get_default_single_line_container_name()

		// 2. Block-extend the active range, and let new range be the result.
		new_range := block_extend_a_range(active)

		// 3. Let node list be a list of nodes, initially empty.
		mut node_list := []&dom.Node{}

		// 4. Append to node list the first node in tree order that is contained in new range and is an allowed child of
		//    "p", if any.
		for contained in new_range.contained_nodes() {
			if is_allowed_child_of_node(allowed_child_node(contained), allowed_child_name('p')) {
				node_list << contained
				break
			}
		}

		// 5. If node list is empty:
		if node_list.len == 0 {
			// 1. If tag is not an allowed child of the active range's start node, return true.
			if !is_allowed_child_of_node(allowed_child_name(tag), allowed_child_node(active.start_container())) {
				return true
			}

			// 2. Set container to the result of calling createElement(tag) on the context object.
			container = editing_create_html_element(document, tag).as_node()

			// 3. Call insertNode(container) on the active range.
			insert_node_into_range(active, container) or { panic(err) }

			// 4. Call createElement("br") on the context object, and append the result as the last child of container.
			append_node(editing_create_html_element(document, 'br').as_node(), container) or { panic(err) }

			// 5. Call collapse(container, 0) on the context object's selection.
			selection.collapse(container, 0) or { panic(err) }

			// 6. Return true.
			return true
		}

		// 6. While the nextSibling of the last member of node list is not null and is an allowed child of "p", append
		//    it to node list.
		mut next_sibling := node_list.last().next_sibling()
		for {
			sibling := next_sibling or { break }
			if !is_allowed_child_of_node(allowed_child_node(sibling), allowed_child_name('p')) {
				break
			}
			node_list << sibling
			next_sibling = sibling.next_sibling()
		}

		// 7. Wrap node list, with sibling criteria returning false and new parent instructions returning the result of
		//    calling createElement(tag) on the context object. Set container to the result.
		// AD-HOC: wrap() does not always return something, but the rest of this algorithm expects it to be a valid
		//         node. Therefore, we only change the container if we successfully wrapped the node list.
		if new_container := wrap(node_list, no_sibling_criteria, fn [document, tag] () ?&dom.Node {
			return editing_create_html_element(document, tag).as_node()
		})
		{
			container = new_container
		}
	}

	// 12. If container's local name is "address", "listing", or "pre":
	if container_element := container.as_element() {
		if container_element.local_name() in ['address', 'listing', 'pre'] {
			// 1. Let br be the result of calling createElement("br") on the context object.
			mut br := editing_create_html_element(document, 'br').as_node()

			// 2. Call insertNode(br) on the active range.
			insert_node_into_range(active, br) or { panic(err) }

			// 3. Call collapse(node, offset + 1) on the context object's selection.
			selection.collapse(node, offset + 1) or { panic(err) }
			active = selection.range() or { return true }

			// 4. If br is the last descendant of container, let br be the result of calling createElement("br") on the
			//    context object, then call insertNode(br) on the active range.
			mut last_descendant := container.last_child()
			for {
				current := last_descendant or { break }
				if !current.has_children() {
					break
				}
				last_descendant = current.last_child()
			}
			if editing_same_node(br, last_descendant) {
				br = editing_create_html_element(document, 'br').as_node()
				insert_node_into_range(active, br) or { panic(err) }
			}

			// 5. Return true.
			return true
		}
	}

	// 13. If container's local name is "li", "dt", or "dd"; and either it has no children or it has a single child and
	//     that child is a br:
	if editing_is_li_dt_or_dd(container) && (!container.has_children() || (container.child_count() == 1
		&& editing_optional_node_is(container.first_child(), editing_is_br))) {
		// 1. Split the parent of the one-node list consisting of container.
		split_the_parent_of_nodes([container])

		// 2. If container has no children, call createElement("br") on the context object and append the result as the
		//    last child of container.
		if !container.has_children() {
			append_node(editing_create_html_element(document, 'br').as_node(), container) or { panic(err) }
		}

		// 3. If container is a dd or dt, and it is not an allowed child of any of its ancestors in the same editing
		//    host, set the tag name of container to the default single-line container name and let container be the
		//    result.
		if is_html_element_named(container, ['dd', 'dt'])
			&& !editing_is_allowed_child_of_some_ancestor_in_same_editing_host(container) {
			if element := container.as_element() {
				container = set_the_tag_name(element, document.get_default_single_line_container_name()).as_node()
			}
		}

		// 4. Fix disallowed ancestors of container.
		fix_disallowed_ancestors_of_node(container)

		// 5. Return true.
		return true
	}

	// 14. Let new line range be a new range whose start is the same as the active range's, and whose end is (container,
	//     length of container).
	mut new_line_range := dom.Range.create_from_boundary_points(active.start_container(), active.start_offset(),
		container, container.length())

	// 15. While new line range's start offset is zero and its start node is not a prohibited paragraph child, set its
	//     start to (parent of start node, index of start node).
	mut start_container := new_line_range.start_container()
	for new_line_range.start_offset() == 0 && !is_prohibited_paragraph_child(start_container) {
		parent := start_container.parent() or { break }
		new_line_range.set_start(parent, start_container.index()) or { panic(err) }
		start_container = parent
	}

	// 16. While new line range's start offset is the length of its start node and its start node is not a prohibited
	//     paragraph child, set its start to (parent of start node, 1 + index of start node).
	start_container = new_line_range.start_container()
	for new_line_range.start_offset() == start_container.length() && !is_prohibited_paragraph_child(start_container) {
		parent := start_container.parent() or { break }
		new_line_range.set_start(parent, start_container.index() + 1) or { panic(err) }
		start_container = parent
	}

	// 17. Let end of line be true if new line range contains either nothing or a single br, and false otherwise.
	single_br := voidptr(new_line_range.start_container()) == voidptr(new_line_range.end_container())
		&& new_line_range.start_offset() == new_line_range.end_offset() - 1
		&& editing_optional_node_is(new_line_range.start_container().child_at_index(new_line_range.start_offset()),
		editing_is_br)
	end_of_line := new_line_range.collapsed() || single_br

	container_element := container.as_element() or { return true }
	container_name := container_element.local_name()
	// 18. If the local name of container is "h1", "h2", "h3", "h4", "h5", or "h6", and end of line is true, let new
	//     container name be the default single-line container name.
	// 19. Otherwise, if the local name of container is "dt" and end of line is true, let new container name be "dd".
	// 20. Otherwise, if the local name of container is "dd" and end of line is true, let new container name be "dt".
	// 21. Otherwise, let new container name be the local name of container.
	new_container_name := if end_of_line && is_heading(container_name) {
		document.get_default_single_line_container_name()
	} else if container_name == 'dt' && end_of_line {
		'dd'
	} else if container_name == 'dd' && end_of_line {
		'dt'
	} else {
		container_name
	}

	// 22. Let new container be the result of calling createElement(new container name) on the context object.
	new_container_element := editing_create_html_element(document, new_container_name)
	mut new_container := new_container_element.as_node()

	// 23. Copy all attributes of container to new container.
	container_element.for_each_attribute_name_value(fn [new_container_element] (name string, value string) {
		set_attribute_value(new_container_element, name, value)
	})

	// 24. If new container has an id attribute, unset it.
	if new_container_element.has_attribute('id') {
		remove_attribute(new_container_element, 'id')
	}

	// 25. Insert new container into the parent of container immediately after container.
	container_parent := container.parent() or { return true }
	insert_node_before(new_container, container_parent, container.next_sibling())

	// 26. Let contained nodes be all nodes contained in new line range.
	// 27. Let frag be the result of calling extractContents() on new line range.
	// 28. Unset the id attribute (if any) of each Element descendant of frag that is not in contained nodes.
	// 29. Call appendChild(frag) on new container.
	//
	// AD-HOC: extractContents() would clone the partially contained ancestors on the range's start path and mutate the
	//         tree behind the editing history's back. Instead, split the start boundary in place (which is exactly what
	//         the cloning in extractContents() amounts to here, since the range's end is the end of container) and then
	//         move the nodes after the boundary directly into new container, performing every mutation through a
	//         reversible edit command. The resulting DOM is identical, and this mirrors how WebKit and Blink split
	//         paragraphs. The elements created by the boundary split take the place of the clones from step 27, so
	//         step 28's id-stripping applies to them.
	mut start_node := new_line_range.start_container()
	mut start_offset := new_line_range.start_offset()

	// AD-HOC: When step 11 wraps only the first node of the line, range gravity can leave the selection start outside
	//         of (just before) container, at one of its ancestors; the spec would then call extractContents() on a
	//         backwards range. INTEROP: Match Chromium for this case instead: the new paragraph becomes an empty block
	//         before the line, and the caret stays at the start of the existing content.
	if voidptr(start_node) != voidptr(container) && !container.is_inclusive_ancestor_of(start_node) {
		insert_node_before(new_container, container_parent, container)
		append_node(editing_create_html_element(document, 'br').as_node(), new_container) or { panic(err) }
		selection.collapse(container, 0) or { panic(err) }
		return true
	}

	for voidptr(start_node) != voidptr(container) {
		parent := start_node.parent() or { break }
		index := start_node.index()
		if start_node.is_text() {
			// NB: Steps 15 and 16 lifted boundaries at the edges of the start node to its parent, so a remaining Text
			//     node boundary is strictly inside the node.
			split_text(unsafe { &dom.Text(start_node) }, start_offset) or { panic(err) }
		} else {
			clone := clone_node_for_editing(start_node, false) or { panic(err) }
			// NB: The clone is not in the tree yet, so its final detached state is staging content. The recorded
			//     insertion below carries that complete state as one reversible mutation.
			if clone_element := clone.as_element() {
				history := begin_editing_proxy_mutation(clone)
				mut mutable_clone := unsafe { &dom.Element(clone_element) }
				mutable_clone.remove_attribute('id')
				end_editing_proxy_mutation(history)
			}
			insert_node_before(clone, parent, start_node.next_sibling())
			mut children_to_move := []&dom.Node{}
			mut child := start_node.child_at_index(start_offset)
			for {
				current := child or { break }
				children_to_move << current
				child = current.next_sibling()
			}
			for child_to_move in children_to_move {
				append_node(child_to_move, clone) or { panic(err) }
			}
		}
		start_offset = index + 1
		start_node = parent
	}
	mut nodes_to_move := []&dom.Node{}
	mut child := container.child_at_index(start_offset)
	for {
		current := child or { break }
		nodes_to_move << current
		child = current.next_sibling()
	}
	for node_to_move in nodes_to_move {
		append_node(node_to_move, new_container) or { panic(err) }
	}

	// 30. While container's lastChild is a prohibited paragraph child, set container to its lastChild.
	for {
		last_child := container.last_child() or { break }
		if !is_prohibited_paragraph_child(last_child) {
			break
		}
		container = last_child
	}

	// 31. While new container's lastChild is a prohibited paragraph child, set new container to its lastChild.
	for {
		last_child := new_container.last_child() or { break }
		if !is_prohibited_paragraph_child(last_child) {
			break
		}
		new_container = last_child
	}

	// 32. If container has no visible children, call createElement("br") on the context object, and append the result
	//     as the last child of container.
	if !has_visible_children(container) {
		append_node(editing_create_html_element(document, 'br').as_node(), container) or { panic(err) }
	}

	// 33. If new container has no visible children, call createElement("br") on the context object, and append the
	//     result as the last child of new container.
	if !has_visible_children(new_container) {
		append_node(editing_create_html_element(document, 'br').as_node(), new_container) or { panic(err) }
	}

	// 34. Call collapse(new container, 0) on the context object's selection.
	selection.collapse(new_container, 0) or { panic(err) }

	// 35. Return true
	return true
}

fn editing_utf16_code_units(value string) []string {
	mut units := []string{}
	for character in value.runes() {
		units << character.str()
	}
	return units
}

// https://w3c.github.io/editing/docs/execCommand/#the-inserttext-command
pub fn command_insert_text_action(mut document dom.Document, value string) bool {
	// 1. Delete the selection, with strip wrappers false.
	mut selection := editing_selection(document)
	replaces_selection := !selection.is_collapsed()
	delete_the_selection(mut selection, true, false, .forwards)
	canonicalize_collapsed_selection_for_editing(mut selection)

	// 2. If the active range's start node is neither editable nor an editing host, return true.
	mut range_ := editing_active_range(document)
	if !range_.start_container().is_editable_or_editing_host() {
		return true
	}

	// 3. If value's length is greater than one:
	// NOTE: V strings are UTF-8; each code point is inserted on its own, which is the code unit loop for every
	//       character in the Basic Multilingual Plane and keeps surrogate pairs together otherwise.
	code_units := editing_utf16_code_units(value)
	if code_units.len > 1 {
		// 1. For each code unit el in value, take the action for the insertText command, with value equal to el.
		for code_unit in code_units {
			take_the_action_for_command(mut document, command_insert_text, code_unit)
		}

		if replaces_selection {
			canonicalize_whitespace_after_selection_replacement(editing_active_range(document).start())
			canonicalize_whitespace_after_selection_replacement(editing_active_range(document).end())
		}

		// 2. Return true.
		return true
	}

	// 4. If value is the empty string, return true.
	if value == '' {
		return true
	}

	// 5. If value is a newline (U+000A), take the action for the insertParagraph command and return true.
	if value == '\n' {
		take_the_action_for_command(mut document, command_insert_paragraph, '')
		return true
	}

	// 6. Let node and offset be the active range's start node and offset.
	mut node := range_.start_container()
	mut offset := range_.start_offset()

	// AD-HOC: If node is a void element, move the position before it and find the best equivalent
	//         insertion point. For inline void elements, this traverses into previous inline siblings
	//         to find existing text nodes. For block void elements like <hr>, we stay in the parent.
	//         See: https://github.com/w3c/editing/issues/522
	if element := node.as_element() {
		if element.is_void_element() {
			if parent := node.parent() {
				offset = node.index()
				element_node := node
				node = parent
				if is_inline_node(element_node) {
					equivalent := first_equivalent_point(editing_boundary(node, offset))
					node = equivalent.node
					offset = equivalent.offset
				}
			}
		}
	}

	// 7. If node has a child whose index is offset − 1, and that child is a Text node, set node to that child, then set
	//    offset to node's length.
	if child := node.child_at_index(offset - 1) {
		if child.is_text() {
			node = child
			offset = node.length()
		}
	}

	// 8. If node has a child whose index is offset, and that child is a Text node, set node to that child, then set
	//    offset to zero.
	if child := node.child_at_index(offset) {
		if child.is_text() {
			node = child
			offset = 0
		}
	}

	// 9. Record current overrides, and let overrides be the result.
	overrides := record_current_overrides(document)

	// 10. Call collapse(node, offset) on the context object's selection.
	selection.collapse(node, offset) or { panic(err) }

	// 11. Canonicalize whitespace at (node, offset).
	canonicalize_whitespace(editing_boundary(node, offset), true)

	// 12. Let (node, offset) be the active range's start.
	range_ = editing_active_range(document)
	node = range_.start_container()
	offset = range_.start_offset()

	// 13. If node is a Text node:
	if node.is_text() {
		// 1. Call insertData(offset, value) on node.
		insert_data(editing_character_data(node), offset, value) or { panic(err) }

		// 2. Call collapse(node, offset) on the context object's selection.
		selection.collapse(node, offset) or { panic(err) }

		// 3. Call extend(node, offset + 1) on the context object's selection.
		selection.extend(node, offset + edit_command_utf16_length(value)) or { panic(err) }
	}

	// 14. Otherwise:
	else {
		// 1. If node has only one child, which is a collapsed line break, remove its child from it.
		if node.child_count() == 1 {
			if first_child := node.first_child() {
				if is_collapsed_line_break(first_child) {
					remove_node(first_child)
				}
			}
		}

		// 2. Let text be the result of calling createTextNode(value) on the context object.
		text := document.create_text_node(value).as_node()

		// 3. Call insertNode(text) on the active range.
		insert_node_into_range(editing_active_range(document), text) or { panic(err) }

		// 4. Call collapse(text, 0) on the context object's selection.
		selection.collapse(text, 0) or { panic(err) }

		// 5. Call extend(text, 1) on the context object's selection.
		selection.extend(text, text.length()) or { panic(err) }
	}

	// 15. Restore states and values from overrides.
	restore_states_and_values(mut document, overrides)

	// 16. Canonicalize whitespace at the active range's start, with fix collapsed space false.
	if replaces_selection {
		canonicalize_whitespace_after_selection_replacement(editing_active_range(document).start())
	} else {
		canonicalize_whitespace(editing_active_range(document).start(), false)
	}

	// 17. Canonicalize whitespace at the active range's end, with fix collapsed space false.
	if replaces_selection {
		canonicalize_whitespace_after_selection_replacement(editing_active_range(document).end())
	} else {
		canonicalize_whitespace(editing_active_range(document).end(), false)
	}

	// 18. If value is a space character, autolink the active range's start.
	if value == ' ' {
		autolink(editing_active_range(document).start())
	}

	// 19. Call collapseToEnd() on the context object's selection.
	selection.collapse_to_end() or { panic(err) }

	// 20. Return true.
	return true
}

// https://w3c.github.io/editing/docs/execCommand/#the-insertunorderedlist-command
pub fn command_insert_unordered_list_action(mut document dom.Document, _ string) bool {
	// Toggle lists with tag name "ul", then return true.
	toggle_lists(document, 'ul')
	return true
}

// https://w3c.github.io/editing/docs/execCommand/#the-insertunorderedlist-command
pub fn command_insert_unordered_list_indeterminate(document &dom.Document) bool {
	// True if the selection's list state is "mixed" or "mixed ul", false otherwise.
	return selections_list_state(document) in [.mixed, .mixed_ul]
}

// https://w3c.github.io/editing/docs/execCommand/#the-insertunorderedlist-command
pub fn command_insert_unordered_list_state(document &dom.Document) bool {
	// True if the selection's list state is "ul", false otherwise.
	return selections_list_state(document) == .ul
}

// https://w3c.github.io/editing/docs/execCommand/#the-italic-command
pub fn command_italic_action(mut document dom.Document, _ string) bool {
	// If queryCommandState("italic") returns true, set the selection's value to "normal".
	if query_command_state(document, command_italic) or { false } {
		set_the_selections_value(mut document, command_italic, 'normal')
	}

	// Otherwise set the selection's value to "italic".
	else {
		set_the_selections_value(mut document, command_italic, 'italic')
	}

	// Either way, return true.
	return true
}

fn editing_justify_matching_nodes(document &dom.Document) ?[]&dom.Node {
	// Return false if the active range is null. Otherwise, block-extend the active range.
	range_ := active_range(document) or { return none }
	extended := block_extend_a_range(range_)
	return extended.contained_nodes().filter(is_visible_node(it) && it.is_editable() && !it.has_children())
}

// https://w3c.github.io/editing/docs/execCommand/#the-justifycenter-command
fn justify_indeterminate(document &dom.Document, alignment JustifyAlignment) bool {
	// NOTE: This definition is taken from the "justifyCenter" spec and was made generic.

	// Return true if among visible editable nodes that are contained in the result and have no children, at least one
	// has alignment value "[alignment]" and at least one does not. Otherwise return false.
	matching_nodes := editing_justify_matching_nodes(document) or { return false }
	return matching_nodes.any(alignment_value_of_node(it) == alignment)
		&& matching_nodes.any(alignment_value_of_node(it) != alignment)
}

// https://w3c.github.io/editing/docs/execCommand/#the-justifycenter-command
fn justify_state(document &dom.Document, alignment JustifyAlignment) bool {
	// NOTE: This definition is taken from the "justifyCenter" spec and was made generic.

	// Return true if there is at least one visible editable node that is contained in the result and has no children,
	// and all such nodes have alignment value "[alignment]". Otherwise return false.
	matching_nodes := editing_justify_matching_nodes(document) or { return false }
	return matching_nodes.len > 0 && matching_nodes.all(alignment_value_of_node(it) == alignment)
}

// https://w3c.github.io/editing/docs/execCommand/#the-justifycenter-command
fn justify_value(document &dom.Document) string {
	// NOTE: This definition is taken from the "justifyCenter" spec and was made generic.

	// Return the empty string if the active range is null. Otherwise, block-extend the active range,
	// and return the alignment value of the first visible editable node that is contained in the result and has no
	// children.
	matching_nodes := editing_justify_matching_nodes(document) or { return '' }
	if matching_nodes.len > 0 {
		return justify_alignment_to_string(alignment_value_of_node(matching_nodes[0]))
	}

	// If there is no such node, return "left".
	return justify_alignment_to_string(.left)
}

// https://w3c.github.io/editing/docs/execCommand/#the-justifycenter-command
pub fn command_justify_center_action(mut document dom.Document, _ string) bool {
	// Justify the selection with alignment "center", then return true.
	justify_the_selection(document, .center)
	return true
}

fn command_justify_center_indeterminate(document &dom.Document) bool {
	return justify_indeterminate(document, .center)
}

fn command_justify_center_state(document &dom.Document) bool {
	return justify_state(document, .center)
}

// https://w3c.github.io/editing/docs/execCommand/#the-justifycenter-command
fn command_justify_center_value(document &dom.Document) string {
	return justify_value(document)
}

// https://w3c.github.io/editing/docs/execCommand/#the-justifyfull-command
pub fn command_justify_full_action(mut document dom.Document, _ string) bool {
	// Justify the selection with alignment "justify", then return true.
	justify_the_selection(document, .justify)
	return true
}

fn command_justify_full_indeterminate(document &dom.Document) bool {
	return justify_indeterminate(document, .justify)
}

fn command_justify_full_state(document &dom.Document) bool {
	return justify_state(document, .justify)
}

// https://w3c.github.io/editing/docs/execCommand/#the-justifyfull-command
fn command_justify_full_value(document &dom.Document) string {
	return justify_value(document)
}

// https://w3c.github.io/editing/docs/execCommand/#the-justifyleft-command
pub fn command_justify_left_action(mut document dom.Document, _ string) bool {
	// Justify the selection with alignment "left", then return true.
	justify_the_selection(document, .left)
	return true
}

fn command_justify_left_indeterminate(document &dom.Document) bool {
	return justify_indeterminate(document, .left)
}

fn command_justify_left_state(document &dom.Document) bool {
	return justify_state(document, .left)
}

// https://w3c.github.io/editing/docs/execCommand/#the-justifyleft-command
fn command_justify_left_value(document &dom.Document) string {
	return justify_value(document)
}

// https://w3c.github.io/editing/docs/execCommand/#the-justifyright-command
pub fn command_justify_right_action(mut document dom.Document, _ string) bool {
	// Justify the selection with alignment "right", then return true.
	justify_the_selection(document, .right)
	return true
}

fn command_justify_right_indeterminate(document &dom.Document) bool {
	return justify_indeterminate(document, .right)
}

fn command_justify_right_state(document &dom.Document) bool {
	return justify_state(document, .right)
}

// https://w3c.github.io/editing/docs/execCommand/#the-justifyright-command
fn command_justify_right_value(document &dom.Document) string {
	return justify_value(document)
}

// https://w3c.github.io/editing/docs/execCommand/#the-outdent-command
pub fn command_outdent_action(mut document dom.Document, _ string) bool {
	// 1. Let items be a list of all lis that are inclusive ancestors of the active range's start and/or end node.
	items := editing_list_items_of_active_range(document)

	// 2. For each item in items, normalize sublists of item.
	for item in items {
		normalize_sublists_in_node(item)
	}

	// 3. Block-extend the active range, and let new range be the result.
	new_range := block_extend_a_range(editing_active_range(document))

	// 4. Let node list be a list of nodes, initially empty.
	mut node_list := []&dom.Node{}

	// 5. For each node node contained in new range, append node to node list if the last member of node list (if any)
	//    is not an ancestor of node; node is editable; and either node has no editable descendants, or is an ol or ul,
	//    or is an li whose parent is an ol or ul.
	for node in new_range.contained_nodes() {
		if (node_list.len == 0 || !node_list.last().is_ancestor_of(node)) && node.is_editable()
			&& (!editing_has_editable_descendant(node) || editing_is_ol_or_ul(node)
			|| (node.is_html_li_element() && editing_optional_node_is(node.parent(), editing_is_ol_or_ul))) {
			node_list << node
		}
	}

	// 6. While node list is not empty:
	for node_list.len > 0 {
		// 1. While the first member of node list is an ol or ul or is not the child of an ol or ul, outdent it and
		//    remove it from node list.
		for node_list.len > 0 && (editing_is_ol_or_ul(node_list[0])
			|| !editing_optional_node_is(node_list[0].parent(), editing_is_ol_or_ul)) {
			first := node_list[0]
			node_list.delete(0)
			outdent(first)
		}

		// 2. If node list is empty, break from these substeps.
		if node_list.len == 0 {
			break
		}

		// 3. Let sublist be a list of nodes, initially empty.
		// 4. Remove the first member of node list and append it to sublist.
		mut sublist := [node_list[0]]
		node_list.delete(0)

		// 5. While the first member of node list is the nextSibling of the last member of sublist, and the first member
		//    of node list is not an ol or ul, remove the first member of node list and append it to sublist.
		for node_list.len > 0 && editing_same_node(node_list[0], sublist.last().next_sibling())
			&& !editing_is_ol_or_ul(node_list[0]) {
			sublist << node_list[0]
			node_list.delete(0)
		}

		// 6. Record the values of sublist, and let values be the result.
		values := record_the_values_of_nodes(sublist)

		// 7. Split the parent of sublist.
		split_the_parent_of_nodes(sublist)

		// 8. Fix disallowed ancestors of each member of sublist.
		for member in sublist {
			fix_disallowed_ancestors_of_node(member)
		}

		// 9. Restore the values from values.
		restore_the_values_of_nodes(values)
	}

	// 7. Return true.
	return true
}

// https://w3c.github.io/editing/docs/execCommand/#the-redo-command
pub fn command_redo_action(mut document dom.Document, _ string) bool {
	// Action: As defined by the UndoManager specification.
	//
	// INTEROP: The UndoManager specification is defunct and never defined this, so we match Chromium: replay the most
	//          recently undone step, restore its ending selection, and fire a non-cancelable input event with inputType
	//          "historyRedo" at the step's editing host.
	history_pointer := editing_history_if_exists(document) or { return false }
	mut history := unsafe { &EditingHistory(history_pointer) }
	return history.redo(document)
}

// https://w3c.github.io/editing/docs/execCommand/#the-removeformat-command
pub fn command_remove_format_action(mut document dom.Document, _ string) bool {
	// 1. Let elements to remove be a list of every removeFormat candidate effectively contained in the active range.
	elements_to_remove := nodes_effectively_contained_in_range(active_range(document)).filter(is_remove_format_candidate(it))

	// 2. For each element in elements to remove:
	for element in elements_to_remove {
		// 1. While element has children, insert the first child of element into the parent of element immediately
		//    before element, preserving ranges.
		parent := element.parent() or { continue }
		mut element_index := element.index()
		for {
			child := element.first_child() or { break }
			move_node_preserving_ranges(child, parent, element_index)
			element_index++
		}

		// 2. Remove element from its parent.
		remove_node(element)
	}

	// 3. If the active range's start node is an editable Text node, and its start offset is neither zero nor its start
	//    node's length, call splitText() on the active range's start node, with argument equal to the active range's
	//    start offset. Then set the active range's start node to the result, and its start offset to zero.
	mut range_ := editing_active_range(document)
	start := range_.start()
	if start.node.is_editable() && start.node.is_text() && start.offset != 0 && start.offset != start.node.length() {
		new_node := split_text(unsafe { &dom.Text(start.node) }, start.offset) or { panic(err) }
		range_.set_start(new_node.as_node(), 0) or { panic(err) }
	}

	// 4. If the active range's end node is an editable Text node, and its end offset is neither zero nor its end node's
	//    length, call splitText() on the active range's end node, with argument equal to the active range's end offset.
	end := range_.end()
	if end.node.is_editable() && end.node.is_text() && end.offset != 0 && end.offset != end.node.length() {
		split_text(unsafe { &dom.Text(end.node) }, end.offset) or { panic(err) }
	}

	// 5. Let node list consist of all editable nodes effectively contained in the active range.
	node_list := nodes_effectively_contained_in_range(active_range(document)).filter(it.is_editable())

	// 6. For each node in node list, while node's parent is a removeFormat candidate in the same editing host as node,
	//    split the parent of the one-node list consisting of node.
	for node in node_list {
		for {
			parent := node.parent() or { break }
			if !is_remove_format_candidate(parent) || !is_in_same_editing_host(parent, node) {
				break
			}
			split_the_parent_of_nodes([node])
			if editing_same_node(node.parent(), parent) {
				break
			}
		}
	}

	// 7. For each of the entries in the following list, in the given order, set the selection's value to null, with
	//    command as given.
	//    1. subscript
	//    2. bold
	//    3. fontName
	//    4. fontSize
	//    5. foreColor
	//    6. hiliteColor
	//    7. italic
	//    8. strikethrough
	//    9. underline
	for command_name in [command_subscript, command_bold, command_font_name, command_font_size,
		command_fore_color, command_hilite_color, command_italic, command_strikethrough,
		command_underline] {
		set_the_selections_value(mut document, command_name, none)
	}

	// 8. Return true.
	return true
}

// https://w3c.github.io/editing/docs/execCommand/#the-selectall-command
pub fn command_select_all_action(mut document dom.Document, _ string) bool {
	// NOTE: The spec mentions "This is totally broken". So fair warning :^)

	// INTEROP: When the selection is inside an editing host, Chromium selects that host's contents rather than the
	//          whole document (the spec itself notes that this is what should happen). Reuse the Select All user
	//          action, which selects the complete active editing host with rendered caret endpoints.
	if range_ := active_range(document) {
		if range_.start_container().is_editable_or_editing_host() {
			modifier := dom.SelectionModifier.new(editing_selection(document))
			modifier.select_all()
			return true
		}
	}

	// 1. Let target be the body element of the context object.
	// 2. If target is null, let target be the context object's documentElement.
	mut target := ?&dom.Node(none)
	if body := document.body() {
		target = body.as_node()
	} else if document_element := document.document_element() {
		target = document_element.as_node()
	}

	// 3. If target is null, call getSelection() on the context object, and call removeAllRanges() on the result.
	mut selection := editing_selection(document)
	if node := target {
		// 4. Otherwise, call getSelection() on the context object, and call selectAllChildren(target) on the result.
		selection.select_all_children(node) or { panic(err) }
	} else {
		selection.remove_all_ranges()
	}

	// 5. Return true.
	return true
}

// https://w3c.github.io/editing/docs/execCommand/#the-strikethrough-command
pub fn command_strikethrough_action(mut document dom.Document, _ string) bool {
	// If queryCommandState("strikethrough") returns true, set the selection's value to null.
	if query_command_state(document, command_strikethrough) or { false } {
		set_the_selections_value(mut document, command_strikethrough, none)
	}

	// Otherwise set the selection's value to "line-through".
	else {
		set_the_selections_value(mut document, command_strikethrough, 'line-through')
	}

	// Either way, return true.
	return true
}

// https://w3c.github.io/editing/docs/execCommand/#the-stylewithcss-command
pub fn command_style_with_css_action(mut document dom.Document, value string) bool {
	// If value is an ASCII case-insensitive match for the string "false", set the CSS styling flag to false.
	// Otherwise, set the CSS styling flag to true.
	document.set_css_styling_flag(command_ascii_lowercase(value) != 'false')

	// Either way, return true.
	return true
}

// https://w3c.github.io/editing/docs/execCommand/#the-stylewithcss-command
pub fn command_style_with_css_state(document &dom.Document) bool {
	// True if the CSS styling flag is true, otherwise false.
	return document.get_css_styling_flag()
}

// https://w3c.github.io/editing/docs/execCommand/#the-subscript-command
pub fn command_subscript_action(mut document dom.Document, _ string) bool {
	// 1. Call queryCommandState("subscript"), and let state be the result.
	state := query_command_state(document, command_subscript) or { false }

	// 2. Set the selection's value to null.
	set_the_selections_value(mut document, command_subscript, none)

	// 3. If state is false, set the selection's value to "subscript".
	if !state {
		set_the_selections_value(mut document, command_subscript, 'subscript')
	}

	// 4. Return true.
	return true
}

fn editing_script_indeterminate(document &dom.Document, command string, script_value string) bool {
	// True if either among formattable nodes that are effectively contained in the active range, there is at least one
	// with effective command value "[script_value]" and at least one with some other effective command value;
	mut has_script_value := false
	mut has_other_value := false
	mut has_mixed_value := false
	for descendant in nodes_effectively_contained_in_range(active_range(document)) {
		if !is_formattable_node(descendant) {
			continue
		}
		node_value := effective_command_value(descendant, command) or { continue }
		if node_value == script_value {
			has_script_value = true
		} else {
			has_other_value = true
			if node_value == 'mixed' {
				has_mixed_value = true
			}
		}
		if has_script_value && has_other_value {
			return true
		}
	}

	// or if there is some formattable node effectively contained in the active range with effective command value
	// "mixed". Otherwise false.
	return has_mixed_value
}

// https://w3c.github.io/editing/docs/execCommand/#the-subscript-command
pub fn command_subscript_indeterminate(document &dom.Document) bool {
	return editing_script_indeterminate(document, command_subscript, 'subscript')
}

// https://w3c.github.io/editing/docs/execCommand/#the-superscript-command
pub fn command_superscript_action(mut document dom.Document, _ string) bool {
	// 1. Call queryCommandState("superscript"), and let state be the result.
	state := query_command_state(document, command_superscript) or { false }

	// 2. Set the selection's value to null.
	set_the_selections_value(mut document, command_superscript, none)

	// 3. If state is false, set the selection's value to "superscript".
	if !state {
		set_the_selections_value(mut document, command_superscript, 'superscript')
	}

	// 4. Return true.
	return true
}

// https://w3c.github.io/editing/docs/execCommand/#the-superscript-command
pub fn command_superscript_indeterminate(document &dom.Document) bool {
	return editing_script_indeterminate(document, command_superscript, 'superscript')
}

// https://w3c.github.io/editing/docs/execCommand/#the-undo-command
pub fn command_undo_action(mut document dom.Document, _ string) bool {
	// Action: As defined by the UndoManager specification.
	//
	// INTEROP: The UndoManager specification is defunct and never defined this, so we match Chromium: unapply the most
	//          recent undo step, restore its starting selection, and fire a non-cancelable input event with inputType
	//          "historyUndo" at the step's editing host.
	history_pointer := editing_history_if_exists(document) or { return false }
	mut history := unsafe { &EditingHistory(history_pointer) }
	return history.undo(document)
}

// https://w3c.github.io/editing/docs/execCommand/#the-underline-command
pub fn command_underline_action(mut document dom.Document, _ string) bool {
	// If queryCommandState("underline") returns true, set the selection's value to null.
	if query_command_state(document, command_underline) or { false } {
		set_the_selections_value(mut document, command_underline, none)
	}

	// Otherwise set the selection's value to "underline".
	else {
		set_the_selections_value(mut document, command_underline, 'underline')
	}

	// Either way, return true.
	return true
}

// https://w3c.github.io/editing/docs/execCommand/#the-unlink-command
pub fn command_unlink_action(mut document dom.Document, _ string) bool {
	// 1. Let hyperlinks be a list of every a element that has an href attribute and is contained in the active range or
	//    is an ancestor of one of its boundary points.
	mut hyperlinks := []&dom.Element{}
	if range_ := active_range(document) {
		for node in range_.contained_nodes() {
			if editing_is_hyperlink(node) {
				hyperlinks << (node.as_element() or { continue })
			}
		}
		for boundary_node in [range_.start_container(), range_.end_container()] {
			mut ancestor := boundary_node.parent()
			for {
				current := ancestor or { break }
				if editing_is_hyperlink(current) {
					hyperlinks << (current.as_element() or { break })
				}
				ancestor = current.parent()
			}
		}
	}

	// 2. Clear the value of each member of hyperlinks.
	for member in hyperlinks {
		clear_the_value(command_unlink, member)
	}

	// 3. Return true.
	return true
}

fn editing_is_hyperlink(node &dom.Node) bool {
	element := node.as_element() or { return false }
	return node.is_html_anchor_element() && element.has_attribute('href')
}

// https://w3c.github.io/editing/docs/execCommand/#the-usecss-command
pub fn command_use_css_action(mut document dom.Document, value string) bool {
	// If value is an ASCII case-insensitive match for the string "false", set the CSS styling flag to true.
	// Otherwise, set the CSS styling flag to false.
	document.set_css_styling_flag(command_ascii_lowercase(value) == 'false')

	// Either way, return true.
	return true
}

pub fn command_definitions() []CommandDefinition {
	return [
		// https://w3c.github.io/editing/docs/execCommand/#the-backcolor-command
		CommandDefinition{
			command:               command_back_color
			action:                command_back_color_action
			indeterminate:         command_back_color_indeterminate
			value:                 command_back_color_value
			relevant_css_property: 'background-color'
			mapped_value:          'formatBackColor'
		},
		// https://w3c.github.io/editing/docs/execCommand/#the-bold-command
		CommandDefinition{
			command:                 command_bold
			action:                  command_bold_action
			relevant_css_property:   'font-weight'
			inline_activated_values: ['bold', '600', '700', '800', '900']
			mapped_value:            'formatBold'
		},
		// https://w3c.github.io/editing/docs/execCommand/#the-createlink-command
		CommandDefinition{
			command:      command_create_link
			action:       command_create_link_action
			mapped_value: 'insertLink'
		},
		// https://w3c.github.io/editing/docs/execCommand/#the-delete-command
		CommandDefinition{
			command:             command_delete
			action:              command_delete_action
			preserves_overrides: true
			mapped_value:        'deleteContentBackward'
		},
		// https://w3c.github.io/editing/docs/execCommand/#the-defaultparagraphseparator-command
		CommandDefinition{
			command: command_default_paragraph_separator
			action:  command_default_paragraph_separator_action
			value:   command_default_paragraph_separator_value
		},
		// https://w3c.github.io/editing/docs/execCommand/#the-fontname-command
		CommandDefinition{
			command:               command_font_name
			action:                command_font_name_action
			indeterminate:         command_font_name_indeterminate
			value:                 command_font_name_value
			relevant_css_property: 'font-family'
			mapped_value:          'formatFontName'
		},
		// https://w3c.github.io/editing/docs/execCommand/#the-fontsize-command
		CommandDefinition{
			command:               command_font_size
			action:                command_font_size_action
			value:                 command_font_size_value
			relevant_css_property: 'font-size'
		},
		// https://w3c.github.io/editing/docs/execCommand/#the-forecolor-command
		CommandDefinition{
			command:               command_fore_color
			action:                command_fore_color_action
			indeterminate:         command_fore_color_indeterminate
			value:                 command_fore_color_value
			relevant_css_property: 'color'
			mapped_value:          'formatFontColor'
		},
		// https://w3c.github.io/editing/docs/execCommand/#the-formatblock-command
		CommandDefinition{
			command:             command_format_block
			action:              command_format_block_action
			indeterminate:       command_format_block_indeterminate
			value:               command_format_block_value
			preserves_overrides: true
		},
		// https://w3c.github.io/editing/docs/execCommand/#the-forwarddelete-command
		CommandDefinition{
			command:             command_forward_delete
			action:              command_forward_delete_action
			preserves_overrides: true
			mapped_value:        'deleteContentForward'
		},
		// https://w3c.github.io/editing/docs/execCommand/#the-hilitecolor-command
		CommandDefinition{
			command:               command_hilite_color
			action:                command_back_color_action // For historical reasons, backColor and hiliteColor behave identically.
			indeterminate:         command_back_color_indeterminate
			value:                 command_back_color_value
			relevant_css_property: 'background-color'
		},
		// https://w3c.github.io/editing/docs/execCommand/#the-indent-command
		CommandDefinition{
			command:             command_indent
			action:              command_indent_action
			preserves_overrides: true
			mapped_value:        'formatIndent'
		},
		// https://w3c.github.io/editing/docs/execCommand/#the-inserthorizontalrule-command
		CommandDefinition{
			command:             command_insert_horizontal_rule
			action:              command_insert_horizontal_rule_action
			preserves_overrides: true
			mapped_value:        'insertHorizontalRule'
		},
		// https://w3c.github.io/editing/docs/execCommand/#the-inserthtml-command
		CommandDefinition{
			command:             command_insert_html
			action:              command_insert_html_action
			preserves_overrides: true
		},
		// https://w3c.github.io/editing/docs/execCommand/#the-insertimage-command
		CommandDefinition{
			command:             command_insert_image
			action:              command_insert_image_action
			preserves_overrides: true
		},
		// https://w3c.github.io/editing/docs/execCommand/#the-insertlinebreak-command
		CommandDefinition{
			command:             command_insert_line_break
			action:              command_insert_linebreak_action
			preserves_overrides: true
			mapped_value:        'insertLineBreak'
		},
		// https://w3c.github.io/editing/docs/execCommand/#the-insertorderedlist-command
		CommandDefinition{
			command:             command_insert_ordered_list
			action:              command_insert_ordered_list_action
			indeterminate:       command_insert_ordered_list_indeterminate
			state:               command_insert_ordered_list_state
			preserves_overrides: true
			mapped_value:        'insertOrderedList'
		},
		// https://w3c.github.io/editing/docs/execCommand/#the-insertparagraph-command
		CommandDefinition{
			command:             command_insert_paragraph
			action:              command_insert_paragraph_action
			preserves_overrides: true
			mapped_value:        'insertParagraph'
		},
		// https://w3c.github.io/editing/docs/execCommand/#the-inserttext-command
		CommandDefinition{
			command:      command_insert_text
			action:       command_insert_text_action
			mapped_value: 'insertText'
		},
		// https://w3c.github.io/editing/docs/execCommand/#the-insertunorderedlist-command
		CommandDefinition{
			command:             command_insert_unordered_list
			action:              command_insert_unordered_list_action
			indeterminate:       command_insert_unordered_list_indeterminate
			state:               command_insert_unordered_list_state
			preserves_overrides: true
			mapped_value:        'insertUnorderedList'
		},
		// https://w3c.github.io/editing/docs/execCommand/#the-italic-command
		CommandDefinition{
			command:                 command_italic
			action:                  command_italic_action
			relevant_css_property:   'font-style'
			inline_activated_values: ['italic', 'oblique']
		},
		// https://w3c.github.io/editing/docs/execCommand/#the-justifycenter-command
		CommandDefinition{
			command:             command_justify_center
			action:              command_justify_center_action
			indeterminate:       command_justify_center_indeterminate
			state:               command_justify_center_state
			value:               command_justify_center_value
			preserves_overrides: true
			mapped_value:        'formatJustifyCenter'
		},
		// https://w3c.github.io/editing/docs/execCommand/#the-justifyfull-command
		CommandDefinition{
			command:             command_justify_full
			action:              command_justify_full_action
			indeterminate:       command_justify_full_indeterminate
			state:               command_justify_full_state
			value:               command_justify_full_value
			preserves_overrides: true
			mapped_value:        'formatJustifyFull'
		},
		// https://w3c.github.io/editing/docs/execCommand/#the-justifyleft-command
		CommandDefinition{
			command:             command_justify_left
			action:              command_justify_left_action
			indeterminate:       command_justify_left_indeterminate
			state:               command_justify_left_state
			value:               command_justify_left_value
			preserves_overrides: true
			mapped_value:        'formatJustifyLeft'
		},
		// https://w3c.github.io/editing/docs/execCommand/#the-justifyright-command
		CommandDefinition{
			command:             command_justify_right
			action:              command_justify_right_action
			indeterminate:       command_justify_right_indeterminate
			state:               command_justify_right_state
			value:               command_justify_right_value
			preserves_overrides: true
			mapped_value:        'formatJustifyRight'
		},
		// https://w3c.github.io/editing/docs/execCommand/#the-outdent-command
		CommandDefinition{
			command:             command_outdent
			action:              command_outdent_action
			preserves_overrides: true
			mapped_value:        'formatOutdent'
		},
		// AD-HOC: This is a Ladybird-specific formatting command that is not part of the spec. It has no action and as
		//         such, it's not supported in userland (yet). The relevant CSS property `white-space` is used to indicate
		//         that if this style value is found during editing commands, it is recorded and restored where necessary.
		//         This is used to keep things like <div style="white-space: pre">..</div> intact when a selection is
		//         deleted, for example.
		CommandDefinition{
			command:               command_preserve_whitespace
			relevant_css_property: 'white-space'
		},
		// https://w3c.github.io/editing/docs/execCommand/#the-redo-command
		CommandDefinition{
			command:      command_redo
			action:       command_redo_action
			mapped_value: 'historyRedo'
		},
		// https://w3c.github.io/editing/docs/execCommand/#the-removeformat-command
		CommandDefinition{
			command: command_remove_format
			action:  command_remove_format_action
		},
		// https://w3c.github.io/editing/docs/execCommand/#the-selectall-command
		CommandDefinition{
			command: command_select_all
			action:  command_select_all_action
		},
		// https://w3c.github.io/editing/docs/execCommand/#the-strikethrough-command
		CommandDefinition{
			command:                 command_strikethrough
			action:                  command_strikethrough_action
			inline_activated_values: ['line-through']
			mapped_value:            'formatStrikeThrough'
		},
		// https://w3c.github.io/editing/docs/execCommand/#the-stylewithcss-command
		CommandDefinition{
			command: command_style_with_css
			action:  command_style_with_css_action
			state:   command_style_with_css_state
		},
		// https://w3c.github.io/editing/docs/execCommand/#the-subscript-command
		CommandDefinition{
			command:                 command_subscript
			action:                  command_subscript_action
			indeterminate:           command_subscript_indeterminate
			inline_activated_values: ['subscript']
		},
		// https://w3c.github.io/editing/docs/execCommand/#the-superscript-command
		CommandDefinition{
			command:                 command_superscript
			action:                  command_superscript_action
			indeterminate:           command_superscript_indeterminate
			inline_activated_values: ['superscript']
			mapped_value:            'formatSuperscript'
		},
		// https://w3c.github.io/editing/docs/execCommand/#the-underline-command
		CommandDefinition{
			command:                 command_underline
			action:                  command_underline_action
			inline_activated_values: ['underline']
		},
		// https://w3c.github.io/editing/docs/execCommand/#the-undo-command
		CommandDefinition{
			command:      command_undo
			action:       command_undo_action
			mapped_value: 'historyUndo'
		},
		// https://w3c.github.io/editing/docs/execCommand/#the-unlink-command
		CommandDefinition{
			command: command_unlink
			action:  command_unlink_action
		},
		// https://w3c.github.io/editing/docs/execCommand/#the-usecss-command
		CommandDefinition{
			command: command_use_css
			action:  command_use_css_action
		},
	]
}

pub fn find_command_definition(command string) ?CommandDefinition {
	lowercase := command_ascii_lowercase(command)
	for definition in command_definitions() {
		if lowercase == command_ascii_lowercase(definition.command) {
			return definition
		}
	}
	return none
}

pub fn take_the_action_for_command(mut document dom.Document, command string, value string) {
	definition := find_command_definition(command) or { return }
	if definition.action == unsafe { nil } {
		return
	}
	definition.action(mut document, value)
}
