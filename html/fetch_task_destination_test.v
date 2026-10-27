module html

import dom
import fetch
import http
import platform

@[heap]
struct HTMLFetchTaskObservation {
mut:
	pending   ?&fetch.PendingResponse
	request   ?&fetch.Request
	callbacks []string
}

fn html_pending_fetch_host(state &HTMLFetchTaskObservation) fetch.FetchHost {
	return fetch.FetchHost{
		perform:       fn (_ &fetch.Request) !&fetch.Response {
			panic('synchronous host was called')
		}
		perform_async: fn [state] (request &fetch.Request) &fetch.PendingResponse {
			mut observation := unsafe { &HTMLFetchTaskObservation(state) }
			mut mutable_request := unsafe { &fetch.Request(request) }
			pending := fetch.PendingResponse.create(mut mutable_request, none)
			observation.pending = pending
			observation.request = request
			return pending
		}
	}
}

fn html_fetch_settings() (&EnvironmentSettingsObject, &EventLoop) {
	mut document := dom.Document.create(dom.URL{value: 'https://example.test/fetch-owner'})
	document.set_origin(document.url.origin())
	window := WindowModel.create_top_level(document, none, 'fetch-owner') or { panic(err) }
	mut realm := &ScriptingRealm{}
	object := WindowEnvironmentSettingsObject.setup(window, document.url, mut realm, none, document.url, document.origin())
	mut settings := object.settings
	loop := EventLoop.create(.window)
	settings.responsible_event_loop_ = loop
	return settings, loop
}

fn start_html_pending_fetch(settings &EnvironmentSettingsObject, state &HTMLFetchTaskObservation) &fetch.FetchController {
	mut request := fetch.Request.create()
	request.client = settings
	request.url_list = [dom.URL{value: 'https://example.test/pending'}]
	request.mode = .same_origin
	request.cache_mode = .no_store
	host := html_pending_fetch_host(state)
	algorithms := fetch.FetchAlgorithms.create(fetch.FetchAlgorithmsInput{
		process_response: fn [state] (_ &fetch.Response) {
			mut observation := unsafe { &HTMLFetchTaskObservation(state) }
			observation.callbacks << 'response'
		}
	})
	return fetch.fetch(request, algorithms, &host, .no)
}

fn resolve_html_pending_fetch(state &HTMLFetchTaskObservation) {
	mut response := fetch.Response.create()
	response.header_list.append(http.Header{ name: 'Content-Type', value: 'text/plain' })
	response.set_body_bytes('network body'.bytes())
	mut pending := state.pending or { panic('no pending response') }
	pending.resolve(response)
}

fn drain_html_fetch_continuations(mut queue TaskQueue) {
	mut plugin := platform.EventLoopPlugin.the()
	for i := 0; i < 10; i++ {
		if task := queue.last_added_task() {
			if task.source == .networking { return }
		}
		assert plugin.run_one_deferred()
	}
	panic('fetch continuation chain did not reach handover')
}

fn test_fetch_pending_continuations_and_response_handover_use_the_real_owner_queue() {
	settings, owner := html_fetch_settings()
	state := &HTMLFetchTaskObservation{}
	controller := start_html_pending_fetch(settings, state)
	mut queue := owner.task_queue()
	assert queue.is_empty()
	resolve_html_pending_fetch(state)
	assert state.callbacks.len == 0
	assert queue.is_empty()
	drain_html_fetch_continuations(mut queue)
	assert state.callbacks.len == 0
	assert queue.last_added_task()?.source == .networking
	assert controller.ongoing_task_count() == 1
	mut task := queue.take_first_runnable() or { panic('no networking handover') }
	task.execute()
	assert state.callbacks == ['response']
	assert controller.ongoing_task_count() == 0
	assert queue.is_empty()
}

