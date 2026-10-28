// Copyright (c) 2026-present, the Ladybird developers
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Editing/EditCommand.{h,cpp}. An EditCommand retains every
// node needed to reverse one primitive editing mutation and revalidates the
// live DOM before replaying it.
module editing

import dom

pub enum EditCommandKind {
	insert_node
	remove_node
	replace_data
	split_text
	set_attribute
}

@[heap]
pub struct EditCommand {
pub:
	kind EditCommandKind
mut:
	node_                               &dom.Node = unsafe { nil }
	parent_                             ?&dom.Node
	reference_child_                    ?&dom.Node
	new_text_node_                      ?&dom.Text
	offset_                             int
	removed_data_                       string
	inserted_data_                      string
	local_name_                         string
	namespace_                          ?string
	old_value_                          ?string
	new_value_                          ?string
	text_control_                       &dom.InputEventsTarget = unsafe { nil }
	lasting_removal_closes_coalescence_ bool
}

pub fn new_insert_node_command(node &dom.Node, parent &dom.Node, reference_child ?&dom.Node) &EditCommand {
	return &EditCommand{
		kind: .insert_node
		node_: node
		parent_: parent
		reference_child_: reference_child
	}
}

pub fn new_remove_node_command(node &dom.Node) &EditCommand {
	return &EditCommand{
		kind: .remove_node
		node_: node
		parent_: node.parent()
		reference_child_: node.next_sibling()
		lasting_removal_closes_coalescence_: true
	}
}

pub fn new_replace_data_command(node &dom.CharacterData, offset int, removed_data string, inserted_data string) &EditCommand {
	text_control := node.as_node().document().form_control_input_events_target(node.as_node()) or {
		unsafe { &dom.InputEventsTarget(nil) }
	}
	return &EditCommand{
		kind: .replace_data
		node_: node.as_node()
		offset_: offset
		removed_data_: removed_data
		inserted_data_: inserted_data
		text_control_: text_control
	}
}

pub fn new_split_text_command(node &dom.Text, offset int) &EditCommand {
	return &EditCommand{
		kind: .split_text
		node_: node.as_node()
		offset_: offset
	}
}

pub fn new_set_attribute_command(element &dom.Element, local_name string, namespace_ ?string, old_value ?string, new_value ?string) &EditCommand {
	return &EditCommand{
		kind: .set_attribute
		node_: element.as_node()
		local_name_: local_name
		namespace_: namespace_
		old_value_: old_value
		new_value_: new_value
	}
}

fn (command &EditCommand) parent() ?&dom.Node {
	return command.parent_
}

fn (command &EditCommand) reference_child() &dom.Node {
	return command.reference_child_ or { unsafe { nil } }
}

fn (command &EditCommand) character_data() ?&dom.CharacterData {
	return command.node_.as_character_data()
}

fn (command &EditCommand) text() ?&dom.Text {
	if !command.node_.is_text() {
		return none
	}
	return unsafe { &dom.Text(command.node_) }
}

fn (command &EditCommand) element() ?&dom.Element {
	return command.node_.as_element()
}

fn edit_command_utf16_length(value string) int {
	mut length := 0
	for character in value.runes() {
		length += if character > rune(0xffff) { 2 } else { 1 }
	}
	return length
}

fn (command &EditCommand) set_or_remove_attribute(value ?string) {
	element := command.element() or { return }
	mut mutable_element := unsafe { &dom.Element(element) }
	if actual := value {
		mutable_element.set_attribute_value_ns(command.local_name_, actual, none, command.namespace_)
	} else if namespace_ := command.namespace_ {
		mutable_element.remove_attribute_ns(namespace_, command.local_name_)
	} else {
		mutable_element.remove_attribute(command.local_name_)
	}
}

