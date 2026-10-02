module webdriver

import time

@[heap]
struct ActionTestClock {
mut:
	now_ms      i64
	events      []string
	completed   int
	window_open bool = true
}

fn test_action_executor_waits_for_longest_tick_then_a_separate_task() {
	mut clock := &ActionTestClock{}
	clock_ptr := voidptr(clock)
	mut event_loop := ActionEventLoop.create_with_clock(fn [clock_ptr] () i64 {
		return unsafe { &ActionTestClock(clock_ptr) }.now_ms
	})
	mut state := InputState{}
	state.get_or_create_input_source(.key, 'keys', none)!
	executor := dispatch_actions_async(mut state, [
		[ActionObject{ id: 'keys', type_: .key, subtype: .key_down, key: 'a' },
			ActionObject{ type_: .none, subtype: .pause, duration_ms: 20 },
			ActionObject{ type_: .none, subtype: .pause, duration_ms: 50 }],
		[ActionObject{ id: 'keys', type_: .key, subtype: .key_up, key: 'a' }],
	], event_loop, ActionsOptions{
		dispatch_event: fn [clock_ptr] (event DispatchedEvent) {
			mut observed := unsafe { &ActionTestClock(clock_ptr) }
			observed.events << event.kind
		}
	}, fn [clock_ptr] (result ActionsResult) {
		mut observed := unsafe { &ActionTestClock(clock_ptr) }
		observed.completed++
		assert result.error_message == ''
	})
	assert clock.events == ['keyDown']
	assert !executor.complete()
	assert state.actions_queue.len == 0
	clock.now_ms = 49
	event_loop.process()
	assert clock.events == ['keyDown']
	clock.now_ms = 50
	event_loop.process() // single-shot timer fires, queueing the next tick
	assert clock.events == ['keyDown']
	event_loop.process() // distinct task dispatches keyUp
	assert clock.events == ['keyDown', 'keyUp']
	assert !executor.complete()
	event_loop.process() // zero-duration timer still requires a task handoff
	assert !executor.complete()
	event_loop.process()
	assert executor.complete()
	assert clock.completed == 1
	assert executor.result().events.map(it.kind) == clock.events
}

fn test_action_executor_reports_closed_window_before_next_tick() {
	mut clock := &ActionTestClock{}
	clock_ptr := voidptr(clock)
	mut event_loop := ActionEventLoop.create_with_clock(fn [clock_ptr] () i64 {
		return unsafe { &ActionTestClock(clock_ptr) }.now_ms
	})
	mut state := InputState{}
	state.get_or_create_input_source(.key, 'keys', none)!
	executor := dispatch_actions_async(mut state, [
		[ActionObject{ type_: .none, subtype: .pause, duration_ms: 5 }],
		[ActionObject{ id: 'keys', type_: .key, subtype: .key_down, key: 'a' }],
	], event_loop, ActionsOptions{
		is_window_open: fn [clock_ptr] () bool {
			return unsafe { &ActionTestClock(clock_ptr) }.window_open
		}
	}, none)
	clock.window_open = false
	clock.now_ms = 5
	event_loop.process()
	event_loop.process()
	assert executor.complete()
	assert executor.result().error_message.contains('no such window')
	assert executor.result().events.len == 0
	assert state.global_key_state().pressed.len == 0
}

fn test_synchronous_actions_honor_real_pause_duration() {
	mut state := InputState{}
	started := time.sys_mono_now()
	events := dispatch_actions(mut state, [[ActionObject{
		type_:       .none
		subtype:     .pause
		duration_ms: 20
	}]])!
	assert (time.sys_mono_now() - started) / 1_000_000 >= 20
	assert events.len == 0
	assert state.actions_queue.len == 0
}
