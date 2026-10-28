module browserjs

import dom
import fetch
import html
import http
import net
import platform
import time

fn worker_script_fetch_settings(url string) &html.EnvironmentSettingsObject {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	parsed := dom.URL{value: url}
	mut realm := &html.ScriptingRealm{}
	scope := html.DedicatedWorkerGlobalScope.create(parsed, html.WorkerOptions{}, realm)
	return html.WorkerEnvironmentSettingsObject.setup(&scope.WorkerGlobalScope, mut realm,
		html.SerializedEnvironmentSettingsObject{
			creation_url: parsed
			api_base_url: parsed
			origin: parsed.origin()
			global: html.SerializedWorkerGlobalScope{relevant_settings_object_is_secure_context: true}
		}, 12).settings
}

fn worker_script_fetch_request(settings &html.EnvironmentSettingsObject, url string) &fetch.Request {
	mut request := fetch.Request.create()
	request.set_url(dom.URL{value: url})
	request.set_client(settings)
	request.destination = .script
	request.cache_mode = .no_store
	return request
}

fn serve_worker_script_redirect(mut listener net.TcpListener) {
	for path in ['/entry.js', '/agents/main.js'] {
		mut socket := listener.accept() or { panic(err) }
		mut input := []u8{len: 4096}
		length := socket.read(mut input) or { panic(err) }
		assert input[..length].bytestr().starts_with('GET ${path} HTTP/1.1\r\n')
		if path == '/entry.js' {
			socket.write_string('HTTP/1.1 302 Found\r\nLocation: /agents/main.js\r\nContent-Length: 0\r\nConnection: close\r\n\r\n') or { panic(err) }
		} else {
			body := 'self.city="Санкт-Петербург 😀";'
			socket.write_string('HTTP/1.1 200 OK\r\nContent-Type: text/javascript\r\nContent-Length: ${body.len}\r\nConnection: close\r\n\r\n') or { panic(err) }
			socket.write(body.bytes()[..10]) or { panic(err) }
			socket.write(body.bytes()[10..]) or { panic(err) }
		}
		socket.close() or {}
	}
}

fn test_worker_script_fetcher_uses_native_fetch_redirects_and_complete_utf8_bodies() {
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	defer { listener.close() or {} }
	server := spawn serve_worker_script_redirect(mut listener)
	base := 'http://${listener.addr()!}'
	settings := worker_script_fetch_settings(base + '/entry.js')
	mut host := WorkerScriptFetcher.create_native(settings, 5000)!
	defer { host.close() }
	mut request := worker_script_fetch_request(settings, base + '/entry.js')
	request.mode = .same_origin
	response := host.perform(request)!
	assert response.status == 200
	assert response.unsafe_response().url()?.serialize() == base + '/agents/main.js'
	assert response.unsafe_response().fetch_response_body_bytes()?.bytestr() == 'self.city="Санкт-Петербург 😀";'
	assert host.connection?.active_request_count() == 0
	assert !settings.responsible_event_loop().execution_paused()
	assert !host.busy
	server.wait()
}

@[heap]
struct WorkerScriptFetchTestState {
mut:
	timer ?&platform.Timer
	controller ?&fetch.FetchController
	paused bool
	order []string
}

fn worker_script_delayed_transport(settings &html.EnvironmentSettingsObject, state_ptr &WorkerScriptFetchTestState) &fetch.FetchHost {
	return &fetch.FetchHost{
		perform: fn (_ &fetch.Request) !&fetch.Response { panic('blocking network transport was used') }
		perform_async_with_params: fn [settings, state_ptr] (params &fetch.FetchParams, request &fetch.Request) &fetch.PendingResponse {
			assert request.client_present && !request.client_is_window
			assert (request.client_creation_url or { panic("Missing client creation URL") }) == settings.fetch_request_client_creation_url()
			mut actual_request := unsafe { &fetch.Request(request) }
			pending := fetch.PendingResponse.create(mut actual_request, none)
			mut state := unsafe { &WorkerScriptFetchTestState(state_ptr) }
			state.controller = params.fetch_params_controller()
			pending_ptr := voidptr(pending)
			mut timer := platform.Timer.create_single_shot(10, fn [settings, state_ptr, pending_ptr] () {
				mut state := unsafe { &WorkerScriptFetchTestState(state_ptr) }
				state.paused = settings.responsible_event_loop().execution_paused()
				state.order << 'network'
				mut response := fetch.Response.create()
				response.header_list.append(http.Header{name: 'Content-Type', value: 'text/javascript'})
				response.set_body_bytes('self.ready=true;'.bytes())
				mut pending := unsafe { &fetch.PendingResponse(pending_ptr) }
				pending.resolve(response)
			})
			state.timer = timer
			timer.start()
			return pending
		}
	}
}

