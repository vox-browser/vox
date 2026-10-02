module html

import dom
import platform
import time

@[heap]
struct NativeScopeTimerObservation {
mut:
	steps []string
}

fn wait_for_native_scope_timeout(condition fn () bool) {
	deadline := time.sys_mono_now() + i64(2_000_000_000)
	for !condition() && time.sys_mono_now() < deadline { platform.pump_native_events(0.01) }
	assert condition()
}

fn test_specification_timeout_removes_clock_before_completion_and_queues_actual_owning_task() {
	if !platform.native_timer_scheduling_available() { return }
	mut scope := WindowOrWorkerGlobalScopeMixin.create(dom.Origin{}, false, false)
	mut owner := EventLoop.create(.worker)
	scope.responsible_event_loop_ = owner
	owner.execution_paused = true
	state := &NativeScopeTimerObservation{}
	scope_handle := voidptr(scope)
	scope.run_steps_after_a_timeout(5, fn [scope_handle, owner, state] () {
		current := unsafe { &WindowOrWorkerGlobalScopeMixin(scope_handle) }
		assert current.active_timer_count() == 0
		mut result := unsafe { &NativeScopeTimerObservation(state) }
		result.steps << 'clock'
		queue_a_task(.timer_task, owner, none, fn [state, owner] () {
			task := owner.currently_running_task() or { panic('missing actual timer task') }
			assert task.source() == .timer_task
			mut task_result := unsafe { &NativeScopeTimerObservation(state) }
			task_result.steps << 'task'
		})
	})
	assert scope.active_timer_count() == 1
	wait_for_native_scope_timeout(fn [state] () bool { return state.steps.len == 1 })
	assert state.steps == ['clock']
	assert owner.task_queue().tasks.len == 1
	assert scope.active_timer_count() == 0
	owner.execution_paused = false
	owner.schedule()
	wait_for_native_scope_timeout(fn [state] () bool { return state.steps.len == 2 })
	assert state.steps == ['clock', 'task']
}

fn test_native_timeout_queued_task_is_cancellable_and_runs_with_actual_source_context() {
	if !platform.native_timer_scheduling_available() { return }
	mut scope := WindowOrWorkerGlobalScopeMixin.create(dom.Origin{}, false, false)
	mut owner := EventLoop.create(.worker)
	scope.responsible_event_loop_ = owner
	mut realm := &ScriptingRealm{}
	scope.error_reporting_realm_ = realm
	state := &NativeScopeTimerObservation{}
	callback := &dom.CallbackType{
		call_with_arguments: fn [state, realm, owner] (_ []dom.JSValue) dom.JSValue {
			assert realm.script_execution_depth == 1
			assert realm.callback_execution_depth == 1
			task := owner.currently_running_task() or { panic('missing actual timer task') }
			assert task.source() == .timer_task
			assert task.timer_nesting_level() == 1
			mut result := unsafe { &NativeScopeTimerObservation(state) }
			result.steps << 'handler'
			return dom.js_undefined()
		}
	}
	owner.execution_paused = true
	cancelled := scope.set_timeout(timer_callback_handler(callback), 5, [])
	wait_for_native_scope_timeout(fn [owner] () bool { return owner.task_queue().tasks.len == 1 })
	assert scope.active_timer_count() == 1
	clock := scope.active_timers_[cancelled].clock_ or { panic('missing actual clock') }
	assert !clock.is_active()
	scope.clear_timeout(cancelled)
	owner.execution_paused = false
	owner.schedule()
	wait_for_native_scope_timeout(fn [owner] () bool { return owner.task_queue().is_empty() })
	assert state.steps.len == 0
	scope.set_timeout(timer_callback_handler(callback), 5, [])
	wait_for_native_scope_timeout(fn [state] () bool { return state.steps.len == 1 })
	assert scope.active_timer_count() == 0
	assert realm.script_execution_depth == 0
	assert realm.callback_execution_depth == 0
}

fn test_timer_task_microtask_resets_source_nesting_and_repeating_clock_is_reused() {
	if !platform.native_timer_scheduling_available() { return }
	mut scope := WindowOrWorkerGlobalScopeMixin.create(dom.Origin{}, false, false)
	mut owner := EventLoop.create(.worker)
	scope.responsible_event_loop_ = owner
	state := &NativeScopeTimerObservation{}
	scope_handle := voidptr(scope)
	callback := &dom.CallbackType{
		call_with_arguments: fn [scope_handle, state, owner] (_ []dom.JSValue) dom.JSValue {
			mut result := unsafe { &NativeScopeTimerObservation(state) }
			result.steps << 'interval'
			if result.steps.len == 1 {
				queue_a_task(.microtask, owner, none, fn [scope_handle] () {
					mut current := unsafe { &WindowOrWorkerGlobalScopeMixin(scope_handle) }
					id := current.set_timeout(timer_source_handler('from microtask'), 0, [])
					assert current.active_timers_[id].nesting_level == 1
					assert current.active_timers_[id].timeout_ms == 0
					current.clear_timeout(id)
				})
			}
			return dom.js_undefined()
		}
	}
	id := scope.set_interval(timer_callback_handler(callback), 5, [])
	first_clock := scope.active_timers_[id].clock_ or { panic('missing repeating clock') }
	wait_for_native_scope_timeout(fn [state] () bool { return state.steps.len >= 2 })
	second_clock := scope.active_timers_[id].clock_ or { panic('missing reused repeating clock') }
	assert voidptr(first_clock) == voidptr(second_clock)
	assert scope.active_timers_[id].nesting_level >= 3
	scope.clear_interval(id)
	assert !first_clock.is_active()
}
