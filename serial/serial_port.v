// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Serial/SerialPort.{h,cpp,idl}.
module serial

import dom

pub enum ParityType {
	none
	even
	odd
}

pub enum FlowControlType {
	none
	hardware
}

pub fn parity_type_from_string(value string) !ParityType {
	return match value {
		'none' { .none }
		'even' { .even }
		'odd' { .odd }
		else { error('Invalid ParityType: ${value}') }
	}
}

pub fn (value ParityType) str() string {
	return match value {
		.none { 'none' }
		.even { 'even' }
		.odd { 'odd' }
	}
}

pub fn flow_control_type_from_string(value string) !FlowControlType {
	return match value {
		'none' { .none }
		'hardware' { .hardware }
		else { error('Invalid FlowControlType: ${value}') }
	}
}

pub fn (value FlowControlType) str() string {
	return match value {
		.none { 'none' }
		.hardware { 'hardware' }
	}
}

pub struct SerialOptions {
pub:
	baud_rate    ?u32
	data_bits    ?u8 = u8(8)
	stop_bits    ?u8 = u8(1)
	parity       ?ParityType = ParityType.none
	buffer_size  ?u32 = u32(255)
	flow_control ?FlowControlType = FlowControlType.none
}

pub struct SerialOutputSignals {
pub:
	data_terminal_ready ?bool
	request_to_send     ?bool
	break_              ?bool
}

pub struct SerialInputSignals {
pub:
	data_carrier_detect bool
	clear_to_send       bool
	ring_indicator      bool
	data_set_ready      bool
}

pub struct SerialPortInfo {
pub:
	usb_vendor_id              ?u16
	usb_product_id             ?u16
	bluetooth_service_class_id ?string
}

pub enum SerialPortState {
	closed
	opening
	opened
	closing
	forgetting
	forgotten
}

@[heap]
pub struct SerialPort {
	dom.EventTarget
mut:
	state_       SerialPortState
	buffer_size_ u32
	connected_   bool
	readable_    ?voidptr
	read_fatal_  bool
	writable_    ?voidptr
	write_fatal_ bool
}

pub fn SerialPort.new() &SerialPort {
	return &SerialPort{
		EventTarget: dom.EventTarget{}
	}
}

pub fn (_ &SerialPort) get_info() SerialPortInfo {
	return SerialPortInfo{}
}

// These methods preserve the current upstream implementation: their specified
// algorithms are marked FIXME and each returns a rejected UnknownError promise.
pub fn (_ &SerialPort) open(_ SerialOptions) &dom.Promise {
	return reject_unknown_error()
}

pub fn (_ &SerialPort) set_signals(_ SerialOutputSignals) &dom.Promise {
	return reject_unknown_error()
}

pub fn (_ &SerialPort) get_signals() &dom.Promise {
	return reject_unknown_error()
}

pub fn (_ &SerialPort) close() &dom.Promise {
	return reject_unknown_error()
}

pub fn (_ &SerialPort) forget() &dom.Promise {
	return reject_unknown_error()
}

pub fn (port &SerialPort) state() SerialPortState {
	return port.state_
}

pub fn (port &SerialPort) connected() bool {
	return port.connected_
}

pub fn (port &SerialPort) readable() ?voidptr {
	return port.readable_
}

pub fn SerialPort.readable_offset() uint {
	return uint(__offsetof(SerialPort, readable_))
}

pub fn (port &SerialPort) writable() ?voidptr {
	return port.writable_
}

pub fn SerialPort.writable_offset() uint {
	return uint(__offsetof(SerialPort, writable_))
}

pub fn (port &SerialPort) set_onconnect(handler ?&dom.CallbackType) {
	port.EventTarget.set_event_handler_attribute('connect', handler)
}

pub fn (port &SerialPort) onconnect() ?&dom.CallbackType {
	return port.EventTarget.event_handler_attribute('connect')
}

pub fn (port &SerialPort) set_ondisconnect(handler ?&dom.CallbackType) {
	port.EventTarget.set_event_handler_attribute('disconnect', handler)
}

pub fn (port &SerialPort) ondisconnect() ?&dom.CallbackType {
	return port.EventTarget.event_handler_attribute('disconnect')
}
