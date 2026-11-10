module html

import dom
import performancetimeline
import usertiming

@[heap]
struct NativePerformanceDelivery {
mut:
	names []string
}

fn native_performance_scope() (&WindowOrWorkerGlobalScopeMixin, &EventLoop) {
	document := parse_document_with_url('<!doctype html>', dom.URL{ value: 'https://observer.test/' })
	window := WindowModel.create_top_level(document, none, 'observer') or { panic(err) }
	mut settings := window.environment_settings_.settings
	mut scope := window.window_or_worker_global_scope()
	owner := EventLoop.create(.window)
	settings.responsible_event_loop_ = owner
	scope.responsible_event_loop_ = owner
	return scope, owner
}

fn drain_native_performance_tasks(owner &EventLoop) {
	mut queue := owner.task_queue()
	for _ in 0 .. 20 {
		task := queue.take_first_runnable() or { return }
		assert task.source() == .performance_timeline
		task.execute()
	}
	panic('Performance tasks did not settle')
}

fn test_native_observer_uses_the_owning_globals_current_and_buffered_entries() {
	mut scope, owner := native_performance_scope()
	mut performance := scope.performance()
	performance.mark('old', usertiming.PerformanceMarkOptions{ start_time: 2 })!
	state := &NativePerformanceDelivery{}
	mut observer := performancetimeline.PerformanceObserver.create(fn [state] (list performancetimeline.PerformanceObserverEntryList, _ &performancetimeline.PerformanceObserver, _ performancetimeline.PerformanceObserverCallbackOptions) {
		mut result := unsafe { &NativePerformanceDelivery(state) }
		result.names << list.get_entries().map(it.name)
	}, performance.timeline)
	observer.observe(performancetimeline.PerformanceObserverInit{ type_: 'mark', buffered: true })!
	scope.queue_the_performance_observer_task()
	performance.mark('new', usertiming.PerformanceMarkOptions{ start_time: 1 })!
	performance.clear_marks('old')
	assert observer.take_records().map(it.name) == ['old', 'new']
	performance.mark('delivered', usertiming.PerformanceMarkOptions{ start_time: 3 })!
	assert state.names.len == 0
	drain_native_performance_tasks(owner)
	assert state.names == ['delivered']
	observer.disconnect()
	observer.observe(performancetimeline.PerformanceObserverInit{ type_: 'mark', buffered: true })!
	assert observer.take_records().map(it.name) == ['new', 'delivered']
	performance.clear_marks(none)
	observer.disconnect()
	observer.observe(performancetimeline.PerformanceObserverInit{ type_: 'mark', buffered: true })!
	assert observer.take_records().len == 0
}

fn test_resource_buffer_overflow_does_not_suppress_native_observer_delivery() {
	mut scope, owner := native_performance_scope()
	mut performance := scope.performance()
	performance.set_resource_timing_buffer_size(1)
	state := &NativePerformanceDelivery{}
	mut observer := performancetimeline.PerformanceObserver.create(fn [state] (list performancetimeline.PerformanceObserverEntryList, _ &performancetimeline.PerformanceObserver, _ performancetimeline.PerformanceObserverCallbackOptions) {
		mut result := unsafe { &NativePerformanceDelivery(state) }
		result.names << list.get_entries().map(it.name)
	}, performance.timeline)
	observer.observe(performancetimeline.PerformanceObserverInit{ type_: 'resource' })!
	performance.add_entry(performancetimeline.PerformanceEntry.new('first', 'resource', 1, 0))
	performance.add_entry(performancetimeline.PerformanceEntry.new('overflow', 'resource', 2, 0))
	assert performance.get_entries_by_type('resource').map(it.name) == ['first']
	drain_native_performance_tasks(owner)
	assert state.names == ['first', 'overflow']
	observer.disconnect()
	observer.observe(performancetimeline.PerformanceObserverInit{ type_: 'resource', buffered: true })!
	assert observer.take_records().map(it.name) == ['first']
	performance.clear_resource_timings()
	observer.disconnect()
	observer.observe(performancetimeline.PerformanceObserverInit{ type_: 'resource', buffered: true })!
	assert observer.take_records().len == 0
}