fn test_pending_fetch_progresses_on_the_native_queue_while_html_execution_is_paused() {
	settings, mut owner := html_fetch_settings()
	state := &HTMLFetchTaskObservation{}
	controller := start_html_pending_fetch(settings, state)
	queue_a_task(.timer_task, owner, none, fn [state] () {
		mut observation := unsafe { &HTMLFetchTaskObservation(state) }
		observation.callbacks << 'timer'
	})
	owner.execution_paused = true
	defer { owner.execution_paused = false }
	resolve_html_pending_fetch(state)
	mut queue := owner.task_queue()
	assert queue.take_first_runnable() == none
	drain_html_fetch_continuations(mut queue)
	assert queue.last_added_task()?.source == .networking
	assert queue.take_first_runnable() == none
	assert state.callbacks == []
	assert controller.ongoing_task_count() == 1
	owner.execution_paused = false
	timer := queue.take_first_runnable() or { panic('missing original timer task') }
	assert timer.source == .timer_task
	timer.execute()
	network := queue.take_first_runnable() or { panic('missing networking handover') }
	network.execute()
	assert state.callbacks == ['timer', 'response']
	assert controller.ongoing_task_count() == 0
}

fn test_parallel_fetch_native_continuation_retains_its_allocation_owner_until_delivery() {
	state := &HTMLFetchTaskObservation{}
	mut storage := platform.new_retained_arena('pending fetch continuation')
	storage.add_cleanup(fn [state] () {
		mut observation := unsafe { &HTMLFetchTaskObservation(state) }
		observation.callbacks << 'released'
	})
	mut scope := storage.enter()
	queue := ParallelQueue.create()
	text := 'native continuation'.clone()
	queue.fetch_request_client_deferred_invoke(fn [state, text] () {
		mut observation := unsafe { &HTMLFetchTaskObservation(state) }
		observation.callbacks << text
	})
	scope.finish()
	storage.release()
	$if prealloc { assert state.callbacks == [] }
	mut plugin := platform.EventLoopPlugin.the()
	assert plugin.run_one_deferred()
	$if prealloc {
		assert state.callbacks == ['native continuation', 'released']
	} $else {
		assert state.callbacks == ['released', 'native continuation']
	}
}

fn test_fetch_native_continuation_retains_document_storage_when_resolved_outside_its_arena() {
	$if !prealloc { return }
	settings, _ := html_fetch_settings()
	mut document := settings.responsible_document() or { panic('missing document') }
	document.enable_native_storage()
	state := &HTMLFetchTaskObservation{}
	mut storage := document.native_storage()
	storage.add_cleanup(fn [state] () {
		mut observation := unsafe { &HTMLFetchTaskObservation(state) }
		observation.callbacks << 'released'
	})
	mut scope := document.enter_native_storage()
	text := 'document continuation'.clone()
	callback := fn [state, text] () {
		mut observation := unsafe { &HTMLFetchTaskObservation(state) }
		observation.callbacks << text
	}
	scope.finish()
	assert platform.current_retained_arena() == unsafe { nil }
	settings.fetch_request_client_deferred_invoke(callback)
	document.release_native_storage()
	assert state.callbacks == []
	mut plugin := platform.EventLoopPlugin.the()
	assert plugin.run_one_deferred()
	assert state.callbacks == ['document continuation', 'released']
}

fn test_stopping_fetch_removes_the_actual_queued_networking_callback() {
	settings, owner := html_fetch_settings()
	state := &HTMLFetchTaskObservation{}
	mut controller := start_html_pending_fetch(settings, state)
	mut queue := owner.task_queue()
	resolve_html_pending_fetch(state)
	drain_html_fetch_continuations(mut queue)
	assert controller.ongoing_task_count() == 1
	assert queue.last_added_task()?.source == .networking
	controller.stop_fetch()
	assert controller.ongoing_task_count() == 0
	assert queue.is_empty()
	assert state.callbacks.len == 0
}

fn test_worker_fetch_callbacks_stay_on_the_worker_event_loop() {
	outside, window_loop := html_fetch_settings()
	mut realm := &ScriptingRealm{}
	scope := WorkerGlobalScope.create(dom.URL{value: 'https://example.test/worker.js'}, .classic, '', realm)
	worker := WorkerEnvironmentSettingsObject.setup(scope, mut realm, outside.serialize(), 0)
	settings := worker.settings
	assert voidptr(settings.responsible_event_loop()) != voidptr(window_loop)
	state := &HTMLFetchTaskObservation{}
	controller := start_html_pending_fetch(settings, state)
	resolve_html_pending_fetch(state)
	assert window_loop.task_queue().is_empty()
	mut queue := settings.responsible_event_loop().task_queue()
	drain_html_fetch_continuations(mut queue)
	mut task := queue.take_first_runnable() or { panic('no worker networking handover') }
	assert task.document() == none
	task.execute()
	assert state.callbacks == ['response']
	assert controller.ongoing_task_count() == 0
}
