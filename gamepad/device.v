// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// SDL is an embedder dependency, so the translation keeps a concrete, typed
// device record at that boundary. Embedders can update it from SDL; Internals
// uses the same record for deterministic virtual devices.
module gamepad

pub const joystick_axis_min = i16(-32768)
pub const joystick_axis_max = i16(32767)

pub struct AxisInput {
pub:
	canonical_index int
	minimum         i16  = joystick_axis_min
	maximum         i16  = joystick_axis_max
	centred         bool = true
pub mut:
	value i16
}

pub struct ButtonInput {
pub:
	canonical_index int
	minimum         i16
	maximum         i16 = 1
	analog          bool
	neutral         bool = true
pub mut:
	value i16
}

pub struct RumbleEffect {
pub:
	low_frequency  u16
	high_frequency u16
}

pub struct TriggerRumbleEffect {
pub:
	left  u16
	right u16
}

@[heap]
pub struct Device {
pub:
	id                      int
	name                    string
	virtual                 bool
	supports_dual_rumble    bool
	supports_trigger_rumble bool
pub mut:
	connected               bool = true
	axes                    []AxisInput
	buttons                 []ButtonInput
	received_rumble         []RumbleEffect
	received_trigger_rumble []TriggerRumbleEffect
}

pub fn new_standard_virtual_device(id int, name string) &Device {
	mut axes := []AxisInput{cap: 4}
	for index in 0 .. 4 {
		axes << AxisInput{
			canonical_index: index
		}
	}
	mut buttons := []ButtonInput{cap: 17}
	for index in 0 .. 17 {
		if index == 6 || index == 7 {
			buttons << ButtonInput{
				canonical_index: index
				minimum:         0
				maximum:         joystick_axis_max
				analog:          true
			}
		} else {
			buttons << ButtonInput{
				canonical_index: index
			}
		}
	}
	return &Device{
		id:                      id
		name:                    name
		virtual:                 true
		supports_dual_rumble:    true
		supports_trigger_rumble: true
		axes:                    axes
		buttons:                 buttons
	}
}

pub fn (mut device Device) set_button(canonical_index int, down bool) ! {
	for mut button in device.buttons {
		if button.canonical_index == canonical_index {
			button.value = if down { button.maximum } else { button.minimum }
			return
		}
	}
	return error('unknown gamepad button ${canonical_index}')
}

pub fn (mut device Device) set_axis(canonical_index int, value i16) ! {
	for mut axis in device.axes {
		if axis.canonical_index == canonical_index {
			axis.value = value
			return
		}
	}
	return error('unknown gamepad axis ${canonical_index}')
}

pub fn (mut device Device) set_trigger(canonical_index int, value i16) ! {
	for mut button in device.buttons {
		if button.canonical_index == canonical_index && button.analog {
			button.value = value
			return
		}
	}
	return error('unknown gamepad trigger ${canonical_index}')
}

pub fn (mut device Device) issue_dual_rumble(low u16, high u16) bool {
	if !device.connected || !device.supports_dual_rumble {
		return false
	}
	device.received_rumble << RumbleEffect{low, high}
	return true
}

pub fn (mut device Device) issue_trigger_rumble(left u16, right u16) bool {
	if !device.connected || !device.supports_trigger_rumble {
		return false
	}
	device.received_trigger_rumble << TriggerRumbleEffect{left, right}
	return true
}
