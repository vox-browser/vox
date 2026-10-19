// Copyright (c) 2026-present, the Ladybird developers
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Editing/EditingHistory.{h,cpp} for document selections and
// contenteditable hosts. Text-control selection/value bridging is installed by
// HTML separately because Editing cannot import HTML without a module cycle.
module editing

import dom

const maximum_undo_stack_depth = 1000

pub enum UndoStepCategory {
	insertion
	backward_deletion
	forward_deletion
	other
}

pub struct SelectionSnapshot {
pub mut:
	has_selection     bool
	anchor_node       &dom.Node = unsafe { nil }
	anchor_offset     int
	focus_node        &dom.Node = unsafe { nil }
	focus_offset      int
	focus_affinity    dom.TextAffinity = .downstream
	text_control      &dom.InputEventsTarget = unsafe { nil }
	text_control_host &dom.Node = unsafe { nil }
	text_selection    dom.TextControlSelectionSnapshot
}

fn selection_snapshot_is_collapsed(snapshot &SelectionSnapshot) bool {
	if snapshot.text_control != unsafe { nil } {
		return snapshot.text_selection.start == snapshot.text_selection.end
	}
	return snapshot.has_selection && snapshot.anchor_node == snapshot.focus_node
		&& snapshot.anchor_offset == snapshot.focus_offset
}

@[heap]
pub struct UndoStep {
pub:
	editing_host &dom.Node
	category     UndoStepCategory
mut:
	last_merged_category_    UndoStepCategory
	closes_after_next_merge_ bool
	commands_                []&EditCommand
	starting_selection_      SelectionSnapshot
	ending_selection_        SelectionSnapshot
}

pub fn UndoStep.new(editing_host &dom.Node, category UndoStepCategory) &UndoStep {
	return &UndoStep{
		editing_host: editing_host
		category: category
		last_merged_category_: category
	}
}

pub fn (mut step UndoStep) add_command(command &EditCommand) {
	step.commands_ << command
}

pub fn (step &UndoStep) has_commands() bool {
	return step.commands_.len > 0
}

pub fn (step &UndoStep) command_count() int {
	return step.commands_.len
}

pub fn (step &UndoStep) starting_selection() SelectionSnapshot {
	return step.starting_selection_
}

pub fn (mut step UndoStep) set_starting_selection(snapshot SelectionSnapshot) {
	step.starting_selection_ = snapshot
}

pub fn (step &UndoStep) ending_selection() SelectionSnapshot {
	return step.ending_selection_
}

pub fn (mut step UndoStep) set_ending_selection(snapshot SelectionSnapshot) {
	step.ending_selection_ = snapshot
}

pub fn (step &UndoStep) accepts_merge_of(category UndoStepCategory) bool {
	return match category {
		.insertion { true }
		.backward_deletion { step.last_merged_category_ == .backward_deletion }
		.forward_deletion { step.last_merged_category_ == .forward_deletion }
		.other { false }
	}
}

pub fn (mut step UndoStep) merge(other &UndoStep) {
	for command in other.commands_ {
		step.commands_ << command
	}
	step.ending_selection_ = other.ending_selection_
	step.last_merged_category_ = other.category
	step.closes_after_next_merge_ = other.closes_after_next_merge_
	if other.category == .backward_deletion
		&& selection_snapshot_is_collapsed(&other.ending_selection_) {
		if step.starting_selection_.text_control != unsafe { nil } {
			step.starting_selection_.text_selection.start = other.ending_selection_.text_selection.start
		} else {
			step.starting_selection_.focus_node = other.ending_selection_.focus_node
			step.starting_selection_.focus_offset = other.ending_selection_.focus_offset
		}
	}
}