fn test_worker_script_fetcher_does_not_reenter_worker_tasks_or_microtasks() {
	settings := worker_script_fetch_settings('https://worker-script-fetch.test/main.js')
	state := &WorkerScriptFetchTestState{}
	mut host := WorkerScriptFetcher.create(settings, worker_script_delayed_transport(settings, state), 1000)!
	defer { host.close() }
	mut loop := settings.responsible_event_loop()
	state_ptr := voidptr(state)
	html.queue_a_task(.posted_message, loop, none, fn [state_ptr] () {
		mut state := unsafe { &WorkerScriptFetchTestState(state_ptr) }
		state.order << 'message'
	})
	loop.enqueue_microtask(html.Task.create(.microtask, none, fn [state_ptr] () {
		mut state := unsafe { &WorkerScriptFetchTestState(state_ptr) }
		state.order << 'microtask'
	}))
	response := host.perform(worker_script_fetch_request(settings, settings.api_base_url().serialize()))!
	assert response.fetch_response_body_bytes()?.bytestr() == 'self.ready=true;'
	assert state.paused
	assert state.order == ['network']
	assert !loop.execution_paused()
	assert state.controller?.state() == .stopped
	loop.process()
	assert state.order == ['network', 'message', 'microtask']
}

fn worker_script_never_transport(state_ptr &WorkerScriptFetchTestState) &fetch.FetchHost {
	return &fetch.FetchHost{
		perform: fn (_ &fetch.Request) !&fetch.Response { panic('blocking network transport was used') }
		perform_async_with_params: fn [state_ptr] (params &fetch.FetchParams, request &fetch.Request) &fetch.PendingResponse {
			mut state := unsafe { &WorkerScriptFetchTestState(state_ptr) }
			state.controller = params.fetch_params_controller()
			mut actual := unsafe { &fetch.Request(request) }
			return fetch.PendingResponse.create(mut actual, none)
		}
	}
}

fn test_worker_script_fetcher_timeout_cancels_fetch_and_restores_its_loop_for_later_loads() {
	settings := worker_script_fetch_settings('https://worker-script-timeout.test/main.js')
	state := &WorkerScriptFetchTestState{}
	mut host := WorkerScriptFetcher.create(settings, worker_script_never_transport(state), 20)!
	defer { host.close() }
	start := time.sys_mono_now()
	if _ := host.perform(worker_script_fetch_request(settings, settings.api_base_url().serialize())) { assert false }
	assert time.sys_mono_now() - start < time.second
	assert state.controller?.state() == .stopped
	assert state.controller?.ongoing_task_count() == 0
	assert !settings.responsible_event_loop().execution_paused()
	assert !host.busy && host.controller == none
	response := host.perform(worker_script_fetch_request(settings, 'data:text/javascript,self.ready%3Dtrue'))!
	assert response.fetch_response_body_bytes()?.bytestr() == 'self.ready=true'
}

fn test_worker_script_fetcher_close_interrupts_pending_network_work_and_rejects_later_calls() {
	settings := worker_script_fetch_settings('https://worker-script-close.test/main.js')
	state := &WorkerScriptFetchTestState{}
	mut host := WorkerScriptFetcher.create(settings, worker_script_never_transport(state), 1000)!
	handle := voidptr(host)
	mut timer := platform.Timer.create_single_shot(10, fn [handle] () {
		mut host := unsafe { &WorkerScriptFetcher(handle) }
		host.close()
	})
	timer.start()
	request := worker_script_fetch_request(settings, settings.api_base_url().serialize())
	if _ := host.perform(request) { assert false }
	assert host.closed && !host.busy && host.controller == none
	assert state.controller?.state() == .stopped
	assert !settings.responsible_event_loop().execution_paused()
	if _ := host.perform(request) { assert false }
	host.close()
}

fn test_worker_script_fetcher_preserves_outer_pause_and_persistent_response_ownership() {
	settings := worker_script_fetch_settings('https://worker-script-memory.test/main.js')
	mut loop := settings.responsible_event_loop()
	pause := loop.pause()
	defer { loop.unpause(pause) }
	mut caller := platform.begin_thread_scratch('worker script fetch caller')
	mut host := WorkerScriptFetcher.create_native(settings, 1000)!
	response := host.perform(worker_script_fetch_request(settings, 'data:text/javascript,self.city%3D%22%D0%9D%D0%B5%D0%B2%D0%B0%22'))!
	caller.finish()
	mut delivery := platform.begin_thread_scratch('worker script fetch delivery')
	assert response.fetch_response_body_bytes()?.bytestr() == 'self.city="Нева"'
	assert loop.execution_paused()
	second := host.perform(worker_script_fetch_request(settings, 'data:text/javascript,self.ready%3Dtrue'))!
	delivery.finish()
	assert second.fetch_response_body_bytes()?.bytestr() == 'self.ready=true'
	assert loop.execution_paused()
	host.close()
}

fn test_worker_script_fetcher_distinguishes_failed_streams_from_empty_bodies() {
	settings := worker_script_fetch_settings('https://worker-script-body.test/main.js')
	transport := &fetch.FetchHost{
		perform: fn (request &fetch.Request) !&fetch.Response {
			mut response := fetch.Response.create()
			if !request.current_url().serialize().ends_with('/empty.js') {
				mut body := fetch.Body.streaming()
				body.error_stream('truncated script response')
				response.body = body
			}
			return response
		}
	}
	mut host := WorkerScriptFetcher.create(settings, transport, 1000)!
	defer { host.close() }
	if _ := host.perform(worker_script_fetch_request(settings, settings.api_base_url().serialize())) {
		assert false
	} else {
		assert err.msg() == 'NetworkError: worker script response body failed'
	}
	assert !settings.responsible_event_loop().execution_paused()
	response := host.perform(worker_script_fetch_request(settings, 'https://worker-script-body.test/empty.js'))!
	assert response.fetch_response_body_bytes() == none
	assert !host.busy
}
