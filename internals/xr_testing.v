// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of FakeXRDevice and XRTest. WebXR device registration remains a
// deliberate host boundary, matching the FIXMEs in the upstream implementation.
module internals

pub enum XRSessionMode {
	inline
	immersive_vr
	immersive_ar
}

pub enum XRPromiseState {
	pending
	fulfilled
	rejected
}

pub struct FakeXRDeviceInit {
pub:
	supported_modes    ?[]XRSessionMode
	supported_features ?[]string
}

@[heap]
pub struct FakeXRDevice {
pub:
	id int
}

@[heap]
pub struct XRPromise {
pub mut:
	state  XRPromiseState
	device ?&FakeXRDevice
	error_ string
}

pub fn (device &FakeXRDevice) disconnect() &XRPromise {
	return &XRPromise{
		state: .fulfilled
	}
}

@[heap]
pub struct XRTest {
pub mut:
	next_id_ int = 1
	// Observable test instrumentation for the otherwise host-owned activation.
	activation_callbacks_run_ int
}

pub fn XRTest.create() &XRTest {
	return &XRTest{}
}

pub fn (mut xr XRTest) simulate_device_connection(init FakeXRDeviceInit) &XRPromise {
	_ = init
	device := &FakeXRDevice{
		id: xr.next_id_
	}
	xr.next_id_++
	return &XRPromise{
		state:  .fulfilled
		device: device
	}
}

pub fn (mut xr XRTest) simulate_user_activation(callback fn ()) {
	callback()
	xr.activation_callbacks_run_++
}

pub fn (mut xr XRTest) disconnect_all_devices() &XRPromise {
	return &XRPromise{
		state: .fulfilled
	}
}
