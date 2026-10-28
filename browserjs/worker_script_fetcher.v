// SPDX-License-Identifier: BSD-2-Clause
// Synchronous worker script loading over the actual asynchronous Fetch pipeline.
module browserjs

import fetch
import html
import platform
import requestserver
import time

@[heap]
pub struct WorkerScriptFetcher {
	settings &html.EnvironmentSettingsObject
	transport &fetch.FetchHost
	timeout_ms int
mut:
	connection ?&requestserver.CurlConnection
	controller ?&fetch.FetchController
	busy bool
	closed bool
}

@[heap]
struct WorkerScriptFetchResult {
mut:
	response ?&fetch.Response
	failed bool
	done bool
}

pub fn WorkerScriptFetcher.create(settings &html.EnvironmentSettingsObject, transport &fetch.FetchHost, timeout_ms int) !&WorkerScriptFetcher {
	loop := settings.responsible_event_loop()
	if settings.responsible_document() != none || loop.type_() != .worker ||
		voidptr(loop) == voidptr(html.main_thread_event_loop()) {
		return error('Worker script fetching requires a separate worker event loop')
	}
	if timeout_ms <= 0 { return error('Worker script fetch timeout must be positive') }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	return &WorkerScriptFetcher{settings: settings, transport: transport, timeout_ms: timeout_ms}
}

pub fn WorkerScriptFetcher.create_native(settings &html.EnvironmentSettingsObject, timeout_ms int) !&WorkerScriptFetcher {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut connection := requestserver.CurlConnection.create()!
	mut host := WorkerScriptFetcher.create(settings, connection.fetch_host(), timeout_ms) or {
		connection.close()
		return err
	}
	host.connection = connection
	return host
}

pub fn (mut host WorkerScriptFetcher) close() {
	if host.closed { return }
	host.closed = true
	if mut controller := host.controller { controller.stop_fetch() }
	if mut connection := host.connection { connection.close() }
}

// The dedicated process services network callbacks on the main native loop.
// Never spin the worker loop here: importScripts must not deliver messages,
// timers or microtasks while its JavaScript caller is still on the stack.
pub fn (mut host WorkerScriptFetcher) perform(request &fetch.Request) !&fetch.Response {
	if host.closed { return error('NetworkError: worker script fetcher is closed') }
	if host.busy { return error('NetworkError: worker script fetch is already in progress') }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	host.busy = true
	defer { host.busy = false; host.controller = none }
	mut loop := host.settings.responsible_event_loop()
	already_paused := loop.execution_paused()
	mut pause := ?&html.PauseHandle(none)
	if !already_paused { pause = loop.pause() }
	defer { if handle := pause { loop.unpause(handle) } }
	result := &WorkerScriptFetchResult{}
	result_ptr := voidptr(result)
	callback := fn [result_ptr] (response &fetch.Response, body fetch.BodyBytes) {
		entry := platform.enter_persistent()
		defer { platform.leave_persistent(entry) }
		mut result := unsafe { &WorkerScriptFetchResult(result_ptr) }
		result.failed = body.kind == .failure
		if body.kind == .bytes {
			mut actual := unsafe { &fetch.Response(response) }
			actual.set_body_bytes(body.bytes)
		}
		result.response = response
		result.done = true
	}
	algorithms := fetch.FetchAlgorithms.create(fetch.FetchAlgorithmsInput{process_response_consume_body: callback})
	mut controller := fetch.fetch_with_parallel_queue(request, algorithms, host.transport, .yes, .no)
	host.controller = controller
	defer {
		controller.stop_fetch()
		platform.release_closure(voidptr(callback))
	}
	deadline := time.sys_mono_now() + i64(host.timeout_ms) * time.millisecond
	for !result.done && !host.closed && time.sys_mono_now() < deadline {
		platform.pump_native_events(0.01)
	}
	if host.closed { return error('NetworkError: worker script fetcher is closed') }
	if !result.done { return error('NetworkError: worker script fetch timed out') }
	if result.failed { return error('NetworkError: worker script response body failed') }
	return result.response or { return error('NetworkError: worker script response is missing') }
}
