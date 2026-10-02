module html

struct TimerTestState {
mut:
	calls int
}

fn test_timer_exact_lifecycle_and_mutation() {
	mut state := &TimerTestState{}
	mut timer := Timer.create(voidptr(0x1), 10, fn [mut state] () {
		state.calls++
	}, 7, .no)
	assert timer.id == 7
	assert timer.interval() == 10
	timer.start()
	timer.fire()
	assert state.calls == 1
	assert !timer.is_active()
	timer.set_interval(25)
	assert timer.interval() == 25
	timer.set_callback(fn [mut state] () {
		state.calls += 2
	})
	timer.start()
	timer.stop()
	timer.fire()
	assert state.calls == 1
}

fn test_timer_source_constructor_retains_fractional_deadline_and_throttling_class() {
	mut timer := Timer.create_with_parameters(10, fn () {}, 11, .no, .chained, 42.125)
	assert timer.deadline() == 42.125
	assert timer.throttling_class() == .chained
	timer.set_deadline(42.625)
	timer.set_throttling_class(.delayed)
	assert timer.deadline() == 42.625
	assert timer.throttling_class() == .delayed
	timer.start()
	timer.stop()
	timer.finalize()
}
