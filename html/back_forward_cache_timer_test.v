module html

import dom

@[heap]
struct BackForwardCacheTimerTicks {
mut:
	count int
}

fn back_forward_cache_counting_handler(ticks &BackForwardCacheTimerTicks) TimerHandler {
	callback := &dom.CallbackType{
		call_with_arguments: fn [ticks] (_ []dom.JSValue) dom.JSValue {
			mut counter := unsafe { &BackForwardCacheTimerTicks(ticks) }
			counter.count++
			return dom.js_undefined()
		}
	}
	return timer_callback_handler(callback)
}

fn back_forward_cache_timer_clock_active(scope &WindowOrWorkerGlobalScopeMixin, id i32) bool {
	timer := scope.active_timers_[id] or { return false }
	clock := timer.clock_ or { return false }
	return clock.is_active()
}

// A cached page is not fully active, so its timer tasks cannot run. Its clocks
// stop instead of queueing an unrunnable task on every tick, including when the
// hidden-page throttling grace period ends while it is cached (that realign
// used to restart repeating clocks at their past deadlines with interval 0).
fn test_back_forward_cached_document_freezes_and_thaws_timers() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/' })
	document.set_origin(document.url.origin())
	window := WindowModel.create_top_level(document, none, 'bfcache-timer-freeze') or {
		panic(err)
	}
	mut scope := window.window_or_worker_global_scope()
	mut ticks := &BackForwardCacheTimerTicks{}
	interval_id := scope.set_interval(back_forward_cache_counting_handler(ticks), 10, [])
	timeout_id := scope.set_timeout(back_forward_cache_counting_handler(ticks), 5_000, [])
	assert back_forward_cache_timer_clock_active(scope, interval_id)
	assert back_forward_cache_timer_clock_active(scope, timeout_id)

	suspend_document_for_back_forward_cache(document)
	mut navigable := window.navigable() or { panic('missing navigable') }
	navigable.set_active_document(none)
	assert !document.is_fully_active()
	assert scope.timers_frozen()
	assert !back_forward_cache_timer_clock_active(scope, interval_id)
	assert !back_forward_cache_timer_clock_active(scope, timeout_id)
	if grace := scope.intensive_timer_grace_timer_ {
		assert !grace.is_active()
	}
	frozen_interval := scope.active_timers_[interval_id] or { panic('missing interval') }
	interval_remaining := frozen_interval.frozen_remaining_ms or { panic('interval not frozen') }
	assert interval_remaining >= 0 && interval_remaining <= 10
	frozen_timeout := scope.active_timers_[timeout_id] or { panic('missing timeout') }
	timeout_remaining := frozen_timeout.frozen_remaining_ms or { panic('timeout not frozen') }
	assert timeout_remaining > 4_000 && timeout_remaining <= 5_000

	scope.chained_timers_intensively_throttled_ = true
	scope.realign_timers(global_scope_now_ms() + 120_000)
	assert !back_forward_cache_timer_clock_active(scope, interval_id)
	assert !back_forward_cache_timer_clock_active(scope, timeout_id)
	scope.chained_timers_intensively_throttled_ = false

	// A frozen window still accepts timers from other windows' scripts.
	installed_id := scope.set_timeout(back_forward_cache_counting_handler(ticks), 0, [])
	assert !back_forward_cache_timer_clock_active(scope, installed_id)
	mut queue := main_thread_event_loop().task_queue()
	queued_before := queue.tasks.len
	scope.process_timers(global_scope_now_ms() + 120_000)
	assert queue.tasks.len == queued_before
	assert ticks.count == 0

	reactivate_back_forward_cached_document(document, navigable, false)
	assert document.is_fully_active()
	assert !scope.timers_frozen()
	for id in [interval_id, timeout_id, installed_id] {
		assert back_forward_cache_timer_clock_active(scope, id)
		thawed := scope.active_timers_[id] or { panic('missing thawed timer') }
		assert thawed.frozen_remaining_ms == none
	}
	thawed_timeout := scope.active_timers_[timeout_id] or { panic('missing timeout') }
	assert thawed_timeout.deadline_ms - global_scope_now_ms() <= timeout_remaining
	// The repeating clock returns to its own interval after the remaining delay.
	thawed_interval := scope.active_timers_[interval_id] or { panic('missing interval') }
	interval_clock := thawed_interval.clock_ or { panic('missing interval clock') }
	assert interval_clock.interval() == 10

	scope.process_timers(thawed_interval.due_time_ms)
	assert ticks.count >= 2
	scope.clear_interval(interval_id)
	scope.clear_timeout(timeout_id)
	assert scope.active_timer_count() == 0
}
