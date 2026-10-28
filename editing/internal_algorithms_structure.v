// Copyright (c) 2024-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the tree restructuring algorithms in Editing/Internal/Algorithms.cpp: setting tag names,
// splitting parents, wrapping, line break cleanup, lists, indentation, and justification.
module editing

import css
import dom

pub type SiblingCriteria = fn (&dom.Node) bool

pub type NewParentInstructions = fn () ?&dom.Node

fn no_sibling_criteria(_ &dom.Node) bool {
	return false
}

fn no_new_parent_instructions() ?&dom.Node {
	return none
}

fn editing_node_list_contains(node_list []&dom.Node, node &dom.Node) bool {
	for member in node_list {
		if voidptr(member) == voidptr(node) {
			return true
		}
	}
	return false
}

// https://w3c.github.io/editing/docs/execCommand/#set-the-tag-name
pub fn set_the_tag_name(element &dom.Element, new_name string) &dom.Element {
	node := element.as_node()

	// 1. If element is an HTML element with local name equal to new name, return element.
	if element.is_html_element() && element.local_name() == new_name {
		return element
	}

	// 2. If element's parent is null, return element.
	parent := node.parent() or { return element }

	// 3. Let replacement element be the result of calling createElement(new name) on the ownerDocument of element.
	replacement_element := node.document().create_element(new_name) or { return element }
	replacement_node := replacement_element.as_node()

	// 4. Insert replacement element into element's parent immediately before element.
	insert_node_before(replacement_node, parent, node)

	// 5. Copy all attributes of element to replacement element, in order.
	element.for_each_attribute_name_value(fn [replacement_element] (name string, value string) {
		set_attribute_value(replacement_element, name, value)
	})

	// 6. While element has children, append the first child of element as the last child of replacement element, preserving ranges.
	for {
		first_child := node.first_child() or { break }
		move_node_preserving_ranges(first_child, replacement_node, replacement_node.child_count())
	}

	// 7. Remove element from its parent.
	remove_node(node)

	// 8. Return replacement element.
	return replacement_element
}

// https://w3c.github.io/editing/docs/execCommand/#split-the-parent
pub fn split_the_parent_of_nodes(node_list []&dom.Node) {
	if node_list.len == 0 {
		return
	}

	// 1. Let original parent be the parent of the first member of node list.
	first_node := node_list.first()
	last_node := node_list.last()
	original_parent := first_node.parent() or { return }

	// 2. If original parent is not editable or its parent is null, do nothing and abort these steps.
	if !original_parent.is_editable() {
		return
	}
	parent_of_original_parent := original_parent.parent() or { return }

	// 3. If the first child of original parent is in node list, remove extraneous line breaks before original parent.
	first_child := original_parent.first_child() or { return }
	first_child_in_nodes_list := editing_node_list_contains(node_list, first_child)
	if first_child_in_nodes_list {
		remove_extraneous_line_breaks_before_node(original_parent)
	}

	// 4. If the first child of original parent is in node list, and original parent follows a line break, set follows
	//    line break to true. Otherwise, set follows line break to false.
	follows_line_break := first_child_in_nodes_list && follows_a_line_break(original_parent)

	// 5. If the last child of original parent is in node list, and original parent precedes a line break, set precedes
	//    line break to true. Otherwise, set precedes line break to false.
	last_child := original_parent.last_child() or { return }
	last_child_in_nodes_list := editing_node_list_contains(node_list, last_child)
	precedes_line_break := last_child_in_nodes_list && precedes_a_line_break(original_parent)

	// 6. If the first child of original parent is not in node list, but its last child is:
	mut original_parent_index := original_parent.index()
	document := original_parent.document()
	if !first_child_in_nodes_list && last_child_in_nodes_list {
		// 1. For each node in node list, in reverse order, insert node into the parent of original parent immediately
		//    after original parent, preserving ranges.
		for index := node_list.len - 1; index >= 0; index-- {
			move_node_preserving_ranges(node_list[index], parent_of_original_parent, original_parent_index + 1)
		}

		// 2. If precedes line break is true, and the last member of node list does not precede a line break, call
		//    createElement("br") on the context object and insert the result immediately after the last member of node
		//    list.
		if precedes_line_break && !precedes_a_line_break(last_node) {
			br_element := editing_create_html_element(document, 'br')
			if last_node_parent := last_node.parent() {
				append_node(br_element.as_node(), last_node_parent) or { panic(err) }
			}
		}

		// 3. Remove extraneous line breaks at the end of original parent.
		remove_extraneous_line_breaks_at_the_end_of_node(original_parent)

		// 4. Abort these steps.
		return
	}

	// 7. If the first child of original parent is not in node list:
	if !first_child_in_nodes_list {
		// 1. Let cloned parent be the result of calling cloneNode(false) on original parent.
		cloned_parent := clone_node_for_editing(original_parent, false) or { panic(err) }

		// 2. If original parent has an id attribute, unset it.
		if original_parent_element := original_parent.as_element() {
			if original_parent_element.has_attribute('id') {
				remove_attribute(original_parent_element, 'id')
			}
		}

		// 3. Insert cloned parent into the parent of original parent immediately before original parent.
		insert_node_before(cloned_parent, parent_of_original_parent, original_parent)
		original_parent_index = original_parent.index()

		// 4. While the previousSibling of the first member of node list is not null, append the first child of original
		//    parent as the last child of cloned parent, preserving ranges.
		for first_node.previous_sibling() != none {
			child := original_parent.first_child() or { break }
			move_node_preserving_ranges(child, cloned_parent, cloned_parent.child_count())
		}
	}

	// 8. For each node in node list, insert node into the parent of original parent immediately before original parent,
	//    preserving ranges.
	for node in node_list {
		move_node_preserving_ranges(node, parent_of_original_parent, original_parent_index)
		original_parent_index++
	}

	// 9. If follows line break is true, and the first member of node list does not follow a line break, call
	//    createElement("br") on the context object and insert the result immediately before the first member of node
	//    list.
	if follows_line_break && !follows_a_line_break(first_node) {
		br_element := editing_create_html_element(document, 'br')
		if first_node_parent := first_node.parent() {
			insert_node_before(br_element.as_node(), first_node_parent, first_node)
		}
	}

	// 10. If the last member of node list is an inline node other than a br, and the first child of original parent is
	//     a br, and original parent is not an inline node, remove the first child of original parent from original
	//     parent.
	if is_inline_node(last_node) && !last_node.is_html_br_element() && first_child.is_html_br_element()
		&& !is_inline_node(original_parent) {
		remove_node(first_child)
	}

	// 11. If original parent has no children:
	if original_parent.child_count() == 0 {
		// 1. Remove original parent from its parent.
		remove_node(original_parent)

		// 2. If precedes line break is true, and the last member of node list does not precede a line break, call
		//    createElement("br") on the context object and insert the result immediately after the last member of node
		//    list.
		if precedes_line_break && !precedes_a_line_break(last_node) {
			br_element := editing_create_html_element(document, 'br')
			if last_node_parent := last_node.parent() {
				insert_node_before(br_element.as_node(), last_node_parent, last_node.next_sibling())
			}
		}
	}

	// 12. Otherwise, remove extraneous line breaks before original parent.
	else {
		remove_extraneous_line_breaks_before_node(original_parent)
	}

	// 13. If node list's last member's nextSibling is null, but its parent is not null, remove extraneous line breaks
	//     at the end of node list's last member's parent.
	if last_node.next_sibling() == none {
		if last_node_parent := last_node.parent() {
			remove_extraneous_line_breaks_at_the_end_of_node(last_node_parent)
		}
	}
}

