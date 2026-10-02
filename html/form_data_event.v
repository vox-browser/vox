// Copyright (c) 2023, Kenneth Myhra <kennethmyhra@serenityos.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of FormDataEvent.{h,cpp}. XHR::FormData's observable entry list
// is represented directly by the already translated FormDataEntry type.
module html

import dom

@[heap]
pub struct FormData {
mut:
	entries_ []FormDataEntry
}

pub fn FormData.create(entries []FormDataEntry) &FormData {
	return &FormData{
		entries_: entries.clone()
	}
}

pub fn (data &FormData) entries() []FormDataEntry {
	return data.entries_.clone()
}

pub fn (mut data FormData) append(entry FormDataEntry) {
	data.entries_ << entry
}

pub fn (mut data FormData) delete(name string) {
	data.entries_ = data.entries_.filter(it.name != name)
}

// XHR::FormData::set(): replace the first matching entry and remove later
// matches, or append when the name is absent.
pub fn (mut data FormData) set(entry FormDataEntry) {
	mut found := false
	mut entries := []FormDataEntry{}
	for old in data.entries_ {
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
	data.entries_ = entries
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
