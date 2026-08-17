// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// IDL-facing types translated from GamepadButton, GamepadEvent and EventNames.
module gamepad

import dom

pub const event_gamepad_connected = 'gamepadconnected'
pub const event_gamepad_disconnected = 'gamepaddisconnected'

pub enum GamepadMappingType {
	empty
	standard
	xr_standard
}

pub fn (mapping GamepadMappingType) idl_string() string {
	return match mapping {
		.empty { '' }
		.standard { 'standard' }
		.xr_standard { 'xr-standard' }
	}
}

@[heap]
pub struct GamepadButton {
pub mut:
	pressed_ bool
	touched_ bool
	value_   f64
}

pub fn (button &GamepadButton) pressed() bool {
	return button.pressed_
}

pub fn (button &GamepadButton) touched() bool {
	return button.touched_
}

pub fn (button &GamepadButton) value() f64 {
	return button.value_
}

pub struct GamepadEventInit {
	dom.EventInit
pub:
	gamepad ?&Gamepad
}

@[heap]
pub struct GamepadEvent {
pub:
	event   &dom.Event
	gamepad ?&Gamepad
}

pub fn GamepadEvent.construct_impl(event_name string, init GamepadEventInit) !&GamepadEvent {
	return &GamepadEvent{
		event:   dom.Event.construct_impl(event_name, init.EventInit)!
		gamepad: init.gamepad
	}
}

pub fn GamepadEvent.create(event_name string, pad ?&Gamepad) &GamepadEvent {
	return &GamepadEvent{
		event:   dom.Event.create(event_name, dom.EventInit{})
		gamepad: pad
	}
}

pub fn (event &GamepadEvent) type_name() string {
	return event.event.type_name()
}