fn editing_last_visible_child(node &dom.Node) ?&dom.Node {
	mut child := node.last_child()
	for {
		current := child or { return none }
		if is_visible_node(current) {
			return current
		}
		child = current.previous_sibling()
	}
	return none
}

fn editing_first_visible_child(node &dom.Node) ?&dom.Node {
	mut child := node.first_child()
	for {
		current := child or { return none }
		if is_visible_node(current) {
			return current
		}
		child = current.next_sibling()
	}
	return none
}

// https://w3c.github.io/editing/docs/execCommand/#wrap
pub fn wrap(input_node_list []&dom.Node, sibling_criteria SiblingCriteria, new_parent_instructions NewParentInstructions) ?&dom.Node {
	if input_node_list.len == 0 {
		return none
	}
	mut node_list := input_node_list.clone()

	// 1. If every member of node list is invisible, and none is a br, return null and abort these steps.
	if !node_list.any(is_visible_node(it) || it.is_html_br_element()) {
		return none
	}

	// 2. If node list's first member's parent is null, return null and abort these steps.
	if node_list.first().parent() == none {
		return none
	}

	// 3. If node list's last member is an inline node that's not a br, and node list's last member's nextSibling is a
	//    br, append that br to node list.
	last_member := node_list.last()
	if is_inline_node(last_member) && !last_member.is_html_br_element() {
		if next_sibling := last_member.next_sibling() {
			if next_sibling.is_html_br_element() {
				node_list << next_sibling
			}
		}
	}

	// 4. While node list's first member's previousSibling is invisible, prepend it to node list.
	for {
		previous_sibling := node_list.first().previous_sibling() or { break }
		if !is_invisible_node(previous_sibling) {
			break
		}
		node_list.prepend(previous_sibling)
	}

	// 5. While node list's last member's nextSibling is invisible, append it to node list.
	for {
		next_sibling := node_list.last().next_sibling() or { break }
		if !is_invisible_node(next_sibling) {
			break
		}
		node_list << next_sibling
	}

	// 6. If the previousSibling of the first member of node list is editable and running sibling criteria on it returns
	//    true, let new parent be the previousSibling of the first member of node list.
	// 7. Otherwise, if the nextSibling of the last member of node list is editable and running sibling criteria on it
	//    returns true, let new parent be the nextSibling of the last member of node list.
	// 8. Otherwise, run new parent instructions, and let new parent be the result.
	mut new_parent_candidate := ?&dom.Node(none)
	if previous_sibling := node_list.first().previous_sibling() {
		if previous_sibling.is_editable() && sibling_criteria(previous_sibling) {
			new_parent_candidate = previous_sibling
		}
	}
	if new_parent_candidate == none {
		if next_sibling := node_list.last().next_sibling() {
			if next_sibling.is_editable() && sibling_criteria(next_sibling) {
				new_parent_candidate = next_sibling
			}
		}
	}
	if new_parent_candidate == none {
		new_parent_candidate = new_parent_instructions()
	}

	// 9. If new parent is null, abort these steps and return null.
	new_parent := new_parent_candidate or { return none }

	// 10. If new parent's parent is null:
	if new_parent.parent() == none {
		// 1. Insert new parent into the parent of the first member of node list immediately before the first member of
		//    node list.
		first_member := node_list.first()
		first_member_parent := first_member.parent() or { return none }
		insert_node_before(new_parent, first_member_parent, first_member)

		// 2. If any range has a boundary point with node equal to the parent of new parent and offset equal to the
		//    index of new parent, add one to that boundary point's offset.
		new_parent_index := new_parent.index()
		if mut active := active_range(new_parent.document()) {
			if voidptr(active.start_container()) == voidptr(new_parent)
				&& active.start_offset() == new_parent_index {
				active.set_start(active.start_container(), new_parent_index + 1) or { panic(err) }
			}
			if voidptr(active.end_container()) == voidptr(new_parent)
				&& active.end_offset() == new_parent_index {
				active.set_end(active.end_container(), new_parent_index + 1) or { panic(err) }
			}
		}
	}

	// 11. Let original parent be the parent of the first member of node list.
	original_parent := node_list.first().parent() or { return none }

	// 12. If new parent is before the first member of node list in tree order:
	if new_parent.is_preceding(node_list.first()) {
		// 1. If new parent is not an inline node, but the last visible child of new parent and the first visible member
		//    of node list are both inline nodes, and the last child of new parent is not a br, call createElement("br")
		//    on the ownerDocument of new parent and append the result as the last child of new parent.
		if !is_inline_node(new_parent) {
			last_visible_child := editing_last_visible_child(new_parent)
			mut first_visible_member := ?&dom.Node(none)
			for member in node_list {
				if is_visible_node(member) {
					first_visible_member = member
					break
				}
			}
			if child := last_visible_child {
				if member := first_visible_member {
					last_child_is_br := if last_child := new_parent.last_child() {
						last_child.is_html_br_element()
					} else {
						false
					}
					if is_inline_node(child) && is_inline_node(member) && !last_child_is_br {
						br_element := editing_create_html_element(new_parent.document(), 'br')
						append_node(br_element.as_node(), new_parent) or { panic(err) }
					}
				}
			}
		}

		// 2. For each node in node list, append node as the last child of new parent, preserving ranges.
		mut new_position := new_parent.child_count()
		for node in node_list {
			move_node_preserving_ranges(node, new_parent, new_position)
			new_position++
		}
	}

	// 13. Otherwise:
	else {
		// 1. If new parent is not an inline node, but the first visible child of new parent and the last visible member
		//    of node list are both inline nodes, and the last member of node list is not a br, call createElement("br")
		//    on the ownerDocument of new parent and insert the result as the first child of new parent.
		if !is_inline_node(new_parent) {
			first_visible_child := editing_first_visible_child(new_parent)
			mut last_visible_member := ?&dom.Node(none)
			for index := node_list.len - 1; index >= 0; index-- {
				if is_visible_node(node_list[index]) {
					last_visible_member = node_list[index]
					break
				}
			}
			if child := first_visible_child {
				if member := last_visible_member {
					if is_inline_node(child) && is_inline_node(member)
						&& !node_list.last().is_html_br_element() {
						br_element := editing_create_html_element(new_parent.document(), 'br')
						insert_node_before(br_element.as_node(), new_parent, new_parent.first_child())
					}
				}
			}
		}

		// 2. For each node in node list, in reverse order, insert node as the first child of new parent, preserving
		//    ranges.
		for index := node_list.len - 1; index >= 0; index-- {
			move_node_preserving_ranges(node_list[index], new_parent, 0)
		}
	}

	// 14. If original parent is editable and has no children, remove it from its parent.
	if original_parent.is_editable() && !original_parent.has_children() {
		remove_node(original_parent)
	}

	// 15. If new parent's nextSibling is editable and running sibling criteria on it returns true:
	if next_sibling := new_parent.next_sibling() {
		if next_sibling.is_editable() && sibling_criteria(next_sibling) {
			// 1. If new parent is not an inline node, but new parent's last child and new parent's nextSibling's first
			//    child are both inline nodes, and new parent's last child is not a br, call createElement("br") on the
			//    ownerDocument of new parent and append the result as the last child of new parent.
			if !is_inline_node(new_parent) {
				if last_child := new_parent.last_child() {
					if next_first_child := next_sibling.first_child() {
						if is_inline_node(last_child) && is_inline_node(next_first_child)
							&& !last_child.is_html_br_element() {
							br_element := editing_create_html_element(new_parent.document(), 'br')
							append_node(br_element.as_node(), new_parent) or { panic(err) }
						}
					}
				}
			}

			// 2. While new parent's nextSibling has children, append its first child as the last child of new parent,
			//    preserving ranges.
			mut new_position := new_parent.child_count()
			for {
				child := next_sibling.first_child() or { break }
				move_node_preserving_ranges(child, new_parent, new_position)
				new_position++
			}

			// 3. Remove new parent's nextSibling from its parent.
			remove_node(next_sibling)
		}
	}

	// 16. Remove extraneous line breaks from new parent.
	remove_extraneous_line_breaks_from_a_node(new_parent)

	// 17. Return new parent.
	return new_parent
}

