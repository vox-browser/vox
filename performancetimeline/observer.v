// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of PerformanceTimeline/PerformanceObserver.{h,cpp}.
module performancetimeline

pub struct PerformanceObserverInit {
pub mut:
	entry_types        ?[]string
	type_              ?string
	buffered           ?bool
	duration_threshold ?u32
}

pub struct PerformanceObserverCallbackOptions {
pub:
	dropped_entries_count ?u64
}

pub enum ObserverType {
	undefined
	single
	multiple
}

pub type PerformanceObserverCallback = fn (entries PerformanceObserverEntryList, observer &PerformanceObserver, options PerformanceObserverCallbackOptions)

@[heap]
pub struct PerformanceObserver {
mut:
	callback_                 PerformanceObserverCallback = unsafe { nil }
	relevant_global_          &PerformanceTimeline = unsafe { nil }
	observer_buffer_          []&PerformanceEntry
	observer_type_            ObserverType
	requires_dropped_entries_ bool
	options_list_             []PerformanceObserverInit
	registered_               bool
	last_delivered_names_     []string
	last_dropped_count_       u64
}

pub fn PerformanceObserver.new(callback PerformanceObserverCallback) &PerformanceObserver {
	return &PerformanceObserver{
		callback_: callback
	}
}

pub fn PerformanceObserver.construct_impl(callback PerformanceObserverCallback) &PerformanceObserver {
	return PerformanceObserver.new(callback)
}

pub fn PerformanceObserver.create(callback PerformanceObserverCallback, relevant_global &PerformanceTimeline) &PerformanceObserver {
	return &PerformanceObserver{
		callback_: callback
		relevant_global_: relevant_global
	}
}

pub fn PerformanceObserver.create_for_constructor(relevant_global &PerformanceTimeline, callback PerformanceObserverCallback) &PerformanceObserver {
	return PerformanceObserver.create(callback, relevant_global)
}

pub fn (observer &PerformanceObserver) relevant_global() &PerformanceTimeline {
	if observer.relevant_global_ == unsafe { nil } {
		panic('PerformanceObserver has not been associated with a relevant global')
	}
	return observer.relevant_global_
}

pub fn (observer &PerformanceObserver) callback() PerformanceObserverCallback {
	return observer.callback_
}

pub fn (observer &PerformanceObserver) observer_type() ObserverType {
	return observer.observer_type_
}

pub fn (observer &PerformanceObserver) requires_dropped_entries() bool {
	return observer.requires_dropped_entries_
}

pub fn (mut observer PerformanceObserver) unset_requires_dropped_entries() {
	observer.requires_dropped_entries_ = false
}

pub fn (observer &PerformanceObserver) options_list() []PerformanceObserverInit {
	return observer.options_list_.clone()
}

pub fn (observer &PerformanceObserver) last_delivered_names() []string {
	return observer.last_delivered_names_.clone()
}

pub fn (observer &PerformanceObserver) last_dropped_count() u64 {
	return observer.last_dropped_count_
}

pub fn (mut observer PerformanceObserver) observe(options PerformanceObserverInit) ! {
	mut timeline := observer.relevant_global()
	mut observer_options := clone_observer_init(options)
	if observer_options.entry_types == none && observer_options.type_ == none {
		return error('TypeError: must specify one of entryTypes or type')
	}
	if observer_options.entry_types != none
		&& (observer_options.type_ != none || observer_options.buffered != none) {
		return error('TypeError: cannot specify type or buffered with entryTypes')
	}
	if observer.observer_type_ == .undefined {
		observer.observer_type_ = if observer_options.entry_types != none {
			.multiple
		} else {
			.single
		}
	} else if observer.observer_type_ == .single && observer_options.entry_types != none {
		return error('InvalidModificationError: cannot change observer from single to multiple')
	} else if observer.observer_type_ == .multiple && observer_options.type_ != none {
		return error('InvalidModificationError: cannot change observer from multiple to single')
	}
	observer.requires_dropped_entries_ = true
	if observer.observer_type_ == .multiple {
		mut filtered := []string{}
		for kind in observer_options.entry_types or { []string{} } {
			if kind in timeline.supported_entry_types {
				filtered << kind
			}
		}
		observer_options.entry_types = filtered
		if filtered.len == 0 {
			return
		}
		observer.options_list_ = [clone_observer_init(observer_options)]
		timeline.register(mut observer)
		return
	}
	kind := observer_options.type_ or { return }
	if kind !in timeline.supported_entry_types {
		return
	}
	if observer.registered_ {
		mut replaced := false
		for index, existing in observer.options_list_ {
			if existing_type := existing.type_ {
				if option_type := observer_options.type_ {
					if existing_type == option_type {
						observer.options_list_[index] = clone_observer_init(observer_options)
						replaced = true
						break
					}
				}
			}
		}
		if !replaced {
			observer.options_list_ << clone_observer_init(observer_options)
		}
	} else {
		observer.options_list_ = [clone_observer_init(observer_options)]
		timeline.register(mut observer)
	}
	if observer_options.buffered or { false } {
		if tuple := timeline.entry_buffers[kind] {
			for entry in tuple.performance_entry_buffer {
				if entry.should_add_entry(observer_options) == .yes {
					observer.observer_buffer_ << entry
				}
			}
		}
		timeline.observer_task_queued = true
	}
}

fn clone_observer_init(options PerformanceObserverInit) PerformanceObserverInit {
	return PerformanceObserverInit{
		entry_types: if types := options.entry_types { types.clone() } else { none }
		type_: options.type_
		buffered: options.buffered
		duration_threshold: options.duration_threshold
	}
}

