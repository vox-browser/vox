module eventtiming

import dom

fn make_timed_event(cancelable bool, time_stamp f64) &dom.Event {
	mut event := dom.Event.new_with_init('pointerdown', dom.EventInit{
		cancelable: cancelable
	})
	event.set_time_stamp(time_stamp)
	return event
}

fn test_initialization_exposes_performance_entry_and_cancelable_data() {
	event := make_timed_event(true, 125.5)
	entry := PerformanceEventTiming.create('pointerdown', 120.0, 32.0, event, 130.0, u64(42))

	assert entry.name() == 'pointerdown'
	assert entry.entry_type() == 'event'
	assert entry.start_time() == 120.0
	assert entry.duration() == 32.0
	assert entry.cancelable()

	// These stored members mirror the C++ constructor even though the current
	// upstream getters below remain FIXME stubs.
	assert entry.event_start_time_ == 125.5
	assert entry.processing_start_ == 130.0
	assert entry.interaction_id_ == 42
}

fn test_non_cancelable_event_is_captured() {
	event := make_timed_event(false, 4.0)
	entry := PerformanceEventTiming.create('keyup', 4.0, 8.0, event, 5.0, u64(0))

	assert !entry.cancelable()
}

fn test_current_upstream_fixme_accessors_return_zero_or_null() {
	event := make_timed_event(true, 25.0)
	entry := PerformanceEventTiming.create('click', 20.0, 200.0, event, 30.0, u64(91))

	assert entry.processing_start() == 0
	assert entry.processing_end() == 0
	assert entry.interaction_id() == 0
	assert entry.target() == none
}

fn test_registry_metadata_matches_current_upstream_behavior() {
	assert PerformanceEventTiming.available_from_timeline() == .yes
	max_buffer_size := PerformanceEventTiming.max_buffer_size() or {
		assert false
		return
	}
	assert max_buffer_size == u64(1)

	event := make_timed_event(true, 25.0)
	entry := PerformanceEventTiming.create('click', 20.0, 1_000.0, event, 30.0, u64(91))

	// Duration and durationThreshold are not implemented upstream, so even a
	// long event is currently not admitted.
	assert entry.should_add_entry(none) == .no
	assert entry.should_add_entry(PerformanceObserverInit{
		duration_threshold: u32(16)
	}) == .no
}

fn test_first_input_registry_branch_is_admitted() {
	entry := &PerformanceEventTiming{
		PerformanceEntry: PerformanceEntry{
			name: 'pointerdown'
			entry_type: 'first-input'
			start_time: 1
			duration: 1
		}
		entry_type_: 'first-input'
	}

	assert entry.should_add_entry(none) == .yes
}

fn test_default_to_json_contains_inherited_and_event_timing_attributes() {
	event := make_timed_event(true, 125.5)
	entry := PerformanceEventTiming.create('pointerup', 120.0, 32.0, event, 130.0, u64(42))
	value := entry.to_json()

	assert value.name == 'pointerup'
	assert value.entry_type == 'event'
	assert value.start_time == 120.0
	assert value.duration == 32.0
	assert value.processing_start == 0
	assert value.processing_end == 0
	assert value.cancelable
	assert value.target == none
	assert value.interaction_id == 0
}
