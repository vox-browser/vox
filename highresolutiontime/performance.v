// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of HighResolutionTime/Performance.{h,cpp,idl}. User- and
// resource-timing entries share the translated PerformanceTimeline buffer.
module highresolutiontime

import navigationtiming
import performancetimeline
import usertiming

pub type ResourceTimingBufferFullHandler = fn ()

pub struct PerformanceHost {
pub:
	time                    TimeOriginContext
	window_context          bool
	navigation_start        u64
	navigation_timing_names map[string]u64
	navigation_timing_entry ?&navigationtiming.PerformanceNavigationTiming
	global_handle voidptr
	current_time_context ?fn () TimeOriginContext
	queue_entry ?fn (&performancetimeline.PerformanceEntry)
	buffer_entry ?fn (&performancetimeline.PerformanceEntry)
	filter_entries ?fn (?string, ?string) []&performancetimeline.PerformanceEntry
	buffer_entries ?fn (string) []&performancetimeline.PerformanceEntry
	remove_entries ?fn (string, ?string)
	set_resource_buffer_limit ?fn (u32)
	create_timing ?fn () &navigationtiming.PerformanceTiming
}

pub struct PerformanceJSON {
pub:
	time_origin DOMHighResTimeStamp
}

pub type StartOrMeasureOptions = string | usertiming.PerformanceMeasureOptions

@[heap]
pub struct Performance {
pub:
	host PerformanceHost
pub mut:
	timeline                    &performancetimeline.PerformanceTimeline
	resource_timing_buffer_size u32 = 250
mut:
	resource_timing_handler ?ResourceTimingBufferFullHandler
	time_origin_timestamp   DOMHighResTimeStamp
	timing_                 ?&navigationtiming.PerformanceTiming
	navigation_             ?&navigationtiming.PerformanceNavigation
}

pub fn Performance.create(host PerformanceHost) &Performance {
	return &Performance{
		host: host
		timeline: performancetimeline.PerformanceTimeline.new(performancetimeline.supported_entry_types_for_global(host.window_context))
		time_origin_timestamp: get_time_origin_timestamp(host.time)
	}
}

pub fn Performance.construct_impl() &Performance {
	now := unsafe_shared_current_time()
	return Performance.create(PerformanceHost{
		time: TimeOriginContext{
			time_origin: now
		}
	})
}

// https://w3c.github.io/navigation-timing/#dom-performance-timing
pub fn (mut performance Performance) timing() &navigationtiming.PerformanceTiming {
	if timing := performance.timing_ {
		return timing
	}
	if create := performance.host.create_timing {
		timing := create()
		performance.timing_ = timing
		return timing
	}
	value := fn [performance] (name string) f64 {
		absolute := performance.host.navigation_timing_names[name] or { u64(0) }
		if absolute == 0 {
			return 0
		}
		return f64(absolute - performance.host.navigation_start)
	}
	timing := &navigationtiming.PerformanceTiming{
		load_timing_info: navigationtiming.DocumentLoadTimingInfo{
			navigation_start_time: f64(performance.host.navigation_start)
			dom_interactive_time: value('domInteractive')
			dom_content_loaded_event_start_time: value('domContentLoadedEventStart')
			dom_content_loaded_event_end_time: value('domContentLoadedEventEnd')
			dom_complete_time: value('domComplete')
			load_event_start_time: value('loadEventStart')
			load_event_end_time: value('loadEventEnd')
		}
		navigation_timing_entry_: performance.host.navigation_timing_entry
		// PerformanceHost's legacy values are already wall-clock milliseconds.
		estimated_monotonic_epoch: 0
	}
	performance.timing_ = timing
	return timing
}

// https://w3c.github.io/navigation-timing/#dom-performance-navigation
pub fn (mut performance Performance) navigation() &navigationtiming.PerformanceNavigation {
	if navigation := performance.navigation_ {
		return navigation
	}
	navigation := navigationtiming.PerformanceNavigation.create(performance.host.navigation_timing_entry)
	performance.navigation_ = navigation
	return navigation
}

// The V embedding represents the relevant WindowOrWorkerGlobalScope mixin by
// the shared performance timeline it owns.
pub fn (performance &Performance) window_or_worker() &performancetimeline.PerformanceTimeline {
	return performance.timeline
}

// PerformanceHost is the embedding's relevant WindowOrWorker global record.
pub fn (performance &Performance) relevant_global_object() PerformanceHost {
	return performance.host
}

pub fn (performance &Performance) time_origin() DOMHighResTimeStamp {
	if current := performance.host.current_time_context {
		return get_time_origin_timestamp(current())
	}
	return performance.time_origin_timestamp
}

pub fn (performance &Performance) now() DOMHighResTimeStamp {
	context := if current := performance.host.current_time_context { current() } else { performance.host.time }
	return current_high_resolution_time(context)
}

