@[has_globals]
module html

import dom
import math
import page

__global (
	global_scope_timer_calls       int
	global_scope_timer_arg         f64
	global_scope_observed          int
	global_scope_timeout_completed bool
)

fn global_scope_timer_callback(arguments []dom.JSValue) dom.JSValue {
	unsafe {
		global_scope_timer_calls++
		if arguments.len > 0 {
			global_scope_timer_arg = arguments[0].number_data
		}
	}
	return dom.js_undefined()
}

fn global_scope_observer_callback(entries []PerformanceEntry) {
	unsafe {
		global_scope_observed += entries.len
	}
}

fn global_scope_timeout_completion() {
	unsafe {
		global_scope_timeout_completed = true
	}
}

fn test_global_scope_identity_timers_and_singletons() {
	mut scope := WindowOrWorkerGlobalScopeMixin.create(dom.Origin{ value: 'https://example.test' }, true, true)
	assert scope.origin() == 'https://example.test'
	assert scope.is_secure_context()
	assert scope.cross_origin_isolated()
	assert scope.window_or_worker_global_scope_extract_an_origin()? == dom.Origin{
		value: 'https://example.test'
	}
	unsafe {
		global_scope_timer_calls = 0
		global_scope_timer_arg = 0
	}
	callback := &dom.CallbackType{
		call_with_arguments: global_scope_timer_callback
	}
	timeout_id := scope.set_timeout(timer_callback_handler(callback), 0, [
		dom.js_number(17),
	])
	interval_id := scope.set_interval(timer_callback_handler(callback), 0, [])
	assert timeout_id != interval_id
	scope.run_all_timers()
	unsafe {
		assert global_scope_timer_calls == 2
		assert global_scope_timer_arg == 17
	}
	assert scope.active_timer_count() == 1
	scope.clear_interval(interval_id)
	assert scope.active_timer_count() == 0
	assert scope.crypto() == scope.crypto()
	assert scope.caches() == scope.caches()
}

fn test_hidden_document_delayed_timers_share_aligned_wakeups() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/' })
	document.set_origin(document.url.origin())
	window := WindowModel.create_top_level(document, none, 'timer-throttling-test') or {
		panic(err)
	}
	document.update_the_visibility_state(.hidden)
	mut scope := window.window_or_worker_global_scope()
	scope.set_hidden_document_timer_wake_up_interval(1_000)
	assert document.is_fully_active()
	assert document.hidden()

	immediate_id := scope.set_timeout(timer_source_handler('immediate'), 0, [])
	delayed_id := scope.set_timeout(timer_source_handler('delayed'), 25, [])
	specification_timeout_id := scope.run_steps_after_a_timeout(0, fn () {})
	immediate := scope.active_timers_[immediate_id] or { panic('missing immediate timer') }
	delayed := scope.active_timers_[delayed_id] or { panic('missing delayed timer') }
	specification_timeout := scope.active_timers_[specification_timeout_id] or {
		panic('missing specification timeout')
	}
	origin := scope.hidden_timer_grid_origin_ms()
	assert immediate.throttling_class == .immediate
	assert immediate.due_time_ms == immediate.deadline_ms
	assert delayed.throttling_class == .delayed
	assert delayed.due_time_ms >= delayed.deadline_ms
	assert math.fmod(delayed.due_time_ms - origin, 1_000) == 0
	assert specification_timeout.due_time_ms >= specification_timeout.deadline_ms
	assert math.fmod(specification_timeout.due_time_ms - origin, 1_000) == 0

	document.set_initial_visibility_state(.visible)
	visible_delayed := scope.active_timers_[delayed_id] or { panic('missing visible timer') }
	assert visible_delayed.due_time_ms == visible_delayed.deadline_ms
	document.update_the_visibility_state(.hidden)
	hidden_again := scope.active_timers_[delayed_id] or { panic('missing hidden timer') }
	assert hidden_again.due_time_ms >= hidden_again.deadline_ms
	assert math.fmod(hidden_again.due_time_ms - origin, 1_000) == 0
}

