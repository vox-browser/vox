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

fn test_incomplete_layout_is_not_standard_and_values_are_clamped() {
	mut device := &Device{
		id:      1
		name:    'one axis'
		axes:    [AxisInput{ canonical_index: 0, value: joystick_axis_max }]
		buttons: [ButtonInput{ canonical_index: 0, value: 3 }]
	}
	pad := Gamepad.create(device, 0, 0)
	assert pad.mapping() == .empty
	assert pad.axes() == [1.0]
	assert pad.buttons()[0].value() == 1.0
}

fn test_gamepad_event_preserves_dom_event_init_and_gamepad() {
	device := new_standard_virtual_device(1, 'pad')
	pad := Gamepad.create(device, 0, 0)
	event := GamepadEvent.construct_impl('custom', GamepadEventInit{
		EventInit: dom.EventInit{
			bubbles:    true
			cancelable: true
			composed:   true
		}
		gamepad:   pad
	})!
	assert event.type_name() == 'custom'
	assert event.event.bubbles()
	assert event.event.cancelable()
	assert event.event.composed()
	assert event.gamepad? == pad
}
