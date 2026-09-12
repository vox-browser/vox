// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of NavigationTiming/EntryNames.cpp,
// PerformanceNavigation.cpp, and PerformanceTiming.cpp.
module navigationtiming

import math
import performancetimeline
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

pub enum NavigationTimingType {
	navigate
	reload
	back_forward
}

pub fn (kind NavigationTimingType) str() string {
	return match kind {
		.navigate { 'navigate' }
		.reload { 'reload' }
		.back_forward { 'back_forward' }
	}
}

pub struct PerformanceNavigation {
pub:
	type_                    u16
	redirect_count           u16
	navigation_timing_entry_ ?&PerformanceNavigationTiming
}

pub fn PerformanceNavigation.new(kind u16, redirect_count u16) PerformanceNavigation {
	return PerformanceNavigation{
		type_: kind
		redirect_count: redirect_count
	}
}

// create retains the Window-owned navigation entry boundary used by the
// upstream GC-allocated wrapper.
pub fn PerformanceNavigation.create(entry ?&PerformanceNavigationTiming) &PerformanceNavigation {
	return &PerformanceNavigation{
		navigation_timing_entry_: entry
	}
}

pub fn (navigation &PerformanceNavigation) navigation_timing_entry() ?&PerformanceNavigationTiming {
	return navigation.navigation_timing_entry_
}

// `type` is a V keyword, so the Web IDL `type()` accessor keeps the repository's
// established trailing-underscore spelling.
pub fn (navigation PerformanceNavigation) type_() u16 {
	if entry := navigation.navigation_timing_entry() {
		return match entry.type_() {
			.navigate { type_navigate }
			.reload { type_reload }
			.back_forward { type_back_forward }
		}
	}
	return navigation.type_
}

pub fn (navigation PerformanceNavigation) redirect_count() u16 {
	if entry := navigation.navigation_timing_entry() {
		return entry.redirect_count()
	}
	return navigation.redirect_count
}

pub struct PerformanceNavigationJSON {
pub:
	type_          u16
	redirect_count u16
}

