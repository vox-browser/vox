// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of EventTiming/PerformanceEventTiming.{h,cpp,idl}.
module eventtiming

import dom

pub enum AvailableFromTimeline {
	no
	yes
}

pub enum ShouldAddEntry {
	no
	yes
}

// This is the portion of PerformanceObserverInit consumed by EventTiming's
// registry hook. The current upstream implementation accepts but does not yet
// inspect it.
pub struct PerformanceObserverInit {
pub:
	duration_threshold ?u32
}

// Typed representation of PerformanceEntry, which is the IDL base interface of
// PerformanceEventTiming. PerformanceTimeline is not translated yet, so this
// package owns the narrow inherited surface it needs.
@[heap]
pub struct PerformanceEntry {
mut:
	name_       string
	start_time_ f64
	duration_   f64
}

pub fn (entry &PerformanceEntry) name() string {
	return entry.name_
}

pub fn (entry &PerformanceEntry) start_time() f64 {
	return entry.start_time_
}

pub fn (entry &PerformanceEntry) duration() f64 {
	return entry.duration_
}

// https://www.w3.org/TR/event-timing/#sec-performance-event-timing
@[heap]
pub struct PerformanceEventTiming {
	PerformanceEntry
mut:
	entry_type_       string
	event_target_     ?&dom.EventTarget
	event_start_time_ f64
	processing_start_ f64
	cancelable_       bool
	interaction_id_   u64
}

// PerformanceEventTiming.create mirrors the private C++ constructor. Realm
// allocation and prototype installation are responsibilities of the omitted
// LibJS binding layer.
// https://www.w3.org/TR/event-timing/#sec-init-event-timing
pub fn PerformanceEventTiming.create(name string, start_time f64, duration f64, event &dom.Event, processing_start f64, interaction_id u64) &PerformanceEventTiming {
	return &PerformanceEventTiming{
		PerformanceEntry:  PerformanceEntry{
			name_:       name
			start_time_: start_time
			duration_:   duration
		}
		entry_type_:       'event'
		event_start_time_: event.time_stamp()
		processing_start_: processing_start
		cancelable_:       event.cancelable()
		interaction_id_:   interaction_id
	}
}

pub fn (entry &PerformanceEventTiming) entry_type() string {
	return entry.entry_type_
}

// The four accessors below preserve the current Ladybird implementation. Its
// C++ source logs FIXME and returns zero/null rather than exposing the stored
// initialization values.
pub fn (entry &PerformanceEventTiming) processing_end() f64 {
	return 0
}

pub fn (entry &PerformanceEventTiming) processing_start() f64 {
	return 0
}

pub fn (entry &PerformanceEventTiming) cancelable() bool {
	return entry.cancelable_
}

pub fn (entry &PerformanceEventTiming) target() ?&dom.Node {
	return none
}

pub fn (entry &PerformanceEventTiming) interaction_id() u64 {
	return 0
}

// https://www.w3.org/TR/event-timing/#sec-should-add-performanceeventtiming
fn (entry &PerformanceEventTiming) should_add_performance_event_timing() ShouldAddEntry {
	// The first-input registry entry is always admitted.
	if entry.entry_type() == 'first-input' {
		return .yes
	}

	// Upstream VERIFYs that every other instance is an event. Keep that invariant
	// as an unconditional failure rather than turning corrupted state into a
	// normal "do not add" result.
	if entry.entry_type() != 'event' {
		panic('PerformanceEventTiming entry type must be event or first-input')
	}

	// Ladybird has not implemented durationThreshold/minDuration yet and
	// therefore currently returns No for all event entries.
	return .no
}

// https://w3c.github.io/timing-entrytypes-registry/#dfn-availablefromtimeline
pub fn PerformanceEventTiming.available_from_timeline() AvailableFromTimeline {
	return .yes
}

// https://w3c.github.io/timing-entrytypes-registry/#dfn-maxbuffersize
pub fn PerformanceEventTiming.max_buffer_size() ?u64 {
	return u64(1)
}

// https://w3c.github.io/timing-entrytypes-registry/#dfn-should-add-entry
pub fn (entry &PerformanceEventTiming) should_add_entry(_ ?PerformanceObserverInit) ShouldAddEntry {
	return entry.should_add_performance_event_timing()
}

// Typed equivalent of Web IDL's default toJSON operation.
pub struct PerformanceEventTimingJSON {
pub:
	name             string
	entry_type       string
	start_time       f64
	duration         f64
	processing_start f64
	processing_end   f64
	cancelable       bool
	target           ?&dom.Node
	interaction_id   u64
}

pub fn (entry &PerformanceEventTiming) to_json() PerformanceEventTimingJSON {
	return PerformanceEventTimingJSON{
		name:             entry.name()
		entry_type:       entry.entry_type()
		start_time:       entry.start_time()
		duration:         entry.duration()
		processing_start: entry.processing_start()
		processing_end:   entry.processing_end()
		cancelable:       entry.cancelable()
		target:           entry.target()
		interaction_id:   entry.interaction_id()
	}
}
