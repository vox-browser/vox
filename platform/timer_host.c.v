// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// Native registration boundary for Platform::Timer's underlying Core::Timer.
module platform

#flag darwin -framework CoreFoundation
#include "timer_host_bridge.h"

fn C.libweb_v_register_timer(context voidptr, interval_ms int, timeout fn (voidptr)) voidptr
fn C.libweb_v_unregister_timer(timer voidptr)
fn C.libweb_v_pump_native_events(wait_seconds f64)
fn C.libweb_v_is_main_thread() bool

fn native_timer_timeout(context voidptr) {
	mut timer := unsafe { &Timer(context) }
	timer.fire()
}

fn register_native_timer(timer &Timer, interval_ms int) voidptr {
	$if macos {
		return C.libweb_v_register_timer(voidptr(timer), interval_ms, native_timer_timeout)
	} $else {
		return unsafe { nil }
	}
}

fn unregister_native_timer(timer voidptr) {
	$if macos {
		if timer != unsafe { nil } { C.libweb_v_unregister_timer(timer) }
	}
}

pub fn native_timer_scheduling_available() bool {
	$if macos { return true } $else { return false }
}

// Core::EventLoop::pump(WaitForEvents). The Cocoa host services timer and input
// sources on the current thread's run loop, including while XHR spins.
pub fn pump_native_events(wait_seconds f64) {
	$if macos { C.libweb_v_pump_native_events(wait_seconds) }
}