// https://w3c.github.io/editing/docs/execCommand/#remove-extraneous-line-breaks-at-the-end-of
pub fn remove_extraneous_line_breaks_at_the_end_of_node(node &dom.Node) {
	// 1. Let ref be node.
	mut ref := unsafe { node }

	// 2. While ref has children, set ref to its lastChild.
	for {
		ref = ref.last_child() or { break }
	}

	// 3. While ref is invisible but not an extraneous line break, and ref does not equal node, set
	//    ref to the node before it in tree order.
	for is_invisible_node(ref) && !is_extraneous_line_break(ref) && voidptr(ref) != voidptr(node) {
		ref = ref.previous_in_pre_order() or { break }
	}

	// 4. If ref is an editable extraneous line break:
	if ref.is_editable() && is_extraneous_line_break(ref) {
		// 1. While ref's parent is editable and invisible, set ref to its parent.
		for {
			parent := ref.parent() or { break }
			if !parent.is_editable() || !is_invisible_node(parent) {
				break
			}
			ref = parent
		}

		// 2. Remove ref from its parent.
		remove_node(ref)
	}
}

// https://w3c.github.io/editing/docs/execCommand/#remove-extraneous-line-breaks-before
pub fn remove_extraneous_line_breaks_before_node(node &dom.Node) {
	// 1. Let ref be the previousSibling of node.
	// 2. If ref is null, abort these steps.
	mut ref := node.previous_sibling() or { return }

	// 3. While ref has children, set ref to its lastChild.
	for {
		ref = ref.last_child() or { break }
	}

	// 4. While ref is invisible but not an extraneous line break, and ref does not equal node's
	//    parent, set ref to the node before it in tree order.
	node_parent := node.parent()
	for is_invisible_node(ref) && !is_extraneous_line_break(ref) && !editing_same_node(ref, node_parent) {
		ref = ref.previous_in_pre_order() or { break }
	}

	// 5. If ref is an editable extraneous line break, remove it from its parent.
	if ref.is_editable() && is_extraneous_line_break(ref) {
		remove_node(ref)
	}
}

// https://w3c.github.io/editing/docs/execCommand/#remove-extraneous-line-breaks-from
pub fn remove_extraneous_line_breaks_from_a_node(node &dom.Node) {
	// To remove extraneous line breaks from a node, first remove extraneous line breaks before it,
	// then remove extraneous line breaks at the end of it.
	remove_extraneous_line_breaks_before_node(node)
	remove_extraneous_line_breaks_at_the_end_of_node(node)
}

// https://w3c.github.io/editing/docs/execCommand/#preserving-its-descendants
pub fn remove_node_preserving_its_descendants(node &dom.Node) {
	// To remove a node node while preserving its descendants, split the parent of node's children if it has any.
	if node.has_children() {
		split_the_parent_of_nodes(node.children_as_vector())
		return
	}

	// If it has no children, instead remove it from its parent.
	remove_node(node)
}

fn editing_is_allowed_child_of_some_ancestor_in_same_editing_host(node &dom.Node) bool {
	mut ancestor := node.parent()
	for {
		current := ancestor or { break }
		if is_in_same_editing_host(current, node)
			&& is_allowed_child_of_node(allowed_child_node(node), allowed_child_node(current)) {
			return true
		}
		ancestor = current.parent()
	}
	return false
}

// https://w3c.github.io/editing/docs/execCommand/#fix-disallowed-ancestors
pub fn fix_disallowed_ancestors_of_node(input_node &dom.Node) {
	mut node := unsafe { input_node }

	// 1. If node is not editable, abort these steps.
	if !node.is_editable() {
		return
	}

	// 2. If node is not an allowed child of any of its ancestors in the same editing host:
	if !editing_is_allowed_child_of_some_ancestor_in_same_editing_host(node) {
		// 1. If node is a dd or dt, wrap the one-node list consisting of node, with sibling criteria returning true for
		//    any dl with no attributes and false otherwise, and new parent instructions returning the result of calling
		//    createElement("dl") on the context object. Then abort these steps.
		if element := node.as_element() {
			if element.local_name() in ['dd', 'dt'] {
				document := node.document()
				wrap([node], fn (sibling &dom.Node) bool {
					sibling_element := sibling.as_element() or { return false }
					return sibling_element.local_name() == 'dl' && !sibling_element.has_attributes()
				}, fn [document] () ?&dom.Node {
					return editing_create_html_element(document, 'dl').as_node()
				})
				return
			}
		}

		// 2. If "p" is not an allowed child of the editing host of node, abort these steps.
		editing_host := node.editing_host() or { return }
		if !is_allowed_child_of_node(allowed_child_name('p'), allowed_child_node(editing_host)) {
			return
		}

		// 3. If node is not a prohibited paragraph child, abort these steps.
		if !is_prohibited_paragraph_child(node) {
			return
		}

		// 4. Set the tag name of node to the default single-line container name, and let node be the result.
		element := node.as_element() or { return }
		node = set_the_tag_name(element, node.document().get_default_single_line_container_name()).as_node()

		// 5. Fix disallowed ancestors of node.
		fix_disallowed_ancestors_of_node(node)

		// 6. Let children be node's children.
		// 7. For each child in children, if child is a prohibited paragraph child:
		for child in node.children_as_vector() {
			if !is_prohibited_paragraph_child(child) {
				continue
			}

			// 1. Record the values of the one-node list consisting of child, and let values be the result.
			values := record_the_values_of_nodes([child])

			// 2. Split the parent of the one-node list consisting of child.
			split_the_parent_of_nodes([child])

			// 3. Restore the values from values.
			restore_the_values_of_nodes(values)
		}

		// 8. Abort these steps.
		return
	}

	// 3. Record the values of the one-node list consisting of node, and let values be the result.
	values := record_the_values_of_nodes([node])

	// 4. While node is not an allowed child of its parent, split the parent of the one-node list consisting of node.
	for {
		parent := node.parent() or { break }
		if is_allowed_child_of_node(allowed_child_node(node), allowed_child_node(parent)) {
			break
		}
		split_the_parent_of_nodes([node])
		if editing_same_node(node.parent(), parent) {
			// Splitting did nothing (for example because the parent is not editable).
			break
		}
	}

	// 5. Restore the values from values.
	restore_the_values_of_nodes(values)
}

