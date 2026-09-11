module usertiming

fn test_mark_validation_and_values() {
	mark := PerformanceMark.create_for_constructor('ready', PerformanceMarkOptions{
		detail: 'cloned detail'
		detail_set: true
	}, 12.5, true)!
	assert mark.entry.entry_type == 'mark'
	assert mark.entry_type() == 'mark'
	assert mark.entry.start_time == 12.5
	assert mark.entry.duration == 0
	assert mark.detail()? == 'cloned detail'
	assert mark.available_from_timeline() == .yes
	assert mark.should_add_entry() == .yes
	assert mark.max_buffer_size() == none
	PerformanceMark.new('navigationStart', PerformanceMarkOptions{}, 1, true) or {
		assert err.msg().starts_with('SyntaxError')
		return
	}
	assert false
}

fn test_negative_start_rejected_and_measure_created() {
	PerformanceMark.new('bad', PerformanceMarkOptions{ start_time: -0.1 }, 1, false) or {
		assert err.msg().starts_with('TypeError')
		measure := PerformanceMeasure.create('work', 2, 5, 'payload')
		assert measure.entry.entry_type == 'measure'
		assert measure.entry_type() == 'measure'
		assert measure.entry.duration == 5
		assert measure.detail()? == 'payload'
		assert measure.should_add_entry() == .yes
		return
	}
	assert false
}
