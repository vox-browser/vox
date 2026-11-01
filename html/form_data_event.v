// Copyright (c) 2023, Kenneth Myhra <kennethmyhra@serenityos.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of FormDataEvent.{h,cpp}. XHR::FormData's observable entry list
// is represented directly by the already translated FormDataEntry type.
module html

import dom

// HTML's entry-list construction and XHR's FormData binding share one mutable
// owner without introducing an HTML -> XHR module dependency.
pub interface FormDataEntryList {
	form_data_entries() []FormDataEntry
mut:
	replace_form_data_entries(entries []FormDataEntry)
}

@[heap]
pub struct FormData {
mut:
	entries_ []FormDataEntry
	entry_list_ ?FormDataEntryList
}

pub fn FormData.create(entries []FormDataEntry) &FormData {
	return &FormData{
		entries_: entries.clone()
	}
}

pub fn (data &FormData) entries() []FormDataEntry {
	if owner := data.entry_list_ { return owner.form_data_entries() }
	return data.entries_.clone()
}

pub fn (data &FormData) entry_list() ?FormDataEntryList {
	return data.entry_list_
}

pub fn (mut data FormData) bind_entry_list(owner FormDataEntryList) {
	data.entry_list_ = owner
	data.entries_ = []FormDataEntry{}
}

fn (mut data FormData) replace_entries(entries []FormDataEntry) {
	if mut owner := data.entry_list_ {
		owner.replace_form_data_entries(entries)
	} else {
		data.entries_ = entries
	}
}

pub fn (mut data FormData) append(entry FormDataEntry) {
	mut entries := data.entries()
	entries << entry
	data.replace_entries(entries)
}

pub fn (mut data FormData) delete(name string) {
	data.replace_entries(data.entries().filter(it.name != name))
}

// XHR::FormData::set(): replace the first matching entry and remove later
// matches, or append when the name is absent.
pub fn (mut data FormData) set(entry FormDataEntry) {
	mut found := false
	mut entries := []FormDataEntry{}
	for old in data.entries() {
		if old.name == entry.name {
			if !found {
				entries << entry
				found = true
			}
		} else {
			entries << old
		}
	}
	if !found {
		entries << entry
	}
	data.replace_entries(entries)
}

pub struct FormDataEventInit {
	dom.EventInit
pub:
	form_data ?&FormData
}

@[heap]
pub struct FormDataEvent {
	dom.Event
mut:
	form_data_ ?&FormData
}

pub fn FormDataEvent.construct_impl(event_name string, event_init FormDataEventInit) !&FormDataEvent {
	return &FormDataEvent{
		Event:      dom.Event{
			interface_:   .form_data_event
			type_:        event_name
			bubbles_:     event_init.bubbles
			cancelable_:  event_init.cancelable
			composed_:    event_init.composed
			initialized_: true
			time_stamp_:  dom.current_event_timestamp()
		}
		form_data_: event_init.form_data
	}
}

pub fn (event &FormDataEvent) form_data() ?&FormData {
	return event.form_data_
}