// https://w3c.github.io/editing/docs/execCommand/#normalize-sublists
pub fn normalize_sublists_in_node(item &dom.Node) {
	// 1. If item is not an li or it is not editable or its parent is not editable, abort these
	//    steps.
	if !item.is_html_li_element() || !item.is_editable() {
		return
	}
	item_parent := item.parent() or { return }
	if !item_parent.is_editable() {
		return
	}

	// 2. Let new item be null.
	mut new_item := ?&dom.Node(none)

	// 3. While item has an ol or ul child:
	for item.children_as_vector().any(editing_is_ol_or_ul(it)) {
		// 1. Let child be the last child of item.
		child := item.last_child() or { break }

		// 2. If child is an ol or ul, or new item is null and child is a Text node whose data
		//    consists of zero of more space characters:
		child_text := child.text_content() or { '' }
		text_is_all_whitespace := child_text.bytes().all(it in [` `, `\t`, `\n`, `\f`, `\r`])
		if editing_is_ol_or_ul(child) || (new_item == none && child.is_text() && text_is_all_whitespace) {
			// 1. Set new item to null.
			new_item = none

			// 2. Insert child into the parent of item immediately following item, preserving
			//    ranges.
			move_node_preserving_ranges(child, item_parent, item.index() + 1)
		}

		// 3. Otherwise:
		else {
			// 1. If new item is null, let new item be the result of calling createElement("li") on
			//    the ownerDocument of item, then insert new item into the parent of item
			//    immediately after item.
			if new_item == none {
				created := editing_create_html_element(item.document(), 'li').as_node()
				insert_node_before(created, item_parent, item.next_sibling())
				new_item = created
			}

			// 2. Insert child into new item as its first child, preserving ranges.
			target := new_item or { break }
			move_node_preserving_ranges(child, target, 0)
		}
	}
}

// https://w3c.github.io/editing/docs/execCommand/#indent
pub fn indent(node_list []&dom.Node) {
	// 1. If node list is empty, do nothing and abort these steps.
	if node_list.len == 0 {
		return
	}

	// 2. Let first node be the first member of node list.
	first_node := node_list.first()
	document := first_node.document()

	// 3. If first node's parent is an ol or ul:
	if first_parent := first_node.parent() {
		if editing_is_ol_or_ul(first_parent) {
			// 1. Let tag be the local name of the parent of first node.
			tag := (first_parent.as_element() or { return }).local_name()

			// 2. Wrap node list, with sibling criteria returning true for an HTML element with local name tag and false
			//    otherwise, and new parent instructions returning the result of calling createElement(tag) on the
			//    ownerDocument of first node.
			wrap(node_list, fn [tag] (sibling &dom.Node) bool {
				element := sibling.as_element() or { return false }
				return element.local_name() == tag
			}, fn [document, tag] () ?&dom.Node {
				return editing_create_html_element(document, tag).as_node()
			})

			// 3. Abort these steps.
			return
		}
	}

	// 4. Wrap node list, with sibling criteria returning true for a simple indentation element and false otherwise, and
	//    new parent instructions returning the result of calling createElement("blockquote") on the ownerDocument of
	//    first node. Let new parent be the result.
	new_parent := wrap(node_list, fn (sibling &dom.Node) bool {
		return is_simple_indentation_element(sibling)
	}, fn [document] () ?&dom.Node {
		return editing_create_html_element(document, 'blockquote').as_node()
	})

	// 5. Fix disallowed ancestors of new parent.
	if parent := new_parent {
		fix_disallowed_ancestors_of_node(parent)
	}
}

// https://w3c.github.io/editing/docs/execCommand/#outdent
pub fn outdent(node &dom.Node) {
	// 1. If node is not editable, abort these steps.
	if !node.is_editable() {
		return
	}

	// 2. If node is a simple indentation element, remove node, preserving its descendants. Then abort these steps.
	if is_simple_indentation_element(node) {
		remove_node_preserving_its_descendants(node)
		return
	}

	// 3. If node is an indentation element:
	if is_indentation_element(node) {
		element := node.as_element() or { return }

		// 1. Unset the dir attribute of node, if any.
		remove_attribute(element, 'dir')

		// 2. Unset the margin, padding, and border CSS properties of node.
		if mut inline_style := css.inline_style_for_element(element) {
			inline_style.remove_property('border') or {}
			inline_style.remove_property('margin') or {}
			inline_style.remove_property('padding') or {}
		}

		// 3. Set the tag name of node to "div".
		set_the_tag_name(element, 'div')

		// 4. Abort these steps.
		return
	}

	// 4. Let current ancestor be node's parent.
	mut current_ancestor := node.parent()

	// 5. Let ancestor list be a list of nodes, initially empty.
	mut ancestor_list := []&dom.Node{}

	// 6. While current ancestor is an editable Element that is neither a simple indentation element nor an ol nor a ul,
	//    append current ancestor to ancestor list and then set current ancestor to its parent.
	for {
		current := current_ancestor or { break }
		if !current.is_element() || !current.is_editable() || is_simple_indentation_element(current)
			|| editing_is_ol_or_ul(current) {
			break
		}
		ancestor_list << current
		current_ancestor = current.parent()
	}

	// 7. If current ancestor is not an editable simple indentation element:
	current_is_editable_simple_indentation := if current := current_ancestor {
		current.is_editable() && is_simple_indentation_element(current)
	} else {
		false
	}
	if !current_is_editable_simple_indentation {
		// 1. Let current ancestor be node's parent.
		current_ancestor = node.parent()

		// 2. Let ancestor list be the empty list.
		ancestor_list.clear()

		// 3. While current ancestor is an editable Element that is neither an indentation element nor an ol nor a ul,
		//    append current ancestor to ancestor list and then set current ancestor to its parent.
		for {
			current := current_ancestor or { break }
			if !current.is_element() || !current.is_editable() || is_indentation_element(current)
				|| editing_is_ol_or_ul(current) {
				break
			}
			ancestor_list << current
			current_ancestor = current.parent()
		}
	}

	// 8. If node is an ol or ul and current ancestor is not an editable indentation element:
	current_is_editable_indentation := if current := current_ancestor {
		current.is_editable() && is_indentation_element(current)
	} else {
		false
	}
	if editing_is_ol_or_ul(node) && !current_is_editable_indentation {
		// 1. Unset the reversed, start, and type attributes of node, if any are set.
		node_element := node.as_element() or { return }
		remove_attribute(node_element, 'reversed')
		remove_attribute(node_element, 'start')
		remove_attribute(node_element, 'type')

		// 2. Let children be the children of node.
		children := node.children_as_vector()

		// 3. If node has attributes, and its parent is not an ol or ul, set the tag name of node to "div".
		parent_is_list := editing_optional_node_is(node.parent(), editing_is_ol_or_ul)
		if node_element.has_attributes() && !parent_is_list {
			set_the_tag_name(node_element, 'div')
		}

		// 4. Otherwise:
		else {
			// 1. Record the values of node's children, and let values be the result.
			values := record_the_values_of_nodes(children)

			// 2. Remove node, preserving its descendants.
			remove_node_preserving_its_descendants(node)

			// 3. Restore the values from values.
			restore_the_values_of_nodes(values)
		}

		// 5. Fix disallowed ancestors of each member of children.
		for child in children {
			fix_disallowed_ancestors_of_node(child)
		}

		// 6. Abort these steps.
		return
	}

	// 9. If current ancestor is not an editable indentation element, abort these steps.
	if !current_is_editable_indentation {
		return
	}
	original_ancestor := current_ancestor or { return }

	// 10. Append current ancestor to ancestor list.
	ancestor_list << original_ancestor

	// 11. Let original ancestor be current ancestor.

	// 12. While ancestor list is not empty:
	for ancestor_list.len > 0 {
		// 1. Let current ancestor be the last member of ancestor list.
		// 2. Remove the last member from ancestor list.
		current := ancestor_list.pop()

		// 3. Let target be the child of current ancestor that is equal to either node or the last member of ancestor
		//    list.
		mut target := ?&dom.Node(none)
		for child in current.children_as_vector() {
			if voidptr(child) == voidptr(node)
				|| (ancestor_list.len > 0 && voidptr(child) == voidptr(ancestor_list.last())) {
				target = child
				break
			}
		}
		target_node := target or { continue }

		// 4. If target is an inline node that is not a br, and its nextSibling is a br, remove target's nextSibling
		//    from its parent.
		if is_inline_node(target_node) && !target_node.is_html_br_element() {
			if next_sibling := target_node.next_sibling() {
				if next_sibling.is_html_br_element() {
					remove_node(next_sibling)
				}
			}
		}

		// 5. Let preceding siblings be the precedings siblings of target, and let following siblings be the followings
		//    siblings of target.
		mut preceding_siblings := []&dom.Node{}
		mut sibling := target_node.previous_sibling()
		for {
			current_sibling := sibling or { break }
			preceding_siblings << current_sibling
			sibling = current_sibling.previous_sibling()
		}
		mut following_siblings := []&dom.Node{}
		sibling = target_node.next_sibling()
		for {
			current_sibling := sibling or { break }
			following_siblings << current_sibling
			sibling = current_sibling.next_sibling()
		}

		// 6. Indent preceding siblings.
		indent(preceding_siblings)

		// 7. Indent following siblings.
		indent(following_siblings)
	}

	// 13. Outdent original ancestor.
	outdent(original_ancestor)
}

