// Copyright (c) 2020-2026, Ladybird contributors.
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Page/EventHandler.{h,cpp}. Painting hit testing is supplied as
// a typed InputTarget; dispatch/default-action ordering remains observable.
module page

pub enum SelectionMode {
	none
	character
	word
	paragraph
}

pub struct InputTarget {
pub:
	id                 string
	is_editable        bool
	is_focusable       bool
	is_link            bool
	cancel_pointer     bool
	cancel_mouse       bool
	cancel_keyboard    bool
	has_scrollable_box bool
}

pub struct InputDispatch {
pub:
	name   string
	target string
}

@[heap]
pub struct EventHandler {
pub mut:
	drag_and_drop DragAndDropEventHandler
	event_log     []InputDispatch
mut:
	active_document       bool = true
	paint_root_available  bool = true
	selection_mode_       SelectionMode
	mousedown_target_     string
	mousedown_click_count int
	prevent_mouse_event   bool
	previous_screen       ?PixelPoint
	focused_target_       string
}

pub fn (mut handler EventHandler) set_document_state(active bool, has_paint_root bool) {
	handler.active_document = active
	handler.paint_root_available = has_paint_root
}

pub fn (handler &EventHandler) is_handling_mouse_selection() bool {
	return handler.selection_mode_ != .none
}

pub fn (mut handler EventHandler) start_selection(mode SelectionMode) {
	handler.selection_mode_ = mode
}

pub fn (mut handler EventHandler) stop_updating_selection() {
	handler.selection_mode_ = .none
}

pub fn (mut handler EventHandler) clear_mousedown_tracking() {
	handler.mousedown_target_ = ''
	handler.mousedown_click_count = 0
}

fn (handler &EventHandler) should_ignore_device_input_event() bool {
	return !handler.active_document || handler.drag_and_drop.has_ongoing_drag_and_drop_operation()
}

fn (mut handler EventHandler) log(name string, target ?InputTarget) {
	handler.event_log << InputDispatch{
		name:   name
		target: if value := target { value.id } else { '' }
	}
}

pub fn (mut handler EventHandler) handle_mousedown(target ?InputTarget, click_count int) EventResult {
	if handler.should_ignore_device_input_event() || !handler.paint_root_available || target == none {
		return .dropped
	}
	value := target or { return .dropped }
	// Upstream records the press target before pointer-event dispatch. A
	// cancelled pointerdown therefore still has a corresponding pointerup/click
	// target, even though compatibility mouse events and default actions are
	// suppressed.
	handler.mousedown_target_ = value.id
	handler.mousedown_click_count = click_count
	handler.log('pointerdown', value)
	if value.cancel_pointer {
		handler.prevent_mouse_event = true
		return .cancelled
	}
	if !handler.prevent_mouse_event {
		handler.log('mousedown', value)
		if value.cancel_mouse {
			return .cancelled
		}
	}
	if value.is_focusable {
		handler.focused_target_ = value.id
	}
	return .handled
}

pub fn (mut handler EventHandler) handle_mouseup(target ?InputTarget) EventResult {
	// The C++ ScopeGuard clears press/selection state on every exit, including
	// missing documents, paint roots and hit targets.
	defer {
		handler.clear_mousedown_tracking()
		handler.stop_updating_selection()
	}
	if handler.should_ignore_device_input_event() || !handler.paint_root_available || target == none {
		return .dropped
	}
	value := target or { return .dropped }
	handler.log('pointerup', value)
	if !handler.prevent_mouse_event {
		handler.log('mouseup', value)
	}
	if handler.mousedown_target_ == value.id {
		handler.log('click', value)
	}
	handler.prevent_mouse_event = false
	// EventHandler::handle_mouseup deliberately ignores cancellation of the
	// compatibility mouseup event once pointerup has been dispatched.
	return .handled
}

pub fn (mut handler EventHandler) handle_mousemove(target ?InputTarget, screen PixelPoint) EventResult {
	if handler.should_ignore_device_input_event() || !handler.paint_root_available || target == none {
		return .dropped
	}
	handler.previous_screen = screen
	value := target or { return .dropped }
	handler.log('pointermove', value)
	if !handler.prevent_mouse_event {
		handler.log('mousemove', value)
	}
	return if value.cancel_mouse { .cancelled } else { .handled }
}

pub fn (mut handler EventHandler) handle_mouseleave() EventResult {
	if handler.should_ignore_device_input_event() || !handler.paint_root_available {
		return .dropped
	}
	handler.log('pointerout', none)
	handler.log('pointerleave', none)
	return .handled
}

pub fn (mut handler EventHandler) handle_mousewheel(target ?InputTarget) EventResult {
	if handler.should_ignore_device_input_event() || !handler.paint_root_available || target == none {
		return .dropped
	}
	value := target or { return .dropped }
	handler.log('wheel', value)
	return if value.cancel_mouse {
		.cancelled
	} else if value.has_scrollable_box {
		.handled
	} else {
		.dropped
	}
}

pub fn (mut handler EventHandler) handle_keydown(key int, code_point u32, modifiers u32, repeat bool, cancelled bool) EventResult {
	_ = modifiers
	_ = repeat
	if !handler.active_document {
		return .dropped
	}
	handler.log('keydown', if handler.focused_target_ != '' {
		InputTarget{
			id: handler.focused_target_
		}
	} else {
		none
	})
	if cancelled {
		return .cancelled
	}
	// Tab, Return, Backspace/Delete and navigation keys have UA default actions.
	if key in [8, 9, 13, 33, 34, 35, 36, 37, 38, 39, 40, 46] {
		return .handled
	}
	if code_point != 0 && code_point != 27 {
		handler.log('beforeinput', if handler.focused_target_ != '' {
			InputTarget{
				id: handler.focused_target_
			}
		} else {
			none
		})
		handler.log('input', if handler.focused_target_ != '' {
			InputTarget{
				id: handler.focused_target_
			}
		} else {
			none
		})
		return .handled
	}
	return .accepted
}

pub fn (mut handler EventHandler) handle_keyup(cancelled bool) EventResult {
	if !handler.active_document {
		return .dropped
	}
	handler.log('keyup', if handler.focused_target_ != '' {
		InputTarget{
			id: handler.focused_target_
		}
	} else {
		none
	})
	return if cancelled { .cancelled } else { .accepted }
}

pub fn (mut handler EventHandler) handle_paste(text string) EventResult {
	if !handler.active_document || handler.focused_target_ == '' || text == '' {
		return .dropped
	}
	target := InputTarget{
		id: handler.focused_target_
	}
	handler.log('beforeinput:insertFromPaste', target)
	handler.log('input:insertFromPaste', target)
	return .handled
}
