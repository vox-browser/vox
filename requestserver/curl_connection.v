// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// ConnectionFromClient.cpp: curl-multi socket callbacks, due-at single-shot
// timer, completion drain and active request ownership. CoreFoundation adapts
// Core::Notifier to the native macOS run loop; request policy remains in Fetch.
@[has_globals]
module requestserver

import fetch
import os
import platform
import time

// Leave descriptors for the window, document loader, and dispatch socket
// duplicates under LaunchServices' 256-descriptor soft limit. libcurl queues
// excess transfers and still multiplexes streams on established connections.
const curl_max_total_connections = 32

// Fetch's "obtain a connection" reuses a connection whose network partition key
// and credentials match. A document's XHR, Fetch and module hosts, its iframes'
// hosts and child navigations each owned a curl multi handle, so every one of
// them opened (and handshook) its own connection to an origin the page was
// already multiplexing on. Pooled connections start main-thread transfers on
// one shared multi handle per pool key; worker threads keep their own.
const retain_separate_curl_connections = os.getenv('VOX_RETAIN_SEPARATE_CURL_CONNECTIONS') != ''
const curl_connection_pool_limit = 8

__global curl_connection_pools_ = map[string]&CurlConnection{}

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
	// A pooled client owns no multi handle while it can route transfers to a
	// shared one; it stops only its own transfers when it closes.
	pooled_ bool
}

pub fn CurlConnection.create() !&CurlConnection {
	entry := platform.enter_persistent()
	defer { platform.leave_persistent(entry) }
	mut connection := &CurlConnection{}
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

// A script host's connection: transfers share the page's established
// connections. VOX_RETAIN_SEPARATE_CURL_CONNECTIONS restores one per host.
pub fn CurlConnection.create_pooled() !&CurlConnection {
	mut connection := CurlConnection.create()!
	connection.pooled_ = !retain_separate_curl_connections
	return connection
}

fn curl_connection_pool_key(request &fetch.Request) ?string {
	partition := fetch.determine_the_http_cache_partition(request) or { return none }
	return '${partition.top_level_origin.serialize_for_ipc()}\n${request.includes_credentials()}'
}

// The shared connection for a request's pool key. Its sockets and timer belong
// to the main run loop, so other threads (and unpartitioned requests) use the
// client's own multi handle.
fn shared_curl_connection(request &fetch.Request) ?&CurlConnection {
	if !platform.is_main_thread() { return none }
	key := curl_connection_pool_key(request) or { return none }
	if pool := curl_connection_pools_[key] {
		if !pool.closed_ { return pool }
	}
	if curl_connection_pools_.len >= curl_connection_pool_limit {
		for pool_key in curl_connection_pools_.keys() {
			mut idle := curl_connection_pools_[pool_key] or { continue }
			if idle.requests_.len == 0 && !idle.in_curl_call_ {
				idle.close()
				curl_connection_pools_.delete(pool_key)
			}
		}
	}
	pool := CurlConnection.create() or { return none }
	curl_connection_pools_[key] = pool
	return pool
}

// Initializing libcurl maps it with its TLS, HTTP/2, HTTP/3 and compression
// libraries. Script hosts create connections for every scripted document, but
// most make no curl transfer, so the multi handle is created with the first.
fn (mut connection CurlConnection) ensure_multi() ! {
	if connection.multi_ != unsafe { nil } { return }
	if C.vox_curl_global_init(C.CURL_GLOBAL_ALL) != C.CURLE_OK {
		return error('Failed to initialize libcurl')
	}
	multi := C.vox_curl_multi_init()
	if multi == unsafe { nil } {
		return error('Failed to initialize curl multi handle')
	}
	connection.multi_ = multi
	check_curl_result(C.vox_curl_multi_setopt_long(multi, C.CURLMOPT_MAX_TOTAL_CONNECTIONS,
		curl_max_total_connections), C.CURLM_OK)
	check_curl_result(C.vox_curl_multi_setopt_socket(multi, curl_socket_callback), C.CURLM_OK)
	check_curl_result(C.vox_curl_multi_setopt_pointer(multi, C.CURLMOPT_SOCKETDATA, &connection), C.CURLM_OK)
	check_curl_result(C.vox_curl_multi_setopt_timer(multi, curl_timeout_callback), C.CURLM_OK)
	check_curl_result(C.vox_curl_multi_setopt_pointer(multi, C.CURLMOPT_TIMERDATA, &connection), C.CURLM_OK)
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
	check_curl_result(C.vox_curl_multi_socket_action(connection.multi_, i32(socket), i32(flags), &running), C.CURLM_OK)
	connection.in_curl_call_ = false
	for {
		mut result := i32(0)
		pointer := C.vox_curl_next_completion(connection.multi_, &result)
		if pointer == unsafe { nil } { break }
		mut request := unsafe { &CurlRequest(pointer) }
		request.notify_fetch_complete(int(result))
	}
}

pub fn (connection &CurlConnection) active_request_count() int {
	mut count := connection.requests_.len
	if connection.pooled_ && platform.is_main_thread() {
		for _, pool in curl_connection_pools_ {
			for _, request in pool.requests_ {
				if request.owner_ == voidptr(connection) { count++ }
			}
		}
	}
	return count
}

pub fn (mut connection CurlConnection) close() {
	if connection.closed_ { return }
	connection.closed_ = true
	connection.timer_.stop()
	for _, mut request in connection.requests_.clone() { request.stop() }
	if connection.pooled_ && platform.is_main_thread() {
		for _, pool in curl_connection_pools_ {
			for _, mut request in pool.requests_.clone() {
				if request.owner_ == voidptr(&connection) { request.stop() }
			}
		}
	}
	$if darwin || linux {
		for _, descriptor in connection.sockets_ { C.vox_curl_socket_destroy(descriptor) }
	}
	connection.sockets_.clear()
	if connection.multi_ != unsafe { nil } {
		check_curl_result(C.vox_curl_multi_cleanup(connection.multi_), C.CURLM_OK)
		connection.multi_ = unsafe { nil }
	}
}
