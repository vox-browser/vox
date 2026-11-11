// Copyright (c) 2026-present, the Ladybird developers
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Editing/StyledMarkupAccumulator.{h,cpp}.
module editing

import dom

pub struct SerializedText {
pub:
	source     &dom.Text
	serialized &dom.Text
}

enum SelectionCoverage {
	partial
	full
}

// Builds the structural clipboard fragment by traversing the selected source subtrees. Keeping this distinct from DOM
// Range cloning gives styled serialization one place to decide which selection-edge ancestors carry structure or
// presentation and to associate emitted content with its source as those policies are applied.
@[heap]
pub struct StyledMarkupAccumulator {
	range_ &dom.Range
	fragment_ &dom.DocumentFragment
mut:
	serialized_text_ []SerializedText
}

fn should_serialize_node(node &dom.Node) bool {
	if node.layout_node() != none {
		return true
	}

	if is_ascii_whitespace_text(node) {
		parent := node.parent_element() or { return false }
		return should_serialize_node(parent.as_node())
	}

	element := node.as_element() or { return false }
	computed := element.el_computed_properties() or { return false }
	return computed.display().is_contents()
}

pub fn StyledMarkupAccumulator.new(selection &StyledMarkupSelection) &StyledMarkupAccumulator {
	range_ := selection.serialization_range()
	mut accumulator := &StyledMarkupAccumulator{
		range_: range_
		fragment_: range_.start_container().document().create_document_fragment()
	}

	common_ancestor := range_.common_ancestor_container()
	if common_ancestor.is_character_data() {
		accumulator.append_selected_node(common_ancestor, accumulator.fragment_.as_node(), .partial)
		return accumulator
	}

	for child in common_ancestor.children_as_vector() {
		if !accumulator.participates_in_selection(child) {
			continue
		}
		coverage := if range_.contains_node(child) {
			SelectionCoverage.full
		} else {
			SelectionCoverage.partial
		}
		accumulator.append_selected_node(child, accumulator.fragment_.as_node(), coverage)
	}
	return accumulator
}

pub fn (accumulator &StyledMarkupAccumulator) fragment() &dom.DocumentFragment {
	return accumulator.fragment_
}

pub fn (accumulator &StyledMarkupAccumulator) serialized_text() []SerializedText {
	return accumulator.serialized_text_
}

fn (accumulator &StyledMarkupAccumulator) participates_in_selection(node &dom.Node) bool {
	return accumulator.range_.contains_node(node)
		|| node.is_inclusive_ancestor_of(accumulator.range_.start_container())
		|| node.is_inclusive_ancestor_of(accumulator.range_.end_container())
}

fn (mut accumulator StyledMarkupAccumulator) append_selected_node(source &dom.Node, destination_parent &dom.Node, coverage SelectionCoverage) bool {
	range_ := accumulator.range_
	// INTEROP: Blink and WebKit traverse the rendered tree when producing clipboard markup. Skip an unrendered node
	//          and its entire subtree so display:none content cannot enter the clipboard. A display:contents element
	//          is the exception: it has no layout node of its own, but both engines retain it around rendered children.
	if !should_serialize_node(source) {
		return false
	}

	// INTEROP: Blink and WebKit treat a trailing br as a block's caret placeholder when the selection ends
	//          immediately after its containing branch. It does not enter the serialized markup, while the same
	//          break in an earlier fully selected block remains part of that block's paragraph structure.
	if source.is_html_br_element() && source.previous_sibling() != none {
		if parent := source.parent() {
			if editing_same_node(parent.last_child(), source) {
				mut selected_branch := unsafe { source }
				for {
					branch_parent := selected_branch.parent() or { break }
					if branch_parent == range_.end_container() {
						break
					}
					if !editing_same_node(branch_parent.last_child(), selected_branch) {
						break
					}
					selected_branch = branch_parent
				}
				if branch_parent := selected_branch.parent() {
					if branch_parent == range_.end_container()
						&& range_.end_offset() == selected_branch.index() + 1 {
						return false
					}
				}
			}
		}
	}

	fully_selected := coverage == .full
	clone := source.clone_node(none, false, none) or { panic(err) }
	mut mutable_destination_parent := unsafe { &dom.Node(destination_parent) }
	mutable_destination_parent.append_child(clone) or { panic(err) }

	if source_character_data := source.as_character_data() {
		mut start_offset := if source == range_.start_container() { range_.start_offset() } else { 0 }
		mut end_offset := if source == range_.end_container() {
			range_.end_offset()
		} else {
			source.length()
		}
		if fully_selected {
			start_offset = 0
			end_offset = source.length()
		}
		data := source_character_data.substring_data(start_offset, end_offset - start_offset) or {
			panic(err)
		}
		emitted_content := data != ''
		mut clone_character_data := clone.as_character_data() or { panic('clone is not CharacterData') }
		clone_character_data.set_data(data)
		if source.is_text() {
			accumulator.serialized_text_ << SerializedText{
				source: unsafe { &dom.Text(source) }
				serialized: unsafe { &dom.Text(clone) }
			}
		}
		return emitted_content
	}

	mut emitted_content := false
	for child in source.children_as_vector() {
		if !fully_selected && !accumulator.participates_in_selection(child) {
			continue
		}
		child_coverage := if fully_selected || range_.contains_node(child) {
			SelectionCoverage.full
		} else {
			SelectionCoverage.partial
		}
		if accumulator.append_selected_node(child, clone, child_coverage) {
			emitted_content = true
		}
	}

	element := source.as_element()
	is_atomic_content := if source_element := element { source_element.is_void_element() } else { false }
	// INTEROP: Blink and WebKit open ancestors while traversing selected nodes, so an inline ancestor reached only
	//          through a zero-length range edge never enters the output. Empty blocks and atomic elements still carry
	//          paragraph structure or content and must remain serializable.
	// INTEROP: A range ending at offset zero in a text node reaches its div only as traversal ancestry. Blink and
	//          WebKit do not emit that empty transport wrapper. A rendered empty paragraph has its placeholder br
	//          inside StyledMarkupSelection's range and therefore has emitted content by the time we get here.
	is_unselected_trailing_wrapper := source.is_inclusive_ancestor_of(range_.end_container())
		&& !source.is_inclusive_ancestor_of(range_.start_container())
		&& range_.end_container().is_character_data()
		&& if source_element := element { source_element.local_name() == 'div' } else { false }
	if coverage == .partial && element != none && !is_atomic_content && !emitted_content
		&& (is_unselected_trailing_wrapper || !is_prohibited_paragraph_child(source)) {
		mut mutable_clone := unsafe { &dom.Node(clone) }
		mutable_clone.remove(false)
		return false
	}
	return emitted_content || is_atomic_content || is_prohibited_paragraph_child(source)
}

