// Copyright (c) 2026-present, the Ladybird developers
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the DOM-facing allowed-child and fix-disallowed-ancestors
// algorithms in Editing/Internal/Algorithms.cpp.
module editing

import dom

fn dom_html_local_name(node &dom.Node) ?string {
	element := node.as_element() or { return none }
	if !element.is_html_element() {
		return none
	}
	return element.local_name().to_lower()
}

fn dom_node_has_heading_name(node &dom.Node) bool {
	name := dom_html_local_name(node) or { return false }
	return is_heading(name)
}

fn dom_node_has_inline_contents(node &dom.Node) bool {
	name := dom_html_local_name(node) or { return false }
	return is_name_of_an_element_with_inline_contents(name)
}

fn dom_node_is_prohibited_paragraph_child(node &dom.Node) bool {
	name := dom_html_local_name(node) or { return false }
	return is_prohibited_paragraph_child_name(name)
}

fn dom_ancestor_has_html_name(node &dom.Node, name string) bool {
	for ancestor := ?&dom.Node(node); ancestor != none;  {
		current := ancestor or { break }
		if dom_html_local_name(current) or { '' } == name {
			return true
		}
		ancestor = current.parent()
	}
	return false
}

fn dom_ancestor_has_heading(node &dom.Node) bool {
	for ancestor := ?&dom.Node(node); ancestor != none;  {
		current := ancestor or { break }
		if dom_node_has_heading_name(current) {
			return true
		}
		ancestor = current.parent()
	}
	return false
}

fn dom_ancestor_has_inline_contents(node &dom.Node) bool {
	for ancestor := ?&dom.Node(node); ancestor != none;  {
		current := ancestor or { break }
		if dom_node_has_inline_contents(current) {
			return true
		}
		ancestor = current.parent()
	}
	return false
}

fn allowed_html_child_name(child_name_ string, parent_name_ string) bool {
	child_name := child_name_.to_lower()
	parent_name := parent_name_.to_lower()
	if parent_name == 'colgroup' {
		return child_name == 'col'
	}
	if parent_name == 'table' {
		return child_name in ['caption', 'col', 'colgroup', 'tbody', 'td', 'tfoot', 'th', 'thead',
			'tr']
	}
	if parent_name in ['tbody', 'tfoot', 'thead'] {
		return child_name in ['td', 'th', 'tr']
	}
	if parent_name == 'tr' {
		return child_name in ['td', 'th']
	}
	if parent_name == 'dl' {
		return child_name in ['dt', 'dd']
	}
	if parent_name in ['dir', 'ol', 'ul'] {
		return child_name in ['dir', 'li', 'ol', 'ul']
	}
	if parent_name == 'hgroup' {
		return is_heading(child_name)
	}
	if child_name in ['body', 'caption', 'col', 'colgroup', 'frame', 'frameset', 'head', 'html',
		'tbody', 'td', 'tfoot', 'th', 'thead', 'tr'] {
		return false
	}
	if child_name in ['dd', 'dt'] && parent_name != 'dl' {
		return false
	}
	if child_name == 'li' && parent_name !in ['ol', 'ul'] {
		return false
	}
	if parent_name == 'a' && child_name == 'a' {
		return false
	}
	if parent_name in ['dd', 'dt'] && child_name in ['dd', 'dt'] {
		return false
	}
	if is_heading(parent_name) && is_heading(child_name) {
		return false
	}
	if parent_name == 'li' && child_name == 'li' {
		return false
	}
	if parent_name == 'nobr' && child_name == 'nobr' {
		return false
	}
	if is_name_of_an_element_with_inline_contents(parent_name)
		&& is_prohibited_paragraph_child_name(child_name) {
		return false
	}
	if parent_name in ['td', 'th']
		&& child_name in ['caption', 'col', 'colgroup', 'tbody', 'td', 'tfoot', 'th', 'thead', 'tr'] {
		return false
	}
	return true
}

fn is_allowed_child_name_of_dom_node(child_name_ string, parent &dom.Node) bool {
	child_name := child_name_.to_lower()
	parent_element := parent.as_element() or {
		return parent.is_document_fragment()
	}
	if !parent_element.is_html_element() {
		return true
	}
	if child_name == 'a' && dom_ancestor_has_html_name(parent, 'a') {
		return false
	}
	if is_prohibited_paragraph_child_name(child_name)
		&& dom_ancestor_has_inline_contents(parent) {
		return false
	}
	if is_heading(child_name) && dom_ancestor_has_heading(parent) {
		return false
	}
	return allowed_html_child_name(child_name, parent_element.local_name())
}

// https://w3c.github.io/editing/docs/execCommand/#allowed-child
pub fn is_allowed_child_of_dom_node(child &dom.Node, parent &dom.Node) bool {
	if parent_name := dom_html_local_name(parent) {
		if parent_name in ['colgroup', 'table', 'tbody', 'tfoot', 'thead', 'tr']
			&& child.is_text() {
			text := unsafe { &dom.Text(child) }
			if !text.data().runes().all(is_ascii_space_character(it)) {
				return false
			}
		}
		if parent_name in ['script', 'style', 'plaintext', 'xmp'] && !child.is_text() {
			return false
		}
	}
	if child.is_document() || child.is_document_fragment() || child.is_document_type() {
		return false
	}
	child_name := dom_html_local_name(child) or {
		return parent.as_element() != none || parent.is_document_fragment()
	}
	return is_allowed_child_name_of_dom_node(child_name, parent)
}