pub fn (mut step UndoStep) finalize_starting_selection() {
	if !selection_snapshot_is_collapsed(&step.starting_selection_) {
		return
	}
	if step.category == .backward_deletion {
		if !selection_snapshot_is_collapsed(&step.ending_selection_) {
			return
		}
		if step.starting_selection_.text_control != unsafe { nil } {
			step.starting_selection_.text_selection.start = step.ending_selection_.text_selection.start
		} else if step.ending_selection_.focus_node != unsafe { nil } {
			step.starting_selection_.focus_node = step.ending_selection_.focus_node
			step.starting_selection_.focus_offset = step.ending_selection_.focus_offset
		}
		return
	}
	if step.category != .forward_deletion || step.commands_.len == 0 {
		return
	}
	command := step.commands_[0]
	if command.kind != .replace_data || command.removed_data() == '' {
		return
	}
	if step.starting_selection_.text_control != unsafe { nil } {
		step.starting_selection_.text_selection.start = u32(command.offset())
		step.starting_selection_.text_selection.end = u32(command.offset() + edit_command_utf16_length(command.removed_data()))
		return
	}
	step.starting_selection_.anchor_node = command.node()
	step.starting_selection_.anchor_offset = command.offset()
	step.starting_selection_.focus_node = command.node()
	step.starting_selection_.focus_offset = command.offset() + edit_command_utf16_length(command.removed_data())
}

pub fn (step &UndoStep) performed_lasting_node_removal() bool {
	return step.commands_.any(it.is_lasting_node_removal())
}

pub fn (mut step UndoStep) unapply() bool {
	for i := step.commands_.len; i > 0; i-- {
		mut command := step.commands_[i - 1]
		if command.unapply() {
			continue
		}
		for j := i; j < step.commands_.len; j++ {
			mut rollback := step.commands_[j]
			rollback.reapply()
		}
		return false
	}
	return step.commands_.len > 0
}

pub fn (mut step UndoStep) reapply() bool {
	for i := 0; i < step.commands_.len; i++ {
		mut command := step.commands_[i]
		if command.reapply() {
			continue
		}
		for j := i; j > 0; j-- {
			mut rollback := step.commands_[j - 1]
			rollback.unapply()
		}
		return false
	}
	return step.commands_.len > 0
}

pub fn (step &UndoStep) closes_after_next_merge() bool {
	return step.closes_after_next_merge_
}

pub fn (mut step UndoStep) set_closes_after_next_merge() {
	step.closes_after_next_merge_ = true
}

pub type EditingHistoryStateCallback = fn (bool, bool)

@[heap]
pub struct EditingHistory {
mut:
	undo_step_being_recorded_ &UndoStep = unsafe { nil }
	open_step_                &UndoStep = unsafe { nil }
	undo_stack_               []&UndoStep
	redo_stack_               []&UndoStep
	applying_history_step_    bool
	last_notified_can_undo_   bool
	last_notified_can_redo_   bool
	proxy_mutation_depth_     u32
	unproxied_mutation_count_ int
	state_callback_           EditingHistoryStateCallback = unsafe { nil }
}

pub fn EditingHistory.new() &EditingHistory {
	return &EditingHistory{}
}

fn capture_selection(editing_host &dom.Node) SelectionSnapshot {
	if text_control := editing_host.document().form_control_input_events_target(editing_host) {
		if text_selection := text_control.text_control_selection() {
			return SelectionSnapshot{
				has_selection: true
				text_control: text_control
				text_control_host: editing_host
				text_selection: text_selection
			}
		}
	}
	selection := editing_host.document().get_selection() or { return SelectionSnapshot{} }
	if selection.range() == none {
		return SelectionSnapshot{}
	}
	mut anchor_node := selection.anchor_node() or { unsafe { &dom.Node(nil) } }
	mut focus_node := selection.focus_node() or { unsafe { &dom.Node(nil) } }
	mut anchor_offset := selection.anchor_offset()
	mut focus_offset := selection.focus_offset()
	if selection.is_collapsed() && focus_node != unsafe { nil } {
		visible_position := VisiblePosition.create_with_affinity(editing_host.document(), dom.BoundaryPoint{
			node: focus_node
			offset: focus_offset
		}, selection.focus_affinity())
		deep_equivalent := visible_position.deep_equivalent()
		anchor_node = deep_equivalent.node
		focus_node = deep_equivalent.node
		anchor_offset = deep_equivalent.offset
		focus_offset = deep_equivalent.offset
	}
	return SelectionSnapshot{
		has_selection: true
		anchor_node: anchor_node
		anchor_offset: anchor_offset
		focus_node: focus_node
		focus_offset: focus_offset
		focus_affinity: selection.focus_affinity()
	}
}

