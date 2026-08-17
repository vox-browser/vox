module internals

import gamepad

fn test_internal_gamepad_integrates_with_public_gamepad_api() {
	mut navigator := gamepad.NavigatorGamepadPartial.new()
	navigator.test_mode_ = true
	mut platform := &PlatformState{}
	mut api := Internals.create(platform, navigator)
	mut virtual := api.connect_virtual_gamepad()
	assert virtual.buttons().len == 15
	assert virtual.axes() == [0, 1, 2, 3]
	assert virtual.triggers() == [6, 7]
	assert navigator.get_gamepads()!.len == 0
	virtual.set_button(0, true)!
	gamepads := navigator.get_gamepads()!
	assert gamepads.len == 1
	public_gamepad := gamepads[0] or { panic('missing public gamepad') }
	assert public_gamepad.id() == virtual_gamepad_name
	assert public_gamepad.buttons()[0].pressed()
	virtual.set_axis(0, gamepad.joystick_axis_max)!
	assert public_gamepad.axes()[0] == 1
	// setAxis is the sole IDL mutation operation for both stick and trigger axes.
	virtual.set_axis(6, gamepad.joystick_axis_max)!
	assert public_gamepad.buttons()[6].value() == 1
	mut actuator := public_gamepad.vibration_actuator()
	promise := actuator.play_effect(.dual_rumble, gamepad.GamepadEffectParameters{
		duration:         1
		strong_magnitude: 1
	}, true, true)
	assert actuator.complete_pending_effect()
	assert promise.result? == .complete
	assert virtual.get_received_rumble_effects().len == 2
	virtual.disconnect()
	assert virtual.disconnected_
	assert navigator.gamepads_.len == 0
	assert api.gamepads_.len == 0
}

fn test_per_test_cleanup_disconnects_all_gamepads() {
	mut navigator := gamepad.NavigatorGamepadPartial.new()
	mut platform := &PlatformState{}
	mut api := Internals.create(platform, navigator)
	first := api.connect_virtual_gamepad()
	second := api.connect_virtual_gamepad()
	api.signal_test_is_done('PASS')
	assert first.disconnected_
	assert second.disconnected_
	assert api.gamepads_.len == 0
	assert platform.test_done_text == 'PASS'
}
