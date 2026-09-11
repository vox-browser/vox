// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of PerformanceTimeline/PerformanceObserverEntryList.{h,cpp}.
module performancetimeline

pub struct PerformanceObserverEntryList {
mut:
	entry_list_ []&PerformanceEntry
}

pub fn PerformanceObserverEntryList.new(entries []&PerformanceEntry) PerformanceObserverEntryList {
	return PerformanceObserverEntryList.create(entries)
}

pub fn PerformanceObserverEntryList.create(entries []&PerformanceEntry) PerformanceObserverEntryList {
	return PerformanceObserverEntryList{
		entry_list_: entries.clone()
	}
}

fn filter_buffer_by_name_and_type(buffer []&PerformanceEntry, name ?string, kind ?string) []&PerformanceEntry {
	mut result := []&PerformanceEntry{}
	for entry in buffer {
		if expected_type := kind {
			if expected_type != entry.entry_type {
				continue
			}
		}
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
	return result
}

pub fn (list &PerformanceObserverEntryList) get_entries() []&PerformanceEntry {
	return filter_buffer_by_name_and_type(list.entry_list_, none, none)
}

pub fn (list &PerformanceObserverEntryList) get_entries_by_type(kind string) []&PerformanceEntry {
	return filter_buffer_by_name_and_type(list.entry_list_, none, kind)
}

pub fn (list &PerformanceObserverEntryList) get_entries_by_name(name string, kind ?string) []&PerformanceEntry {
	return filter_buffer_by_name_and_type(list.entry_list_, name, kind)
}