pub fn (history &EditingHistory) undo_step_being_recorded() ?&UndoStep {
	if history.undo_step_being_recorded_ == unsafe { nil } {
		return none
	}
	return history.undo_step_being_recorded_
}

pub fn (mut history EditingHistory) begin_recording(editing_host &dom.Node, category UndoStepCategory) {
	if history.undo_step_being_recorded_ != unsafe { nil } || history.applying_history_step_ {
		return
	}
	mut step := UndoStep.new(editing_host, category)
	step.set_starting_selection(capture_selection(editing_host))
	history.undo_step_being_recorded_ = step
}

pub fn (mut history EditingHistory) end_recording() {
	if history.undo_step_being_recorded_ == unsafe { nil } {
		return
	}
	mut step := history.undo_step_being_recorded_
	if !step.has_commands() {
		history.undo_step_being_recorded_ = unsafe { nil }
		return
	}
	step.set_ending_selection(capture_selection(step.editing_host))
	closes_coalescing := step.performed_lasting_node_removal()
	if history.open_step_ != unsafe { nil } && history.undo_stack_.len > 0
		&& voidptr(history.open_step_) == voidptr(history.undo_stack_.last())
		&& history.open_step_.editing_host == step.editing_host
		&& history.open_step_.accepts_merge_of(step.category) {
		deferred_close := history.open_step_.closes_after_next_merge()
		mut open_step := history.open_step_
		open_step.merge(step)
		if deferred_close {
			history.open_step_ = unsafe { nil }
		}
	} else {
		step.finalize_starting_selection()
		history.redo_stack_.clear()
		if history.undo_stack_.len >= maximum_undo_stack_depth {
			history.undo_stack_.delete(0)
		}
		history.undo_stack_ << step
		if step.category == .other {
			history.open_step_ = unsafe { nil }
		} else {
			history.open_step_ = step
		}
	}
	if closes_coalescing {
		history.open_step_ = unsafe { nil }
	}
	history.undo_step_being_recorded_ = unsafe { nil }
	history.notify_state_if_changed(step.editing_host.document())
}

pub fn (mut history EditingHistory) begin_proxy_mutation() {
	history.proxy_mutation_depth_++
}

pub fn (mut history EditingHistory) end_proxy_mutation() {
	if history.proxy_mutation_depth_ > 0 {
		history.proxy_mutation_depth_--
	}
}

pub fn (mut history EditingHistory) notify_dom_mutation() {
	if history.undo_step_being_recorded_ == unsafe { nil } || history.proxy_mutation_depth_ > 0
		|| history.applying_history_step_ {
		return
	}
	history.unproxied_mutation_count_++
}

pub fn (history &EditingHistory) unproxied_mutation_count() int {
	return history.unproxied_mutation_count_
}

pub fn (mut history EditingHistory) selection_changed() {
	if history.undo_step_being_recorded_ != unsafe { nil } || history.applying_history_step_ {
		return
	}
	history.open_step_ = unsafe { nil }
}

fn (mut history EditingHistory) prune_steps_for_disconnected_hosts() {
	history.undo_stack_ = history.undo_stack_.filter(it.editing_host.is_connected())
	history.redo_stack_ = history.redo_stack_.filter(it.editing_host.is_connected())
	if history.open_step_ != unsafe { nil } && !history.open_step_.editing_host.is_connected() {
		history.open_step_ = unsafe { nil }
	}
}

