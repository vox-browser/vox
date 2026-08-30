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
