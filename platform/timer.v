// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Platform/Timer.{h,cpp} and its Core::Timer state transitions.
// The native host supplies registration and unregistering of the timer event.
module platform

__global platform_active_timers_ []&Timer

pub type TimerCallback = fn ()

@[heap]
pub struct Timer {
pub mut:
	on_timeout TimerCallback = unsafe { nil }
mut:
	active_      bool
	activity_root_ bool
	interval_ms_ int
	single_shot_ bool
	interval_dirty_ bool
	native_timer_ voidptr
	registration_generation_ u64
	allocation_owner_ &RetainedArena = unsafe { nil }
}

pub fn Timer.create() &Timer {
	return &Timer{allocation_owner_: timer_allocation_owner()}
}

fn timer_allocation_owner() &RetainedArena {
	// Process-wide timers created in a persistent section have no document
	// payload owner, even when that initialization runs during document work.
	if !arena_entered() { return unsafe { nil } }
	return current_retained_arena()
}

pub fn Timer.create_repeating(interval_ms int, handler TimerCallback) &Timer {
	return &Timer{
		allocation_owner_: timer_allocation_owner()
		interval_ms_: interval_ms
		single_shot_: false
		on_timeout: handler
	}
}

pub fn Timer.create_single_shot(interval_ms int, handler TimerCallback) &Timer {
	return &Timer{
		allocation_owner_: timer_allocation_owner()
		interval_ms_: interval_ms
		single_shot_: true
		on_timeout: handler
	}
}

pub fn (mut timer Timer) start() {
	timer.start_with_interval(timer.interval_ms_)
}

pub fn (mut timer Timer) start_with_interval(interval_ms int) {
	if timer.active_ { timer.take_activity_root(); return }
	timer.interval_ms_ = interval_ms
	timer.registration_generation_++
	timer.native_timer_ = register_native_timer(&timer, interval_ms)
	timer.active_ = true
	timer.take_activity_root()
}

pub fn (mut timer Timer) restart() {
	timer.restart_with_interval(timer.interval_ms_)
}

pub fn (mut timer Timer) restart_with_interval(interval_ms int) {
	mut owner := timer.allocation_owner_
	if owner != unsafe { nil } { owner.retain() }
	defer { if owner != unsafe { nil } { owner.release() } }
	timer.stop()
	timer.start_with_interval(interval_ms)
}

pub fn (mut timer Timer) stop() {
	timer.stop_registration()
	timer.release_activity_root()
}

fn (mut timer Timer) stop_registration() {
	if !timer.active_ { return }
	unregister_native_timer(timer.native_timer_)
	timer.native_timer_ = unsafe { nil }
	timer.active_ = false
}

fn (mut timer Timer) take_activity_root() {
	persistent := enter_persistent()
	defer { leave_persistent(persistent) }
	if timer.activity_root_ { return }
	timer.activity_root_ = true
	if timer.allocation_owner_ != unsafe { nil } { timer.allocation_owner_.retain() }
	platform_active_timers_ << &timer
}

fn (mut timer Timer) release_activity_root() {
	if !timer.activity_root_ { return }
	persistent := enter_persistent()
	timer.activity_root_ = false
	for index, active in platform_active_timers_ {
		if voidptr(active) == voidptr(&timer) {
			platform_active_timers_.delete(index)
			break
		}
	}
	leave_persistent(persistent)
	mut owner := timer.allocation_owner_
	if owner != unsafe { nil } { owner.release() }
}

pub fn (mut timer Timer) set_active(active bool) {
	if active { timer.start() } else { timer.stop() }
}

pub fn (timer &Timer) is_active() bool {
	return timer.active_
}

pub fn (timer &Timer) has_activity_root() bool {
	return timer.activity_root_
}

pub fn (timer &Timer) interval() int {
	return timer.interval_ms_
}

pub fn (mut timer Timer) set_interval(interval_ms int) {
	if timer.interval_ms_ == interval_ms { return }
	timer.interval_ms_ = interval_ms
	timer.interval_dirty_ = true
}

pub fn (timer &Timer) is_single_shot() bool {
	return timer.single_shot_
}

pub fn (mut timer Timer) set_single_shot(single_shot bool) {
	timer.single_shot_ = single_shot
}

pub fn (mut timer Timer) fire() {
	if !timer.active_ {
		return
	}
	if defer_timer_during_cooperative_work(&timer) { return }
	// A callback may stop the timer or retire its document. Keep the callback
	// and receiver alive until all post-callback timer bookkeeping is complete.
	mut owner := timer.allocation_owner_
	if owner != unsafe { nil } { owner.retain() }
	defer { if owner != unsafe { nil } { owner.release() } }
	// Load completions, HTML tasks and script callbacks are active work too.
	// Keep collection spacing through callback cleanup, then restore idle policy.
	mut heap_scope := begin_browser_activity_heap_scope()
	defer { heap_scope.finish() }
	if timer.single_shot_ {
		// Core::Timer stops before the handler. Platform::Timer retains its
		// activity root until that handler returns, unless it restarts the timer.
		timer.stop_registration()
	} else if timer.interval_dirty_ {
		timer.restart()
		timer.interval_dirty_ = false
	}
	if timer.on_timeout != unsafe { nil } {
		timer.on_timeout()
	}
	if !timer.active_ { timer.release_activity_root() }
}
