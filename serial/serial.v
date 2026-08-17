// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Serial/Serial.{h,cpp,idl}.
module serial

import dom

pub struct SerialPortFilter {
pub:
	usb_vendor_id              ?u16
	usb_product_id             ?u16
	bluetooth_service_class_id ?string
}

pub struct SerialPortRequestOptions {
pub:
	filters                             ?[]SerialPortFilter
	allowed_bluetooth_service_class_ids ?[]string
}

@[heap]
pub struct Serial {
	dom.EventTarget
}

pub fn Serial.new() &Serial {
	return &Serial{
		EventTarget: dom.EventTarget{}
	}
}

fn rejected_unknown_error() &dom.Promise {
	return dom.Promise.rejected(dom.js_string('UnknownError:'))
}

// Current upstream deliberately returns rejected UnknownError promises while
// platform enumeration and prompting are FIXME.
pub fn (_ &Serial) request_port(_ SerialPortRequestOptions) &dom.Promise {
	return rejected_unknown_error()
}

pub fn (_ &Serial) get_ports() &dom.Promise {
	return rejected_unknown_error()
}

pub fn (serial_api &Serial) set_onconnect(handler ?&dom.CallbackType) {
	serial_api.EventTarget.set_event_handler_attribute('connect', handler)
}

pub fn (serial_api &Serial) onconnect() ?&dom.CallbackType {
	return serial_api.EventTarget.event_handler_attribute('connect')
}

pub fn (serial_api &Serial) set_ondisconnect(handler ?&dom.CallbackType) {
	serial_api.EventTarget.set_event_handler_attribute('disconnect', handler)
}

pub fn (serial_api &Serial) ondisconnect() ?&dom.CallbackType {
	return serial_api.EventTarget.event_handler_attribute('disconnect')
}
