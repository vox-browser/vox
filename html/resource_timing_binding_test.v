module html

import dom
import fetch
import highresolutiontime
import http
import resourcetiming
import streams

@[heap]
struct ResourceTimingObservation {
mut:
	names []string
}

fn resource_timing_fixture() (&EnvironmentSettingsObject, &WindowOrWorkerGlobalScopeMixin, &EventLoop) {
	mut document := dom.Document.create(dom.URL{'https://timing.example/page'})
	document.set_origin(document.url.origin())
	window := WindowModel.create_top_level(document, none, 'resource-timing') or { panic(err) }
	mut settings := window.environment_settings_.settings
	mut scope := window.window_or_worker_global_scope()
	owner := EventLoop.create(.window)
	settings.responsible_event_loop_ = owner
	scope.responsible_event_loop_ = owner
	settings.time_origin_ = highresolutiontime.coarsened_shared_current_time(false) - 50
	return settings, scope, owner
}

fn resource_timing_params(settings &EnvironmentSettingsObject, url string) &fetch.FetchParams {
	mut request := fetch.Request.create()
	request.client = settings
	request.url_list = [dom.URL{url}]
	request.initiator_type = .fetch
	mut timing := fetch.FetchTimingInfo.create()
	timing.start_time = settings.time_origin() + 10
	timing.post_redirect_start_time = timing.start_time
	timing.final_network_request_start_time = settings.time_origin() + 20
	timing.render_blocking = true
	return fetch.FetchParams.create(request, timing)
}

fn drain_resource_timing_owner(owner &EventLoop) {
	mut queue := owner.task_queue()
	for i := 0; i < 100; i++ {
		mut task := queue.take_first_runnable() or { return }
		task.execute()
	}
	panic('resource timing queue did not settle')
}

fn test_fetch_eof_queues_and_buffers_the_actual_resource_entry_on_its_global() {
	settings, mut scope, owner := resource_timing_fixture()
	observation := &ResourceTimingObservation{}
	scope.register_performance_observer(&PerformanceObserverRecord{
		entry_types: ['resource']
		callback: fn [observation] (entries []PerformanceEntry) {
			mut state := unsafe { &ResourceTimingObservation(observation) }
			state.names << entries.map(it.name)
		}
	})
	params := resource_timing_params(settings, 'https://timing.example/stream.js')
	mut response := fetch.Response.create()
	response.timing_allow_passed = true
	response.body_info = fetch.BodyInfo{ encoded_size: 5, decoded_size: 5 }
	response.header_list.append(http.Header{ name: 'Content-Type', value: 'application/x-javascript;charset=UTF-8' })
	body := fetch.Body.streaming()
	mut producer := body.stream()
	response.body = body
	fetch.fetch_response_handover(params, response)
	mut consumer := response.body or { panic('missing transformed body') }
	consumer.incrementally_read(fn (_ []u8) {}, fn () {}, fn (reason string) { panic(reason) })
	producer.enqueue(streams.bytes_value('bytes'.bytes()))!
	producer.close()
	assert !params.request.done
	mut performance := scope.performance()
	assert performance.get_entries_by_type('resource').len == 0
	assert observation.names.len == 0
	mut queue := owner.task_queue()
	mut task := queue.take_first_runnable() or { panic('missing EOF task') }
	assert task.source() == .networking
	task.execute()
	assert params.request.done
	entries := performance.get_entries_by_type('resource')
	assert entries.len == 1
	entry := unsafe { &resourcetiming.PerformanceResourceTiming(entries[0]) }
	assert entry.performance_entry() == entries[0]
	assert entry.performance_entry().name == 'https://timing.example/stream.js'
	assert entry.performance_entry().start_time == 10
	assert entry.performance_entry().duration > 0
	assert entry.initiator_type() == 'fetch'
	assert entry.response_status() == 200
	assert entry.content_type() == 'text/javascript'
	assert entry.encoded_body_size() == 5
	assert entry.render_blocking_status() == .blocking
	assert observation.names.len == 0
	assert queue.last_added_task()?.source() == .performance_timeline
	drain_resource_timing_owner(owner)
	assert observation.names == ['https://timing.example/stream.js']
}

