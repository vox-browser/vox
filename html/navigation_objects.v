// Copyright (c) 2023, Andrew Kaster <akaster@serenityos.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of NavigationDestination, NavigationHistoryEntry,
// NavigationTransition, and NavigationCurrentEntryChangeEvent.
module html

import dom

fn navigation_deserialize(record SerializationRecord) !dom.JSValue {
	return structured_deserialize(record)
}

@[heap]
pub struct NavigationHistoryEntry {
	dom.EventTarget
mut:
	session_history_entry_ &SessionHistoryEntry
	associated_document_   ?&dom.Document
	navigation_entries_    []&SessionHistoryEntry
	fully_active_override_ ?bool
}

pub fn NavigationHistoryEntry.create(session_history_entry &SessionHistoryEntry, associated_document ?&dom.Document) &NavigationHistoryEntry {
	return &NavigationHistoryEntry{
		session_history_entry_: session_history_entry
		associated_document_:   associated_document
	}
}

// The embedding supplies the Navigation API entry list because Window and
// Navigation are not owned by the html module in this port.
pub fn (mut entry NavigationHistoryEntry) set_navigation_entries(entries []&SessionHistoryEntry) {
	entry.navigation_entries_ = entries.clone()
}

// Useful to embeddings which know the Window state without constructing a full
// Navigable graph. With none, Document.is_fully_active() remains authoritative.
pub fn (mut entry NavigationHistoryEntry) set_fully_active_override(value ?bool) {
	entry.fully_active_override_ = value
}

fn (entry &NavigationHistoryEntry) associated_document_is_fully_active() bool {
	if value := entry.fully_active_override_ {
		return value
	}
	document := entry.associated_document_ or { return false }
	return document.is_fully_active()
}

pub fn (entry &NavigationHistoryEntry) url() ?string {
	if !entry.associated_document_is_fully_active() {
		return ''
	}
	associated_document := entry.associated_document_ or { return '' }
	if state := entry.session_history_entry_.document_state {
		is_associated_document := if document_id := state.document_id() {
			document_id == associated_document.unique_id()
		} else {
			false
		}
		if !is_associated_document {
			if state.request_referrer_policy in [.no_referrer, .origin] {
				return none
			}
		}
	}
	return entry.session_history_entry_.url.serialize()
}

pub fn (entry &NavigationHistoryEntry) key() string {
	if !entry.associated_document_is_fully_active() {
		return ''
	}
	return entry.session_history_entry_.navigation_api_key
}

pub fn (entry &NavigationHistoryEntry) id() string {
	if !entry.associated_document_is_fully_active() {
		return ''
	}
	return entry.session_history_entry_.navigation_api_id
}

pub fn (entry &NavigationHistoryEntry) index() i64 {
	if !entry.associated_document_is_fully_active() {
		return -1
	}
	for index, candidate in entry.navigation_entries_ {
		if voidptr(candidate) == voidptr(entry.session_history_entry_) {
			return i64(index)
		}
	}
	return -1
}

pub fn (entry &NavigationHistoryEntry) same_document() bool {
	if !entry.associated_document_is_fully_active() {
		return false
	}
	associated_document := entry.associated_document_ or { return false }
	state := entry.session_history_entry_.document_state or { return false }
	document_id := state.document_id() or { return false }
	return document_id == associated_document.unique_id()
}

pub fn (entry &NavigationHistoryEntry) get_state() !dom.JSValue {
	if !entry.associated_document_is_fully_active() {
		return dom.js_undefined()
	}
	return navigation_deserialize(entry.session_history_entry_.navigation_api_state)
}

pub fn (entry &NavigationHistoryEntry) session_history_entry() &SessionHistoryEntry {
	return entry.session_history_entry_
}

pub fn (entry &NavigationHistoryEntry) set_ondispose(handler ?&dom.CallbackType) {
	unsafe { &dom.EventTarget(entry) }.set_event_handler_attribute('dispose', handler)
}

pub fn (entry &NavigationHistoryEntry) ondispose() ?&dom.CallbackType {
	return unsafe { &dom.EventTarget(entry) }.event_handler_attribute('dispose')
}

@[heap]
pub struct NavigationDestination {
mut:
	url_              dom.URL
	entry_            ?&NavigationHistoryEntry
	state_            SerializationRecord
	is_same_document_ bool
}

