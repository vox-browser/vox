module html

import dom
import highresolutiontime
import performancetimeline
import usertiming

@[heap]
struct GlobalPerformanceObservation {
mut:
	names       []string
	full_events int
}

fn performance_window_fixture() (&dom.Document, &WindowModel, &EventLoop) {
	mut document := parse_document_with_url('<!doctype html><body>Performance fixture</body>', dom.URL{ value: 'https://performance.example/' })
	document.load_timing_info.navigation_start_time = highresolutiontime.coarsened_shared_current_time(false) - 50
	window := WindowModel.create_top_level(document, none, 'performance') or { panic(err) }
	mut settings := window.environment_settings_.settings
	owner := EventLoop.create(.window)
	settings.responsible_event_loop_ = owner
	mut services := window.window_or_worker_global_scope()
	services.responsible_event_loop_ = owner
	return document, window, owner
}

fn drain_performance_owner(owner &EventLoop) {
	mut queue := owner.task_queue()
	for i := 0; i < 10; i++ {
		task := queue.take_first_runnable() or { return }
		assert task.source() == .performance_timeline
		task.execute()
	}
	panic('performance queue did not drain')
}

fn test_global_performance_retains_identity_and_uses_real_settings_and_entry_buffers() {
	_, window, owner := performance_window_fixture()
	mut scope := window.window_or_worker_global_scope()
	mut performance := scope.performance()
	assert performance == scope.performance()
	assert performance.relevant_global_handle() == voidptr(window)
	assert performance.now() >= 50
	assert performance.now() < 1000
	state := &GlobalPerformanceObservation{}
	scope.register_performance_observer(&PerformanceObserverRecord{
		entry_types: ['mark', 'measure']
		callback:    fn [state] (entries []PerformanceEntry) {
			mut observation := unsafe { &GlobalPerformanceObservation(state) }
			observation.names << entries.map(it.name)
		}
	})
	first := performance.mark('same', usertiming.PerformanceMarkOptions{ start_time: 20 })!
	second := performance.mark('same', usertiming.PerformanceMarkOptions{ start_time: 3 })!
	assert performance.get_entries_by_name('same', none) == [second.entry, first.entry]
	assert performance.convert_mark_to_timestamp(usertiming.StringOrTimestamp('same'))! == 3
	measurement := performance.measure('span', highresolutiontime.StartOrMeasureOptions(usertiming.PerformanceMeasureOptions{ start: usertiming.StringOrTimestamp('same'), duration: 5 }), none)!
	assert measurement.entry.start_time == 3
	assert measurement.entry.duration == 5
	assert scope.filter_buffer_map_by_name_and_type(none, none).len == 4
	assert state.names.len == 0
	drain_performance_owner(owner)
	assert state.names == ['same', 'same', 'span']
	performance.clear_marks('same')
	assert scope.filter_buffer_map_by_name_and_type(none, 'mark').len == 0
	performance.clear_measures(none)
	assert performance.get_entries_by_type('mark').len == 0
	assert performance.get_entries_by_type('measure').len == 0
	assert performance.get_entries_by_type('visibility-state').len == 1
}

fn test_global_resource_timing_overflow_dispatches_actual_event_and_reentrant_buffer_clear() {
	_, window, owner := performance_window_fixture()
	mut scope := window.window_or_worker_global_scope()
	mut performance := scope.performance()
	state := &GlobalPerformanceObservation{}
	performance.set_resource_timing_buffer_size(1)
	performance.set_onresourcetimingbufferfull(fn [state, performance] () {
		mut observation := unsafe { &GlobalPerformanceObservation(state) }
		observation.full_events++
		mut current := unsafe { &GlobalScopePerformance(performance) }
		current.clear_resource_timings()
	})
	first := performancetimeline.PerformanceEntry.new('first', 'resource', 1, 0)
	second := performancetimeline.PerformanceEntry.new('second', 'resource', 2, 0)
	performance.add_entry(first)
	performance.add_entry(second)
	assert performance.get_entries_by_type('resource') == [first]
	assert scope.resource_timing_buffer_current_size() == 1
	assert state.full_events == 0
	drain_performance_owner(owner)
	assert state.full_events == 1
	assert performance.get_entries_by_type('resource') == [second]
	performance.set_onresourcetimingbufferfull(none)
	if _ := performance.onresourcetimingbufferfull() {
		assert false
	}
}

fn test_cached_legacy_timing_reads_live_document_completion_timestamps() {
	mut document, window, _ := performance_window_fixture()
	document.load_timing_info.navigation_start_time = 1000
	mut scope := window.window_or_worker_global_scope()
	mut performance := scope.performance()
	timing := performance.timing()
	assert timing.load_event_end() == 0
	document.load_timing_info.load_event_end_time = 250
	assert performance.timing() == timing
	assert performance.convert_mark_to_timestamp(usertiming.StringOrTimestamp('loadEventEnd'))! == 250
	mut replacement := parse_document_with_url('<!doctype html><body>replacement</body>', dom.URL{ value: 'https://performance.example/replacement' })
	replacement.load_timing_info.navigation_start_time = 2000
	replacement.load_timing_info.load_event_end_time = 400
	mut current_window := unsafe { &WindowModel(window) }
	current_window.set_associated_document(replacement)
	assert performance.timing() == timing
	assert performance.convert_mark_to_timestamp(usertiming.StringOrTimestamp('loadEventEnd'))! == 400
}

fn test_worker_performance_has_its_own_real_global_and_window_name_restrictions() {
	_, window, _ := performance_window_fixture()
	mut realm := &ScriptingRealm{}
	worker := WorkerGlobalScope.create(dom.URL{ value: 'https://performance.example/worker.js' }, .classic, '', realm)
	_ = WorkerEnvironmentSettingsObject.setup(worker, mut realm, window.environment_settings_.settings.serialize(), highresolutiontime.unsafe_shared_current_time())
	mut scope := worker.window_or_worker_global_scope()
	mut performance := scope.performance()
	assert performance == scope.performance()
	assert performance.relevant_global_handle() == voidptr(worker)
	performance.mark('navigationStart', usertiming.PerformanceMarkOptions{ start_time: 5 })!
	assert performance.get_entries_by_type('mark').len == 1
	if _ := performance.convert_mark_to_timestamp(usertiming.StringOrTimestamp('navigationStart')) {
		assert false
	} else {
		assert err.msg().contains('requires a Window')
	}
	mut window_scope := window.window_or_worker_global_scope()
	assert window_scope.performance().get_entries_by_type('mark').len == 0
	assert window_scope.performance().get_entries_by_type('visibility-state').len == 1
}
