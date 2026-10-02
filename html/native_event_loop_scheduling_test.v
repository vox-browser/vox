module html

import platform
import time

@[heap]
struct NativeEventLoopObservation {
mut:
	steps []string
}

fn wait_for_native_html_task(condition fn () bool) {
	deadline := time.sys_mono_now() + i64(2_000_000_000)
	for !condition() && time.sys_mono_now() < deadline {
		platform.pump_native_events(0.05)
	}
	assert condition()
}

fn test_queued_tasks_execute_on_the_native_run_loop_without_manual_process_calls() {
	if !platform.native_timer_scheduling_available() { return }
	mut owner := EventLoop.create(.window)
	state := &NativeEventLoopObservation{}
	queue_a_task(.networking, owner, none, fn [state] () {
		mut observation := unsafe { &NativeEventLoopObservation(state) }
		observation.steps << 'first'
	})
	queue_a_task(.dom_manipulation, owner, none, fn [state] () {
		mut observation := unsafe { &NativeEventLoopObservation(state) }
		observation.steps << 'second'
	})
	assert state.steps.len == 0
	registration := owner.system_event_loop_timer_ or { panic('native scheduling timer missing') }
	owner.schedule()
	assert owner.system_event_loop_timer_? == registration
	wait_for_native_html_task(fn [state] () bool { return state.steps.len == 2 })
	assert state.steps == ['first', 'second']
	assert owner.task_queue().is_empty()
	assert owner.task_generation() >= 2
}

fn test_spinning_an_empty_html_queue_waits_for_a_real_later_host_callback() {
	if !platform.native_timer_scheduling_available() { return }
	mut owner := EventLoop.create(.worker)
	state := &NativeEventLoopObservation{}
	mut response_timer := platform.Timer.create_single_shot(20, fn [owner, state] () {
		queue_a_task(.networking, owner, none, fn [state] () {
			mut observation := unsafe { &NativeEventLoopObservation(state) }
			observation.steps << 'response'
		})
	})
	response_timer.start()
	assert owner.task_queue().is_empty()
	owner.spin_until(fn [state] () bool { return state.steps.len == 1 })
	assert state.steps == ['response']
	assert !response_timer.is_active()
}
