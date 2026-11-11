// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of PerformanceTimeline/PerformanceEntry.{h,cpp}, EntryTypes.cpp,
// EventNames.cpp, and PerformanceEntryTuple.h.
module performancetimeline

pub enum AvailableFromTimeline {
	no
	yes
}

pub enum ShouldAddEntry {
	no
	yes
}

pub const entry_types = [
	'element',
	'event',
	'first-input',
	'largest-contentful-paint',
	'layout-shift',
	'longtask',
	'mark',
	'measure',
	'navigation',
	'paint',
	'resource',
	'visibility-state',
]

pub const event_names = ['resourcetimingbufferfull']

// HighResolutionTime/SupportedPerformanceTypes.h is the current implementation
// capability list; entry_types above is the complete registry vocabulary.
pub const supported_entry_types = ['mark', 'measure', 'resource']

pub fn supported_entry_types_for_global(window_context bool) []string {
	mut result := supported_entry_types.clone()
	if window_context { result << 'visibility-state' }
	return result
}

// PerformanceEntry is the shared translated base value. Concrete entry types
// retain their specialised state and expose this value through performance_entry().
@[heap]
pub struct PerformanceEntry {
pub:
	name              string
	entry_type        string
	start_time        f64
	duration          f64
	available         AvailableFromTimeline = .yes
	max_buffer_size   ?u64
	should_add_result ShouldAddEntry = .yes
}

pub fn PerformanceEntry.new(name string, entry_type string, start_time f64, duration f64) &PerformanceEntry {
	return &PerformanceEntry{
		name: name
		entry_type: entry_type
		start_time: start_time
		duration: duration
	}
}

pub fn (entry &PerformanceEntry) name() string {
	return entry.name
}

pub fn (entry &PerformanceEntry) entry_type() string {
	return entry.entry_type
}

pub fn (entry &PerformanceEntry) start_time() f64 {
	return entry.start_time
}

pub fn (entry &PerformanceEntry) duration() f64 {
	return entry.duration
}

pub fn (entry &PerformanceEntry) should_add_entry(_ PerformanceObserverInit) ShouldAddEntry {
	return entry.should_add_result
}

pub struct PerformanceEntryJSON {
pub:
	name       string
	entry_type string
	start_time f64
	duration   f64
}

pub fn (entry &PerformanceEntry) to_json() PerformanceEntryJSON {
	return PerformanceEntryJSON{
		name: entry.name
		entry_type: entry.entry_type
		start_time: entry.start_time
		duration: entry.duration
	}
}

pub struct PerformanceEntryTuple {
pub mut:
	performance_entry_buffer []&PerformanceEntry
	max_buffer_size          ?u64
	available_from_timeline  AvailableFromTimeline
	dropped_entries_count    u64
}

// is_full mirrors PerformanceEntryTuple::is_full(): an absent maximum means
// infinite capacity, and every rejected insertion increments the drop count.
pub fn (mut tuple PerformanceEntryTuple) is_full() bool {
	limit := tuple.max_buffer_size or { return false }
	if u64(tuple.performance_entry_buffer.len) < limit {
		return false
	}
	tuple.dropped_entries_count++
	return true
}
