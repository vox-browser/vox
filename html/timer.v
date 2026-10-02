// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of HTML/Timer.{h,cpp}; platform.Timer supplies the Core::Timer
// host registration. fire() is the explicit host adapter for manual embedders.
module html

import platform

pub enum TimerRepeating {
	no
	yes
}

@[heap]
pub struct Timer {
pub:
	window_or_worker_global_scope voidptr
	id                            i32
mut:
	timer_            &platform.Timer @[required]
	throttling_class_ TimerThrottlingClass = .delayed
	deadline_         i64
}

pub fn Timer.create(window_or_worker_global_scope voidptr, milliseconds i32, callback fn (), id i32, repeating TimerRepeating) &Timer {
	core_timer := if repeating == .yes {
		platform.Timer.create_repeating(int(milliseconds), callback)
	} else {
		platform.Timer.create_single_shot(int(milliseconds), callback)
	}
	return &Timer{
		window_or_worker_global_scope: window_or_worker_global_scope
		id: id
		timer_: core_timer
	}
}

pub fn (mut timer Timer) start() { timer.timer_.start() }
pub fn (mut timer Timer) stop() { timer.timer_.stop() }
pub fn (mut timer Timer) restart(milliseconds i32) { timer.timer_.restart_with_interval(int(milliseconds)) }
pub fn (mut timer Timer) set_callback(callback fn ()) { timer.timer_.on_timeout = callback }

// HTML::Timer::set_interval restarts when the interval changes, unlike the
// deferred dirty interval update exposed by Platform::Timer itself.
pub fn (mut timer Timer) set_interval(milliseconds i32) {
	if timer.timer_.interval() != int(milliseconds) { timer.restart(milliseconds) }
}

pub fn (mut timer Timer) fire() { timer.timer_.fire() }
pub fn (timer &Timer) is_active() bool { return timer.timer_.is_active() }
pub fn (timer &Timer) interval() i32 { return i32(timer.timer_.interval()) }
pub fn (timer &Timer) throttling_class() TimerThrottlingClass { return timer.throttling_class_ }
pub fn (mut timer Timer) set_throttling_class(class TimerThrottlingClass) { timer.throttling_class_ = class }
pub fn (timer &Timer) deadline() i64 { return timer.deadline_ }
pub fn (mut timer Timer) set_deadline(deadline i64) { timer.deadline_ = deadline }
