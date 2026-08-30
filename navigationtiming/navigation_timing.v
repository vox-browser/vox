// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of NavigationTiming/EntryNames.cpp,
// PerformanceNavigation.cpp, and PerformanceTiming.cpp.
module navigationtiming

import math
import time

pub const entry_names = [
	'connectEnd',
	'connectStart',
	'domainLookupEnd',
	'domainLookupStart',
	'domComplete',
	'domContentLoadedEventEnd',
	'domContentLoadedEventStart',
	'domInteractive',
	'domLoading',
	'fetchStart',
	'loadEventEnd',
	'loadEventStart',
	'navigationStart',
	'redirectEnd',
	'redirectStart',
	'requestStart',
	'responseEnd',
	'responseStart',
	'secureConnectionStart',
	'unloadEventEnd',
	'unloadEventStart',
]

pub const type_navigate = u16(0)
pub const type_reload = u16(1)
pub const type_back_forward = u16(2)
pub const type_reserved = u16(255)

pub struct PerformanceNavigation {
pub:
	type_          u16
	redirect_count u16
}

pub fn PerformanceNavigation.new(kind u16, redirect_count u16) PerformanceNavigation {
	return PerformanceNavigation{
		type_: kind
		redirect_count: redirect_count
	}
}

// `type` is a V keyword, so the Web IDL `type()` accessor keeps the repository's
// established trailing-underscore spelling.
pub fn (navigation PerformanceNavigation) type_() u16 {
	return navigation.type_
}

pub fn (navigation PerformanceNavigation) redirect_count() u16 {
	return navigation.redirect_count
}

pub struct PerformanceNavigationJSON {
pub:
	type_          u16
	redirect_count u16
}

pub fn (navigation PerformanceNavigation) to_json() PerformanceNavigationJSON {
	return PerformanceNavigationJSON{
		type_: navigation.type_
		redirect_count: navigation.redirect_count
	}
}

// PerformanceExtensions.idl exposes these two objects with [SameObject]. This
// wrapper retains and returns the exact instances rather than recreating them.
@[heap]
pub struct PerformanceExtensions {
mut:
	timing_     &PerformanceTiming = unsafe { nil }
	navigation_ &PerformanceNavigation = unsafe { nil }
}

pub fn PerformanceExtensions.new(timing &PerformanceTiming, navigation &PerformanceNavigation) &PerformanceExtensions {
	return &PerformanceExtensions{
		timing_: timing
		navigation_: navigation
	}
}

pub fn (extensions &PerformanceExtensions) timing() &PerformanceTiming {
	return extensions.timing_
}

pub fn (extensions &PerformanceExtensions) navigation() &PerformanceNavigation {
	return extensions.navigation_
}

pub struct DocumentLoadTimingInfo {
pub:
	navigation_start_time               f64
	dom_interactive_time                f64
	dom_content_loaded_event_start_time f64
	dom_content_loaded_event_end_time   f64
	dom_complete_time                   f64
	load_event_start_time               f64
	load_event_end_time                 f64
}

pub struct PerformanceTiming {
pub:
	load_timing_info DocumentLoadTimingInfo
	// Injectable for deterministic tests; production callers use
	// highresolutiontime.estimated_monotonic_time_of_the_unix_epoch().
	estimated_monotonic_epoch f64
}

fn coarsen_time(timestamp f64) f64 {
	return math.floor(timestamp / 0.1) * 0.1
}

fn estimated_monotonic_time_of_the_unix_epoch() f64 {
	wall_time := f64(time.now().unix_nano()) / 1.0e6
	monotonic_time := f64(time.sys_mono_now()) / 1.0e6
	return coarsen_time(monotonic_time - wall_time)
}

pub fn PerformanceTiming.new(load_timing_info DocumentLoadTimingInfo) PerformanceTiming {
	return PerformanceTiming{
		load_timing_info: load_timing_info
		estimated_monotonic_epoch: estimated_monotonic_time_of_the_unix_epoch()
	}
}

pub fn PerformanceTiming.with_epoch(load_timing_info DocumentLoadTimingInfo, epoch f64) PerformanceTiming {
	return PerformanceTiming{
		load_timing_info: load_timing_info
		estimated_monotonic_epoch: epoch
	}
}

// The C++ implementation obtains this through the relevant Window. The V host
// injects the same document timing record when constructing PerformanceTiming.
pub fn (timing PerformanceTiming) document_load_timing_info() DocumentLoadTimingInfo {
	return timing.load_timing_info
}