fn test_hidden_document_short_interval_fires_once_per_wakeup() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/' })
	document.set_origin(document.url.origin())
	window := WindowModel.create_top_level(document, none, 'interval-throttling-test') or {
		panic(err)
	}
	document.update_the_visibility_state(.hidden)
	mut scope := window.window_or_worker_global_scope()
	scope.set_hidden_document_timer_wake_up_interval(1_000)
	unsafe {
		global_scope_timer_calls = 0
	}
	callback := &dom.CallbackType{
		call_with_arguments: global_scope_timer_callback
	}
	interval_id := scope.set_interval(timer_callback_handler(callback), 10, [])
	first := scope.active_timers_[interval_id] or { panic('missing interval') }
	scope.process_timers(first.due_time_ms)
	unsafe {
		assert global_scope_timer_calls == 1
	}
	second := scope.active_timers_[interval_id] or { panic('missing repeated interval') }
	assert second.due_time_ms == first.due_time_ms + 1_000
	scope.process_timers(first.due_time_ms + 999)
	unsafe {
		assert global_scope_timer_calls == 1
	}
	scope.process_timers(second.due_time_ms)
	unsafe {
		assert global_scope_timer_calls == 2
	}
	scope.clear_interval(interval_id)
}

fn test_worker_style_global_scope_does_not_throttle_timers() {
	mut scope := WindowOrWorkerGlobalScopeMixin.create(dom.Origin{}, false, false)
	id := scope.set_timeout(timer_source_handler('worker'), 25, [])
	timer := scope.active_timers_[id] or { panic('missing worker timer') }
	assert timer.due_time_ms == timer.deadline_ms
}

fn test_hidden_document_intensively_throttles_chained_timers_after_grace() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/' })
	document.set_origin(document.url.origin())
	window := WindowModel.create_top_level(document, none, 'intensive-throttling-test') or {
		panic(err)
	}
	mut scope := window.window_or_worker_global_scope()
	scope.set_hidden_document_timer_wake_up_interval(100)
	scope.set_hidden_document_intensive_timer_throttling(1_000, 0, 0)
	scope.last_chained_timer_wake_up_ms_ = global_scope_now_ms()
	document.update_the_visibility_state(.hidden)

	chained_id := scope.run_steps_after_a_timeout(5, fn () {})
	delayed_id := scope.set_timeout(timer_source_handler('delayed'), 5, [])
	grace_deadline := scope.intensive_timer_grace_deadline_ms_ or {
		panic('missing intensive throttling grace deadline')
	}
	scope.process_timers(grace_deadline)
	assert scope.chained_timers_intensively_throttled_
	chained := scope.active_timers_[chained_id] or { panic('missing chained timer') }
	delayed := scope.active_timers_[delayed_id] or { panic('missing delayed timer') }
	origin := scope.hidden_timer_grid_origin_ms()
	assert chained.throttling_class == .chained
	assert math.fmod(chained.due_time_ms - origin, 1_000) == 0
	assert delayed.throttling_class == .delayed
	assert math.fmod(delayed.due_time_ms - origin, 100) == 0
}

fn test_intensive_throttling_allows_a_rare_chained_timer_at_an_ordinary_wakeup() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/' })
	document.set_origin(document.url.origin())
	window := WindowModel.create_top_level(document, none, 'rare-chained-timer-test') or {
		panic(err)
	}
	document.update_the_visibility_state(.hidden)
	mut scope := window.window_or_worker_global_scope()
	scope.set_hidden_document_timer_wake_up_interval(100)
	scope.set_hidden_document_intensive_timer_throttling(1_000, 0, 0)
	scope.chained_timers_intensively_throttled_ = true
	origin := scope.hidden_timer_grid_origin_ms()
	deadline := origin + 12_345
	ordinary_wake_up := timer_wake_up_at_or_after(deadline, origin, 100)
	intensive_wake_up := timer_wake_up_at_or_after(deadline, origin, 1_000)

	scope.last_chained_timer_wake_up_ms_ = none
	assert scope.timer_due_time(.chained, deadline, deadline) == ordinary_wake_up
	scope.last_chained_timer_wake_up_ms_ = deadline
	assert scope.timer_due_time(.chained, deadline, deadline) == intensive_wake_up
}

fn test_intensive_throttling_grace_depends_on_readiness_when_document_hides() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/' })
	document.set_origin(document.url.origin())
	window := WindowModel.create_top_level(document, none, 'timer-grace-test') or {
		panic(err)
	}
	mut scope := window.window_or_worker_global_scope()
	scope.set_hidden_document_intensive_timer_throttling(1_000, 10, 50)

	loaded_start := global_scope_now_ms()
	document.update_the_visibility_state(.hidden)
	loaded_deadline := scope.intensive_timer_grace_deadline_ms_ or { panic('missing loaded grace') }
	assert loaded_deadline >= loaded_start + 10
	assert loaded_deadline <= global_scope_now_ms() + 10

	document.update_the_visibility_state(.visible)
	document.update_readiness(.loading)
	loading_start := global_scope_now_ms()
	document.update_the_visibility_state(.hidden)
	loading_deadline := scope.intensive_timer_grace_deadline_ms_ or {
		panic('missing loading grace')
	}
	assert loading_deadline >= loading_start + 50
	assert loading_deadline <= global_scope_now_ms() + 50
}