pub fn (mut history EditingHistory) can_undo() bool {
	history.prune_steps_for_disconnected_hosts()
	return history.undo_stack_.len > 0
}

pub fn (mut history EditingHistory) can_redo() bool {
	history.prune_steps_for_disconnected_hosts()
	return history.redo_stack_.len > 0
}

pub fn (mut history EditingHistory) next_undo_step() ?&UndoStep {
	history.prune_steps_for_disconnected_hosts()
	if history.undo_stack_.len == 0 {
		return none
	}
	return history.undo_stack_.last()
}

pub fn (mut history EditingHistory) next_redo_step() ?&UndoStep {
	history.prune_steps_for_disconnected_hosts()
	if history.redo_stack_.len == 0 {
		return none
	}
	return history.redo_stack_.last()
}

fn (mut history EditingHistory) restore_selection(document &dom.Document, snapshot SelectionSnapshot) {
	if snapshot.text_control != unsafe { nil } {
		if snapshot.text_control_host == unsafe { nil }
			|| !snapshot.text_control_host.is_connected()
			|| snapshot.text_control_host.document() != document {
			return
		}
		snapshot.text_control.set_text_control_selection(snapshot.text_selection)
		return
	}
	selection_pointer := document.get_selection() or { return }
	if snapshot.anchor_node == unsafe { nil } || snapshot.focus_node == unsafe { nil }
		|| !snapshot.anchor_node.is_connected() || !snapshot.focus_node.is_connected()
		|| snapshot.anchor_node.document() != document || snapshot.focus_node.document() != document
		|| snapshot.anchor_offset > snapshot.anchor_node.length()
		|| snapshot.focus_offset > snapshot.focus_node.length() {
		return
	}
	mut selection := unsafe { &dom.Selection(selection_pointer) }
	selection.set_base_and_extent(snapshot.anchor_node, snapshot.anchor_offset, snapshot.focus_node, snapshot.focus_offset) or { return }
	selection.set_focus_affinity(snapshot.focus_affinity)
}

fn dispatch_history_input_event(editing_host &dom.Node, input_type string) {
	event := dom.InputEvent.create_from_platform_event('input', dom.InputEventInit{
		input_type: input_type
	}, [], dom.current_event_timestamp())
	target := unsafe { &dom.EventTarget(editing_host) }
	base_event := unsafe { &dom.Event(event) }
	target.dispatch_event(base_event)
}

pub fn (mut history EditingHistory) undo(document &dom.Document) bool {
	if history.applying_history_step_ || history.undo_step_being_recorded_ != unsafe { nil }
		|| !history.can_undo() {
		return false
	}
	history.open_step_ = unsafe { nil }
	mut step := history.undo_stack_.pop()
	history.applying_history_step_ = true
	performed := step.unapply()
	history.applying_history_step_ = false
	history.restore_selection(document, step.starting_selection())
	if performed {
		history.redo_stack_ << step
	}
	history.notify_state_if_changed(document)
	dispatch_history_input_event(step.editing_host, 'historyUndo')
	return true
}

pub fn (mut history EditingHistory) redo(document &dom.Document) bool {
	if history.applying_history_step_ || history.undo_step_being_recorded_ != unsafe { nil }
		|| !history.can_redo() {
		return false
	}
	history.open_step_ = unsafe { nil }
	mut step := history.redo_stack_.pop()
	history.applying_history_step_ = true
	performed := step.reapply()
	history.applying_history_step_ = false
	history.restore_selection(document, step.ending_selection())
	if performed {
		history.undo_stack_ << step
	}
	history.notify_state_if_changed(document)
	dispatch_history_input_event(step.editing_host, 'historyRedo')
	return true
}

pub fn (mut history EditingHistory) set_state_change_callback(callback EditingHistoryStateCallback) {
	history.state_callback_ = callback
}

