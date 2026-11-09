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
	deadline_         f64
}

pub fn Timer.create(window_or_worker_global_scope voidptr, milliseconds i32, callback fn (), id i32, repeating TimerRepeating) &Timer {
	return create_html_timer(window_or_worker_global_scope, milliseconds, callback, id, repeating, .delayed, 0)
}

// The source constructor carries the deadline on the shared high-resolution
// monotonic clock without losing its fractional milliseconds.
pub fn Timer.create_with_parameters(milliseconds i32, callback fn (), id i32, repeating TimerRepeating, throttling_class TimerThrottlingClass, deadline f64) &Timer {
	return create_html_timer(unsafe { nil }, milliseconds, callback, id, repeating, throttling_class, deadline)
}

fn create_html_timer(scope voidptr, milliseconds i32, callback fn (), id i32, repeating TimerRepeating, throttling_class TimerThrottlingClass, deadline f64) &Timer {
	core_timer := if repeating == .yes {
		platform.Timer.create_repeating(int(milliseconds), callback)
	} else {
		platform.Timer.create_single_shot(int(milliseconds), callback)
	}
	return &Timer{
		window_or_worker_global_scope: scope
		id: id
		timer_: core_timer
		throttling_class_: throttling_class
		deadline_: deadline
	}
}

pub fn (mut timer Timer) start() { timer.timer_.start() }
pub fn (mut timer Timer) stop() { timer.timer_.stop() }
pub fn (mut timer Timer) restart(milliseconds i32) { timer.timer_.restart_with_interval(int(milliseconds)) }

// Fire after `first_milliseconds`; a repeating timer then fires every
// `period_milliseconds` instead of keeping the first delay as its interval.
pub fn (mut timer Timer) restart_once(first_milliseconds i32, period_milliseconds i32) {
	timer.timer_.restart_with_interval(int(first_milliseconds))
	if !timer.timer_.is_single_shot() { timer.timer_.set_interval(int(period_milliseconds)) }
}
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
pub fn (timer &Timer) deadline() f64 { return timer.deadline_ }
pub fn (mut timer Timer) set_deadline(deadline f64) { timer.deadline_ = deadline }

// GC finalization is still an embedding boundary; explicit owner lifecycle
// uses the same source invariant and must stop the native clock first.
pub fn (timer &Timer) finalize() { assert !timer.is_active() }