// Apply the command for the first time. SplitTextCommand exposes the created
// Text through split_text_result() after this succeeds.
pub fn (mut command EditCommand) apply() ! {
	match command.kind {
		.insert_node {
			parent := command.parent() or { return }
			mut mutable_parent := unsafe { &dom.Node(parent) }
			mutable_parent.insert_before(command.node_, command.reference_child_, false)
		}
		.remove_node {
			if command.node_.parent() != none {
				mut mutable_node := unsafe { &dom.Node(command.node_) }
				mutable_node.remove(false)
			}
		}
		.replace_data {
			character_data := command.character_data() or {
				return error('replace-data command lost its CharacterData node')
			}
			mut mutable_data := unsafe { &dom.CharacterData(character_data) }
			mutable_data.replace_data(command.offset_, edit_command_utf16_length(command.removed_data_), command.inserted_data_)!
		}
		.split_text {
			text := command.text() or { return error('split-text command lost its Text node') }
			mut mutable_text := unsafe { &dom.Text(text) }
			command.new_text_node_ = mutable_text.split_text(command.offset_)!
		}
		.set_attribute {
			command.set_or_remove_attribute(command.new_value_)
		}
	}
}

pub fn (command &EditCommand) split_text_result() ?&dom.Text {
	return command.new_text_node_
}

fn (command &EditCommand) replay_data(from string, to string) bool {
	character_data := command.character_data() or { return false }
	if command.text_control_ == unsafe { nil } && !command.node_.is_editable_or_editing_host() {
		return false
	}
	from_length := edit_command_utf16_length(from)
	current_data := if command.text_control_ != unsafe { nil } {
		command.text_control_.text_control_relevant_value() or { return false }
	} else {
		character_data.data()
	}
	current_length := edit_command_utf16_length(current_data)
	if command.offset_ < 0 || command.offset_ + from_length > current_length {
		return false
	}
	current := dom.substring_by_utf16_offsets(current_data, command.offset_, command.offset_ + from_length) or {
		return false
	}
	if current != from {
		return false
	}
	if command.text_control_ != unsafe { nil } {
		return command.text_control_.replace_text_control_range(to, u32(command.offset_), u32(command.offset_ + from_length))
	}
	mut mutable_data := unsafe { &dom.CharacterData(character_data) }
	mutable_data.replace_data(command.offset_, from_length, to) or { return false }
	return true
}

// Replay methods return false when script mutations made the recorded action
// unsafe. Callers can then discard the whole undo step.
pub fn (mut command EditCommand) unapply() bool {
	match command.kind {
		.insert_node {
			parent := command.node_.parent() or { return false }
			if !parent.is_editable_or_editing_host() {
				return false
			}
			mut mutable_node := unsafe { &dom.Node(command.node_) }
			mutable_node.remove(false)
			return true
		}
		.remove_node {
			parent := command.parent() or { return false }
			if !parent.is_editable_or_editing_host() {
				return false
			}
			mut reference_child := ?&dom.Node(none)
			old_next := command.reference_child()
			if old_next != unsafe { nil } {
				old_next_parent := old_next.parent() or { unsafe { &dom.Node(nil) } }
				if old_next_parent == parent {
					reference_child = old_next
				}
			}
			parent.ensure_pre_insertion_validity(unsafe { nil }, command.node_, reference_child) or {
				return false
			}
			mut mutable_parent := unsafe { &dom.Node(parent) }
			mutable_parent.insert_before(command.node_, reference_child, false)
			return true
		}
		.replace_data {
			return command.replay_data(command.inserted_data_, command.removed_data_)
		}
		.split_text {
			new_node := command.new_text_node_ or { return false }
			if !command.node_.is_editable_or_editing_host() {
				return false
			}
			text := command.text() or { return false }
			mut mutable_text_data := unsafe { &dom.CharacterData(text) }
			mutable_text_data.replace_data(text.length_in_utf16_code_units(), 0, new_node.data()) or { return false }
			if new_node.as_node().parent() != none {
				mut mutable_new_node := unsafe { &dom.Node(new_node.as_node()) }
				mutable_new_node.remove(false)
			}
			return true
		}
		.set_attribute {
			command.set_or_remove_attribute(command.old_value_)
			return true
		}
	}
}

