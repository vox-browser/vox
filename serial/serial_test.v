module serial

import dom

fn test_serial_methods_preserve_current_rejected_promise_boundary() {
	serial_api := Serial.new()
	assert serial_api.request_port(SerialPortRequestOptions{}).state() == .rejected
	assert serial_api.get_ports().result().string_data.starts_with('UnknownError:')
	port := SerialPort.new()
	assert port.state() == .closed
	assert !port.connected()
	assert port.get_info() == SerialPortInfo{}
	for promise in [port.open(SerialOptions{}), port.set_signals(SerialOutputSignals{}),
		port.get_signals(), port.close(), port.forget()] {
		assert promise.state() == dom.PromiseState.rejected
	}
}

fn test_enums_defaults_and_event_handler_storage() {
	assert parity_type_from_string('even')! == .even
	assert ParityType.odd.str() == 'odd'
	assert flow_control_type_from_string('hardware')! == .hardware
	options := SerialOptions{}
	assert options.data_bits or { 0 } == 8
	assert options.stop_bits or { 0 } == 1
	assert options.buffer_size or { 0 } == 255
	serial_api := Serial.new()
	callback := &dom.CallbackType{}
	serial_api.set_onconnect(callback)
	assert serial_api.onconnect() or { panic('missing handler') } == callback
	serial_api.set_onconnect(none)
	assert serial_api.onconnect() == none
}