fn same_dom_editing_host(first &dom.Node, second &dom.Node) bool {
	first_host := first.editing_host() or { return false }
	second_host := second.editing_host() or { return false }
	return first_host == second_host
}

fn set_dom_tag_name(node &dom.Node, new_name string) &dom.Node {
	element := node.as_element() or { return node }
	if element.is_html_element() && element.local_name() == new_name {
		return node
	}
	parent := node.parent() or { return node }
	replacement_element := node.document().create_element(new_name) or { return node }
	mut mutable_parent := unsafe { &dom.Node(parent) }
	mutable_parent.insert_before(replacement_element.as_node(), node, false)
	mut mutable_replacement := unsafe { &dom.Element(replacement_element) }
	for attribute_name in element.get_attribute_names() {
		mutable_replacement.set_attribute_value(attribute_name, element.get_attribute_value(attribute_name))
	}
	for node.first_child() != none {
		child := node.first_child() or { break }
		move_node_preserving_ranges(child, replacement_element.as_node(), replacement_element.as_node().child_count())
	}
	mut mutable_node := unsafe { &dom.Node(node) }
	mutable_node.remove(false)
	return replacement_element.as_node()
}

fn unadorned_definition_list(node &dom.Node) bool {
	element := node.as_element() or { return false }
	return element.is_html_element() && element.local_name() == 'dl' && !element.has_attributes()
}

fn wrap_dom_definition_item(node &dom.Node) {
	parent := node.parent() or { return }
	if previous := node.previous_sibling() {
		if unadorned_definition_list(previous) {
			move_node_preserving_ranges(node, previous, previous.child_count())
			return
		}
	}
	if next := node.next_sibling() {
		if unadorned_definition_list(next) {
			move_node_preserving_ranges(node, next, 0)
			return
		}
	}
	dl := node.document().create_element('dl') or { return }
	mut mutable_parent := unsafe { &dom.Node(parent) }
	mutable_parent.insert_before(dl.as_node(), node, false)
	move_node_preserving_ranges(node, dl.as_node(), 0)
}

// Split a single child out of an editable wrapper while retaining the wrappers
// on both sides of it. This is the one-node form used by fix-disallowed-ancestors.
fn split_dom_parent_of_node(node &dom.Node) bool {
	parent := node.parent() or { return false }
	grandparent := parent.parent() or { return false }
	if !parent.is_editable() {
		return false
	}
	was_first := parent.first_child() or { return false } == node
	was_last := parent.last_child() or { return false } == node
	if !was_first && !was_last {
		cloned_parent := parent.clone_node(none, false, none) or { return false }
		if parent_element := parent.as_element() {
			if parent_element.has_attribute('id') {
				mut mutable_parent_element := unsafe { &dom.Element(parent_element) }
				mutable_parent_element.remove_attribute('id')
			}
		}
		mut mutable_grandparent := unsafe { &dom.Node(grandparent) }
		mutable_grandparent.insert_before(cloned_parent, parent, false)
		for node.previous_sibling() != none {
			first_child := parent.first_child() or { break }
			move_node_preserving_ranges(first_child, cloned_parent, cloned_parent.child_count())
		}
	}
	insertion_index := if was_last && !was_first { parent.index() + 1 } else { parent.index() }
	move_node_preserving_ranges(node, grandparent, insertion_index)
	if parent.child_count() == 0 {
		mut mutable_parent := unsafe { &dom.Node(parent) }
		mutable_parent.remove(false)
	}
	return true
}

// https://w3c.github.io/editing/docs/execCommand/#fix-disallowed-ancestors
pub fn fix_disallowed_ancestors_of_dom_node(node_ &dom.Node) {
	if !node_.is_editable() {
		return
	}
	mut allowed_child_of_any_ancestor := false
	for ancestor := node_.parent(); ancestor != none;  {
		current := ancestor or { break }
		if same_dom_editing_host(current, node_)
			&& is_allowed_child_of_dom_node(node_, current) {
			allowed_child_of_any_ancestor = true
			break
		}
		ancestor = current.parent()
	}
	if !allowed_child_of_any_ancestor {
		if name := dom_html_local_name(node_) {
			if name in ['dd', 'dt'] {
				wrap_dom_definition_item(node_)
				return
			}
		}
		host := node_.editing_host() or { return }
		if !is_allowed_child_name_of_dom_node('p', host)
			|| !dom_node_is_prohibited_paragraph_child(node_) {
			return
		}
		replacement := set_dom_tag_name(node_, node_.document().get_default_single_line_container_name())
		fix_disallowed_ancestors_of_dom_node(replacement)
		for child in replacement.children_as_vector() {
			if dom_node_is_prohibited_paragraph_child(child) {
				split_dom_parent_of_node(child)
			}
		}
		return
	}

	mut node := node_
	for {
		parent := node.parent() or { break }
		if is_allowed_child_of_dom_node(node, parent) {
			break
		}
		if !split_dom_parent_of_node(node) {
			break
		}
	}
}

fn collect_dom_descendants(node &dom.Node, mut descendants []&dom.Node) {
	for child in node.children_as_vector() {
		descendants << child
		collect_dom_descendants(child, mut descendants)
	}
}