pub fn (navigation PerformanceNavigation) to_json() PerformanceNavigationJSON {
	return PerformanceNavigationJSON{
		type_: navigation.type_()
		redirect_count: navigation.redirect_count()
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
	dom_loading_time                    f64
	dom_interactive_time                f64
	dom_content_loaded_event_start_time f64
	dom_content_loaded_event_end_time   f64
	dom_complete_time                   f64
	load_event_start_time               f64
	load_event_end_time                 f64
}

pub struct DocumentUnloadTimingInfo {
pub:
	unload_event_start_time f64
	unload_event_end_time   f64
}

pub struct NavigationConnectionTimingInfo {
pub:
	domain_lookup_start_time     f64
	domain_lookup_end_time       f64
	connection_start_time        f64
	connection_end_time          f64
	secure_connection_start_time f64
}

pub struct NavigationFetchTimingInfo {
pub:
	start_time                        f64
	redirect_start_time               f64
	redirect_end_time                 f64
	post_redirect_start_time          f64
	final_network_request_start_time  f64
	final_network_response_start_time f64
	end_time                          f64
	final_connection_timing_info      ?NavigationConnectionTimingInfo
}

pub struct NavigationTimingContext {
pub:
	document_url                    string
	time_origin                     f64
	cross_origin_isolated_capability bool
	load_timing_info                DocumentLoadTimingInfo
	previous_document_unload_timing DocumentUnloadTimingInfo
pub mut:
	timeline                &performancetimeline.PerformanceTimeline = performancetimeline.PerformanceTimeline.new(performancetimeline.supported_entry_types)
	navigation_timing_entry ?&PerformanceNavigationTiming
}

// PerformanceNavigationTiming is the navigation-specialized resource timing
// entry introduced upstream after the March snapshot.
@[heap]
pub struct PerformanceNavigationTiming {
mut:
	performance_entry_              &performancetimeline.PerformanceEntry = unsafe { nil }
	timing_info_                    NavigationFetchTimingInfo
	context_                        &NavigationTimingContext = unsafe { nil }
	redirect_count_                 u16
	navigation_type_                NavigationTimingType
	load_timing_info_               DocumentLoadTimingInfo
	previous_document_unload_timing_ DocumentUnloadTimingInfo
}

fn PerformanceNavigationTiming.new(context &NavigationTimingContext, timing_info NavigationFetchTimingInfo, redirect_count u16, navigation_type NavigationTimingType) &PerformanceNavigationTiming {
	return &PerformanceNavigationTiming{
		performance_entry_: &performancetimeline.PerformanceEntry{
			name: context.document_url
			entry_type: 'navigation'
			start_time: 0
			duration: 0
			available: .yes
		}
		timing_info_: timing_info
		context_: context
		redirect_count_: redirect_count
		navigation_type_: navigation_type
		load_timing_info_: context.load_timing_info
		previous_document_unload_timing_: context.previous_document_unload_timing
	}
}

// https://w3c.github.io/navigation-timing/#dfn-create-the-navigation-timing-entry
pub fn PerformanceNavigationTiming.create_navigation_timing_entry(mut context NavigationTimingContext, timing_info NavigationFetchTimingInfo, redirect_count u16, navigation_type NavigationTimingType) &PerformanceNavigationTiming {
	mut entry := PerformanceNavigationTiming.new(context, timing_info, redirect_count,
		navigation_type)
	entry.performance_entry_ = &performancetimeline.PerformanceEntry{
		name: context.document_url
		entry_type: 'navigation'
		start_time: 0
		duration: entry.load_event_end()
		available: .yes
	}
	context.navigation_timing_entry = entry
	context.timeline.add_entry(entry.performance_entry_)
	return entry
}

fn (entry &PerformanceNavigationTiming) convert_fetch_timestamp(timestamp f64) f64 {
	if timestamp == 0 {
		return 0
	}
	resolution := if entry.context_.cross_origin_isolated_capability { 0.005 } else { 0.1 }
	return math.floor((timestamp - entry.context_.time_origin) / resolution) * resolution
}

pub fn (entry &PerformanceNavigationTiming) performance_entry() &performancetimeline.PerformanceEntry {
	return entry.performance_entry_
}

pub fn (_ &PerformanceNavigationTiming) entry_type() string {
	return 'navigation'
}

pub fn PerformanceNavigationTiming.available_from_timeline() performancetimeline.AvailableFromTimeline {
	return .yes
}

pub fn PerformanceNavigationTiming.max_buffer_size() ?u64 {
	return none
}

pub fn (_ &PerformanceNavigationTiming) should_add_entry(_ ?performancetimeline.PerformanceObserverInit) performancetimeline.ShouldAddEntry {
	return .yes
}

pub fn (entry &PerformanceNavigationTiming) duration() f64 {
	return entry.load_event_end()
}

pub fn (entry &PerformanceNavigationTiming) redirect_start() f64 {
	if entry.redirect_count_ == 0 {
		return 0
	}
	return entry.convert_fetch_timestamp(entry.timing_info_.redirect_start_time)
}

pub fn (entry &PerformanceNavigationTiming) redirect_end() f64 {
	if entry.redirect_count_ == 0 {
		return 0
	}
	return entry.convert_fetch_timestamp(entry.timing_info_.redirect_end_time)
}

pub fn (entry &PerformanceNavigationTiming) fetch_start() f64 {
	return entry.convert_fetch_timestamp(entry.timing_info_.post_redirect_start_time)
}

pub fn (entry &PerformanceNavigationTiming) domain_lookup_start() f64 {
	info := entry.timing_info_.final_connection_timing_info or { return 0 }
	return entry.convert_fetch_timestamp(info.domain_lookup_start_time)
}

pub fn (entry &PerformanceNavigationTiming) domain_lookup_end() f64 {
	info := entry.timing_info_.final_connection_timing_info or { return 0 }
	return entry.convert_fetch_timestamp(info.domain_lookup_end_time)
}

pub fn (entry &PerformanceNavigationTiming) connect_start() f64 {
	info := entry.timing_info_.final_connection_timing_info or { return 0 }
	return entry.convert_fetch_timestamp(info.connection_start_time)
}

pub fn (entry &PerformanceNavigationTiming) connect_end() f64 {
	info := entry.timing_info_.final_connection_timing_info or { return 0 }
	return entry.convert_fetch_timestamp(info.connection_end_time)
}

pub fn (entry &PerformanceNavigationTiming) secure_connection_start() f64 {
	info := entry.timing_info_.final_connection_timing_info or { return 0 }
	return entry.convert_fetch_timestamp(info.secure_connection_start_time)
}

pub fn (entry &PerformanceNavigationTiming) request_start() f64 {
	return entry.convert_fetch_timestamp(entry.timing_info_.final_network_request_start_time)
}

pub fn (entry &PerformanceNavigationTiming) response_start() f64 {
	return entry.convert_fetch_timestamp(entry.timing_info_.final_network_response_start_time)
}

pub fn (entry &PerformanceNavigationTiming) response_end() f64 {
	return entry.convert_fetch_timestamp(entry.timing_info_.end_time)
}

pub fn (entry &PerformanceNavigationTiming) unload_event_start() f64 {
	return entry.previous_document_unload_timing_.unload_event_start_time
}

pub fn (entry &PerformanceNavigationTiming) unload_event_end() f64 {
	return entry.previous_document_unload_timing_.unload_event_end_time
}

pub fn (entry &PerformanceNavigationTiming) dom_interactive() f64 {
	return entry.load_timing_info_.dom_interactive_time
}

pub fn (entry &PerformanceNavigationTiming) dom_content_loaded_event_start() f64 {
	return entry.load_timing_info_.dom_content_loaded_event_start_time
}

pub fn (entry &PerformanceNavigationTiming) dom_content_loaded_event_end() f64 {
	return entry.load_timing_info_.dom_content_loaded_event_end_time
}

pub fn (entry &PerformanceNavigationTiming) dom_complete() f64 {
	return entry.load_timing_info_.dom_complete_time
}

pub fn (entry &PerformanceNavigationTiming) load_event_start() f64 {
	return entry.load_timing_info_.load_event_start_time
}

pub fn (entry &PerformanceNavigationTiming) load_event_end() f64 {
	return entry.load_timing_info_.load_event_end_time
}

pub fn (entry &PerformanceNavigationTiming) type_() NavigationTimingType {
	return entry.navigation_type_
}

pub fn (entry &PerformanceNavigationTiming) redirect_count() u16 {
	return entry.redirect_count_
}

pub fn (_ &PerformanceNavigationTiming) critical_ch_restart() f64 {
	return 0
}

pub struct PerformanceNavigationTimingJSON {
pub:
	name                           string
	entry_type                     string
	start_time                     f64
	duration                       f64
	unload_event_start             f64
	unload_event_end               f64
	dom_interactive                f64
	dom_content_loaded_event_start f64
	dom_content_loaded_event_end   f64
	dom_complete                   f64
	load_event_start               f64
	load_event_end                 f64
	type_                          NavigationTimingType
	redirect_count                 u16
	critical_ch_restart            f64
}

pub fn (entry &PerformanceNavigationTiming) to_json() PerformanceNavigationTimingJSON {
	base := entry.performance_entry_
	return PerformanceNavigationTimingJSON{
		name: base.name
		entry_type: entry.entry_type()
		start_time: base.start_time
		duration: entry.duration()
		unload_event_start: entry.unload_event_start()
		unload_event_end: entry.unload_event_end()
		dom_interactive: entry.dom_interactive()
		dom_content_loaded_event_start: entry.dom_content_loaded_event_start()
		dom_content_loaded_event_end: entry.dom_content_loaded_event_end()
		dom_complete: entry.dom_complete()
		load_event_start: entry.load_event_start()
		load_event_end: entry.load_event_end()
		type_: entry.type_()
		redirect_count: entry.redirect_count()
		critical_ch_restart: entry.critical_ch_restart()
	}
}

pub struct PerformanceTiming {
pub:
	load_timing_info DocumentLoadTimingInfo
	previous_document_unload_timing DocumentUnloadTimingInfo
	navigation_timing_entry_ ?&PerformanceNavigationTiming
	// Injectable for deterministic tests; production callers use
	// highresolutiontime.estimated_monotonic_time_of_the_unix_epoch().
	estimated_monotonic_epoch f64
}

pub fn PerformanceTiming.create(load_timing_info DocumentLoadTimingInfo, previous_document_unload_timing DocumentUnloadTimingInfo, navigation_timing_entry ?&PerformanceNavigationTiming, epoch f64) &PerformanceTiming {
	return &PerformanceTiming{
		load_timing_info: load_timing_info
		previous_document_unload_timing: previous_document_unload_timing
		navigation_timing_entry_: navigation_timing_entry
		estimated_monotonic_epoch: epoch
	}
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

fn (timing PerformanceTiming) fetch_phase_to_wall_time_milliseconds(relative_timestamp f64) u64 {
	return timing.monotonic_timestamp_to_wall_time_milliseconds(relative_timestamp + timing.load_timing_info.navigation_start_time)
}

fn (timing PerformanceTiming) relative_timestamp_to_wall_time_milliseconds(relative_timestamp f64) u64 {
	if relative_timestamp == 0 {
		return 0
	}
	return timing.fetch_phase_to_wall_time_milliseconds(relative_timestamp)
}

pub fn (timing PerformanceTiming) navigation_timing_entry() ?&PerformanceNavigationTiming {
	return timing.navigation_timing_entry_
}

pub fn (timing PerformanceTiming) navigation_start() u64 {
	return timing.monotonic_timestamp_to_wall_time_milliseconds(timing.load_timing_info.navigation_start_time)
}

pub fn (timing PerformanceTiming) unload_event_start() u64 {
	return timing.relative_timestamp_to_wall_time_milliseconds(timing.previous_document_unload_timing.unload_event_start_time)
}

pub fn (timing PerformanceTiming) unload_event_end() u64 {
	return timing.relative_timestamp_to_wall_time_milliseconds(timing.previous_document_unload_timing.unload_event_end_time)
}

pub fn (timing PerformanceTiming) redirect_start() u64 {
	entry := timing.navigation_timing_entry() or { return 0 }
	if entry.redirect_count() == 0 {
		return 0
	}
	return timing.fetch_phase_to_wall_time_milliseconds(entry.redirect_start())
}

pub fn (timing PerformanceTiming) redirect_end() u64 {
	entry := timing.navigation_timing_entry() or { return 0 }
	if entry.redirect_count() == 0 {
		return 0
	}
	return timing.fetch_phase_to_wall_time_milliseconds(entry.redirect_end())
}

pub fn (timing PerformanceTiming) fetch_start() u64 {
	entry := timing.navigation_timing_entry() or { return 0 }
	return timing.fetch_phase_to_wall_time_milliseconds(entry.fetch_start())
}

pub fn (timing PerformanceTiming) domain_lookup_start() u64 {
	entry := timing.navigation_timing_entry() or { return 0 }
	return timing.fetch_phase_to_wall_time_milliseconds(entry.domain_lookup_start())
}

pub fn (timing PerformanceTiming) domain_lookup_end() u64 {
	entry := timing.navigation_timing_entry() or { return 0 }
	return timing.fetch_phase_to_wall_time_milliseconds(entry.domain_lookup_end())
}

pub fn (timing PerformanceTiming) connect_start() u64 {
	entry := timing.navigation_timing_entry() or { return 0 }
	return timing.fetch_phase_to_wall_time_milliseconds(entry.connect_start())
}

pub fn (timing PerformanceTiming) connect_end() u64 {
	entry := timing.navigation_timing_entry() or { return 0 }
	return timing.fetch_phase_to_wall_time_milliseconds(entry.connect_end())
}

pub fn (timing PerformanceTiming) secure_connection_start() u64 {
	entry := timing.navigation_timing_entry() or { return 0 }
	return timing.relative_timestamp_to_wall_time_milliseconds(entry.secure_connection_start())
}

pub fn (timing PerformanceTiming) request_start() u64 {
	entry := timing.navigation_timing_entry() or { return 0 }
	return timing.fetch_phase_to_wall_time_milliseconds(entry.request_start())
}

pub fn (timing PerformanceTiming) response_start() u64 {
	entry := timing.navigation_timing_entry() or { return 0 }
	return timing.fetch_phase_to_wall_time_milliseconds(entry.response_start())
}

pub fn (timing PerformanceTiming) response_end() u64 {
	entry := timing.navigation_timing_entry() or { return 0 }
	return timing.relative_timestamp_to_wall_time_milliseconds(entry.response_end())
}

pub fn (timing PerformanceTiming) dom_loading() u64 {
	return timing.relative_timestamp_to_wall_time_milliseconds(timing.load_timing_info.dom_loading_time)
}

pub fn (timing PerformanceTiming) dom_interactive() u64 {
	return timing.relative_timestamp_to_wall_time_milliseconds(timing.load_timing_info.dom_interactive_time)
}

pub fn (timing PerformanceTiming) dom_content_loaded_event_start() u64 {
	return timing.relative_timestamp_to_wall_time_milliseconds(timing.load_timing_info.dom_content_loaded_event_start_time)
}

pub fn (timing PerformanceTiming) dom_content_loaded_event_end() u64 {
	return timing.relative_timestamp_to_wall_time_milliseconds(timing.load_timing_info.dom_content_loaded_event_end_time)
}

pub fn (timing PerformanceTiming) dom_complete() u64 {
	return timing.relative_timestamp_to_wall_time_milliseconds(timing.load_timing_info.dom_complete_time)
}

pub fn (timing PerformanceTiming) load_event_start() u64 {
	return timing.relative_timestamp_to_wall_time_milliseconds(timing.load_timing_info.load_event_start_time)
}

pub fn (timing PerformanceTiming) load_event_end() u64 {
	return timing.relative_timestamp_to_wall_time_milliseconds(timing.load_timing_info.load_event_end_time)
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
