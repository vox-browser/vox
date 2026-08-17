module performancetimeline

fn record_observer_callback(_ PerformanceObserverEntryList, _ &PerformanceObserver, _ PerformanceObserverCallbackOptions) {
}

fn test_observe_validation_type_locking_and_disconnect() {
	mut timeline := PerformanceTimeline.new(['mark', 'resource'])
	mut observer := PerformanceObserver.new(record_observer_callback)
	mut missing := PerformanceObserverInit{}
	observer.observe(mut timeline, mut missing) or { assert err.msg().starts_with('TypeError:') }
	mut illegal := PerformanceObserverInit{
		entry_types: ['mark']
		type_:       'mark'
	}
	observer.observe(mut timeline, mut illegal) or { assert err.msg().starts_with('TypeError:') }
	mut single := PerformanceObserverInit{
		type_: 'mark'
	}
	observer.observe(mut timeline, mut single)!
	assert observer.observer_type() == .single
	mut multiple := PerformanceObserverInit{
		entry_types: ['resource']
	}
	observer.observe(mut timeline, mut multiple) or {
		assert err.msg().starts_with('InvalidModificationError:')
	}
	observer.disconnect(mut timeline)
	assert observer.take_records().len == 0
}

fn test_buffered_observation_delivery_and_dropped_count() {
	mut timeline := PerformanceTimeline.new(['resource'])
	timeline.add_entry(&PerformanceEntry{
		name:            'one'
		entry_type:      'resource'
		start_time:      1
		available:       .yes
		max_buffer_size: u64(1)
	})
	timeline.add_entry(&PerformanceEntry{
		name:            'dropped'
		entry_type:      'resource'
		start_time:      2
		available:       .yes
		max_buffer_size: u64(1)
	})
	mut observer := PerformanceObserver.new(record_observer_callback)
	mut options := PerformanceObserverInit{
		type_:    'resource'
		buffered: true
	}
	observer.observe(mut timeline, mut options)!
	assert timeline.observer_task_queued
	timeline.run_observer_task()
	assert observer.last_delivered_names() == ['one']
	assert observer.last_dropped_count() == 1
	assert !observer.requires_dropped_entries()
}

fn test_multiple_observer_filters_unsupported_types_and_receives_new_entries() {
	mut timeline := PerformanceTimeline.new(['mark', 'resource'])
	mut observer := PerformanceObserver.new(record_observer_callback)
	mut options := PerformanceObserverInit{
		entry_types: ['unsupported', 'mark']
	}
	observer.observe(mut timeline, mut options)!
	assert observer.options_list()[0].entry_types or { []string{} } == ['mark']
	timeline.add_entry(PerformanceEntry.new('m', 'mark', 3, 0))
	timeline.add_entry(PerformanceEntry.new('r', 'resource', 4, 0))
	timeline.run_observer_task()
	assert observer.last_delivered_names() == ['m']
}

fn test_tuple_capacity_and_multiple_observer_dropped_count() {
	mut unlimited := PerformanceEntryTuple{}
	assert !unlimited.is_full()
	mut limited := PerformanceEntryTuple{
		max_buffer_size: u64(0)
	}
	assert limited.is_full()
	assert limited.dropped_entries_count == 1

	mut timeline := PerformanceTimeline.new(['mark', 'resource'])
	timeline.add_entry(&PerformanceEntry{
		name:            'm1'
		entry_type:      'mark'
		available:       .yes
		max_buffer_size: u64(0)
	})
	timeline.add_entry(&PerformanceEntry{
		name:            'r1'
		entry_type:      'resource'
		available:       .yes
		max_buffer_size: u64(0)
	})
	mut observer := PerformanceObserver.new(record_observer_callback)
	mut options := PerformanceObserverInit{
		entry_types: ['mark', 'resource']
	}
	observer.observe(mut timeline, mut options)!
	// A delivered record is needed before upstream computes callback options.
	timeline.add_entry(PerformanceEntry.new('new', 'mark', 1, 0))
	timeline.run_observer_task()
	assert observer.last_dropped_count() == 2
}
