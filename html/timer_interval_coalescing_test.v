module html

import dom

@[heap]
struct IntervalCoalescingObservation {
mut:
	calls []f64
	clock ?&Timer
}

fn test_interval_keeps_native_ticks_after_delayed_tasks_and_coalesces_nested_firings() {
	mut scope := WindowOrWorkerGlobalScopeMixin.create(dom.Origin{}, false, false)
	defer { scope.clear_map_of_active_timers() }
	mut event_loop := EventLoop.create(.window)
	scope.responsible_event_loop_ = event_loop
	scope.manual_timer_clock_ = 0
	observation := &IntervalCoalescingObservation{}
	owner_handle := voidptr(scope)
	callback := &dom.CallbackType{
		call_with_arguments: fn [owner_handle, observation] (_ []dom.JSValue) dom.JSValue {
			mut owner := unsafe { &WindowOrWorkerGlobalScopeMixin(owner_handle) }
			mut observed := unsafe { &IntervalCoalescingObservation(observation) }
			observed.calls << owner.timer_now_ms()
			// Model callback work after delivery. The native periodic clock
			// still fires at 100, 200, 300, ... milliseconds.
			owner.manual_timer_clock_ = owner.timer_now_ms() + 5
			// A callback that pumps native events must not queue itself again
			// before it has completed and rearmed its interval.
			mut clock := observed.clock or { panic('missing interval clock') }
			clock.fire()
			return dom.js_undefined()
		}
	}
	id := scope.set_interval(timer_callback_handler(callback), 100, [])
	timer := scope.active_timers_[id] or { panic('missing interval') }
	mut clock := timer.clock_ or { panic('missing interval clock') }
	mut observed := unsafe { &IntervalCoalescingObservation(observation) }
	observed.clock = clock
	for index, tick in [100.0, 200.0, 300.0] {
		scope.manual_timer_clock_ = tick
		clock.fire()
		clock.fire()
		assert observation.calls.len == index
		event_loop.process()
		assert observation.calls.len == index + 1
		assert !event_loop.task_queue().has_runnable_tasks()
	}
	assert observation.calls == [100.0, 200.0, 300.0]
}

fn test_clearing_an_interval_cancels_its_coalesced_queued_firing() {
	mut scope := WindowOrWorkerGlobalScopeMixin.create(dom.Origin{}, false, false)
	defer { scope.clear_map_of_active_timers() }
	mut event_loop := EventLoop.create(.window)
	scope.responsible_event_loop_ = event_loop
	scope.manual_timer_clock_ = 0
	observation := &IntervalCoalescingObservation{}
	callback := &dom.CallbackType{
		call_with_arguments: fn [observation] (_ []dom.JSValue) dom.JSValue {
			mut observed := unsafe { &IntervalCoalescingObservation(observation) }
			observed.calls << 1
			return dom.js_undefined()
		}
	}
	id := scope.set_interval(timer_callback_handler(callback), 100, [])
	timer := scope.active_timers_[id] or { panic('missing interval') }
	mut clock := timer.clock_ or { panic('missing interval clock') }
	scope.manual_timer_clock_ = 100
	clock.fire()
	clock.fire()
	scope.clear_interval(id)
	event_loop.process()
	assert observation.calls.len == 0
	assert !event_loop.task_queue().has_runnable_tasks()
	assert scope.active_timer_count() == 0
}