// https://w3c.github.io/editing/docs/execCommand/#block-extend
pub fn block_extend_a_range(range_ &dom.Range) &dom.Range {
	// 1. Let start node, start offset, end node, and end offset be the start and end nodes and offsets of range.
	mut start_node := range_.start_container()
	mut start_offset := range_.start_offset()
	mut end_node := range_.end_container()
	mut end_offset := range_.end_offset()

	// 2. If some inclusive ancestor of start node is an li, set start offset to the index of the last such li in tree
	//    order, and set start node to that li's parent.
	mut ancestor := ?&dom.Node(start_node)
	for {
		current := ancestor or { break }
		if current.is_html_li_element() {
			if parent := current.parent() {
				start_offset = current.index()
				start_node = parent
			}
			break
		}
		ancestor = current.parent()
	}

	// 3. If (start node, start offset) is not a block start point, repeat the following steps:
	if !is_block_start_point(editing_boundary(start_node, start_offset)) {
		for {
			// 1. If start offset is zero, set it to start node's index, then set start node to its parent.
			if start_offset == 0 {
				parent := start_node.parent() or { break }
				start_offset = start_node.index()
				start_node = parent
			}

			// 2. Otherwise, subtract one from start offset.
			else {
				start_offset--
			}

			// 3. If (start node, start offset) is a block boundary point, break from this loop.
			if is_block_boundary_point(editing_boundary(start_node, start_offset)) {
				break
			}
		}
	}

	// 4. While start offset is zero and start node's parent is not null, set start offset to start node's index, then
	//    set start node to its parent.
	for start_offset == 0 {
		parent := start_node.parent() or { break }
		start_offset = start_node.index()
		start_node = parent
	}

	// 5. If some inclusive ancestor of end node is an li, set end offset to one plus the index of the last such li in
	//    tree order, and set end node to that li's parent.
	ancestor = end_node
	for {
		current := ancestor or { break }
		if current.is_html_li_element() {
			if parent := current.parent() {
				end_offset = current.index() + 1
				end_node = parent
			}
			break
		}
		ancestor = current.parent()
	}

	// 6. If (end node, end offset) is not a block end point, repeat the following steps:
	if !is_block_end_point(editing_boundary(end_node, end_offset)) {
		for {
			// 1. If end offset is end node's length, set it to one plus end node's index, then set end node to its
			//    parent.
			if end_offset == end_node.length() {
				parent := end_node.parent() or { break }
				end_offset = end_node.index() + 1
				end_node = parent
			}

			// 2. Otherwise, add one to end offset.
			else {
				end_offset++
			}

			// 3. If (end node, end offset) is a block boundary point, break from this loop.
			if is_block_boundary_point(editing_boundary(end_node, end_offset)) {
				break
			}
		}
	}

	// 7. While end offset is end node's length and end node's parent is not null, set end offset to one plus end node's
	//    index, then set end node to its parent.
	for end_offset == end_node.length() {
		parent := end_node.parent() or { break }
		end_offset = end_node.index() + 1
		end_node = parent
	}

	// 8. Let new range be a new range whose start and end nodes and offsets are start node, start offset, end node, and
	//    end offset.
	// 9. Return new range.
	return dom.Range.create_from_boundary_points(start_node, start_offset, end_node, end_offset)
}

// https://w3c.github.io/editing/docs/execCommand/#alignment-value
pub fn alignment_value_of_node(input_node ?&dom.Node) JustifyAlignment {
	// 1. While node is neither null nor an Element, or it is an Element but its "display" property has resolved value
	//    "inline" or "none", set node to its parent.
	mut node := input_node
	for {
		current := node or { break }
		if current.is_element() {
			display := resolved_display(current) or { break }
			if !((display.is_inline_outside() && display.is_flow_inside()) || display.is_none()) {
				break
			}
		}
		node = current.parent()
	}

	// 2. If node is not an Element, return "left".
	current := node or { return .left }
	element := current.as_element() or { return .left }

	// 3. If node's "text-align" property has resolved value "start", return "left" if the directionality of node is
	//    "ltr", "right" if it is "rtl".
	text_align_value := resolved_keyword(current, 'text-align') or { return .left }
	if text_align_value == 'start' {
		return if element.directionality() == .ltr { JustifyAlignment.left } else { JustifyAlignment.right }
	}

	// 4. If node's "text-align" property has resolved value "end", return "right" if the directionality of node is
	//    "ltr", "left" if it is "rtl".
	if text_align_value == 'end' {
		return if element.directionality() == .ltr { JustifyAlignment.right } else { JustifyAlignment.left }
	}

	// 5. If node's "text-align" property has resolved value "center", "justify", "left", or "right", return that value.
	// 6. Return "left".
	return match text_align_value {
		'center' { .center }
		'justify' { .justify }
		'right' { .right }
		else { .left }
	}
}

