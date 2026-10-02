module platform

import time

@[heap]
struct NativeDeferredObservation {
mut:
	values []string
}

fn test_deferred_plugin_callbacks_run_on_the_native_loop_and_nested_work_gets_a_later_turn() {
	if !native_timer_scheduling_available() { return }
	mut plugin := EventLoopPlugin.new()
	state := &NativeDeferredObservation{}
	plugin.deferred_invoke(fn [mut plugin, state] () {
		mut observation := unsafe { &NativeDeferredObservation(state) }
		observation.values << 'first'
		plugin.deferred_invoke(fn [state] () {
			mut nested := unsafe { &NativeDeferredObservation(state) }
			nested.values << 'nested'
		})
		assert observation.values == ['first']
	})
	plugin.deferred_invoke(fn [state] () {
		mut observation := unsafe { &NativeDeferredObservation(state) }
		observation.values << 'second'
	})
	assert state.values.len == 0
	deadline := time.sys_mono_now() + i64(2_000_000_000)
	for state.values.len < 3 && time.sys_mono_now() < deadline { pump_native_events(0.05) }
	assert state.values == ['first', 'second', 'nested']
}

fn test_plugin_spin_waits_for_a_real_future_timer_even_with_no_initial_deferred_work() {
	if !native_timer_scheduling_available() { return }
	mut plugin := EventLoopPlugin.new()
	state := &NativeDeferredObservation{}
	mut timer := Timer.create_single_shot(20, fn [state] () {
		mut observation := unsafe { &NativeDeferredObservation(state) }
		observation.values << 'timer'
	})
	timer.start()
	plugin.spin_until(fn [state] () bool { return state.values.len == 1 })
	assert state.values == ['timer']
}
