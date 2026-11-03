// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of UserTiming/PerformanceMark and PerformanceMeasure.
module usertiming

import performancetimeline

pub const navigation_timing_entry_names = ['connectEnd', 'connectStart', 'domainLookupEnd',
	'domainLookupStart', 'domComplete', 'domContentLoadedEventEnd', 'domContentLoadedEventStart',
	'domInteractive', 'domLoading', 'fetchStart', 'loadEventEnd', 'loadEventStart', 'navigationStart',
	'redirectEnd', 'redirectStart', 'requestStart', 'responseEnd', 'responseStart',
	'secureConnectionStart', 'unloadEventEnd', 'unloadEventStart']

pub struct PerformanceMarkOptions {
pub:
	detail     string
	detail_set bool
	start_time ?f64
}

@[heap]
pub struct PerformanceMark {
pub:
	entry  &performancetimeline.PerformanceEntry
	detail ?string
}

pub fn PerformanceMark.new(name string, options PerformanceMarkOptions, now f64, window_context bool) !&PerformanceMark {
	return PerformanceMark.create_for_constructor(name, options, now, window_context)
}

// The current time and principal-global kind are supplied by the translated
// host boundary; the remaining steps mirror the constructor algorithm.
pub fn PerformanceMark.create_for_constructor(mark_name string, mark_options PerformanceMarkOptions, now f64, window_context bool) !&PerformanceMark {
	validate_mark_options(mark_name, mark_options, now, window_context)!
	start_time := mark_options.start_time or { now }
	return &PerformanceMark{
		entry: performancetimeline.PerformanceEntry.new(mark_name, 'mark', start_time, 0)
		detail: if mark_options.detail_set { mark_options.detail } else { none }
	}
}

// The actual-value binding performs the constructor's detail clone after these
// checks and before allocating or publishing its native entry.
pub fn validate_mark_options(mark_name string, mark_options PerformanceMarkOptions, now f64, window_context bool) ! {
	if window_context && mark_name in navigation_timing_entry_names {
		return error("SyntaxError: '${mark_name}' is part of PerformanceTiming")
	}
	start_time := mark_options.start_time or { now }
	if start_time < 0 { return error('TypeError: startTime cannot be negative') }
}

pub fn PerformanceMark.construct_impl(mark_name string, mark_options PerformanceMarkOptions, now f64, window_context bool) !&PerformanceMark {
	return PerformanceMark.create_for_constructor(mark_name, mark_options, now, window_context)
}

pub fn (_ &PerformanceMark) entry_type() string {
	return 'mark'
}

pub fn (mark &PerformanceMark) detail() ?string {
	return mark.detail
}

pub fn (_ &PerformanceMark) available_from_timeline() performancetimeline.AvailableFromTimeline {
	return .yes
}

pub fn (_ &PerformanceMark) max_buffer_size() ?u64 {
	return none
}

pub fn (_ &PerformanceMark) should_add_entry() performancetimeline.ShouldAddEntry {
	return .yes
}

pub struct PerformanceMeasureOptions {
pub:
	detail   ?string
	start    ?StringOrTimestamp
	duration ?f64
	end      ?StringOrTimestamp
}

pub type StringOrTimestamp = f64 | string

@[heap]
pub struct PerformanceMeasure {
pub:
	entry  &performancetimeline.PerformanceEntry
	detail ?string
}

pub fn PerformanceMeasure.new(name string, start_time f64, duration f64, detail ?string) &PerformanceMeasure {
	return PerformanceMeasure.create(name, start_time, duration, detail)
}

pub fn PerformanceMeasure.create(measure_name string, start_time f64, duration f64, detail ?string) &PerformanceMeasure {
	return &PerformanceMeasure{
		entry: performancetimeline.PerformanceEntry.new(measure_name, 'measure', start_time, duration)
		detail: detail
	}
}

pub fn (_ &PerformanceMeasure) entry_type() string {
	return 'measure'
}

pub fn (measure &PerformanceMeasure) detail() ?string {
	return measure.detail
}

pub fn (_ &PerformanceMeasure) available_from_timeline() performancetimeline.AvailableFromTimeline {
	return .yes
}

pub fn (_ &PerformanceMeasure) max_buffer_size() ?u64 {
	return none
}

pub fn (_ &PerformanceMeasure) should_add_entry() performancetimeline.ShouldAddEntry {
	return .yes
}
