module highresolutiontime

import navigationtiming
import performancetimeline
import usertiming

fn deterministic_performance() &Performance {
	return Performance.create(PerformanceHost{
		time: TimeOriginContext{
			time_origin: 100
		}
		window_context: true
		navigation_start: 1_000
		navigation_timing_names: {
			'loadEventEnd': u64(1_250)
		}
	})
}

@[heap]
struct PerformanceFlag {
mut:
	called bool
}

fn test_performance_mark_buffers_and_filters_entries() {
	mut performance := deterministic_performance()
	first := performance.mark('first', usertiming.PerformanceMarkOptions{ start_time: 20 }) or {
		assert false
		return
	}
	second := performance.mark('second', usertiming.PerformanceMarkOptions{ start_time: 10 }) or {
		assert false
		return
	}
	assert first.entry.start_time == 20
	assert performance.get_entries().map(it.name) == [second.entry.name, first.entry.name]
	assert performance.get_entries_by_name('first', none).len == 1
	assert performance.get_entries_by_type('measure').len == 0
}

fn test_performance_mark_rejects_navigation_timing_names_in_window() {
	mut performance := deterministic_performance()
	if _ := performance.mark('navigationStart', usertiming.PerformanceMarkOptions{}) {
		assert false
	} else {
		assert err.msg().contains('SyntaxError')
	}
}

fn test_convert_mark_uses_latest_mark_and_legacy_timing() {
	mut performance := deterministic_performance()
	performance.mark('same', usertiming.PerformanceMarkOptions{ start_time: 3 })!
	performance.mark('same', usertiming.PerformanceMarkOptions{ start_time: 8 })!
	assert performance.convert_mark_to_timestamp(usertiming.StringOrTimestamp('same'))! == 8
	assert performance.convert_mark_to_timestamp(usertiming.StringOrTimestamp('navigationStart'))! == 0
	assert performance.convert_mark_to_timestamp(usertiming.StringOrTimestamp('loadEventEnd'))! == 250
}

fn test_measure_options_compute_start_end_and_duration() {
	mut performance := deterministic_performance()
	entry := performance.measure('span', StartOrMeasureOptions(usertiming.PerformanceMeasureOptions{
		start: usertiming.StringOrTimestamp(10.0)
		duration: 5.0
	}), none)!
	assert entry.entry.start_time == 10
	assert entry.entry.duration == 5
	assert performance.get_entries_by_type('measure').len == 1
}

fn test_measure_rejects_inconsistent_options() {
	mut performance := deterministic_performance()
	if _ := performance.measure('bad', StartOrMeasureOptions(usertiming.PerformanceMeasureOptions{
		start: usertiming.StringOrTimestamp(1.0)
		end: usertiming.StringOrTimestamp(2.0)
		duration: 1.0
	}), none) {
		assert false
	} else {
		assert err.msg().contains('cannot all be present')
	}
}

fn test_clear_marks_measures_and_resources() {
	mut performance := deterministic_performance()
	performance.mark('keep', usertiming.PerformanceMarkOptions{ start_time: 1 })!
	performance.mark('drop', usertiming.PerformanceMarkOptions{ start_time: 2 })!
	performance.clear_marks('drop')
	assert performance.get_entries_by_type('mark').map(it.name) == ['keep']
	performance.clear_marks(none)
	assert performance.get_entries_by_type('mark').len == 0
	performance.add_entry(performancetimeline.PerformanceEntry.new('resource', 'resource', 3, 1))
	performance.clear_resource_timings()
	assert performance.get_entries_by_type('resource').len == 0
}

fn test_resource_timing_buffer_and_handler() {
	mut performance := deterministic_performance()
	performance.set_resource_timing_buffer_size(1)
	performance.add_entry(performancetimeline.PerformanceEntry.new('one', 'resource', 1, 0))
	performance.add_entry(performancetimeline.PerformanceEntry.new('two', 'resource', 2, 0))
	assert performance.get_entries_by_type('resource').map(it.name) == ['one']
	mut flag := &PerformanceFlag{}
	performance.set_onresourcetimingbufferfull(fn [mut flag] () {
		flag.called = true
	})
	performance.dispatch_resource_timing_buffer_full()
	assert flag.called
}

fn test_performance_to_json_exposes_time_origin() {
	performance := deterministic_performance()
	assert performance.to_json().time_origin == performance.time_origin()
}

fn test_legacy_navigation_objects_are_lazy_same_objects() {
	mut performance := deterministic_performance()
	timing := performance.timing()
	navigation := performance.navigation()
	assert timing.navigation_start() == 1_000
	assert timing.load_event_end() == 1_250
	assert voidptr(timing) == voidptr(performance.timing())
	assert navigation.type_() == navigationtiming.type_navigate
	assert navigation.redirect_count() == 0
	assert voidptr(navigation) == voidptr(performance.navigation())
	assert performance.window_or_worker() == performance.timeline
	assert performance.relevant_global_object() == performance.host
}
