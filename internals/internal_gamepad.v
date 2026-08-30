// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of InternalGamepad.cpp/.h using Gamepad's typed virtual-device
// boundary rather than duplicating its state.
module internals

import gamepad

pub const virtual_gamepad_name = 'Ladybird Virtual Gamepad'

@[heap]
pub struct InternalGamepad {
pub:
	device    &gamepad.Device
	navigator &gamepad.NavigatorGamepadPartial
	owner     &Internals
pub mut:
	disconnected_ bool
}

pub fn InternalGamepad.create(id int, navigator &gamepad.NavigatorGamepadPartial, owner &Internals) &InternalGamepad {
	device := gamepad.new_standard_virtual_device(id, virtual_gamepad_name)
	mut mutable_navigator := unsafe { &gamepad.NavigatorGamepadPartial(navigator) }
	mutable_navigator.handle_gamepad_connected(device, mutable_navigator.now_)
	return &InternalGamepad{
		device:    device
		navigator: navigator
		owner:     owner
	}
}

pub fn (internal &InternalGamepad) buttons() []int {
	return [0, 1, 2, 3, 4, 5, 8, 9, 10, 11, 12, 13, 14, 15, 16]
}

pub fn (internal &InternalGamepad) axes() []int {
	return [0, 1, 2, 3]
}

pub fn (internal &InternalGamepad) triggers() []int {
	return [6, 7]
}

pub fn (mut internal InternalGamepad) set_button(button int, down bool) ! {
	if internal.disconnected_ { return error('virtual gamepad is disconnected') }
	mut device := unsafe { &gamepad.Device(internal.device) }
	device.set_button(button, down)!
	mut navigator := unsafe { &gamepad.NavigatorGamepadPartial(internal.navigator) }
	navigator.now_++
	navigator.handle_gamepad_updated(device.id, navigator.now_)
}

pub fn (mut internal InternalGamepad) set_axis(axis int, value i16) ! {
	if internal.disconnected_ { return error('virtual gamepad is disconnected') }
	mut device := unsafe { &gamepad.Device(internal.device) }
	if axis in internal.triggers() {
		device.set_trigger(axis, value)!
	} else {
		device.set_axis(axis, value)!
	}
	mut navigator := unsafe { &gamepad.NavigatorGamepadPartial(internal.navigator) }
	navigator.now_++
	navigator.handle_gamepad_updated(device.id, navigator.now_)
}

pub fn (mut internal InternalGamepad) set_trigger(trigger int, value i16) ! {
	if internal.disconnected_ { return error('virtual gamepad is disconnected') }
	mut device := unsafe { &gamepad.Device(internal.device) }
	device.set_trigger(trigger, value)!
	mut navigator := unsafe { &gamepad.NavigatorGamepadPartial(internal.navigator) }
	navigator.now_++
	navigator.handle_gamepad_updated(device.id, navigator.now_)
}

pub fn (internal &InternalGamepad) get_received_rumble_effects() []gamepad.RumbleEffect {
	return internal.device.received_rumble.clone()
}

pub fn (internal &InternalGamepad) get_received_rumble_trigger_effects() []gamepad.TriggerRumbleEffect {
	return internal.device.received_trigger_rumble.clone()
}

pub fn rumble(mut internal InternalGamepad, low_frequency_rumble u16, high_frequency_rumble u16) bool {
	internal.received_rumble(low_frequency_rumble, high_frequency_rumble)
	return true
}

pub fn rumble_triggers(mut internal InternalGamepad, left_rumble u16, right_rumble u16) bool {
	internal.received_rumble_triggers(left_rumble, right_rumble)
	return true
}

pub fn (mut internal InternalGamepad) received_rumble(low_frequency_rumble u16, high_frequency_rumble u16) {
	mut device := unsafe { &gamepad.Device(internal.device) }
	device.issue_dual_rumble(low_frequency_rumble, high_frequency_rumble)
}

pub fn (mut internal InternalGamepad) received_rumble_triggers(left_rumble u16, right_rumble u16) {
	mut device := unsafe { &gamepad.Device(internal.device) }
	device.issue_trigger_rumble(left_rumble, right_rumble)
}

pub fn (mut internal InternalGamepad) disconnect() {
	if internal.disconnected_ { return }
	mut device := unsafe { &gamepad.Device(internal.device) }
	device.connected = false
	mut navigator := unsafe { &gamepad.NavigatorGamepadPartial(internal.navigator) }
	navigator.handle_gamepad_disconnected(device.id)
	internal.disconnected_ = true
	mut owner := unsafe { &Internals(internal.owner) }
	owner.disconnect_virtual_gamepad(internal)
}