fn optional_element(node ?&dom.Node) ?&dom.Element {
	found := node or { return none }
	return found.as_element()
}

fn is_interchange_newline(node &dom.Node) bool {
	if !node.is_html_br_element() {
		return false
	}
	element := node.as_element() or { return false }
	return element.has_class('Apple-interchange-newline')
}

fn is_list_transport_sibling(node &dom.Node) bool {
	if node.is_text() {
		return unsafe { &dom.Text(node) }.data().runes().all(is_ascii_space_character(it))
	}
	if is_interchange_newline(node) {
		return true
	}
	if !node.is_element() || node.child_count() != 1 {
		return false
	}
	first_child := node.first_child() or { return false }
	return first_child.is_html_br_element()
}

fn single_list_transport_wrapper(fragment &dom.DocumentFragment) ?&dom.Element {
	mut list := ?&dom.Element(none)
	for child in fragment.as_node().children_as_vector() {
		if element := child.as_element() {
			if element.local_name() in ['ul', 'ol'] {
				if list != none {
					return none
				}
				list = element
				continue
			}
		}
		if !is_list_transport_sibling(child) {
			return none
		}
	}
	return list
}

pub fn (accumulator &StyledMarkupAccumulator) remove_partial_block_transport_wrapper() {
	range_ := accumulator.range_
	mut fragment_node := unsafe { &dom.Node(accumulator.fragment_.as_node()) }
	first_child := fragment_node.first_child()
	mut block := optional_element(first_child)
	if child := first_child {
		if is_interchange_newline(child) {
			block = optional_element(child.next_sibling())
		}
	}
	document := range_.start_container().document()
	visible_start := VisiblePosition.create(document, range_.start())
	visible_end := VisiblePosition.create(document, range_.end())
	if block_element := block {
		if block_element.local_name() == 'div' {
			block_node := block_element.as_node()
			// INTEROP: A leading interchange newline is selected boundary content, so the following div is not a lone
			//          transport wrapper. This differs from list serialization, where boundary markers may surround the
			//          single structural list wrapper without becoming part of it.
			if !editing_same_node(fragment_node.first_child(), block_node)
				|| !editing_same_node(fragment_node.last_child(), block_node) {
				return
			}
			if visible_start.is_start_of_containing_block() && visible_end.is_end_of_containing_block() {
				return
			}

			mut source_block := ?&dom.Node(range_.end_container())
			for source_block != none {
				current := source_block or { break }
				if element := current.as_element() {
					if element.local_name() == 'div' {
						break
					}
				}
				source_block = current.parent()
			}
			if found_source_block := source_block {
				start_container := range_.start_container()
				if start_container.is_text() {
					start_text := unsafe { &dom.Text(start_container) }
					if next_sibling := start_container.next_sibling() {
						if next_sibling == found_source_block
							&& start_text.data().runes().all(is_ascii_space_character(it)) {
							// INTEROP: Formatting whitespace before a partially selected block is not serialized, but the range still
							//          crosses into that block. Keep its transport wrapper so replacement retains the paragraph seam.
							return
						}
					}
				}
			}

			// INTEROP: Blink and WebKit traverse selected nodes and wrap only ancestors which carry required structure or
			//          formatting. A lone partial div is transport structure rather than selected content, so flatten it.
			for block_node.first_child() != none {
				child := block_node.first_child() or { break }
				fragment_node.insert_before(child, block_node, false)
			}
			mut mutable_block := unsafe { &dom.Node(block_node) }
			mutable_block.remove(false)
			return
		}
	}

	list := single_list_transport_wrapper(accumulator.fragment_) or { return }
	list_node := list.as_node()
	if list_node.child_count() != 1 {
		return
	}
	list_item := list_node.first_child() or { return }
	if !list_item.is_html_li_element() {
		return
	}

	mut source_list_item := ?&dom.Node(range_.end_container())
	for source_list_item != none {
		current := source_list_item or { break }
		if current.is_html_li_element() {
			break
		}
		source_list_item = current.parent()
	}
	found_source_list_item := source_list_item or { return }
	if found_source_list_item.is_inclusive_ancestor_of(range_.start_container())
		|| visible_end.is_end_of_containing_block() {
		return
	}

	// INTEROP: A range entering a list and ending inside its first selected item contains only an inline prefix of
	//          that paragraph. Blink and WebKit do not retain the list ancestors reached through the range edge.
	for list_item.first_child() != none {
		child := list_item.first_child() or { break }
		fragment_node.insert_before(child, list_node, false)
	}
	mut mutable_list := unsafe { &dom.Node(list_node) }
	mutable_list.remove(false)
}
