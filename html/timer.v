// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Timer.{h,cpp}. The embedder drives fire(); start/stop and
// interval mutation mirror the underlying Core::Timer state.
module html

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
	interval_ms i32
	callback    fn () @[required]
	repeating   bool
	active      bool
}

pub fn Timer.create(window_or_worker_global_scope voidptr, milliseconds i32, callback fn (), id i32, repeating TimerRepeating) &Timer {
	return &Timer{
		window_or_worker_global_scope: window_or_worker_global_scope
		id:                            id
		interval_ms:                   milliseconds
		callback:                      callback
		repeating:                     repeating == .yes
	}
}

pub fn (mut timer Timer) start() {
	timer.active = true
}

pub fn (mut timer Timer) stop() {
	timer.active = false
}

pub fn (mut timer Timer) set_callback(callback fn ()) {
	timer.callback = callback
}

pub fn (mut timer Timer) set_interval(milliseconds i32) {
	if timer.interval_ms != milliseconds {
		timer.interval_ms = milliseconds
	}
}

pub fn (mut timer Timer) fire() {
	if !timer.active {
		return
	}
	if !timer.repeating {
		timer.active = false
	}
	timer.callback()
}

pub fn (timer &Timer) is_active() bool {
	return timer.active
}

pub fn (timer &Timer) interval() i32 {
	return timer.interval_ms
}