fn (mut history EditingHistory) notify_state_if_changed(document &dom.Document) {
	new_can_undo := history.can_undo()
	new_can_redo := history.can_redo()
	if new_can_undo == history.last_notified_can_undo_
		&& new_can_redo == history.last_notified_can_redo_ {
		return
	}
	history.last_notified_can_undo_ = new_can_undo
	history.last_notified_can_redo_ = new_can_redo
	if history.state_callback_ != unsafe { nil } {
		history.state_callback_(new_can_undo, new_can_redo)
	}
	if document.has_page() {
		document.page().client_page_did_update_editing_history_state(new_can_undo, new_can_redo)
	}
}

fn editing_history_notify_mutation_callback(target voidptr) {
	mut history := unsafe { &EditingHistory(target) }
	history.notify_dom_mutation()
}

fn editing_history_selection_changed_callback(target voidptr) {
	mut history := unsafe { &EditingHistory(target) }
	history.selection_changed()
}

fn editing_history_can_undo_callback(target voidptr) bool {
	mut history := unsafe { &EditingHistory(target) }
	return history.can_undo()
}

fn editing_history_can_redo_callback(target voidptr) bool {
	mut history := unsafe { &EditingHistory(target) }
	return history.can_redo()
}

pub fn editing_history_if_exists(document &dom.Document) ?&EditingHistory {
	hook := document.editing_history_hook() or { return none }
	if hook.target == unsafe { nil } {
		return none
	}
	return unsafe { &EditingHistory(hook.target) }
}

pub fn install_editing_history(document &dom.Document) &EditingHistory {
	// DOM cannot directly import Editing, so installing history also makes the
	// undo/redo command entry point available on programmatically built documents.
	install_dom_editing_bridge(document)
	if history := editing_history_if_exists(document) {
		return history
	}
	history := EditingHistory.new()
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_editing_history_hook(dom.DocumentEditingHistoryHook{
		target: voidptr(history)
		notify_dom_mutation: editing_history_notify_mutation_callback
		selection_changed: editing_history_selection_changed_callback
		can_undo: editing_history_can_undo_callback
		can_redo: editing_history_can_redo_callback
	})
	return history
}

fn record_edit_command(node &dom.Node, command &EditCommand) {
	history_pointer := editing_history_if_exists(node.document()) or { return }
	mut history := unsafe { &EditingHistory(history_pointer) }
	step_pointer := history.undo_step_being_recorded() or { return }
	mut step := unsafe { &UndoStep(step_pointer) }
	step.add_command(command)
}

fn begin_editing_proxy_mutation(node &dom.Node) ?&EditingHistory {
	history_pointer := editing_history_if_exists(node.document()) or { return none }
	mut history := unsafe { &EditingHistory(history_pointer) }
	history.begin_proxy_mutation()
	return history_pointer
}

fn end_editing_proxy_mutation(history_pointer ?&EditingHistory) {
	history := history_pointer or { return }
	mut mutable_history := unsafe { &EditingHistory(history) }
	mutable_history.end_proxy_mutation()
}

pub enum HistoryAction {
	undo
	redo
}

pub fn perform_history_action(document &dom.Document, action HistoryAction) dom.EventResult {
	history_pointer := editing_history_if_exists(document) or { return .handled }
	mut history := unsafe { &EditingHistory(history_pointer) }
	step := if action == .undo {
		history.next_undo_step() or { return .handled }
	} else {
		history.next_redo_step() or { return .handled }
	}
	input_type := if action == .undo { 'historyUndo' } else { 'historyRedo' }
	event := dom.InputEvent.create_from_platform_event('beforeinput', dom.InputEventInit{
		input_type: input_type
	}, [], dom.current_event_timestamp())
	target := unsafe { &dom.EventTarget(step.editing_host) }
	base_event := unsafe { &dom.Event(event) }
	if !target.dispatch_event(base_event) {
		return .handled
	}
	if action == .undo {
		history.undo(document)
	} else {
		history.redo(document)
	}
	return .handled
}
