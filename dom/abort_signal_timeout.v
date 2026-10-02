// Copyright (c) 2024, Tim Ledbetter <tim.ledbetter@ladybird.org>
// SPDX-License-Identifier: BSD-2-Clause
// Source: DOM/AbortSignal.cpp timeout(). HTML supplies the actual owning global
// scheduling and clock callbacks at the module boundary.
module dom

import platform

pub struct AbortSignalTimeoutContext {
pub:
	run_steps_after_timeout fn (u64, fn ()) @[required]
	queue_timer_task        fn (fn ())      @[required]
	event_timestamp         fn () f64       @[required]
}

pub fn AbortSignal.timeout_in_context(milliseconds u64, context AbortSignalTimeoutContext) !&AbortSignal {
	// 1-2. Create a signal in the caller's realm; context is its relevant global.
	signal := AbortSignal.construct_impl()!
	// 3. Wait with that global, then queue its actual TimerTask. The reason is
	// created only in the task, in the same order as the source algorithm.
	context.run_steps_after_timeout(milliseconds, fn [signal, context] () {
		context.queue_timer_task(fn [signal, context] () {
			mut current := unsafe { &AbortSignal(signal) }
			current.signal_abort_with_clock(timeout_error_value('Signal timed out'), context.event_timestamp)
		})
	})
	return signal
}

// Compatibility for standalone DOM embedders with no HTML global. This is an
// explicit native-clock adapter; browser factories always supply the actual
// Window/Worker context above. It never runs a background thread against DOM.
pub fn AbortSignal.timeout(milliseconds u64) !&AbortSignal {
	signal := AbortSignal.construct_impl()!
	mut timer := platform.Timer.create_single_shot(int(i32(milliseconds)), fn [signal] () {
		mut current := unsafe { &AbortSignal(signal) }
		current.signal_abort(timeout_error_value('Signal timed out'))
	})
	timer.start()
	return signal
}