fn (timing PerformanceTiming) monotonic_timestamp_to_wall_time_milliseconds(timestamp f64) u64 {
	if timestamp == 0 {
		return 0
	}
	wall_time := timestamp - timing.estimated_monotonic_epoch
	return u64(coarsen_time(wall_time))
}

pub fn (timing PerformanceTiming) navigation_start() u64 {
	return timing.monotonic_timestamp_to_wall_time_milliseconds(timing.load_timing_info.navigation_start_time)
}

pub fn (_ PerformanceTiming) unload_event_start() u64 {
	return 0
}

pub fn (_ PerformanceTiming) unload_event_end() u64 {
	return 0
}

pub fn (_ PerformanceTiming) redirect_start() u64 {
	return 0
}

pub fn (_ PerformanceTiming) redirect_end() u64 {
	return 0
}

pub fn (_ PerformanceTiming) fetch_start() u64 {
	return 0
}

pub fn (_ PerformanceTiming) domain_lookup_start() u64 {
	return 0
}

pub fn (_ PerformanceTiming) domain_lookup_end() u64 {
	return 0
}

pub fn (_ PerformanceTiming) connect_start() u64 {
	return 0
}

pub fn (_ PerformanceTiming) connect_end() u64 {
	return 0
}

pub fn (_ PerformanceTiming) secure_connection_start() u64 {
	return 0
}

pub fn (_ PerformanceTiming) request_start() u64 {
	return 0
}

pub fn (_ PerformanceTiming) response_start() u64 {
	return 0
}

pub fn (_ PerformanceTiming) response_end() u64 {
	return 0
}

pub fn (_ PerformanceTiming) dom_loading() u64 {
	return 0
}

pub fn (timing PerformanceTiming) dom_interactive() u64 {
	return timing.monotonic_timestamp_to_wall_time_milliseconds(timing.load_timing_info.dom_interactive_time)
}

pub fn (timing PerformanceTiming) dom_content_loaded_event_start() u64 {
	return timing.monotonic_timestamp_to_wall_time_milliseconds(timing.load_timing_info.dom_content_loaded_event_start_time)
}

pub fn (timing PerformanceTiming) dom_content_loaded_event_end() u64 {
	return timing.monotonic_timestamp_to_wall_time_milliseconds(timing.load_timing_info.dom_content_loaded_event_end_time)
}

pub fn (timing PerformanceTiming) dom_complete() u64 {
	return timing.monotonic_timestamp_to_wall_time_milliseconds(timing.load_timing_info.dom_complete_time)
}

pub fn (timing PerformanceTiming) load_event_start() u64 {
	return timing.monotonic_timestamp_to_wall_time_milliseconds(timing.load_timing_info.load_event_start_time)
}

pub fn (timing PerformanceTiming) load_event_end() u64 {
	return timing.monotonic_timestamp_to_wall_time_milliseconds(timing.load_timing_info.load_event_end_time)
}

pub struct PerformanceTimingJSON {
pub:
	navigation_start               u64
	unload_event_start             u64
	unload_event_end               u64
	redirect_start                 u64
	redirect_end                   u64
	fetch_start                    u64
	domain_lookup_start            u64
	domain_lookup_end              u64
	connect_start                  u64
	connect_end                    u64
	secure_connection_start        u64
	request_start                  u64
	response_start                 u64
	response_end                   u64
	dom_loading                    u64
	dom_interactive                u64
	dom_content_loaded_event_start u64
	dom_content_loaded_event_end   u64
	dom_complete                   u64
	load_event_start               u64
	load_event_end                 u64
}

pub fn (timing PerformanceTiming) to_json() PerformanceTimingJSON {
	return PerformanceTimingJSON{
		navigation_start: timing.navigation_start()
		unload_event_start: timing.unload_event_start()
		unload_event_end: timing.unload_event_end()
		redirect_start: timing.redirect_start()
		redirect_end: timing.redirect_end()
		fetch_start: timing.fetch_start()
		domain_lookup_start: timing.domain_lookup_start()
		domain_lookup_end: timing.domain_lookup_end()
		connect_start: timing.connect_start()
		connect_end: timing.connect_end()
		secure_connection_start: timing.secure_connection_start()
		request_start: timing.request_start()
		response_start: timing.response_start()
		response_end: timing.response_end()
		dom_loading: timing.dom_loading()
		dom_interactive: timing.dom_interactive()
		dom_content_loaded_event_start: timing.dom_content_loaded_event_start()
		dom_content_loaded_event_end: timing.dom_content_loaded_event_end()
		dom_complete: timing.dom_complete()
		load_event_start: timing.load_event_start()
		load_event_end: timing.load_event_end()
	}
}