pub fn (performance &Performance) to_json() PerformanceJSON {
	return PerformanceJSON{
		time_origin: performance.time_origin()
	}
}

pub fn (mut performance Performance) mark(name string, options usertiming.PerformanceMarkOptions) !&usertiming.PerformanceMark {
	entry := usertiming.PerformanceMark.new(name, options, performance.now(), performance.host.window_context)!
	performance.record_entry(entry.entry)
	return entry
}

pub fn (mut performance Performance) clear_marks(name ?string) {
	performance.remove_entries('mark', name)
}

fn (mut performance Performance) convert_name_to_timestamp(name string) !DOMHighResTimeStamp {
	if !performance.host.window_context {
		return error("TypeError: '${name}' is a PerformanceTiming attribute and requires a Window")
	}
	if name == 'navigationStart' {
		return 0
	}
	timing := performance.timing()
	start_time := timing.navigation_start()
	end_time := match name {
		'unloadEventStart' { timing.unload_event_start() }
		'unloadEventEnd' { timing.unload_event_end() }
		'redirectStart' { timing.redirect_start() }
		'redirectEnd' { timing.redirect_end() }
		'fetchStart' { timing.fetch_start() }
		'domainLookupStart' { timing.domain_lookup_start() }
		'domainLookupEnd' { timing.domain_lookup_end() }
		'connectStart' { timing.connect_start() }
		'connectEnd' { timing.connect_end() }
		'secureConnectionStart' { timing.secure_connection_start() }
		'requestStart' { timing.request_start() }
		'responseStart' { timing.response_start() }
		'responseEnd' { timing.response_end() }
		'domLoading' { timing.dom_loading() }
		'domInteractive' { timing.dom_interactive() }
		'domContentLoadedEventStart' { timing.dom_content_loaded_event_start() }
		'domContentLoadedEventEnd' { timing.dom_content_loaded_event_end() }
		'domComplete' { timing.dom_complete() }
		'loadEventStart' { timing.load_event_start() }
		'loadEventEnd' { timing.load_event_end() }
		else { u64(0) }
	}
	if end_time == 0 {
		return error("InvalidAccessError: '${name}' has not happened yet")
	}
	return f64(end_time - start_time)
}

pub fn (mut performance Performance) convert_mark_to_timestamp(mark usertiming.StringOrTimestamp) !DOMHighResTimeStamp {
	match mark {
		string {
			if mark in usertiming.navigation_timing_entry_names {
				return performance.convert_name_to_timestamp(mark)
			}
			entries := performance.buffer_entries_for_type('mark')
			if entries.len == 0 {
				return error("SyntaxError: no PerformanceMark named '${mark}'")
			}
			for index := entries.len - 1; index >= 0; index-- {
				entry := entries[index]
				if entry.name == mark {
					return entry.start_time
				}
			}
			return error("SyntaxError: no PerformanceMark named '${mark}'")
		}
		f64 {
			if mark < 0 {
				return error('TypeError: mark timestamps cannot be negative')
			}
			return mark
		}
	}
}

pub fn (mut performance Performance) measure(name string, start_or_options ?StartOrMeasureOptions, end_mark ?string) !&usertiming.PerformanceMeasure {
	mut start_name := ?string(none)
	mut options := ?usertiming.PerformanceMeasureOptions(none)
	if argument := start_or_options {
		match argument {
			string {
				start_name = argument
			}
			usertiming.PerformanceMeasureOptions {
				options = argument
			}
		}
	}
	if measure_options := options {
		has_any := measure_options.start != none || measure_options.end != none
			|| measure_options.duration != none || measure_options.detail != none
		if has_any && end_mark != none {
			return error('TypeError: options and endMark cannot be supplied together')
		}
		if has_any && measure_options.start == none && measure_options.end == none {
			return error("TypeError: options require 'start' or 'end'")
		}
		if measure_options.start != none && measure_options.end != none
			&& measure_options.duration != none {
			return error("TypeError: 'start', 'end', and 'duration' cannot all be present")
		}
	}

	mut end_time := performance.now()
	if end := end_mark {
		end_time = performance.convert_mark_to_timestamp(usertiming.StringOrTimestamp(end))!
	} else if measure_options := options {
		if end := measure_options.end {
			end_time = performance.convert_mark_to_timestamp(end)!
		} else if start := measure_options.start {
			if duration := measure_options.duration {
				end_time = performance.convert_mark_to_timestamp(start)! + performance.convert_mark_to_timestamp(usertiming.StringOrTimestamp(duration))!
			}
		}
	}

	mut start_time := 0.0
	if measure_options := options {
		if start := measure_options.start {
			start_time = performance.convert_mark_to_timestamp(start)!
		} else if duration := measure_options.duration {
			if end := measure_options.end {
				start_time = performance.convert_mark_to_timestamp(end)! - performance.convert_mark_to_timestamp(usertiming.StringOrTimestamp(duration))!
			}
		}
	} else if start := start_name {
		start_time = performance.convert_mark_to_timestamp(usertiming.StringOrTimestamp(start))!
	}
	detail := if measure_options := options { measure_options.detail } else { none }
	entry := usertiming.PerformanceMeasure.new(name, start_time, end_time - start_time, detail)
	performance.record_entry(entry.entry)
	return entry
}

