// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// ConnectionFromClient.cpp: curl-multi socket callbacks, due-at single-shot
// timer, completion drain and active request ownership. CoreFoundation adapts
// Core::Notifier to the native macOS run loop; request policy remains in Fetch.
module requestserver

import platform
import time

@[heap]
pub struct CurlConnection {
mut:
	multi_ voidptr
	timer_ &platform.Timer = platform.Timer.create()
	// The embedding adapter owns the deferred IPC delivery queue; it uses the
	// translated native EventLoopPlugin without requiring a global LibWeb plugin.
	deferred_     &platform.EventLoopPlugin = platform.EventLoopPlugin.new()
	timer_due_at_ ?i64
	sockets_      map[int]voidptr
	socket_flags_ map[int]int
	requests_     map[u64]&CurlRequest
	next_id_      u64 = 1
	closed_       bool
	in_curl_call_ bool
}

pub fn CurlConnection.create() !&CurlConnection {
	entry := platform.enter_persistent()
	defer { platform.leave_persistent(entry) }
	if C.curl_global_init(C.CURL_GLOBAL_ALL) != C.CURLE_OK {
		return error('Failed to initialize libcurl')
	}
	mut connection := &CurlConnection{ multi_: C.curl_multi_init() }
	if connection.multi_ == unsafe { nil } {
		return error('Failed to initialize curl multi handle')
	}
	check_curl_result(C.vox_curl_multi_setopt_socket(connection.multi_, curl_socket_callback), C.CURLM_OK)
	check_curl_result(C.vox_curl_multi_setopt_pointer(connection.multi_, C.CURLMOPT_SOCKETDATA, connection), C.CURLM_OK)
	check_curl_result(C.vox_curl_multi_setopt_timer(connection.multi_, curl_timeout_callback), C.CURLM_OK)
	check_curl_result(C.vox_curl_multi_setopt_pointer(connection.multi_, C.CURLMOPT_TIMERDATA, connection), C.CURLM_OK)
	connection.timer_ = platform.Timer.create_single_shot(0, fn [mut connection] () {
		if due := connection.timer_due_at_ {
			now := time.sys_mono_now()
			if now < due {
				connection.timer_.restart_with_interval(clamp_curl_interval((due - now) / time.millisecond))
				return
			}
		}
		connection.timer_due_at_ = none
		connection.socket_action(C.CURL_SOCKET_TIMEOUT, 0)
	})
	return connection
}

fn clamp_curl_interval(value i64) int {
	return if value > 2147483647 { 2147483647 } else { int(value) }
}

fn curl_timeout_callback(_ voidptr, timeout_ms i64, owner voidptr) i32 {
	mut connection := unsafe { &CurlConnection(owner) }
	if connection.closed_ { return 0 }
	if timeout_ms == -1 {
		connection.timer_.stop()
		connection.timer_due_at_ = none
	} else {
		assert timeout_ms >= 0
		connection.timer_due_at_ = time.sys_mono_now() + timeout_ms * time.millisecond
		connection.timer_.restart_with_interval(clamp_curl_interval(timeout_ms))
	}
	return 0
}

fn curl_socket_callback(_ voidptr, native_socket i32, native_what i32, owner voidptr, _ voidptr) i32 {
	// Native int arguments occupy 32 bits even when V int is 64 bits. Narrow
	// at the callback boundary before these values become map keys or flags.
	socket := int(native_socket)
	what := int(native_what)
	entry := platform.enter_persistent()
	defer { platform.leave_persistent(entry) }
	mut connection := unsafe { &CurlConnection(owner) }
	$if darwin || linux {
		if what == C.CURL_POLL_REMOVE {
			if descriptor := connection.sockets_[socket] { C.vox_curl_socket_destroy(descriptor) }
			connection.sockets_.delete(socket)
			connection.socket_flags_.delete(socket)
			return 0
		}
		descriptor := connection.sockets_[socket] or {
			created := C.vox_curl_socket_create(connection, i32(socket), curl_socket_activate)
			connection.sockets_[socket] = created
			created
		}
		flags := what & (C.CURL_POLL_IN | C.CURL_POLL_OUT)
		connection.socket_flags_[socket] = flags
		C.vox_curl_socket_set_enabled(descriptor, i32(flags))
	}
	return 0
}

fn curl_socket_activate(owner voidptr, native_socket i32, native_flags i32) {
	socket := int(native_socket)
	flags := int(native_flags)
	mut connection := unsafe { &CurlConnection(owner) }
	connection.socket_action(socket, flags)
	$if darwin || linux {
		if descriptor := connection.sockets_[socket] {
			C.vox_curl_socket_set_enabled(descriptor, i32(connection.socket_flags_[socket]))
		}
	}
}

fn (mut connection CurlConnection) socket_action(socket int, flags int) {
	entry := platform.enter_persistent()
	defer { platform.leave_persistent(entry) }
	if connection.closed_ { return }
	mut running := i32(0)
	connection.in_curl_call_ = true
	check_curl_result(C.curl_multi_socket_action(connection.multi_, i32(socket), i32(flags), &running), C.CURLM_OK)
	connection.in_curl_call_ = false
	for {
		mut result := i32(0)
		pointer := C.vox_curl_next_completion(connection.multi_, &result)
		if pointer == unsafe { nil } { break }
		mut request := unsafe { &CurlRequest(pointer) }
		request.notify_fetch_complete(int(result))
	}
}

pub fn (connection &CurlConnection) active_request_count() int { return connection.requests_.len }

pub fn (mut connection CurlConnection) close() {
	if connection.closed_ { return }
	connection.closed_ = true
	connection.timer_.stop()
	for _, mut request in connection.requests_.clone() { request.stop() }
	$if darwin || linux {
		for _, descriptor in connection.sockets_ { C.vox_curl_socket_destroy(descriptor) }
	}
	connection.sockets_.clear()
	check_curl_result(C.curl_multi_cleanup(connection.multi_), C.CURLM_OK)
	connection.multi_ = unsafe { nil }
}
