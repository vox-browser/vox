module html

import dom
import highresolutiontime
import performancetimeline

fn test_initial_visibility_entry_is_published_once_without_queuing_an_observer_task() {
	mut document := dom.Document.create(dom.URL{value: 'https://visibility-entry.test/'})
	defer { document.finalize() }
	document.set_origin(document.url.origin())
	document.load_timing_info.navigation_start_time = highresolutiontime.coarsened_shared_current_time(false) - 50
	window := WindowModel.create_top_level(document, none, 'visibility')!
	mut scope := window.window_or_worker_global_scope()
	mut performance := scope.performance()
	assert scope.supported_entry_types() == ['mark', 'measure', 'resource', 'visibility-state']
	entries := performance.get_entries_by_type('visibility-state')
	assert entries.len == 1
	assert entries[0].name == 'visible'
	assert entries[0].start_time == 0
	assert entries[0].duration == 0
	assert !scope.observer_task_queued_
	assert !performance.timeline.observer_task_queued
	document.flush_initial_visibility_state_entry()
	assert performance.get_entries_by_type('visibility-state').len == 1
	document.update_the_visibility_state(.visible)
	assert performance.get_entries_by_type('visibility-state').len == 1
	document.update_the_visibility_state(.hidden)
	assert performance.get_entries_by_type('visibility-state')[1].start_time >= 50
	assert !scope.observer_task_queued_
	assert !performance.timeline.observer_task_queued
}

fn test_visibility_buffer_caps_entries_without_suppressing_interested_observers() {
	mut document := dom.Document.create(dom.URL{value: 'https://visibility-buffer.test/'})
	defer { document.finalize() }
	window := WindowModel.create_top_level(document, none, '')!
	mut scope := window.window_or_worker_global_scope()
	mut performance := scope.performance()
	mut observer := performancetimeline.PerformanceObserver.create(fn (_ performancetimeline.PerformanceObserverEntryList,
		_ &performancetimeline.PerformanceObserver, _ performancetimeline.PerformanceObserverCallbackOptions) {}, performance.timeline)
	observer.observe(performancetimeline.PerformanceObserverInit{type_: 'visibility-state'})!
	for index in 0 .. 60 {
		document.update_the_visibility_state(if index % 2 == 0 { .hidden } else { .visible })
	}
	assert scope.observer_task_queued_
	assert performance.get_entries_by_type('visibility-state').len == 50
	assert observer.take_records().len == 60
	tuple := performance.timeline.entry_buffers['visibility-state'] or { panic('missing visibility buffer') }
	assert tuple.performance_entry_buffer.len == 50
	assert tuple.dropped_entries_count == 11
	observer.disconnect()
}

fn test_replacement_document_initial_entry_uses_the_traversables_hidden_state() {
	url := dom.URL{value: 'https://visibility-navigation.test/first'}
	mut first := create_navigation_document(url, url.origin(), none)!
	defer { first.finalize() }
	host := first.cached_navigable()?
	model := navigable_model_for_host(host)?
	traversable := TraversableNavigable.create_a_new_top_level_traversable('')!
	mut context := model.active_browsing_context()?
	context.set_top_level_traversable(traversable)
	assert traversable.system_visibility_state() == .hidden
	second_url := dom.URL{value: 'https://visibility-navigation.test/second'}
	mut second := create_navigation_document(second_url, second_url.origin(), first)!
	defer { second.finalize() }
	settings := unsafe { &EnvironmentSettingsObject(second.relevant_settings_object()) }
	mut scope := settings.window_or_worker_global_scope()!
	entries := scope.performance().get_entries_by_type('visibility-state')
	assert entries.len == 1
	assert entries[0].name == 'hidden'
	assert entries[0].start_time == 0
}
