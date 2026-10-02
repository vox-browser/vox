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
}

pub fn Timer.create() &Timer {
	return &Timer{}
}

pub fn Timer.create_repeating(interval_ms int, handler TimerCallback) &Timer {
	return &Timer{
		interval_ms_: interval_ms
		single_shot_: false
		on_timeout: handler
	}
}

pub fn Timer.create_single_shot(interval_ms int, handler TimerCallback) &Timer {
	return &Timer{
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
	timer.native_timer_ = register_native_timer(&timer, interval_ms)
	timer.active_ = true
	timer.take_activity_root()
}

pub fn (mut timer Timer) restart() {
	timer.restart_with_interval(timer.interval_ms_)
}

pub fn (mut timer Timer) restart_with_interval(interval_ms int) {
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
	if timer.activity_root_ { return }
	timer.activity_root_ = true
	platform_active_timers_ << &timer
}

fn (mut timer Timer) release_activity_root() {
	timer.activity_root_ = false
	platform_active_timers_ = platform_active_timers_.filter(voidptr(it) != voidptr(&timer))
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