pub fn NavigationDestination.create() &NavigationDestination {
	return &NavigationDestination{}
}

pub fn (destination &NavigationDestination) url() string {
	return destination.url_.serialize()
}

pub fn (destination &NavigationDestination) key() string {
	entry := destination.entry_ or { return '' }
	return entry.key()
}

pub fn (destination &NavigationDestination) id() string {
	entry := destination.entry_ or { return '' }
	return entry.id()
}

pub fn (destination &NavigationDestination) index() i64 {
	entry := destination.entry_ or { return -1 }
	return entry.index()
}

pub fn (destination &NavigationDestination) same_document() bool {
	return destination.is_same_document_
}

pub fn (destination &NavigationDestination) get_state() !dom.JSValue {
	return navigation_deserialize(destination.state_)
}

pub fn (destination &NavigationDestination) navigation_history_entry() ?&NavigationHistoryEntry {
	return destination.entry_
}

pub fn (mut destination NavigationDestination) set_url(url dom.URL) {
	destination.url_ = url
}

pub fn (mut destination NavigationDestination) set_entry(entry ?&NavigationHistoryEntry) {
	destination.entry_ = entry
}

pub fn (mut destination NavigationDestination) set_state(state SerializationRecord) {
	destination.state_ = SerializationRecord{
		type_:                state.type_
		data:                 state.data.clone()
		shared_array_buffers: state.shared_array_buffers.clone()
	}
}

pub fn (mut destination NavigationDestination) set_is_same_document(value bool) {
	destination.is_same_document_ = value
}

pub fn (destination &NavigationDestination) raw_url() dom.URL {
	return destination.url_
}

@[heap]
pub struct NavigationTransition {
	navigation_type_   dom.NavigationType
	from_entry_        &NavigationHistoryEntry
	destination_       &NavigationDestination
	committed_promise_ &dom.Promise
	finished_promise_  &dom.Promise
}

pub fn NavigationTransition.create(navigation_type dom.NavigationType, from_entry &NavigationHistoryEntry, destination &NavigationDestination, committed_promise &dom.Promise, finished_promise &dom.Promise) &NavigationTransition {
	return &NavigationTransition{
		navigation_type_:   navigation_type
		from_entry_:        from_entry
		destination_:       destination
		committed_promise_: committed_promise
		finished_promise_:  finished_promise
	}
}

pub fn (transition &NavigationTransition) navigation_type() dom.NavigationType {
	return transition.navigation_type_
}

pub fn (transition &NavigationTransition) from() &NavigationHistoryEntry {
	return transition.from_entry_
}

pub fn (transition &NavigationTransition) to() &NavigationDestination {
	return transition.destination_
}

pub fn (transition &NavigationTransition) committed() &dom.Promise {
	return transition.committed_promise_
}

pub fn (transition &NavigationTransition) finished() &dom.Promise {
	return transition.finished_promise_
}

pub struct NavigationCurrentEntryChangeEventInit {
	dom.EventInit
pub:
	navigation_type ?dom.NavigationType
	from            &NavigationHistoryEntry = unsafe { nil }
}

@[heap]
pub struct NavigationCurrentEntryChangeEvent {
	dom.Event
mut:
	navigation_type_ ?dom.NavigationType
	from_            &NavigationHistoryEntry
}

pub fn NavigationCurrentEntryChangeEvent.construct_impl(event_name string, event_init NavigationCurrentEntryChangeEventInit) !&NavigationCurrentEntryChangeEvent {
	if event_init.from == unsafe { nil } {
		return error('NavigationCurrentEntryChangeEventInit.from is required')
	}
	return &NavigationCurrentEntryChangeEvent{
		Event:            dom.Event{
			interface_:   .navigation_current_entry_change_event
			type_:        event_name
			bubbles_:     event_init.bubbles
			cancelable_:  event_init.cancelable
			composed_:    event_init.composed
			initialized_: true
			time_stamp_:  dom.current_event_timestamp()
		}
		navigation_type_: event_init.navigation_type
		from_:            event_init.from
	}
}

pub fn (event &NavigationCurrentEntryChangeEvent) navigation_type() ?dom.NavigationType {
	return event.navigation_type_
}

pub fn (event &NavigationCurrentEntryChangeEvent) from() &NavigationHistoryEntry {
	return event.from_
}
