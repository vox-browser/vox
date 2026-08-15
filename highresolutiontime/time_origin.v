// Copyright (c) 2022, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the self-contained core of Libraries/LibWeb/HighResolutionTime/TimeOrigin.cpp — coarsen
// time, the wall/monotonic unsafe current times, coarsened shared current time, and the estimated
// monotonic time of the Unix epoch.
//
// OUT OF SCOPE: get-time-origin-timestamp, current/relative high resolution time, and relative high
// resolution coarse time — these read a global object's relevant settings object's time origin (the
// HTML environment settings object), which is not translated.
// https://w3c.github.io/hr-time/
module highresolutiontime

import time
import math

// https://w3c.github.io/hr-time/#dom-domhighrestimestamp — a count of milliseconds (may be fractional).
pub type DOMHighResTimeStamp = f64

// https://w3c.github.io/hr-time/#dfn-coarsen-time
// Coarsen a timestamp so its resolution does not exceed 100 microseconds (0.1 ms), or 5 microseconds
// (0.005 ms) when the cross-origin isolated capability is set (HTML::CanUseCrossOriginIsolatedAPIs::Yes).
pub fn coarsen_time(timestamp DOMHighResTimeStamp, cross_origin_isolated_capability bool) DOMHighResTimeStamp {
	// 1. Time resolution is 100 microseconds.
	mut time_resolution_milliseconds := 0.1
	// 2. If cross-origin isolated, time resolution is 5 microseconds.
	if cross_origin_isolated_capability {
		time_resolution_milliseconds = 0.005
	}
	// 3. Coarsen timestamp so its resolution will not exceed time resolution.
	return math.floor(f64(timestamp) / time_resolution_milliseconds) * time_resolution_milliseconds
}

// https://w3c.github.io/hr-time/#wall-clock-unsafe-current-time — the wall clock's time in milliseconds
// since the Unix epoch (as a double, preserving sub-millisecond precision).
pub fn wall_clock_unsafe_current_time() DOMHighResTimeStamp {
	return f64(time.now().unix_nano()) / 1.0e6
}

// https://w3c.github.io/hr-time/#dfn-unsafe-shared-current-time — the shared monotonic clock in
// milliseconds (stored as a double).
pub fn unsafe_shared_current_time() DOMHighResTimeStamp {
	return f64(time.sys_mono_now()) / 1.0e6
}

// https://w3c.github.io/hr-time/#dfn-coarsened-shared-current-time — coarsen the unsafe shared current
// time.
pub fn coarsened_shared_current_time(cross_origin_isolated_capability bool) DOMHighResTimeStamp {
	return coarsen_time(unsafe_shared_current_time(), cross_origin_isolated_capability)
}

// https://w3c.github.io/hr-time/#dfn-estimated-monotonic-time-of-the-unix-epoch
pub fn estimated_monotonic_time_of_the_unix_epoch() DOMHighResTimeStamp {
	// 1. wall time is the wall clock's unsafe current time.
	wall_time := wall_clock_unsafe_current_time()
	// 2. monotonic time is the monotonic clock's unsafe current time.
	monotonic_time := unsafe_shared_current_time()
	// 3. epoch time is monotonic time - (wall time - Unix epoch).
	epoch_time := monotonic_time - (wall_time - 0.0)
	// 4. Return the coarsened epoch time.
	return coarsen_time(epoch_time, false)
}