fn test_parallel_fetch_requires_explicit_reporting_to_its_current_global() {
	settings, mut scope, owner := resource_timing_fixture()
	mut request := fetch.Request.create()
	request.client = settings
	request.url_list = [dom.URL{'https://timing.example/synchronous'}]
	request.mode = .same_origin
	request.initiator_type = .xml_http_request
	controller := fetch.fetch_with_parallel_queue(request, fetch.FetchAlgorithms.create(fetch.FetchAlgorithmsInput{}), &fetch.FetchHost{
		perform: fn (_ &fetch.Request) !&fetch.Response { return fetch.Response.create() }
	}, .yes, .no)
	drain_resource_timing_owner(main_thread_event_loop())
	assert request.done
	mut performance := scope.performance()
	assert performance.get_entries_by_type('resource').len == 0
	assert owner.task_queue().is_empty()
	controller.report_timing_with_global(settings)
	entries := performance.get_entries_by_type('resource')
	assert entries.len == 1
	entry := unsafe { &resourcetiming.PerformanceResourceTiming(entries[0]) }
	assert entry.initiator_type() == 'xmlhttprequest'
}

fn test_resource_reporting_applies_opaque_timing_and_navigation_redirect_visibility() {
	settings, mut scope, owner := resource_timing_fixture()
	mut params := resource_timing_params(settings, 'https://timing.example/redirected')
	params.request.mode = .navigate
	mut response := fetch.Response.create()
	response.status = 206
	response.cache_state = .local
	response.redirect_taint = .cross_site
	response.header_list.append(http.Header{ name: 'Content-Type', value: 'application/javascript' })
	fetch.fetch_response_handover(params, response)
	drain_resource_timing_owner(owner)
	mut performance := scope.performance()
	entries := performance.get_entries_by_type('resource')
	assert entries.len == 1
	entry := unsafe { &resourcetiming.PerformanceResourceTiming(entries[0]) }
	assert entry.fetch_start() == 10
	assert entry.request_start() == 0 // Opaque timing excludes wire timing.
	assert entry.response_end() >= 10 // End time survives opacity.
	assert entry.response_status() == 0
	assert entry.content_type() == ''
	assert entry.delivery_type() == ''
	assert entry.render_blocking_status() == .blocking
}

fn test_resource_reporting_uses_worker_ownership_and_skips_non_http_urls() {
	outside, mut window_scope, window_owner := resource_timing_fixture()
	mut realm := &ScriptingRealm{}
	worker := WorkerGlobalScope.create(dom.URL{'https://timing.example/worker.js'}, .classic, '', realm)
	settings := WorkerEnvironmentSettingsObject.setup(worker, mut realm, outside.serialize(), 0).settings
	mut scope := worker.window_or_worker_global_scope()
	params := resource_timing_params(settings, 'https://timing.example/worker-resource')
	mut response := fetch.Response.create()
	response.timing_allow_passed = true
	fetch.fetch_response_handover(params, response)
	assert window_owner.task_queue().is_empty()
	drain_resource_timing_owner(settings.responsible_event_loop())
	mut performance := scope.performance()
	assert performance.get_entries_by_type('resource').len == 1
	mut window_performance := window_scope.performance()
	assert window_performance.get_entries_by_type('resource').len == 0
	local_params := resource_timing_params(settings, 'data:text/plain,local')
	fetch.fetch_response_handover(local_params, fetch.Response.create())
	drain_resource_timing_owner(settings.responsible_event_loop())
	assert performance.get_entries_by_type('resource').len == 1
	assert local_params.timing_info.end_time == 0
}