pub fn (mut command EditCommand) reapply() bool {
	match command.kind {
		.insert_node {
			parent := command.parent() or { return false }
			if !parent.is_editable_or_editing_host() {
				return false
			}
			reference := command.reference_child()
			if reference != unsafe { nil } {
				reference_parent := reference.parent() or { return false }
				if reference_parent != parent {
					return false
				}
			}
			parent.ensure_pre_insertion_validity(unsafe { nil }, command.node_, command.reference_child_) or { return false }
			mut mutable_parent := unsafe { &dom.Node(parent) }
			mutable_parent.insert_before(command.node_, command.reference_child_, false)
			return true
		}
		.remove_node {
			parent := command.node_.parent() or { return false }
			if !parent.is_editable_or_editing_host() {
				return false
			}
			mut mutable_node := unsafe { &dom.Node(command.node_) }
			mutable_node.remove(false)
			return true
		}
		.replace_data {
			return command.replay_data(command.removed_data_, command.inserted_data_)
		}
		.split_text {
			new_node := command.new_text_node_ or { return false }
			text := command.text() or { return false }
			parent := command.node_.parent() or { return false }
			if !command.node_.is_editable_or_editing_host()
				|| command.offset_ > text.length_in_utf16_code_units() {
				return false
			}
			mut mutable_text_data := unsafe { &dom.CharacterData(text) }
			mutable_text_data.replace_data(command.offset_, text.length_in_utf16_code_units() - command.offset_, '') or { return false }
			mut mutable_parent := unsafe { &dom.Node(parent) }
			mutable_parent.insert_before(new_node.as_node(), command.node_.next_sibling(), false)
			return true
		}
		.set_attribute {
			command.set_or_remove_attribute(command.new_value_)
			return true
		}
	}
}

pub fn (command &EditCommand) is_lasting_node_removal() bool {
	return command.kind == .remove_node && command.lasting_removal_closes_coalescence_
		&& command.node_.parent() == none
}

pub fn (mut command EditCommand) keep_typing_coalescence_open() {
	command.lasting_removal_closes_coalescence_ = false
}

pub fn (command &EditCommand) removed_data() string {
	return command.removed_data_
}

pub fn (command &EditCommand) offset() int {
	return command.offset_
}

pub fn (command &EditCommand) node() &dom.Node {
	return command.node_
}

// Editing mutation proxies. History recording is layered onto these by
// EditingHistory; without an active recording they still perform the exact DOM
// mutation through its reversible command object.
pub fn insert_node_before(node &dom.Node, parent &dom.Node, child ?&dom.Node) {
	if node.is_document_fragment() {
		for fragment_child in node.children_as_vector() {
			insert_node_before(fragment_child, parent, child)
		}
		return
	}
	history := begin_editing_proxy_mutation(parent)
	defer {
		end_editing_proxy_mutation(history)
	}
	if old_parent := node.parent() {
		if !old_parent.is_document_fragment() {
			mut remove_command := new_remove_node_command(node)
			remove_command.apply() or { return }
			record_edit_command(parent, remove_command)
		}
	}
	mut command := new_insert_node_command(node, parent, child)
	command.apply() or {}
	record_edit_command(parent, command)
}

pub fn append_node(node &dom.Node, parent &dom.Node) ! {
	parent.ensure_pre_insertion_validity(unsafe { nil }, node, none)!
	insert_node_before(node, parent, none)
}

fn remove_node_with_coalescence_behavior(node &dom.Node, closes_coalescence bool) {
	history := begin_editing_proxy_mutation(node)
	defer {
		end_editing_proxy_mutation(history)
	}
	mut command := new_remove_node_command(node)
	if !closes_coalescence {
		command.keep_typing_coalescence_open()
	}
	command.apply() or {}
	record_edit_command(node, command)
}

pub fn remove_node(node &dom.Node) {
	remove_node_with_coalescence_behavior(node, true)
}