// https://w3c.github.io/editing/docs/execCommand/#justify-the-selection
pub fn justify_the_selection(document &dom.Document, alignment JustifyAlignment) {
	// 1. Block-extend the active range, and let new range be the result.
	mut new_range := block_extend_a_range(active_range(document) or { return })

	// 2. Let element list be a list of all editable Elements contained in new range that either has an attribute in the
	//    HTML namespace whose local name is "align", or has a style attribute that sets "text-align", or is a center.
	mut element_list := []&dom.Element{}
	for node in new_range.contained_nodes() {
		if !node.is_editable() {
			continue
		}
		element := node.as_element() or { continue }
		if element.has_attribute_ns(editing_html_namespace, 'align')
			|| property_in_style_attribute(element, 'text-align') != none
			|| element.local_name() == 'center' {
			element_list << element
		}
	}

	// 3. For each element in element list:
	for element in element_list {
		// 1. If element has an attribute in the HTML namespace whose local name is "align", remove that attribute.
		if element.has_attribute_ns(editing_html_namespace, 'align') {
			remove_attribute_ns(element, editing_html_namespace, 'align')
		}

		// 2. Unset the CSS property "text-align" on element, if it's set by a style attribute.
		if mut inline_style := css.inline_style_for_element(element) {
			inline_style.remove_property('text-align') or {}
		}

		// 3. If element is a div or span or center with no attributes, remove it, preserving its descendants.
		if element.local_name() in ['div', 'span', 'center'] && !element.has_attributes() {
			remove_node_preserving_its_descendants(element.as_node())
		}

		// 4. If element is a center with one or more attributes, set the tag name of element to "div".
		if element.local_name() == 'center' && element.has_attributes() {
			set_the_tag_name(element, 'div')
		}
	}

	// 4. Block-extend the active range, and let new range be the result.
	new_range = block_extend_a_range(active_range(document) or { return })

	// 5. Let node list be a list of nodes, initially empty.
	mut node_list := []&dom.Node{}

	// 6. For each node node contained in new range, append node to node list if the last member of node list (if any)
	//    is not an ancestor of node; node is editable; node is an allowed child of "div"; and node's alignment value is
	//    not alignment.
	for node in new_range.contained_nodes() {
		if (node_list.len == 0 || !node_list.last().is_ancestor_of(node)) && node.is_editable()
			&& is_allowed_child_of_node(allowed_child_node(node), allowed_child_name('div'))
			&& alignment_value_of_node(node) != alignment {
			node_list << node
		}
	}

	// 7. While node list is not empty:
	alignment_keyword := justify_alignment_to_string(alignment)
	for node_list.len > 0 {
		// 1. Let sublist be a list of nodes, initially empty.
		// 2. Remove the first member of node list and append it to sublist.
		mut sublist := [node_list[0]]
		node_list.delete(0)

		// 3. While node list is not empty, and the first member of node list is the nextSibling of the last member of
		//    sublist, remove the first member of node list and append it to sublist.
		for node_list.len > 0 && editing_same_node(node_list[0], sublist.last().next_sibling()) {
			sublist << node_list[0]
			node_list.delete(0)
		}

		// 4. Wrap sublist. Sibling criteria returns true for any div that has one or both of the following two
		//    attributes and no other attributes, and false otherwise:
		//    * An align attribute whose value is an ASCII case-insensitive match for alignment.
		//    * A style attribute which sets exactly one CSS property (including unrecognized or invalid attributes),
		//      which is "text-align", which is set to alignment.
		//
		//    New parent instructions are to call createElement("div") on the context object, then set its CSS property
		//    "text-align" to alignment and return the result.
		wrap(sublist, fn [alignment_keyword] (sibling &dom.Node) bool {
			if !sibling.is_html_div_element() {
				return false
			}
			element := sibling.as_element() or { return false }
			mut number_of_matching_attributes := 0
			if element.get_attribute_value('align').to_lower() == alignment_keyword {
				number_of_matching_attributes++
			}
			if element.has_attribute('style') && editing_inline_style_length(element) == 1 {
				if text_align := property_in_style_attribute(element, 'text-align') {
					if text_align.to_lower() == alignment_keyword {
						number_of_matching_attributes++
					}
				}
			}
			return element.attribute_list_size() == number_of_matching_attributes
		}, fn [document, alignment_keyword] () ?&dom.Node {
			div := editing_create_html_element(document, 'div')
			mut inline_style := css.element_style(div)
			inline_style.set_property('text-align', alignment_keyword, '') or {}
			return div.as_node()
		})
	}
}

// https://w3c.github.io/editing/docs/execCommand/#selection's-list-state
pub fn selections_list_state(document &dom.Document) SelectionsListState {
	// 1. If the active range is null, return "none".
	range_ := active_range(document) or { return .none }

	// 2. Block-extend the active range, and let new range be the result.
	new_range := block_extend_a_range(range_)

	// 3. Let node list be a list of nodes, initially empty.
	mut node_list := []&dom.Node{}

	// 4. For each node contained in new range, append node to node list if the last member of node list (if any) is not
	//    an ancestor of node; node is editable; node is not an indentation element; and node is either an ol or ul, or
	//    the child of an ol or ul, or an allowed child of "li".
	for node in new_range.contained_nodes() {
		if (node_list.len == 0 || !node_list.last().is_ancestor_of(node)) && node.is_editable()
			&& !is_indentation_element(node) && (editing_is_ol_or_ul(node)
			|| editing_optional_node_is(node.parent(), editing_is_ol_or_ul)
			|| is_allowed_child_of_node(allowed_child_node(node), allowed_child_name('li'))) {
			node_list << node
		}
	}

	// 5. If node list is empty, return "none".
	if node_list.len == 0 {
		return .none
	}

	// 6. If every member of node list is either an ol or the child of an ol or the child of an li child of an ol, and
	//    none is a ul or an ancestor of a ul, return "ol".
	mut all_is_an_ol := true
	mut none_is_a_ul := true
	for node in node_list {
		if !editing_is_type_or_child_of_list_type(node, editing_is_ol) {
			all_is_an_ol = false
			break
		}
		if node.is_html_ulist_element() || editing_is_ancestor_of_type(node, editing_is_ul) {
			none_is_a_ul = false
			break
		}
	}
	if all_is_an_ol && none_is_a_ul {
		return .ol
	}

	// 7. If every member of node list is either a ul or the child of a ul or the child of an li child of a ul, and none
	//    is an ol or an ancestor of an ol, return "ul".
	mut all_is_a_ul := true
	mut none_is_an_ol := true
	for node in node_list {
		if !editing_is_type_or_child_of_list_type(node, editing_is_ul) {
			all_is_a_ul = false
			break
		}
		if node.is_html_olist_element() || editing_is_ancestor_of_type(node, editing_is_ol) {
			none_is_an_ol = false
			break
		}
	}
	if all_is_a_ul && none_is_an_ol {
		return .ul
	}

	// 8. If some member of node list is either an ol or the child or ancestor of an ol or the child of an li child of
	//    an ol, and some member of node list is either a ul or the child or ancestor of a ul or the child of an li
	//    child of a ul, return "mixed".
	mut any_is_ol := false
	mut any_is_ul := false
	for node in node_list {
		if editing_is_type_or_child_of_list_type(node, editing_is_ol)
			|| editing_is_ancestor_of_type(node, editing_is_ol) {
			any_is_ol = true
		}
		if editing_is_type_or_child_of_list_type(node, editing_is_ul)
			|| editing_is_ancestor_of_type(node, editing_is_ul) {
			any_is_ul = true
		}
		if any_is_ol && any_is_ul {
			break
		}
	}
	if any_is_ol && any_is_ul {
		return .mixed
	}

	// 9. If some member of node list is either an ol or the child or ancestor of an ol or the child of an li child of
	//    an ol, return "mixed ol".
	if any_is_ol {
		return .mixed_ol
	}

	// 10. If some member of node list is either a ul or the child or ancestor of a ul or the child of an li child of a
	//     ul, return "mixed ul".
	if any_is_ul {
		return .mixed_ul
	}

	// 11. Return "none".
	return .none
}

