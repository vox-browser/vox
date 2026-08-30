@[has_globals]
module html

import dom

__global (
	global_scope_timer_calls       int
	global_scope_timer_arg         f64
	global_scope_observed          int
	global_scope_timeout_completed bool
)

fn global_scope_timer_callback(arguments []dom.JSValue) {
	unsafe {
		global_scope_timer_calls++
		if arguments.len > 0 {
			global_scope_timer_arg = arguments[0].number_data
		}
	}
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
	timeout_id := scope.set_timeout(timer_callback_handler(global_scope_timer_callback), 0, [
		dom.js_number(17),
	])
	interval_id := scope.set_interval(timer_callback_handler(global_scope_timer_callback), 0, [])
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
	input := &dom.ImmutableBitmap_{
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