fn test_deeply_nested_timer_is_chained_and_clamped() {
	mut scope := WindowOrWorkerGlobalScopeMixin.create(dom.Origin{}, false, false)
	mut owner := scope.responsible_event_loop()
	previous_task := owner.currently_running_task_
	mut task := Task.create(.timer_task, none, fn () {})
	task.set_timer_nesting_level(6)
	owner.currently_running_task_ = task
	defer { owner.currently_running_task_ = previous_task }
	id := scope.set_timeout(timer_source_handler('nested'), 0, [])
	timer := scope.active_timers_[id] or { panic('missing nested timer') }
	assert timer.nesting_level == 7
	assert timer.timeout_ms == 4
	assert timer.throttling_class == .chained
}

fn test_repeating_timer_becomes_chained_after_deep_nesting() {
	mut scope := WindowOrWorkerGlobalScopeMixin.create(dom.Origin{}, false, false)
	callback := &dom.CallbackType{
		call_with_arguments: global_scope_timer_callback
	}
	id := scope.set_interval(timer_callback_handler(callback), 0, [])
	for _ in 0 .. 6 {
		timer := scope.active_timers_[id] or { panic('missing repeating timer') }
		scope.process_timers(timer.due_time_ms)
	}
	timer := scope.active_timers_[id] or { panic('missing rescheduled timer') }
	assert timer.nesting_level == 7
	assert timer.timeout_ms == 4
	assert timer.throttling_class == .chained
	scope.clear_interval(id)
}

@[heap]
struct LegacyMuteTimerObservation {
mut:
	calls int
}

fn test_legacy_media_state_adapter_keeps_hidden_timer_mute_transitions() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/' })
	document.set_origin(document.url.origin())
	mut page_model := page.Page.create(1) or { panic(err) }
	document.set_page(unsafe { &dom.Page(page_model) })
	mut unrelated_document := dom.Document.create(dom.URL{ value: 'https://unrelated.example.test/' })
	unrelated_document.set_page(unsafe { &dom.Page(page_model) })
	observation := &LegacyMuteTimerObservation{}
	unrelated_document.set_lifecycle_hook(dom.DocumentLifecycleHook{
		target: voidptr(observation)
		timer_audio_play_state_changed: fn (target voidptr, _ &dom.Document) {
			mut state := unsafe { &LegacyMuteTimerObservation(target) }
			state.calls++
		}
	})
	window := WindowModel.create_top_level(document, none, 'audible-timer-test') or {
		panic(err)
	}
	mut scope := window.window_or_worker_global_scope()
	scope.set_hidden_document_timer_wake_up_interval(1_000)
	scope.set_hidden_document_intensive_timer_throttling(60_000, 1_000, 1_000)
	document.update_the_visibility_state(.hidden)
	grace_deadline := scope.intensive_timer_grace_deadline_ms_

	timer_id := scope.set_timeout(timer_source_handler('audible'), 25, [])
	hidden_timer := scope.active_timers_[timer_id] or { panic('missing hidden timer') }
	assert hidden_timer.due_time_ms >= hidden_timer.deadline_ms
	assert math.fmod(hidden_timer.due_time_ms - scope.hidden_timer_grid_origin_ms(), 1_000) == 0

	// Explicit state-record adapter; this ID has no concrete DOM media owner.
	media_id := dom.UniqueNodeID(987)
	document.media_element_audio_play_state_changed(media_id, true)
	assert document.is_playing_audio()
	audible_timer := scope.active_timers_[timer_id] or { panic('missing audible timer') }
	assert audible_timer.due_time_ms == audible_timer.deadline_ms
	assert scope.intensive_timer_grace_deadline_ms_ == grace_deadline
	page_model.set_page_mute_state(.muted)
	assert !document.is_playing_audio()
	page_muted_timer := scope.active_timers_[timer_id] or { panic('missing page-muted timer') }
	assert math.fmod(page_muted_timer.due_time_ms - scope.hidden_timer_grid_origin_ms(), 1_000) == 0
	page_model.set_page_mute_state(.unmuted)
	assert document.is_playing_audio()
	page_unmuted_timer := scope.active_timers_[timer_id] or { panic('missing page-unmuted timer') }
	assert page_unmuted_timer.due_time_ms == page_unmuted_timer.deadline_ms
	assert observation.calls == 0

	document.media_element_audio_play_state_changed(media_id, false)
	assert !document.is_playing_audio()
	silent_timer := scope.active_timers_[timer_id] or { panic('missing silent timer') }
	assert silent_timer.due_time_ms >= silent_timer.deadline_ms
	assert math.fmod(silent_timer.due_time_ms - scope.hidden_timer_grid_origin_ms(), 1_000) == 0
	assert scope.intensive_timer_grace_deadline_ms_ == grace_deadline
}

