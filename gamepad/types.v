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

pub fn GamepadButton.create() &GamepadButton {
	return &GamepadButton{}
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

pub fn (mut button GamepadButton) set_pressed(value bool) {
	button.pressed_ = value
}

pub fn (mut button GamepadButton) set_touched(value bool) {
	button.touched_ = value
}

pub fn (mut button GamepadButton) set_value(value f64) {
	button.value_ = value
}

pub struct GamepadEventInit {
	dom.EventInit
pub:
	gamepad ?&Gamepad
}

@[heap]
pub struct GamepadEvent {
pub:
	event    &dom.Event
	gamepad_ ?&Gamepad
}

pub fn GamepadEvent.construct_impl(event_name string, init GamepadEventInit) !&GamepadEvent {
	base := dom.Event.construct_impl(event_name, init.EventInit)!
	return GamepadEvent.create_with_timestamp(event_name, init, base.time_stamp())
}

pub fn GamepadEvent.create(event_name string, pad ?&Gamepad) &GamepadEvent {
	return GamepadEvent.create_with_timestamp(event_name, GamepadEventInit{
		gamepad: pad
	}, 0)
}

pub fn GamepadEvent.create_with_timestamp(event_name string, init GamepadEventInit, time_stamp f64) &GamepadEvent {
	mut event := dom.Event.create(event_name, init.EventInit)
	event.set_time_stamp(time_stamp)
	return &GamepadEvent{
		event: event
		gamepad_: init.gamepad
	}
}

pub fn GamepadEvent.gamepad_offset() uint {
	return uint(__offsetof(GamepadEvent, gamepad_))
}

pub fn (event &GamepadEvent) gamepad() ?&Gamepad {
	return event.gamepad_
}

pub fn (event &GamepadEvent) type_name() string {
	return event.event.type_name()
}
