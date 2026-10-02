module html

import platform
import time

@[heap]
struct NativeHTMLTimerState {
mut:
	calls int
}

fn wait_for_native_html_timer(condition fn () bool) {
	deadline := time.sys_mono_now() + i64(2_000_000_000)
	for !condition() && time.sys_mono_now() < deadline { platform.pump_native_events(0.02) }
	assert condition()
}

fn test_html_timer_native_clock_replaces_callback_and_rearms_changed_interval() {
	if !platform.native_timer_scheduling_available() { return }
	state := &NativeHTMLTimerState{}
	mut timer := Timer.create(unsafe { nil }, 2_000, fn () { panic('replaced native timer callback') }, 7, .no)
	timer.start()
	timer.set_callback(fn [state] () {
		mut result := unsafe { &NativeHTMLTimerState(state) }
		result.calls++
	})
	timer.set_interval(5)
	assert timer.interval() == 5
	wait_for_native_html_timer(fn [state] () bool { return state.calls == 1 })
	assert !timer.is_active()
	timer.restart(5)
	timer.stop()
	platform.pump_native_events(0.02)
	assert state.calls == 1
}

fn test_html_repeating_timer_native_clock_stops_inside_source_callback() {
	if !platform.native_timer_scheduling_available() { return }
	state := &NativeHTMLTimerState{}
	mut timer := Timer.create(unsafe { nil }, 5, fn () {}, 8, .yes)
	timer_pointer := voidptr(timer)
	timer.set_callback(fn [state, timer_pointer] () {
		mut result := unsafe { &NativeHTMLTimerState(state) }
		result.calls++
		if result.calls == 2 {
			mut current := unsafe { &Timer(timer_pointer) }
			current.stop()
		}
	})
	timer.start()
	wait_for_native_html_timer(fn [state] () bool { return state.calls == 2 })
	assert !timer.is_active()
	platform.pump_native_events(0.02)
	assert state.calls == 2
}
