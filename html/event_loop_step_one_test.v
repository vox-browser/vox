module html

import platform
import time

@[heap]
struct StepOneObservation {
mut:
	steps []string
}

fn test_paused_processing_preserves_step_one_callbacks_tasks_and_generation() {
	mut owner := EventLoop.create(.window)
	state := &StepOneObservation{}
	owner.run_upon_reaching_step_1(fn [state] () {
		mut result := unsafe { &StepOneObservation(state) }
		result.steps << 'step-one'
	})
	queue_a_task(.dom_manipulation, owner, none, fn [state] () {
		mut result := unsafe { &StepOneObservation(state) }
		result.steps << 'task'
	})
	handle := owner.pause()
	owner.process()
	assert state.steps == []
	assert owner.task_generation() == 0
	assert owner.reached_step_1_tasks.len == 1
	assert !owner.task_queue().is_empty()
	owner.unpause(handle)
	owner.process()
	assert state.steps == ['step-one', 'task']
	assert owner.task_generation() == 1
	assert owner.reached_step_1_tasks.len == 0
	assert owner.task_queue().is_empty()
}

fn test_step_one_callbacks_registered_during_a_turn_wait_for_the_next_turn() {
	mut owner := EventLoop.create(.window)
	state := &StepOneObservation{}
	owner.run_upon_reaching_step_1(fn [owner, state] () {
		mut result := unsafe { &StepOneObservation(state) }
		result.steps << 'first-boundary'
		mut same_loop := unsafe { &EventLoop(owner) }
		same_loop.run_upon_reaching_step_1(fn [state] () {
			mut result := unsafe { &StepOneObservation(state) }
			result.steps << 'next-boundary'
		})
	})
	queue_a_task(.dom_manipulation, owner, none, fn [state] () {
		mut result := unsafe { &StepOneObservation(state) }
		result.steps << 'task'
	})
	owner.process()
	assert state.steps == ['first-boundary', 'task']
	assert owner.reached_step_1_tasks.len == 1
	owner.process()
	assert state.steps == ['first-boundary', 'task', 'next-boundary']
	assert owner.reached_step_1_tasks.len == 0
}

fn test_step_one_helper_uses_the_main_loop_without_running_at_a_microtask_checkpoint() {
	mut owner := main_thread_event_loop()
	mut worker := EventLoop.create(.worker)
	state := &StepOneObservation{}
	pending := owner.reached_step_1_tasks.len
	scheduled := owner.scheduled
	run_when_event_loop_reaches_step_1(fn [state] () {
		mut result := unsafe { &StepOneObservation(state) }
		result.steps << 'main-boundary'
	})
	assert owner.reached_step_1_tasks.len == pending + 1
	assert owner.scheduled == scheduled
	worker.process()
	owner.perform_a_microtask_checkpoint()
	assert state.steps == []
	owner.process()
	assert state.steps == ['main-boundary']
}

fn test_unpause_schedules_pending_step_one_callbacks_and_tasks_on_the_native_loop() {
	if !platform.native_timer_scheduling_available() { return }
	mut owner := EventLoop.create(.window)
	state := &StepOneObservation{}
	owner.run_upon_reaching_step_1(fn [state] () {
		mut result := unsafe { &StepOneObservation(state) }
		result.steps << 'step-one'
	})
	queue_a_task(.dom_manipulation, owner, none, fn [state] () {
		mut result := unsafe { &StepOneObservation(state) }
		result.steps << 'task'
	})
	handle := owner.pause()
	registration := owner.system_event_loop_timer_ or { panic('missing native timer') }
	deadline := time.sys_mono_now() + i64(2_000_000_000)
	for registration.is_active() && time.sys_mono_now() < deadline {
		platform.pump_native_events(0.01)
	}
	assert !registration.is_active()
	assert state.steps == []
	assert owner.task_generation() == 0
	owner.unpause(handle)
	assert registration.is_active()
	resume_deadline := time.sys_mono_now() + i64(2_000_000_000)
	for state.steps.len < 2 && time.sys_mono_now() < resume_deadline {
		platform.pump_native_events(0.01)
	}
	assert state.steps == ['step-one', 'task']
	assert owner.reached_step_1_tasks.len == 0
	assert owner.task_queue().is_empty()
	assert owner.task_generation() == 1
}
