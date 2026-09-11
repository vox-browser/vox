module gamepad

import dom

fn test_standard_device_initializes_and_normalizes_state() {
	mut device := new_standard_virtual_device(7, 'Test Pad')
	mut pad := Gamepad.create(device, 2, 10.0)
	assert pad.id() == 'Test Pad'
	assert pad.index() == 2
	assert pad.connected()
	assert pad.mapping() == .standard
	assert pad.mapping().idl_string() == 'standard'
	assert pad.axes().len == 4
	assert pad.buttons().len == 17
	device.set_axis(0, joystick_axis_max)!
	device.set_axis(1, joystick_axis_min)!
	device.set_button(0, true)!
	device.set_trigger(6, i16(16384))!
	pad.update_input_state(12.5)
	assert pad.timestamp() == 12.5
	assert pad.axes()[0] == 1.0
	assert pad.axes()[1] == -1.0
	assert pad.buttons()[0].pressed()
	assert pad.buttons()[0].touched()
	assert pad.buttons()[0].value() == 1.0
	assert pad.buttons()[6].pressed()
	assert pad.buttons()[6].value() > 0.5
	assert pad.contains_gamepad_user_gesture()
}

fn test_incomplete_layout_is_not_standard_and_uses_upstream_normalization_formula() {
	mut device := &Device{
		id: 1
		name: 'one axis'
		axes: [AxisInput{ canonical_index: 0, value: joystick_axis_max }]
		buttons: [ButtonInput{ canonical_index: 0, value: 3 }]
	}
	pad := Gamepad.create(device, 0, 0)
	assert pad.mapping() == .empty
	assert pad.axes() == [1.0]
	assert pad.buttons()[0].value() == 3.0
}

fn test_gamepad_event_preserves_dom_event_init_and_gamepad() {
	device := new_standard_virtual_device(1, 'pad')
	pad := Gamepad.create(device, 0, 0)
	event := GamepadEvent.construct_impl('custom', GamepadEventInit{
		EventInit: dom.EventInit{
			bubbles: true
			cancelable: true
			composed: true
		}
		gamepad: pad
	})!
	assert event.type_name() == 'custom'
	assert event.event.bubbles()
	assert event.event.cancelable()
	assert event.event.composed()
	assert event.gamepad()? == pad
}

fn test_exact_gamepad_state_entry_points_and_platform_accessors() {
	mut device := new_standard_virtual_device(17, 'exact methods')
	mut pad := Gamepad.create(device, 0, 1)
	assert pad.sdl_joystick_id() == 17
	assert voidptr(pad.sdl_gamepad()) == voidptr(device)
	pad.set_connected(false)
	pad.set_exposed(true)
	pad.set_timestamp(2)
	assert !pad.connected()
	assert pad.exposed()
	assert pad.timestamp() == 2
	device.set_axis(0, joystick_axis_max)!
	device.set_button(0, true)!
	pad.map_and_normalize_axes()
	pad.map_and_normalize_buttons()
	assert pad.axes()[0] == 1.0
	assert pad.buttons()[0].pressed()
	device.set_axis(0, joystick_axis_min)!
	pad.update_gamepad_state(3)
	assert pad.timestamp() == 3
	assert pad.axes()[0] == -1.0

	mut button := &GamepadButton{}
	button.set_pressed(true)
	button.set_touched(true)
	button.set_value(0.75)
	assert button.pressed()
	assert button.touched()
	assert button.value() == 0.75
}

fn test_gamepad_window_button_factory_and_event_offset() {
	window := GamepadWindow.create('test-window')
	device := new_standard_virtual_device(22, 'window pad')
	pad := Gamepad.create_with_window(window, device, 0, 0)
	assert pad.window() == window
	assert GamepadButton.create().value() == 0
	event := GamepadEvent.create_with_timestamp('gamepadconnected', GamepadEventInit{
		gamepad: pad
	}, 12.5)
	assert event.gamepad()? == pad
	assert event.event.time_stamp() == 12.5
	assert GamepadEvent.gamepad_offset() > 0
}
