// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Gamepad.cpp/.h.
module gamepad

import math

const analog_button_press_threshold = 0.1
const gamepad_exposure_axis_threshold = 0.5

@[heap]
pub struct Gamepad {
pub:
	device &Device
pub mut:
	id_                 string
	index_              int
	connected_          bool
	timestamp_          f64
	exposed_            bool
	mapping_            GamepadMappingType
	axes_               []f64
	buttons_            []&GamepadButton
	vibration_actuator_ &GamepadHapticActuator = unsafe { nil }
}

pub fn Gamepad.create(device &Device, index int, timestamp f64) &Gamepad {
	mut pad := &Gamepad{
		device:     device
		id_:        device.name
		index_:     index
		connected_: device.connected
		timestamp_: timestamp
	}
	pad.initialize_axes()
	pad.initialize_buttons()
	pad.select_a_mapping()
	pad.vibration_actuator_ = GamepadHapticActuator.create(pad)
	pad.update_input_state(timestamp)
	return pad
}

pub fn (pad &Gamepad) id() string {
	return pad.id_
}

pub fn (pad &Gamepad) index() int {
	return pad.index_
}

pub fn (pad &Gamepad) connected() bool {
	return pad.connected_
}

pub fn (pad &Gamepad) timestamp() f64 {
	return pad.timestamp_
}

pub fn (pad &Gamepad) exposed() bool {
	return pad.exposed_
}

pub fn (pad &Gamepad) mapping() GamepadMappingType {
	return pad.mapping_
}

pub fn (pad &Gamepad) axes() []f64 {
	return pad.axes_.clone()
}

pub fn (pad &Gamepad) buttons() []&GamepadButton {
	return pad.buttons_.clone()
}

pub fn (pad &Gamepad) vibration_actuator() &GamepadHapticActuator {
	return pad.vibration_actuator_
}

pub fn (pad &Gamepad) sdl_joystick_id() int {
	return pad.device.id
}

// Device is the translated platform boundary corresponding to SDL_Gamepad.
pub fn (pad &Gamepad) sdl_gamepad() &Device {
	return pad.device
}

pub fn (mut pad Gamepad) set_connected(value bool) {
	pad.connected_ = value
}

pub fn (mut pad Gamepad) set_exposed(value bool) {
	pad.exposed_ = value
}

pub fn (mut pad Gamepad) set_timestamp(value f64) {
	pad.timestamp_ = value
}

fn (mut pad Gamepad) initialize_axes() {
	mut maximum_index := -1
	for input in pad.device.axes {
		if input.canonical_index > maximum_index { maximum_index = input.canonical_index }
	}
	pad.axes_ = []f64{len: maximum_index + 1}
}

fn (mut pad Gamepad) initialize_buttons() {
	mut maximum_index := -1
	for input in pad.device.buttons {
		if input.canonical_index > maximum_index { maximum_index = input.canonical_index }
	}
	pad.buttons_ = []&GamepadButton{cap: maximum_index + 1}
	for _ in 0 .. maximum_index + 1 {
		pad.buttons_ << &GamepadButton{}
	}
}

fn (mut pad Gamepad) select_a_mapping() {
	mut seen_axes := map[int]bool{}
	for axis in pad.device.axes {
		seen_axes[axis.canonical_index] = true
	}
	mut seen_buttons := map[int]bool{}
	for button in pad.device.buttons {
		seen_buttons[button.canonical_index] = true
	}
	for index in 0 .. 4 {
		if !seen_axes[index] {
			pad.mapping_ = .empty
			return
		}
	}
	for index in 0 .. 17 {
		if !seen_buttons[index] {
			pad.mapping_ = .empty
			return
		}
	}
	pad.mapping_ = .standard
}

fn normalize_axis(value i16, minimum i16, maximum i16) f64 {
	return 2.0 * (f64(value) - f64(minimum)) / (f64(maximum) - f64(minimum)) - 1.0
}

fn normalize_button(value i16, minimum i16, maximum i16) f64 {
	return (f64(value) - f64(minimum)) / (f64(maximum) - f64(minimum))
}

pub fn (mut pad Gamepad) map_and_normalize_axes() {
	for input in pad.device.axes {
		if input.canonical_index >= 0 && input.canonical_index < pad.axes_.len {
			pad.axes_[input.canonical_index] = normalize_axis(input.value, input.minimum,
				input.maximum)
		}
	}
}

pub fn (mut pad Gamepad) map_and_normalize_buttons() {
	for input in pad.device.buttons {
		if input.canonical_index < 0 || input.canonical_index >= pad.buttons_.len { continue
		 }
		mut button := pad.buttons_[input.canonical_index]
		value := normalize_button(input.value, input.minimum, input.maximum)
		button.set_value(value)
		button.set_pressed(if input.maximum == 1 {
			input.value == input.maximum
		} else {
			value > analog_button_press_threshold
		})
		button.set_touched(button.pressed())
	}
}

pub fn (mut pad Gamepad) update_gamepad_state(timestamp f64) {
	pad.set_timestamp(timestamp)
	pad.map_and_normalize_axes()
	pad.map_and_normalize_buttons()
}

pub fn (mut pad Gamepad) update_input_state(timestamp f64) {
	pad.update_gamepad_state(timestamp)
}

pub fn (pad &Gamepad) contains_gamepad_user_gesture() bool {
	for button in pad.buttons_ {
		if button.pressed() { return true }
	}
	for axis in pad.axes_ {
		if math.abs(axis) > gamepad_exposure_axis_threshold { return true }
	}
	return false
}
