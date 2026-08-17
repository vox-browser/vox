// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of NavigatorGamepad.cpp/.h. Upstream queues gamepad tasks; this
// standalone translation processes one platform notification atomically and
// exposes the resulting typed events for the host event loop to dispatch.
module gamepad

@[heap]
pub struct NavigatorGamepadPartial {
pub mut:
	active_              bool = true
	permission_allowed_  bool = true
	test_mode_           bool
	has_gamepad_gesture_ bool
	gamepads_            []?&Gamepad
	available_           map[int]bool
	events_              []&GamepadEvent
	now_                 f64
}

pub fn NavigatorGamepadPartial.new() &NavigatorGamepadPartial {
	return &NavigatorGamepadPartial{}
}

pub fn (mut navigator NavigatorGamepadPartial) get_gamepads() ![]?&Gamepad {
	if !navigator.active_ { return []?&Gamepad{} }
	if !navigator.permission_allowed_ { return error('SecurityError: Not allowed to use gamepads') }
	if !navigator.has_gamepad_gesture_ { return []?&Gamepad{} }
	for slot in navigator.gamepads_ {
		if mut pad := slot {
			if !pad.exposed_ {
				pad.exposed_ = true
				pad.timestamp_ = navigator.now_
			}
		}
	}
	return navigator.gamepads_.clone()
}

pub fn (mut navigator NavigatorGamepadPartial) select_an_unused_gamepad_index() int {
	for index, slot in navigator.gamepads_ {
		if slot == none { return index }
	}
	navigator.gamepads_ << none
	return navigator.gamepads_.len - 1
}

pub fn (mut navigator NavigatorGamepadPartial) handle_gamepad_connected(device &Device, timestamp f64) ?&Gamepad {
	if device.id in navigator.available_ || !navigator.permission_allowed_ { return none }
	if navigator.test_mode_ && !device.virtual { return none }
	navigator.available_[device.id] = true
	index := navigator.select_an_unused_gamepad_index()
	mut pad := Gamepad.create(device, index, timestamp)
	navigator.gamepads_[index] = pad
	if navigator.has_gamepad_gesture_ {
		pad.exposed_ = true
		if navigator.active_ {
			navigator.events_ << GamepadEvent.create(event_gamepad_connected, pad)
		}
	}
	return pad
}

pub fn (mut navigator NavigatorGamepadPartial) handle_gamepad_updated(device_id int, timestamp f64) {
	for slot in navigator.gamepads_ {
		if mut pad := slot {
			if pad.device.id != device_id { continue
			 }
			pad.update_input_state(timestamp)
			if !navigator.has_gamepad_gesture_ && pad.contains_gamepad_user_gesture() {
				navigator.has_gamepad_gesture_ = true
				for connected_slot in navigator.gamepads_ {
					if mut connected := connected_slot {
						connected.exposed_ = true
						connected.timestamp_ = timestamp
						if navigator.active_ {
							navigator.events_ << GamepadEvent.create(event_gamepad_connected,
								connected)
						}
					}
				}
			}
			return
		}
	}
}

pub fn (mut navigator NavigatorGamepadPartial) handle_gamepad_disconnected(device_id int) {
	navigator.available_.delete(device_id)
	for index, slot in navigator.gamepads_ {
		if mut pad := slot {
			if pad.device.id != device_id { continue
			 }
			pad.connected_ = false
			if pad.exposed_ && navigator.active_ {
				navigator.events_ << GamepadEvent.create(event_gamepad_disconnected, pad)
			}
			navigator.gamepads_[index] = none
			break
		}
	}
	for navigator.gamepads_.len > 0 && navigator.gamepads_.last() == none {
		navigator.gamepads_.delete_last()
	}
}

pub fn (navigator &NavigatorGamepadPartial) events() []&GamepadEvent {
	return navigator.events_.clone()
}
