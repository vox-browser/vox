// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of CookieStore/CookieChangeEvent.{h,cpp,idl}.
module cookiestore

import dom

pub struct CookieChangeEventInit {
	dom.EventInit
pub mut:
	changed ?[]CookieListItem
	deleted ?[]CookieListItem
}

@[heap]
pub struct CookieChangeEvent {
	dom.Event
mut:
	changed_ []CookieListItem
	deleted_ []CookieListItem
}

pub fn CookieChangeEvent.create(event_name string, init CookieChangeEventInit) &CookieChangeEvent {
	return &CookieChangeEvent{
		Event:    dom.Event{
			interface_:   .cookie_change_event
			type_:        event_name
			bubbles_:     init.bubbles
			cancelable_:  init.cancelable
			composed_:    init.composed
			initialized_: true
			time_stamp_:  dom.current_event_timestamp()
		}
		changed_: (init.changed or { []CookieListItem{} }).clone()
		deleted_: (init.deleted or { []CookieListItem{} }).clone()
	}
}

pub fn CookieChangeEvent.construct_impl(event_name string, init CookieChangeEventInit) !&CookieChangeEvent {
	return CookieChangeEvent.create(event_name, init)
}

// The JS binding exposes cached frozen arrays. Typed V callers receive a
// clone, which provides the same immutability guarantee.
pub fn (event &CookieChangeEvent) changed() []CookieListItem {
	return event.changed_.clone()
}

pub fn (event &CookieChangeEvent) deleted() []CookieListItem {
	return event.deleted_.clone()
}