fn editing_is_ancestor_of_type(node &dom.Node, predicate fn (&dom.Node) bool) bool {
	mut current := node.next_in_pre_order(node)
	for {
		descendant := current or { break }
		if predicate(descendant) {
			return true
		}
		current = descendant.next_in_pre_order(node)
	}
	return false
}

fn editing_is_type_or_child_of_list_type(node &dom.Node, predicate fn (&dom.Node) bool) bool {
	if predicate(node) {
		return true
	}
	parent := node.parent() or { return false }
	if predicate(parent) {
		return true
	}
	if parent.is_html_li_element() {
		if grandparent := parent.parent() {
			return predicate(grandparent)
		}
	}
	return false
}

fn editing_is_html_element_with_local_name(node ?&dom.Node, tag_name string) bool {
	current := node or { return false }
	name := editing_html_local_name(current) or { return false }
	return name == tag_name
}

// https://w3c.github.io/editing/docs/execCommand/#toggle-lists
pub fn toggle_lists(document &dom.Document, tag_name string) {
	// 1. Let mode be "disable" if the selection's list state is tag name, and "enable" otherwise.
	list_state := selections_list_state(document)
	enable := !((list_state == .ol && tag_name == 'ol') || (list_state == .ul && tag_name == 'ul'))

	// 2. Let other tag name be "ol" if tag name is "ul", and "ul" if tag name is "ol".
	other_tag_name := if tag_name == 'ul' { 'ol' } else { 'ul' }

	// 3. Let items be a list of all lis that are inclusive ancestors of the active range's start and/or end node.
	range_ := active_range(document) or { return }
	mut items := []&dom.Node{}
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

	// 4. For each item in items, normalize sublists of item.
	for item in items {
		normalize_sublists_in_node(item)
	}

	// 5. Block-extend the active range, and let new range be the result.
	new_range := block_extend_a_range(active_range(document) or { return })

	// 6. If mode is "enable", then let lists to convert consist of every editable HTML element with local name other
	//    tag name that is contained in new range, and for every list in lists to convert:
	if enable {
		mut lists_to_convert := []&dom.Node{}
		for node in new_range.contained_nodes() {
			if node.is_editable() && editing_is_html_element_with_local_name(node, other_tag_name) {
				lists_to_convert << node
			}
		}
		for list in lists_to_convert {
			// 1. If list's previousSibling or nextSibling is an editable HTML element with local name tag name:
			previous_matches := if previous_sibling := list.previous_sibling() {
				previous_sibling.is_editable()
					&& editing_is_html_element_with_local_name(previous_sibling, tag_name)
			} else {
				false
			}
			next_matches := if next_sibling := list.next_sibling() {
				next_sibling.is_editable() && editing_is_html_element_with_local_name(next_sibling, tag_name)
			} else {
				false
			}
			if previous_matches || next_matches {
				// 1. Let children be list's children.
				children := list.children_as_vector()

				// 2. Record the values of children, and let values be the result.
				values := record_the_values_of_nodes(children)

				// 3. Split the parent of children.
				split_the_parent_of_nodes(children)

				// 4. Wrap children, with sibling criteria returning true for an HTML element with local name tag name and
				//    false otherwise.
				wrap(children, fn [tag_name] (sibling &dom.Node) bool {
					return editing_is_html_element_with_local_name(sibling, tag_name)
				}, no_new_parent_instructions)

				// 5. Restore the values from values.
				restore_the_values_of_nodes(values)
			}

			// 2. Otherwise, set the tag name of list to tag name.
			else {
				if list_element := list.as_element() {
					set_the_tag_name(list_element, tag_name)
				}
			}
		}
	}

	// 7. Let node list be a list of nodes, initially empty.
	mut node_list := []&dom.Node{}

	// 8. For each node node contained in new range, if node is editable; the last member of node list (if any) is not
	//    an ancestor of node; node is not an indentation element; and either node is an ol or ul, or its parent is an
	//    ol or ul, or it is an allowed child of "li"; then append node to node list.
	for node in new_range.contained_nodes() {
		if node.is_editable() && (node_list.len == 0 || !node_list.last().is_ancestor_of(node))
			&& !is_indentation_element(node) && (editing_is_ol_or_ul(node)
			|| editing_optional_node_is(node.parent(), editing_is_ol_or_ul)
			|| is_allowed_child_of_node(allowed_child_node(node), allowed_child_name('li'))) {
			node_list << node
		}
	}

	// 9. If mode is "enable", remove from node list any ol or ul whose parent is not also an ol or ul.
	if enable {
		node_list = node_list.filter(!((it.is_html_olist_element()
			&& !editing_optional_node_is(it.parent(), editing_is_ol))
			|| (it.is_html_ulist_element() && !editing_optional_node_is(it.parent(), editing_is_ul))))
	}

	// 10. If mode is "disable", then while node list is not empty:
	if !enable {
		for node_list.len > 0 {
			// 1. Let sublist be an empty list of nodes.
			// 2. Remove the first member from node list and append it to sublist.
			mut sublist := [node_list[0]]
			node_list.delete(0)

			// 3. If the first member of sublist is an HTML element with local name tag name, outdent it and continue this
			//    loop from the beginning.
			if editing_is_html_element_with_local_name(sublist[0], tag_name) {
				outdent(sublist[0])
				continue
			}

			// 4. While node list is not empty, and the first member of node list is the nextSibling of the last member of
			//    sublist and is not an HTML element with local name tag name, remove the first member from node list and
			//    append it to sublist.
			for node_list.len > 0 && editing_same_node(node_list[0], sublist.last().next_sibling())
				&& !editing_is_html_element_with_local_name(node_list[0], tag_name) {
				sublist << node_list[0]
				node_list.delete(0)
			}

			// 5. Record the values of sublist, and let values be the result.
			values := record_the_values_of_nodes(sublist)

			// 6. Split the parent of sublist.
			split_the_parent_of_nodes(sublist)

			// 7. Fix disallowed ancestors of each member of sublist.
			for member in sublist {
				fix_disallowed_ancestors_of_node(member)
			}

			// 8. Restore the values from values.
			restore_the_values_of_nodes(values)
		}
		return
	}

	// 11. Otherwise, while node list is not empty:
	for node_list.len > 0 {
		// 1. Let sublist be an empty list of nodes.
		mut sublist := []&dom.Node{}

		// 2. While either sublist is empty, or node list is not empty and its first member is the nextSibling of
		//    sublist's last member:
		// AD-HOC: This condition needs to be a bit different from what the spec describes, because node_list and
		//         sublist can both be empty at the same time: https://github.com/w3c/editing/issues/521
		for node_list.len > 0
			&& (sublist.len == 0 || editing_same_node(node_list[0], sublist.last().next_sibling())) {
			first := node_list[0]

			// 1. If node list's first member is a p or div, set the tag name of node list's first member to "li",
			//    and append the result to sublist. Remove the first member from node list.
			if is_html_element_named(first, ['p', 'div']) {
				first_element := first.as_element() or { break }
				sublist << set_the_tag_name(first_element, 'li').as_node()
				node_list.delete(0)
			}

			// 2. Otherwise, if the first member of node list is an li or ol or ul, remove it from node list and
			//    append it to sublist.
			else if first.is_element() && (first.is_html_li_element() || editing_is_ol_or_ul(first)) {
				sublist << first
				node_list.delete(0)
			}

			// 3. Otherwise:
			else {
				// 1. Let nodes to wrap be a list of nodes, initially empty.
				mut nodes_to_wrap := []&dom.Node{}

				// 2. While nodes to wrap is empty, or node list is not empty and its first member is the
				//    nextSibling of nodes to wrap's last member and the first member of node list is an inline node
				//    and the last member of nodes to wrap is an inline node other than a br, remove the first
				//    member from node list and append it to nodes to wrap.
				for nodes_to_wrap.len == 0 || (node_list.len > 0
					&& editing_same_node(node_list[0], nodes_to_wrap.last().next_sibling())
					&& is_inline_node(node_list[0]) && is_inline_node(nodes_to_wrap.last())
					&& !nodes_to_wrap.last().is_html_br_element()) {
					if node_list.len == 0 {
						break
					}
					nodes_to_wrap << node_list[0]
					node_list.delete(0)
				}

				// 3. Wrap nodes to wrap, with new parent instructions returning the result of calling
				//    createElement("li") on the context object. Append the result to sublist.
				if result := wrap(nodes_to_wrap, no_sibling_criteria, fn [document] () ?&dom.Node {
					return editing_create_html_element(document, 'li').as_node()
				})
				{
					sublist << result
				}
			}
		}

		// 3. If sublist's first member's parent is an HTML element with local name tag name, or if every member of
		//    sublist is an ol or ul, continue this loop from the beginning.
		if sublist.len > 0 && editing_is_html_element_with_local_name(sublist[0].parent(), tag_name) {
			continue
		}
		if sublist.all(editing_is_ol_or_ul(it)) {
			continue
		}

		// 4. If sublist's first member's parent is an HTML element with local name other tag name:
		if sublist.len > 0 && editing_is_html_element_with_local_name(sublist[0].parent(), other_tag_name) {
			// 1. Record the values of sublist, and let values be the result.
			values := record_the_values_of_nodes(sublist)

			// 2. Split the parent of sublist.
			split_the_parent_of_nodes(sublist)

			// 3. Wrap sublist, with sibling criteria returning true for an HTML element with local name tag name
			//    and false otherwise, and new parent instructions returning the result of calling
			//    createElement(tag name) on the context object.
			wrap(sublist, fn [tag_name] (sibling &dom.Node) bool {
				return editing_is_html_element_with_local_name(sibling, tag_name)
			}, fn [document, tag_name] () ?&dom.Node {
				return editing_create_html_element(document, tag_name).as_node()
			})

			// 4. Restore the values from values.
			restore_the_values_of_nodes(values)

			// 5. Continue this loop from the beginning.
			continue
		}

		// 5. Wrap sublist, with sibling criteria returning true for an HTML element with local name tag name and
		//    false otherwise, and new parent instructions being the following:
		first_member := sublist[0]
		result := wrap(sublist, fn [tag_name] (sibling &dom.Node) bool {
			return editing_is_html_element_with_local_name(sibling, tag_name)
		}, fn [document, tag_name, first_member] () ?&dom.Node {
			// 1. If sublist's first member's parent is not an editable simple indentation element, or sublist's
			//    first member's parent's previousSibling is not an editable HTML element with local name tag name,
			//    call createElement(tag name) on the context object and return the result.
			first_parent := first_member.parent() or {
				return editing_create_html_element(document, tag_name).as_node()
			}
			if !first_parent.is_editable() || !is_simple_indentation_element(first_parent)
				|| !editing_is_html_element_with_local_name(first_parent.previous_sibling(), tag_name) {
				return editing_create_html_element(document, tag_name).as_node()
			}

			// 2. Let list be sublist's first member's parent's previousSibling.
			list := first_parent.previous_sibling() or {
				return editing_create_html_element(document, tag_name).as_node()
			}

			// 3. Normalize sublists of list's lastChild.
			if last_child := list.last_child() {
				normalize_sublists_in_node(last_child)
			}

			// 4. If list's lastChild is not an editable HTML element with local name tag name, call
			//    createElement(tag name) on the context object, and append the result as the last child of list.
			last_child_matches := if last_child := list.last_child() {
				last_child.is_editable() && editing_is_html_element_with_local_name(last_child, tag_name)
			} else {
				false
			}
			if !last_child_matches {
				append_node(editing_create_html_element(document, tag_name).as_node(), list) or {
					panic(err)
				}
			}

			// 5. Return the last child of list.
			return list.last_child()
		})

		// 6. Fix disallowed ancestors of the previous step's result.
		if wrapped := result {
			fix_disallowed_ancestors_of_node(wrapped)
		}
	}
}

// https://w3c.github.io/editing/docs/execCommand/#autolink
pub fn autolink(boundary_point dom.BoundaryPoint) {
	// 1. While (node, end offset)'s previous equivalent point is not null, set it to its previous equivalent point.
	point := first_equivalent_point(boundary_point)

	// 2. If node is not a Text node, or has an a ancestor, do nothing and abort these steps.
	if !point.node.is_text() {
		return
	}
	mut ancestor := point.node.parent()
	for {
		current := ancestor or { break }
		if current.is_html_anchor_element() {
			return
		}
		ancestor = current.parent()
	}

	// FIXME: 3. Let search be the largest substring of node's data whose end is end offset and that contains no space
	//    characters.

	// FIXME: 4. If some substring of search is an autolinkable URL:
	// FIXME: 5. Otherwise, if some substring of search is a valid e-mail address:

	// 6. Otherwise, do nothing and abort these steps.
	// NOTE: Upstream leaves steps 3 through 5 unimplemented, so no URL or e-mail address is ever autolinkable and the
	//       remaining steps (7 through 10) are unreachable.
}
