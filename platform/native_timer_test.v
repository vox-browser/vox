module platform

import time

@[heap]
struct NativeTimerObservation {
mut:
	fires int
	start i64
	first_fire i64
}

fn wait_for_native_timer(condition fn () bool) {
	deadline := time.sys_mono_now() + i64(2_000_000_000)
	for !condition() && time.sys_mono_now() < deadline {
		pump_native_events(0.05)
	}
	assert condition()
}

fn test_single_shot_fires_from_the_native_run_loop_and_releases_its_activity_root() {
	if !native_timer_scheduling_available() { return }
	state := &NativeTimerObservation{ start: time.sys_mono_now() }
	mut timer := Timer.create_single_shot(20, fn [state] () {
		mut observation := unsafe { &NativeTimerObservation(state) }
		observation.fires++
		observation.first_fire = time.sys_mono_now()
	})
	timer.start()
	assert timer.is_active()
	wait_for_native_timer(fn [state] () bool { return state.fires == 1 })
	assert state.first_fire - state.start >= 10_000_000
	assert !timer.is_active()
	assert !timer.has_activity_root()
	assert !platform_active_timers_.any(voidptr(it) == voidptr(timer))
}

fn test_stopped_native_timer_never_delivers_its_callback() {
	if !native_timer_scheduling_available() { return }
	state := &NativeTimerObservation{}
	mut timer := Timer.create_single_shot(5, fn [state] () {
		mut observation := unsafe { &NativeTimerObservation(state) }
		observation.fires++
	})
	timer.start()
	timer.stop()
	mut sentinel := Timer.create_single_shot(20, fn () {})
	sentinel.start()
	wait_for_native_timer(fn [sentinel] () bool { return !sentinel.is_active() })
	assert state.fires == 0
}

fn test_native_repeating_timer_reloads_a_dirty_interval() {
	if !native_timer_scheduling_available() { return }
	state := &NativeTimerObservation{}
	mut timer := Timer.create_repeating(5, fn [state] () {
		mut observation := unsafe { &NativeTimerObservation(state) }
		observation.fires++
	})
	timer.start()
	timer.set_interval(10)
	wait_for_native_timer(fn [state] () bool { return state.fires >= 3 })
	timer.stop()
	assert timer.interval() == 10
	assert !timer.is_active()
	assert state.fires >= 3
}

fn test_single_shot_activity_root_is_retained_until_the_handler_returns() {
	mut timer := Timer.create_single_shot(30, fn () {})
	timer.on_timeout = fn [timer] () {
		assert !timer.is_active()
		assert timer.has_activity_root()
	}
	timer.start()
	timer.fire()
	assert !timer.has_activity_root()
}

fn test_start_of_an_active_timer_keeps_the_existing_registration_and_interval() {
	mut timer := Timer.create_single_shot(30, fn () {})
	timer.start()
	registration := timer.native_timer_
	timer.start_with_interval(90)
	assert timer.interval() == 30
	assert timer.native_timer_ == registration
	timer.stop()
}
