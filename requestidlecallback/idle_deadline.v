// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of RequestIdleCallback/IdleDeadline.cpp and IdleRequest.h.
module requestidlecallback

import math

pub struct IdleRequestOptions {
pub:
	timeout ?u32 = u32(0)
}

pub struct IdleDeadline {
pub:
	did_timeout bool
}

pub fn IdleDeadline.create(did_timeout bool) IdleDeadline {
	return IdleDeadline{
		did_timeout: did_timeout
	}
}

// The upstream object obtains both values from the relevant global's event
// loop. Passing them explicitly preserves that boundary and makes coarsening
// deterministic.
pub fn (deadline IdleDeadline) time_remaining_at(now f64, event_loop_deadline f64) f64 {
	_ = deadline
	remaining := event_loop_deadline - now
	if remaining < 0 {
		return 0
	}
	return math.ceil(remaining)
}
