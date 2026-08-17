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
	if window_context && name in navigation_timing_entry_names {
		return error("SyntaxError: '${name}' is part of PerformanceTiming")
	}
	start_time := options.start_time or { now }
	if start_time < 0 {
		return error('TypeError: startTime cannot be negative')
	}
	return &PerformanceMark{
		entry:  performancetimeline.PerformanceEntry.new(name, 'mark', start_time, 0)
		detail: if options.detail_set { options.detail } else { none }
	}
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
	return &PerformanceMeasure{
		entry:  performancetimeline.PerformanceEntry.new(name, 'measure', start_time, duration)
		detail: detail
	}
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
