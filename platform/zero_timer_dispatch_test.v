module platform

import time

@[heap]
struct ZeroTimerObservation {
mut:
	values []int
}

fn test_zero_timers_wait_for_a_pump_and_deliver_in_registration_order() {
	if !native_timer_scheduling_available() { return }
	state := &ZeroTimerObservation{}
	mut timers := []&Timer{}
	for value in 0 .. 4 {
		mut timer := Timer.create_single_shot(0, fn [state, value] () {
			mut observed := unsafe { &ZeroTimerObservation(state) }
			observed.values << value
		})
		timer.start()
		timers << timer
	}
	assert state.values.len == 0
	wait_for_native_timer(fn [state] () bool { return state.values.len == 4 })
	assert state.values == [0, 1, 2, 3]
	for timer in timers { assert !timer.is_active() && !timer.has_activity_root() }
}

fn test_zero_timer_cancellation_and_restart_discard_the_old_queued_callback() {
	if !native_timer_scheduling_available() { return }
	state := &ZeroTimerObservation{}
	mut cancelled := Timer.create_single_shot(0, fn () { assert false })
	mut restarted := Timer.create_single_shot(0, fn [state] () {
		mut observed := unsafe { &ZeroTimerObservation(state) }
		observed.values << 1
	})
	cancelled.start()
	restarted.start()
	cancelled.stop()
	restarted.restart()
	wait_for_native_timer(fn [state] () bool { return state.values.len == 1 })
	pump_native_events(0.005)
	assert state.values == [1]
	assert !cancelled.has_activity_root() && !restarted.has_activity_root()
}

fn test_zero_timer_nested_native_pump_delivers_another_timer_before_returning() {
	if !native_timer_scheduling_available() { return }
	state := &ZeroTimerObservation{}
	mut first := Timer.create_single_shot(0, fn [state] () {
		mut observed := unsafe { &ZeroTimerObservation(state) }
		observed.values << 1
		wait_for_native_timer(fn [state] () bool { return state.values.len == 2 })
		assert observed.values == [1, 2]
		observed.values << 3
	})
	mut second := Timer.create_single_shot(0, fn [state] () {
		mut observed := unsafe { &ZeroTimerObservation(state) }
		observed.values << 2
	})
	first.start()
	second.start()
	wait_for_native_timer(fn [state] () bool { return state.values.len == 3 })
	assert state.values == [1, 2, 3]
}

fn test_repeating_zero_timer_can_stop_and_restart_itself_without_a_stale_delivery() {
	if !native_timer_scheduling_available() { return }
	state := &ZeroTimerObservation{}
	mut timer := Timer.create_repeating(0, fn () {})
	timer.on_timeout = fn [state, timer] () {
		mut observed := unsafe { &ZeroTimerObservation(state) }
		observed.values << observed.values.len
		mut current := unsafe { &Timer(timer) }
		if observed.values.len == 1 { current.restart() }
		if observed.values.len == 3 { current.stop() }
	}
	timer.start()
	wait_for_native_timer(fn [state] () bool { return state.values.len == 3 })
	pump_native_events(0.005)
	assert state.values == [0, 1, 2]
	assert !timer.is_active() && !timer.has_activity_root()
}

fn test_zero_timer_can_change_single_shot_policy_and_reload_a_positive_interval() {
	if !native_timer_scheduling_available() { return }
	state := &ZeroTimerObservation{}
	mut timer := Timer.create_single_shot(0, fn () {})
	timer.on_timeout = fn [state, timer] () {
		mut observed := unsafe { &ZeroTimerObservation(state) }
		observed.values << int(time.sys_mono_now() / 1_000_000)
		mut current := unsafe { &Timer(timer) }
		if observed.values.len == 1 { current.set_interval(20) }
		if observed.values.len == 2 { current.set_single_shot(true) }
	}
	timer.start()
	timer.set_single_shot(false)
	wait_for_native_timer(fn [state] () bool { return state.values.len == 3 })
	assert state.values[2] - state.values[1] >= 10
	assert timer.interval() == 20 && !timer.is_active() && !timer.has_activity_root()
}

fn test_zero_timer_keeps_a_retired_owner_through_native_callback_cleanup() {
	if !native_timer_scheduling_available() { return }
	mut owner := new_retained_arena('zero native timer owner')
	state := &ZeroTimerObservation{}
	mut scope := owner.enter()
	payload := 'retired zero timer'.bytes()
	mut timer := Timer.create_single_shot(0, fn [state, payload] () {
		assert payload.bytestr() == 'retired zero timer'
		mut observed := unsafe { &ZeroTimerObservation(state) }
		observed.values << 1
	})
	timer.start()
	scope.finish()
	owner.release()
	wait_for_native_timer(fn [state] () bool { return state.values.len == 1 })
	assert owner.arena.usage().used == 0
}

fn test_zero_timer_delivery_stays_coalesced_during_cooperative_work() {
	if !native_timer_scheduling_available() { return }
	state := &ZeroTimerObservation{}
	mut timer := Timer.create_single_shot(0, fn [state] () {
		mut observed := unsafe { &ZeroTimerObservation(state) }
		observed.values << 1
	})
	mut work := begin_cooperative_work(unsafe { nil }, fn (_ voidptr) {})
	timer.start()
	pump_native_events(0.005)
	assert state.values.len == 0
	work.finish()
	wait_for_native_timer(fn [state] () bool { return state.values.len == 1 })
	pump_native_events(0.005)
	assert state.values == [1] && !timer.has_activity_root()
}
