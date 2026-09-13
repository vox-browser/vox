// Copyright (c) 2024, Tim Flynn <trflynn89@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Page/DragAndDropEventHandler.{h,cpp}. DOM dispatch is modeled
// as an event log plus cancellation inputs, retaining the HTML DND state machine.
module page

pub enum EventResult {
	accepted
	handled
	dropped
	cancelled
}

pub enum DragDataStoreMode {
	read_write
	read_only
	protected_
}

pub enum DragEffect {
	uninitialized
	none
	copy
	copy_link
	copy_move
	link
	link_move
	move
	all
}

pub struct DragItem {
pub:
	kind      string
	type_     string
	file_name string
	data      []u8
}

pub struct DragTarget {
pub:
	id               string
	is_dom_element   bool = true
	allows_text_drop bool
}

pub struct DragDispatch {
pub:
	name           string
	target         string
	related_target string
	cancelable     bool
	drop_effect    DragEffect
	mode           DragDataStoreMode
}

@[heap]
pub struct DragAndDropEventHandler {
pub mut:
	event_log []DragDispatch
mut:
	ongoing_          bool
	mode_             DragDataStoreMode = .protected_
	items_            []DragItem
	current_target_   ?DragTarget
	current_operation DragEffect = .none
	allowed_effects_  DragEffect = .uninitialized
}

pub fn (handler &DragAndDropEventHandler) has_ongoing_drag_and_drop_operation() bool {
	return handler.ongoing_
}

pub fn (handler &DragAndDropEventHandler) items() []DragItem {
	return handler.items_.clone()
}

pub fn (handler &DragAndDropEventHandler) current_operation() DragEffect {
	return handler.current_operation
}

fn default_drop_effect(effect DragEffect) DragEffect {
	return match effect {
		.none { .none }
		.copy, .copy_link, .copy_move, .all { .copy }
		.link, .link_move { .link }
		.move { .move }
		else { .copy }
	}
}

fn effect_allowed(allowed DragEffect, requested DragEffect) bool {
	return match requested {
		.copy { allowed in [.uninitialized, .copy, .copy_link, .copy_move, .all] }
		.link { allowed in [.uninitialized, .link, .copy_link, .link_move, .all] }
		.move { allowed in [.uninitialized, .move, .copy_move, .link_move, .all] }
		else { false }
	}
}

fn (mut handler DragAndDropEventHandler) dispatch(name string, target ?DragTarget, related ?DragTarget, cancelled bool, requested_effect DragEffect) {
	mut changed := false
	if name == 'dragstart' {
		handler.mode_ = .read_write
		changed = true
	} else if name == 'drop' {
		handler.mode_ = .read_only
	}
	mut drop_effect := if name in ['dragstart', 'drag', 'dragleave'] {
		DragEffect.none
	} else if name in ['drop', 'dragend'] {
		handler.current_operation
	} else {
		default_drop_effect(handler.allowed_effects_)
	}
	if cancelled && requested_effect != .none {
		drop_effect = requested_effect
	}
	handler.event_log << DragDispatch{
		name:           name
		target:         if value := target { value.id } else { '' }
		related_target: if value := related { value.id } else { '' }
		cancelable:     name !in ['dragleave', 'dragend']
		drop_effect:    drop_effect
		mode:           handler.mode_
	}
	if changed {
		handler.mode_ = .protected_
	}
}

pub fn (mut handler DragAndDropEventHandler) handle_drag_start(files []SelectedFile, cancelled bool, allowed_effects DragEffect) EventResult {
	if handler.ongoing_ {
		handler.reset()
	}
	handler.ongoing_ = true
	handler.allowed_effects_ = allowed_effects
	for file in files {
		handler.items_ << DragItem{
			kind:      'file'
			type_:     if file.mime_type == '' { 'application/octet-stream' } else { file.mime_type }
			file_name: file.name
			data:      file.contents.clone()
		}
	}
	handler.dispatch('dragstart', none, none, cancelled, .none)
	if cancelled {
		handler.reset()
		return .cancelled
	}
	return .handled
}

// This is one DND processing-model iteration. The three cancellation flags
// represent script preventDefault() on drag, dragenter and dragover.
pub fn (mut handler DragAndDropEventHandler) handle_drag_move(target ?DragTarget, drag_cancelled bool, dragenter_cancelled bool, dragover_cancelled bool, requested_effect DragEffect) EventResult {
	if !handler.ongoing_ {
		return .cancelled
	}
	handler.dispatch('drag', none, none, drag_cancelled, requested_effect)
	if drag_cancelled {
		return handler.handle_drag_end(true, false, .none)
	}
	if target != handler.current_target_ {
		previous := handler.current_target_
		handler.dispatch('dragenter', target, previous, dragenter_cancelled, requested_effect)
		if previous != none {
			handler.dispatch('dragleave', previous, target, false, .none)
		}
		handler.current_target_ = target
	}
	if current := handler.current_target_ {
		handler.dispatch('dragover', current, none, dragover_cancelled, requested_effect)
		if dragover_cancelled {
			handler.current_operation = if effect_allowed(handler.allowed_effects_,
				requested_effect)
			{
				requested_effect
			} else {
				.none
			}
		} else {
			handler.current_operation = if current.allows_text_drop && handler.has_text_item() {
				.copy
			} else {
				.none
			}
		}
	}
	return .handled
}

fn (handler &DragAndDropEventHandler) has_text_item() bool {
	for item in handler.items_ {
		if item.kind == 'text' && item.type_ == 'text/plain' {
			return true
		}
	}
	return false
}

pub fn (mut handler DragAndDropEventHandler) add_text_item(text string) {
	if handler.ongoing_ && handler.mode_ == .protected_ {
		// This test/embedder entry point models content installed at drag start;
		// user script cannot mutate the protected store afterwards.
		handler.items_ << DragItem{
			kind:  'text'
			type_: 'text/plain'
			data:  text.bytes()
		}
	}
}

pub fn (mut handler DragAndDropEventHandler) handle_drag_end(cancelled bool, drop_cancelled bool, requested_effect DragEffect) EventResult {
	if !handler.ongoing_ {
		return .cancelled
	}
	mut dropped := false
	if handler.current_operation == .none || cancelled || handler.current_target_ == none {
		if target := handler.current_target_ {
			if target.is_dom_element {
				handler.dispatch('dragleave', target, none, false, .none)
			}
		}
		handler.current_operation = .none
	} else if target := handler.current_target_ {
		dropped = true
		if target.is_dom_element {
			handler.dispatch('drop', target, none, drop_cancelled, requested_effect)
		}
		if drop_cancelled {
			handler.current_operation = requested_effect
		} else if !(target.allows_text_drop && handler.has_text_item()) {
			handler.current_operation = .none
		}
	}
	handler.dispatch('dragend', none, none, false, .none)
	result := if dropped && handler.current_operation != .none {
		EventResult.handled
	} else {
		EventResult.cancelled
	}
	handler.reset()
	return result
}

pub fn (mut handler DragAndDropEventHandler) handle_drag_cancel() EventResult {
	return handler.handle_drag_end(true, false, .none)
}

pub fn (mut handler DragAndDropEventHandler) reset() {
	handler.ongoing_ = false
	handler.mode_ = .protected_
	handler.items_.clear()
	handler.current_target_ = none
	handler.current_operation = .none
	handler.allowed_effects_ = .uninitialized
}
