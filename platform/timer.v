// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Platform/Timer.{h,cpp}. Scheduling is supplied by the host;
// fire() is the host timeout edge.
module platform

pub type TimerCallback = fn ()

@[heap]
pub struct Timer {
pub mut:
	on_timeout TimerCallback = unsafe { nil }
mut:
	active_      bool
	interval_ms_ int
	single_shot_ bool
	has_timeout_ bool
}

pub fn Timer.create() &Timer {
	return &Timer{}
}

pub fn Timer.create_repeating(interval_ms int, handler TimerCallback) &Timer {
	return &Timer{
		interval_ms_: interval_ms
		single_shot_: false
		on_timeout: handler
		has_timeout_: true
	}
}

pub fn Timer.create_single_shot(interval_ms int, handler TimerCallback) &Timer {
	return &Timer{
		interval_ms_: interval_ms
		single_shot_: true
		on_timeout: handler
		has_timeout_: true
	}
}

pub fn (mut timer Timer) start() {
	timer.active_ = true
}

pub fn (mut timer Timer) start_with_interval(interval_ms int) {
	timer.interval_ms_ = interval_ms
	timer.active_ = true
}

pub fn (mut timer Timer) restart() {
	timer.active_ = true
}

pub fn (mut timer Timer) restart_with_interval(interval_ms int) {
	timer.interval_ms_ = interval_ms
	timer.active_ = true
}

pub fn (mut timer Timer) stop() {
	timer.active_ = false
}

pub fn (mut timer Timer) set_active(active bool) {
	timer.active_ = active
}

pub fn (timer &Timer) is_active() bool {
	return timer.active_
}

pub fn (timer &Timer) has_activity_root() bool {
	return timer.active_
}

pub fn (timer &Timer) interval() int {
	return timer.interval_ms_
}

pub fn (mut timer Timer) set_interval(interval_ms int) {
	timer.interval_ms_ = interval_ms
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
		timer.active_ = false
	}
	if timer.has_timeout_ {
		timer.on_timeout()
	}
}
