// Copyright (c) 2022, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HighResolutionTime/TimeOrigin.cpp. The
// relevant settings object is represented by the explicit TimeOriginContext.
// https://w3c.github.io/hr-time/
module highresolutiontime

import time
import math

// https://w3c.github.io/hr-time/#dom-domhighrestimestamp — a count of milliseconds (may be fractional).
pub type DOMHighResTimeStamp = f64

// https://www.w3.org/TR/hr-time-3/#the-epochtimestamp-typedef
pub type EpochTimeStamp = u64

// The two environment-settings values consumed by the time-origin algorithms.
pub struct TimeOriginContext {
pub:
	time_origin                      DOMHighResTimeStamp
	cross_origin_isolated_capability bool
}

// https://w3c.github.io/hr-time/#dfn-coarsen-time
// Coarsen a timestamp so its resolution does not exceed 100 microseconds (0.1 ms), or 5 microseconds
// (0.005 ms) when the cross-origin isolated capability is set (HTML::CanUseCrossOriginIsolatedAPIs::Yes).
pub fn coarsen_time(timestamp DOMHighResTimeStamp, cross_origin_isolated_capability bool) DOMHighResTimeStamp {
	// 1. Time resolution is 100 microseconds.
	mut coarsening_factor := i64(10)
	// 2. If cross-origin isolated, time resolution is 5 microseconds.
	if cross_origin_isolated_capability {
		coarsening_factor = 200
	}
	// 3. Coarsen timestamp so its resolution will not exceed time resolution.
	bucket := i64(math.floor(f64(timestamp) * f64(coarsening_factor)))
	mut coarse := f64(bucket) / f64(coarsening_factor)
	// The source avoids selecting the previous bucket when a representable
	// division result lies immediately below its intended bucket boundary.
	if math.floor(coarse * f64(coarsening_factor)) < f64(bucket) {
		coarse = math.nextafter(coarse, math.inf(1))
	}
	return coarse
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

pub fn get_time_origin_timestamp(context TimeOriginContext) DOMHighResTimeStamp {
	return context.time_origin - estimated_monotonic_time_of_the_unix_epoch()
}

pub fn current_high_resolution_time(context TimeOriginContext) DOMHighResTimeStamp {
	return relative_high_resolution_time(unsafe_shared_current_time(), context)
}

pub fn relative_high_resolution_time(timestamp DOMHighResTimeStamp, context TimeOriginContext) DOMHighResTimeStamp {
	coarse_time := coarsen_time(timestamp, context.cross_origin_isolated_capability)
	return relative_high_resolution_coarsen_time(coarse_time, context)
}

pub fn relative_high_resolution_coarsen_time(coarse_time DOMHighResTimeStamp, context TimeOriginContext) DOMHighResTimeStamp {
	return coarse_time - context.time_origin
}