pub fn (mut observer PerformanceObserver) disconnect() {
	mut timeline := observer.relevant_global()
	timeline.unregister(&observer)
	observer.observer_buffer_.clear()
	observer.options_list_.clear()
	observer.registered_ = false
}

pub fn (mut observer PerformanceObserver) take_records() []&PerformanceEntry {
	records := observer.observer_buffer_.clone()
	observer.observer_buffer_.clear()
	return records
}

pub fn (mut observer PerformanceObserver) append_to_observer_buffer(entry &PerformanceEntry) {
	observer.observer_buffer_ << entry
}

pub fn (observer &PerformanceObserver) supported_entry_types() []string {
	return supported_entry_types_cache_for(observer.relevant_global())
}

pub fn (mut observer PerformanceObserver) invoke_callback(entry_list PerformanceObserverEntryList, dropped_entries_count ?u64) {
	observer.last_delivered_names_ = entry_list.get_entries().map(it.name)
	observer.last_dropped_count_ = dropped_entries_count or { 0 }
	observer.callback_(entry_list, observer, PerformanceObserverCallbackOptions{
		dropped_entries_count: dropped_entries_count
	})
}

struct SupportedEntryTypesCaches {}

fn supported_entry_types_caches() SupportedEntryTypesCaches {
	return SupportedEntryTypesCaches{}
}

fn (_ SupportedEntryTypesCaches) cache_for(relevant_global &PerformanceTimeline) []string {
	return create_supported_entry_types_array(relevant_global)
}

fn supported_entry_types_cache_for(relevant_global &PerformanceTimeline) []string {
	return supported_entry_types_caches().cache_for(relevant_global)
}

fn create_supported_entry_types_array(relevant_global &PerformanceTimeline) []string {
	// V arrays are values at the WebIDL boundary. Returning a clone gives callers
	// the same immutable-snapshot semantics as upstream's frozen JS array cache.
	return relevant_global.supported_entry_types.clone()
}

@[heap]
pub struct PerformanceTimeline {
pub:
	supported_entry_types []string = supported_entry_types.clone()
pub mut:
	entry_buffers        map[string]PerformanceEntryTuple
	observer_task_queued bool
mut:
	observers_ []&PerformanceObserver
}

pub fn PerformanceTimeline.new(supported []string) &PerformanceTimeline {
	return &PerformanceTimeline{
		supported_entry_types: supported.clone()
	}
}

fn (mut timeline PerformanceTimeline) register(mut observer PerformanceObserver) {
	if !observer.registered_ {
		timeline.observers_ << &observer
		observer.registered_ = true
	}
}

fn (mut timeline PerformanceTimeline) unregister(observer &PerformanceObserver) {
	mut retained := []&PerformanceObserver{}
	for existing in timeline.observers_ {
		if voidptr(existing) != voidptr(observer) {
			retained << existing
		}
	}
	timeline.observers_ = retained
}

pub fn (mut timeline PerformanceTimeline) add_entry(entry &PerformanceEntry) {
	timeline.buffer_entry(entry)
	timeline.queue_entry(entry)
}

// Embedders buffer and queue separately: a full resource buffer still sends
// entries to observers, and clearing the timeline must not clear their records.
pub fn (mut timeline PerformanceTimeline) buffer_entry(entry &PerformanceEntry) {
	mut tuple := timeline.entry_buffers[entry.entry_type] or { PerformanceEntryTuple{} }
	if entry.available == .yes {
		tuple.available_from_timeline = .yes
		tuple.max_buffer_size = entry.max_buffer_size
		if !tuple.is_full() {
			tuple.performance_entry_buffer << entry
		}
	}
	timeline.entry_buffers[entry.entry_type] = tuple
}

pub fn (mut timeline PerformanceTimeline) queue_entry(entry &PerformanceEntry) {
	for mut observer in timeline.observers_ {
		mut matches := false
		for option in observer.options_list_ {
			matches_type := if kind := option.type_ { kind == entry.entry_type } else { false }
			if matches_type || entry.entry_type in (option.entry_types or { []string{} }) {
				matches = true
				if entry.should_add_entry(option) == .yes {
					observer.observer_buffer_ << entry
				}
			}
		}
		if matches {
			timeline.observer_task_queued = true
		}
	}
}

pub fn (mut timeline PerformanceTimeline) run_observer_task() {
	if !timeline.observer_task_queued {
		return
	}
	timeline.observer_task_queued = false
	// A callback may disconnect itself or another observer, or register a new
	// observer. Deliver this task's snapshot without indexing a mutated array.
	mut observers := timeline.observers_.clone()
	for mut observer in observers {
		if observer.observer_buffer_.len == 0 {
			continue
		}
		mut records := observer.observer_buffer_.clone()
		observer.observer_buffer_.clear()
		mut dropped := ?u64(none)
		if observer.requires_dropped_entries_ {
			dropped = u64(0)
			for option in observer.options_list_ {
				if kind := option.type_ {
					if tuple := timeline.entry_buffers[kind] {
						dropped = dropped or { 0 } + tuple.dropped_entries_count
					}
				} else {
					for kind in option.entry_types or { []string{} } {
						if tuple := timeline.entry_buffers[kind] {
							dropped = dropped or { 0 } + tuple.dropped_entries_count
						}
					}
				}
			}
			observer.requires_dropped_entries_ = false
		}
		observer.invoke_callback(PerformanceObserverEntryList.create(records), dropped)
	}
}