pub fn (mut performance Performance) clear_measures(name ?string) {
	performance.remove_entries('measure', name)
}

pub fn (mut performance Performance) clear_resource_timings() {
	performance.remove_entries('resource', none)
}

pub fn (mut performance Performance) set_resource_timing_buffer_size(max_size u32) {
	performance.resource_timing_buffer_size = max_size
	if set_limit := performance.host.set_resource_buffer_limit {
		set_limit(max_size)
		return
	}
	mut tuple := performance.window_or_worker().entry_buffers['resource'] or {
		performancetimeline.PerformanceEntryTuple{}
	}
	tuple.max_buffer_size = u64(max_size)
	unsafe {
		performance.window_or_worker().entry_buffers['resource'] = tuple
	}
}

pub fn (mut performance Performance) set_onresourcetimingbufferfull(handler ?ResourceTimingBufferFullHandler) {
	performance.resource_timing_handler = handler
}

pub fn (performance &Performance) onresourcetimingbufferfull() ?ResourceTimingBufferFullHandler {
	return performance.resource_timing_handler
}

pub fn (performance &Performance) dispatch_resource_timing_buffer_full() {
	handler := performance.resource_timing_handler or { return }
	handler()
}

pub fn (mut performance Performance) add_entry(entry &performancetimeline.PerformanceEntry) {
	if performance.host.buffer_entry != none {
		performance.record_entry(entry)
		return
	}
	mut timeline := performance.window_or_worker()
	if entry.entry_type == 'resource' {
		bounded_entry := &performancetimeline.PerformanceEntry{
			...entry
			max_buffer_size: u64(performance.resource_timing_buffer_size)
		}
		timeline.add_entry(bounded_entry)
		return
	}
	timeline.add_entry(entry)
}

pub fn (performance &Performance) get_entries() []&performancetimeline.PerformanceEntry {
	return performance.filtered_entries(none, none)
}

pub fn (performance &Performance) get_entries_by_type(kind string) []&performancetimeline.PerformanceEntry {
	return performance.filtered_entries(none, kind)
}

pub fn (performance &Performance) get_entries_by_name(name string, kind ?string) []&performancetimeline.PerformanceEntry {
	return performance.filtered_entries(name, kind)
}

fn (mut performance Performance) remove_entries(kind string, name ?string) {
	if remove := performance.host.remove_entries {
		remove(kind, name)
		return
	}
	if expected := name {
		mut tuple := performance.window_or_worker().entry_buffers[kind] or { return }
		tuple.performance_entry_buffer = tuple.performance_entry_buffer.filter(it.name != expected)
		unsafe {
			performance.window_or_worker().entry_buffers[kind] = tuple
		}
	} else {
		mut timeline := performance.window_or_worker()
		timeline.entry_buffers.delete(kind)
	}
}

fn (performance &Performance) filtered_entries(name ?string, kind ?string) []&performancetimeline.PerformanceEntry {
	if filter := performance.host.filter_entries { return filter(name, kind) }
	mut result := []&performancetimeline.PerformanceEntry{}
	for entry_kind, tuple in performance.window_or_worker().entry_buffers {
		if expected_type := kind {
			if expected_type != entry_kind {
				continue
			}
		}
		for entry in tuple.performance_entry_buffer {
			if expected_name := name {
				if expected_name != entry.name {
					continue
				}
			}
			mut inserted := false
			for index, existing in result {
				if entry.start_time < existing.start_time {
					result.insert(index, entry)
					inserted = true
					break
				}
			}
			if !inserted {
				result << entry
			}
		}
	}
	return result
}

// Performance.cpp queues and buffers through its relevant global's mixin.
pub fn (mut performance Performance) record_entry(entry &performancetimeline.PerformanceEntry) {
	if queue := performance.host.queue_entry { queue(entry) }
	if buffer := performance.host.buffer_entry { buffer(entry); return }
	mut timeline := performance.window_or_worker()
	timeline.add_entry(entry)
}

fn (performance &Performance) buffer_entries_for_type(kind string) []&performancetimeline.PerformanceEntry {
	if entries := performance.host.buffer_entries { return entries(kind) }
	tuple := performance.window_or_worker().entry_buffers[kind] or { return []&performancetimeline.PerformanceEntry{} }
	return tuple.performance_entry_buffer.clone()
}

pub fn (performance &Performance) relevant_global_handle() voidptr {
	return performance.host.global_handle
}
