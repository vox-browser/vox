module internals

import dom

fn activation_callback() {}

fn test_xr_test_device_lifecycle_and_activation_boundary() {
	mut test := XRTest.create()
	promise := test.simulate_device_connection(FakeXRDeviceInit{
		supported_modes:    [.inline, .immersive_vr]
		supported_features: ['viewer', 'local-floor']
	})
	assert promise.state == .fulfilled
	device := promise.device or { panic('device missing') }
	test.simulate_user_activation(activation_callback)
	assert test.activation_callbacks_run_ == 1
	disconnected := device.disconnect()
	assert disconnected.state == .fulfilled
	second := test.simulate_device_connection(FakeXRDeviceInit{}).device or {
		panic('second device missing')
	}

	assert second.id != device.id
	all := test.disconnect_all_devices()
	assert all.state == .fulfilled
}

fn test_web_ui_forwards_name_and_value_to_platform() {
	mut platform := &PlatformState{}
	ui := WebUI.create(platform)
	ui.send_message('ready', dom.js_string('yes'))
	assert platform.web_ui_messages.len == 1
	assert platform.web_ui_messages[0].name == 'ready'
	assert platform.web_ui_messages[0].data.string_data == 'yes'
}
