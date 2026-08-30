module gamepad

fn test_navigator_gesture_gating_events_and_index_reuse() {
	mut navigator := NavigatorGamepadPartial.new()
	mut first_device := new_standard_virtual_device(11, 'first')
	first := navigator.handle_gamepad_connected(first_device, 1.0) or { panic('not connected') }
	assert first.index() == 0
	assert navigator.get_gamepads()!.len == 0
	first_device.set_button(0, true)!
	navigator.handle_gamepad_updated(11, 2.0)
	assert navigator.has_gamepad_gesture_
	assert navigator.get_gamepads()!.len == 1
	assert navigator.events().len == 1
	assert navigator.events()[0].type_name() == event_gamepad_connected
	navigator.handle_gamepad_disconnected(11)
	assert !first.connected()
	assert navigator.events().last().type_name() == event_gamepad_disconnected
	second_device := new_standard_virtual_device(12, 'second')
	second := navigator.handle_gamepad_connected(second_device, 3.0) or { panic('not connected') }
	assert second.index() == 0
	assert second.exposed()
}

fn test_exact_navigator_gamepad_gesture_and_connection_scan_entry_points() {
	mut navigator := NavigatorGamepadPartial.new()
	assert !navigator.has_gamepad_gesture()
	navigator.set_has_gamepad_gesture(true)
	assert navigator.has_gamepad_gesture()
	device := new_standard_virtual_device(8, 'discovered')
	navigator.connected_devices_ = [device]
	navigator.now_ = 9
	navigator.check_for_connected_gamepads()
	pads := navigator.get_gamepads()!
	assert pads.len == 1
	discovered := pads[0] or { panic('missing discovered gamepad') }
	assert discovered.timestamp() == 9
	// A second platform scan does not create a duplicate object.
	navigator.check_for_connected_gamepads()
	assert navigator.get_gamepads()!.len == 1
}

fn test_navigator_security_inactive_deduplication_and_test_mode() {
	mut navigator := NavigatorGamepadPartial.new()
	navigator.permission_allowed_ = false
	device := new_standard_virtual_device(1, 'virtual')
	assert navigator.handle_gamepad_connected(device, 0) == none
	if _ := navigator.get_gamepads() {
		assert false
	} else {
		assert err.msg().contains('SecurityError')
	}
	navigator.permission_allowed_ = true
	navigator.has_gamepad_gesture_ = true
	navigator.active_ = false
	assert navigator.get_gamepads()!.len == 0
	navigator.active_ = true
	navigator.test_mode_ = true
	real_device := &Device{
		id:      2
		name:    'real'
		virtual: false
	}
	assert navigator.handle_gamepad_connected(real_device, 0) == none
	assert navigator.handle_gamepad_connected(device, 0) != none
	assert navigator.handle_gamepad_connected(device, 0) == none
}

fn test_get_gamepads_exposes_all_connected_pads_at_current_time() {
	mut navigator := NavigatorGamepadPartial.new()
	device := new_standard_virtual_device(7, 'late exposure')
	pad := navigator.handle_gamepad_connected(device, 1) or { panic('not connected') }
	assert !pad.exposed()
	navigator.has_gamepad_gesture_ = true
	navigator.now_ = 42.5
	assert navigator.get_gamepads()!.len == 1
	assert pad.exposed()
	assert pad.timestamp() == 42.5
}
