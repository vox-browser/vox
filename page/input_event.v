// Copyright (c) 2024, Tim Flynn <trflynn89@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Page/InputEvent.{h,cpp}. Native browser_data is deliberately
// opaque and, like the C++ clone/IPC operations, never crosses the boundary.
module page

import math

pub enum KeyEventType {
	key_down
	key_up
}

pub enum MouseEventType {
	mouse_down
	mouse_up
	mouse_move
	mouse_leave
	mouse_wheel
}

pub enum DragEventType {
	drag_start
	drag_move
	drag_end
	drop
}

pub struct SelectedFile {
pub:
	name      string
	mime_type string
	contents  []u8
}

pub struct KeyEvent {
pub:
	type_        KeyEventType
	key          int
	modifiers    u32
	code_point   u32
	repeat       bool
	browser_data voidptr
}

pub fn (event KeyEvent) clone_without_browser_data() KeyEvent {
	return KeyEvent{
		...event
		browser_data: unsafe { nil }
	}
}

pub struct MouseEvent {
pub:
	type_           MouseEventType
	position        PixelPoint
	screen_position PixelPoint
	button          u32
	buttons         u32
	modifiers       u32
	wheel_delta_x   int
	wheel_delta_y   int
	click_count     int
	browser_data    voidptr
}

pub fn (event MouseEvent) clone_without_browser_data() MouseEvent {
	return MouseEvent{
		...event
		browser_data: unsafe { nil }
	}
}

pub struct DragEvent {
pub:
	type_           DragEventType
	position        PixelPoint
	screen_position PixelPoint
	button          u32
	buttons         u32
	modifiers       u32
	files           []SelectedFile
	browser_data    voidptr
}

// C++ intentionally strips both native browser data and the file payload.
pub fn (event DragEvent) clone_without_browser_data() DragEvent {
	return DragEvent{
		type_:           event.type_
		position:        event.position
		screen_position: event.screen_position
		button:          event.button
		buttons:         event.buttons
		modifiers:       event.modifiers
	}
}

pub struct PinchEvent {
pub:
	position    PixelPoint
	scale_delta f64
}

pub fn PinchEvent.decode(position PixelPoint, scale_delta f64) !PinchEvent {
	if math.is_nan(scale_delta) || math.is_inf(scale_delta, 0) {
		return error('IPC: Invalid scale_delta value')
	}
	return PinchEvent{
		position:    position
		scale_delta: scale_delta
	}
}

pub type InputEvent = DragEvent | KeyEvent | MouseEvent | PinchEvent

pub struct QueuedInputEvent {
pub:
	page_id               u64
	event                 InputEvent
	coalesced_event_count uint
}
