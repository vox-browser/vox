module html

import dom
import highresolutiontime
import platform
import time
import webidl

@[heap]
struct AbortTimeoutObservation {
mut:
	steps     []string
	timestamp f64
}

fn wait_for_actual_abort_timeout(condition fn () bool) {
	deadline := time.sys_mono_now() + i64(2_000_000_000)
	for !condition() && time.sys_mono_now() < deadline { platform.pump_native_events(0.01) }
	assert condition()
}

fn abort_timeout_window() &WindowModel {
	url := dom.URL{value: 'https://abort-timeout.example.test/'}
	document := &dom.Document{
		url:              url
		origin_:          url.origin()
		load_timing_info: dom.DocumentLoadTimingInfo{ navigation_start_time: highresolutiontime.unsafe_shared_current_time() }
	}
	return WindowModel.create_top_level(document, none, 'timeout') or { panic(err) }
}

fn test_abort_timeout_waits_for_owning_timer_task_and_uses_original_native_timeout_exception() {
	if !platform.native_timer_scheduling_available() { return }
	window := abort_timeout_window()
	settings := window.environment_settings_.settings
	mut owner := settings.responsible_event_loop()
	previous_paused := owner.execution_paused
	owner.execution_paused = true
	defer { owner.execution_paused = previous_paused }
	mut signal := abort_signal_timeout(settings, 5)!
	mut dependent := dom.AbortSignal.any([signal])!
	state := &AbortTimeoutObservation{}
	signal.add_abort_algorithm(fn [state] () {
		mut result := unsafe { &AbortTimeoutObservation(state) }
		result.steps << 'algorithm'
	})
	signal.add_event_listener_without_options('abort', dom.IDLEventListener.new(&dom.CallbackType{
		handle_event: fn [owner, signal, dependent, state, settings] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			assert signal.aborted() && dependent.aborted()
			assert event.is_trusted()
			task := owner.currently_running_task() or { panic('missing actual TimerTask') }
			assert task.source() == .timer_task
			assert voidptr(task.document() or { panic('missing owning document') }) == voidptr(settings.responsible_document() or { panic('missing signal document') })
			mut result := unsafe { &AbortTimeoutObservation(state) }
			result.steps << 'event'
			result.timestamp = event.time_stamp()
			return dom.js_undefined()
		}
	}))
	mut scope := window.window_or_worker_global_scope()
	wait_for_actual_abort_timeout(fn [scope] () bool { return scope.active_timer_count() == 0 })
	assert !signal.aborted() && !dependent.aborted()
	assert state.steps.len == 0
	assert owner.task_queue().tasks.any(it.source() == .timer_task)
	owner.execution_paused = false
	owner.schedule()
	wait_for_actual_abort_timeout(fn [signal] () bool { return signal.aborted() })
	assert state.steps == ['algorithm', 'event']
	assert state.timestamp >= 0 && state.timestamp <= settings.global_relative_event_timestamp()
	exception := webidl.dom_exception_from_object(signal.reason().as_webidl_value()!) or { panic('missing actual TimeoutError') }
	assert exception.name() == 'TimeoutError'
	assert exception.message() == 'Signal timed out'
	original_value := signal.reason().as_webidl_value()!
	dependent_value := dependent.reason().as_webidl_value()!
	assert voidptr(original_value.dom_exception_ or { panic('missing original native exception record') }) == voidptr(dependent_value.dom_exception_ or { panic('missing dependent native exception record') })
}

fn test_worker_abort_timeout_uses_worker_loop_and_global_relative_clock() {
	if !platform.native_timer_scheduling_available() { return }
	window := abort_timeout_window()
	mut realm := &ScriptingRealm{}
	worker := WorkerGlobalScope.create(dom.URL{value: 'https://abort-timeout.example.test/worker.js'}, .classic, '', realm)
	settings := WorkerEnvironmentSettingsObject.setup(worker, mut realm, window.environment_settings_.settings.serialize(), highresolutiontime.unsafe_shared_current_time()).settings
	mut owner := worker.event_loop
	assert voidptr(owner) != voidptr(main_thread_event_loop())
	owner.execution_paused = true
	mut signal := abort_signal_timeout(settings, 5)!
	state := &AbortTimeoutObservation{}
	signal.add_event_listener_without_options('abort', dom.IDLEventListener.new(&dom.CallbackType{
		handle_event: fn [owner, state] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			task := owner.currently_running_task() or { panic('missing Worker timer task') }
			assert task.source() == .timer_task && task.document() == none
			mut result := unsafe { &AbortTimeoutObservation(state) }
			result.steps << 'worker event'
			result.timestamp = event.time_stamp()
			return dom.js_undefined()
		}
	}))
	mut scope := worker.window_or_worker_global_scope()
	wait_for_actual_abort_timeout(fn [scope] () bool { return scope.active_timer_count() == 0 })
	assert !signal.aborted()
	assert owner.task_queue().tasks.len == 1
	owner.execution_paused = false
	owner.schedule()
	wait_for_actual_abort_timeout(fn [signal] () bool { return signal.aborted() })
	assert state.steps == ['worker event']
	assert state.timestamp >= 0 && state.timestamp <= settings.global_relative_event_timestamp()
}

fn test_controller_abort_uses_calling_global_clock_for_source_and_each_dependent_event() {
	mut controller := dom.AbortController.construct_impl()!
	signal := controller.signal()
	dependent := dom.AbortSignal.any([signal])!
	state := &AbortTimeoutObservation{}
	for target in [signal, dependent] {
		target.add_event_listener_without_options('abort', dom.IDLEventListener.new(&dom.CallbackType{
			handle_event: fn [state] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
				assert event.time_stamp() == 12.125
				mut result := unsafe { &AbortTimeoutObservation(state) }
				result.steps << 'abort'
				return dom.js_undefined()
			}
		}))
	}
	controller.abort_with_clock(dom.js_string('actual reason'), fn () f64 { return 12.125 })
	assert state.steps.len == 2
}