pub fn replace_data(node &dom.CharacterData, offset int, count int, data string) ! {
	length := node.length_in_utf16_code_units()
	if offset < 0 || offset > length || count < 0 {
		mut mutable_node := unsafe { &dom.CharacterData(node) }
		mutable_node.replace_data(offset, count, data)!
		return
	}
	actual_count := if offset + count > length { length - offset } else { count }
	removed_data := node.substring_data(offset, actual_count)!
	is_no_op := removed_data == data
	history := begin_editing_proxy_mutation(node.as_node())
	defer {
		end_editing_proxy_mutation(history)
	}
	mut command := new_replace_data_command(node, offset, removed_data, data)
	command.apply()!
	if !is_no_op {
		record_edit_command(node.as_node(), command)
	}
}

pub fn insert_data(node &dom.CharacterData, offset int, data string) ! {
	replace_data(node, offset, 0, data)!
}

pub fn delete_data(node &dom.CharacterData, offset int, count int) ! {
	replace_data(node, offset, count, '')!
}

pub fn split_text(node &dom.Text, offset int) !&dom.Text {
	history := begin_editing_proxy_mutation(node.as_node())
	defer {
		end_editing_proxy_mutation(history)
	}
	mut command := new_split_text_command(node, offset)
	command.apply()!
	record_edit_command(node.as_node(), command)
	return command.split_text_result() or { return error('split-text command produced no node') }
}

pub fn set_attribute_value(element &dom.Element, local_name string, value string) {
	history := begin_editing_proxy_mutation(element.as_node())
	defer {
		end_editing_proxy_mutation(history)
	}
	mut command := new_set_attribute_command(element, local_name, none, element.get_attribute(local_name), value)
	command.apply() or {}
	record_edit_command(element.as_node(), command)
}

pub fn remove_attribute(element &dom.Element, name string) {
	old_value := element.get_attribute(name) or { return }
	history := begin_editing_proxy_mutation(element.as_node())
	defer {
		end_editing_proxy_mutation(history)
	}
	mut command := new_set_attribute_command(element, name, none, old_value, none)
	command.apply() or {}
	record_edit_command(element.as_node(), command)
}

pub fn remove_attribute_ns(element &dom.Element, namespace_ ?string, name string) {
	old_value := element.get_attribute_ns(namespace_, name) or { return }
	history := begin_editing_proxy_mutation(element.as_node())
	defer {
		end_editing_proxy_mutation(history)
	}
	mut command := new_set_attribute_command(element, name, namespace_, old_value, none)
	command.apply() or {}
	record_edit_command(element.as_node(), command)
}

pub fn clone_node_for_editing(node &dom.Node, subtree bool) !&dom.Node {
	history := begin_editing_proxy_mutation(node)
	defer {
		end_editing_proxy_mutation(history)
	}
	return node.clone_node(none, subtree, none)
}

// https://dom.spec.whatwg.org/#concept-range-insert
pub fn insert_node_into_range(range_pointer &dom.Range, node &dom.Node) ! {
	mut range_ := unsafe { &dom.Range(range_pointer) }
	start_container := range_.start_container()
	if start_container.as_processing_instruction() != none || start_container.is_comment()
		|| (start_container.is_text() && start_container.parent() == none)
		|| start_container == node {
		return error('HierarchyRequestError: Range has inappropriate start node for insertion')
	}
	mut reference_node := if start_container.is_text() {
		?&dom.Node(start_container)
	} else {
		start_container.child_at_index(range_.start_offset())
	}
	parent := if reference := reference_node {
		reference.parent() or { start_container }
	} else {
		start_container
	}
	parent.ensure_pre_insertion_validity(unsafe { nil }, node, reference_node)!
	if start_container.is_text() {
		text := unsafe { &dom.Text(start_container) }
		reference_node = split_text(text, range_.start_offset())!.as_node()
	}
	if reference := reference_node {
		if reference == node {
			reference_node = reference.next_sibling()
		}
	}
	if node.parent() != none {
		remove_node(node)
	}
	mut new_offset := if reference := reference_node { reference.index() } else { parent.length() }
	new_offset += if node.is_document_fragment() { node.length() } else { 1 }
	parent.ensure_pre_insertion_validity(unsafe { nil }, node, reference_node)!
	insert_node_before(node, parent, reference_node)
	if range_.collapsed() {
		range_.set_end(parent, new_offset)!
	}
}