fn test_global_scope_create_image_bitmap_crop_resize_flip() {
	data := ImageData.create_with_data([
		u8(255),
		0,
		0,
		255,
		0,
		255,
		0,
		255,
		0,
		0,
		255,
		255,
		255,
		255,
		255,
		255,
	], 2, 2, none)!
	scope := WindowOrWorkerGlobalScopeMixin.create(dom.Origin{}, false, false)
	bitmap := scope.create_image_bitmap_with_crop(ImageBitmapSource{ image_data: data }, 0, 0, 2, 2, ImageBitmapOptions{
		image_orientation: .flip_y
		resize_width: 1
		resize_height: 2
	})!
	assert bitmap.width() == 1
	assert bitmap.height() == 2
	pixels := bitmap.bitmap()?.data
	assert pixels[..4] == [u8(0), 0, 255, 255]
	assert pixels[4..8] == [u8(255), 0, 0, 255]
}

fn test_crop_source_rectangle_infers_aspect_ratio_with_ceiling() {
	input := &dom.Bitmap_{
		width: 3
		height: 2
		pitch: 12
		data: []u8{len: 24, init: 255}
	}
	result := crop_to_the_source_rectangle_with_formatting(input, none, none, none, none, ImageBitmapOptions{ resize_height: 1 })!
	assert result.width == 2
	assert result.height == 1
}

fn test_global_scope_performance_observer_and_filtering() {
	unsafe {
		global_scope_observed = 0
	}
	mut scope := WindowOrWorkerGlobalScopeMixin.create(dom.Origin{}, false, false)
	observer := &PerformanceObserverRecord{
		callback: global_scope_observer_callback
		entry_types: ['mark']
	}
	scope.register_performance_observer(observer)
	assert scope.has_registered_performance_observer(observer)
	scope.queue_performance_entry(PerformanceEntry{ name: 'later', entry_type: 'mark', start_time: 2 })
	scope.add_performance_entry(PerformanceEntry{ name: 'later', entry_type: 'mark', start_time: 2 })
	scope.queue_performance_entry(PerformanceEntry{ name: 'first', entry_type: 'mark', start_time: 1 })
	scope.add_performance_entry(PerformanceEntry{ name: 'first', entry_type: 'mark', start_time: 1 })
	scope.add_performance_entry(PerformanceEntry{
		name: 'resource'
		entry_type: 'resource'
		start_time: 0
	})
	scope.process_performance_observers()
	unsafe {
		assert global_scope_observed == 2
	}
	marks := scope.filter_buffer_map_by_name_and_type(none, 'mark')
	assert marks.len == 2
	assert marks[0].name == 'first'
	assert scope.filter_buffer_map_by_name_and_type('later', none).len == 1
	scope.unregister_performance_observer(observer)
	assert !scope.has_registered_performance_observer(observer)
}

fn test_global_scope_resource_timing_and_timeout_completion_algorithms() {
	mut scope := WindowOrWorkerGlobalScopeMixin.create(dom.Origin{}, false, false)
	for index in 0 .. 250 {
		scope.add_resource_timing_entry(PerformanceEntry{
			name: 'resource-${index}'
			entry_type: 'resource'
		})
	}
	assert scope.resource_timing_buffer_current_size() == 250
	assert !scope.can_add_resource_timing_entry()
	scope.add_resource_timing_entry(PerformanceEntry{ name: 'overflow', entry_type: 'resource' })
	assert scope.resource_timing_secondary_.len == 1
	scope.fire_resource_timing_buffer_full_event()
	assert scope.resource_timing_secondary_.len == 0
	unsafe {
		global_scope_timeout_completed = false
	}
	scope.run_steps_after_a_timeout(0, global_scope_timeout_completion)
	scope.run_all_timers()
	unsafe {
		assert global_scope_timeout_completed
	}
}

fn test_global_scope_closes_registered_event_sources_and_reports_errors() {
	mut scope := WindowOrWorkerGlobalScopeMixin.create(dom.Origin{}, false, false)
	mut source := EventSource.construct_impl('https://example.test/events', dom.url_about_blank(), EventSourceInit{})!
	source.announce_the_connection()
	scope.register_event_source(source)
	scope.forcibly_close_all_event_sources()
	assert source.ready_state() == .closed
	scope.report_error(dom.js_string('boom'))
	assert scope.reported_errors().len == 1
	assert 'resource' in scope.supported_entry_types()
}
