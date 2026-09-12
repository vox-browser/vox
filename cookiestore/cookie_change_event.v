// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of CookieStore/CookieChangeEvent.{h,cpp,idl}.
@[has_globals]
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
	live_    bool = true
}

pub fn CookieChangeEvent.create(event_name string, init CookieChangeEventInit) &CookieChangeEvent {
	return CookieChangeEvent.create_with_timestamp(event_name, init, dom.current_event_timestamp())
}

pub fn CookieChangeEvent.create_with_timestamp(event_name string, init CookieChangeEventInit, time_stamp f64) &CookieChangeEvent {
	return &CookieChangeEvent{
		Event: dom.Event{
			interface_: .cookie_change_event
			type_: event_name
			bubbles_: init.bubbles
			cancelable_: init.cancelable
			composed_: init.composed
			initialized_: true
			time_stamp_: time_stamp
		}
		changed_: (init.changed or { []CookieListItem{} }).clone()
		deleted_: (init.deleted or { []CookieListItem{} }).clone()
	}
}

pub fn CookieChangeEvent.construct_impl(event_name string, init CookieChangeEventInit) !&CookieChangeEvent {
	return CookieChangeEvent.create(event_name, init)
}

@[heap]
pub struct CookieListArray {
mut:
	items_ []CookieListItem
}

pub fn (array &CookieListArray) items() []CookieListItem {
	return array.items_.clone()
}

@[heap]
struct CookieChangeEventCacheEntry {
	event voidptr
mut:
	changed_arrays map[u64]&CookieListArray
	deleted_arrays map[u64]&CookieListArray
	live_          bool = true
}

__global cookie_change_event_cache_entries = []&CookieChangeEventCacheEntry{}

fn cookie_change_event_caches() []&CookieChangeEventCacheEntry {
	return cookie_change_event_cache_entries.clone()
}

fn prune_cookie_change_event_caches() {
	mut retained := []&CookieChangeEventCacheEntry{}
	for entry in cookie_change_event_cache_entries {
		if entry.live_ {
			retained << entry
		}
	}
	cookie_change_event_cache_entries = retained.clone()
}

fn cookie_change_event_cache_for(event &CookieChangeEvent) &CookieChangeEventCacheEntry {
	prune_cookie_change_event_caches()
	for entry in cookie_change_event_cache_entries {
		if entry.event == voidptr(event) {
			return entry
		}
	}
	entry := &CookieChangeEventCacheEntry{
		event: voidptr(event)
		changed_arrays: map[u64]&CookieListArray{}
		deleted_arrays: map[u64]&CookieListArray{}
	}
	cookie_change_event_cache_entries << entry
	return entry
}

pub fn cached_changed(event &CookieChangeEvent, wrapper_world u64) ?&CookieListArray {
	entry := cookie_change_event_cache_for(event)
	return entry.changed_arrays[wrapper_world] or { return none }
}

pub fn set_cached_changed(event &CookieChangeEvent, wrapper_world u64, array &CookieListArray) {
	mut entry := cookie_change_event_cache_for(event)
	entry.changed_arrays[wrapper_world] = array
}

pub fn cached_deleted(event &CookieChangeEvent, wrapper_world u64) ?&CookieListArray {
	entry := cookie_change_event_cache_for(event)
	return entry.deleted_arrays[wrapper_world] or { return none }
}

pub fn set_cached_deleted(event &CookieChangeEvent, wrapper_world u64, array &CookieListArray) {
	mut entry := cookie_change_event_cache_for(event)
	entry.deleted_arrays[wrapper_world] = array
}

fn (event &CookieChangeEvent) changed_array_for_world(wrapper_world u64) &CookieListArray {
	if array := cached_changed(event, wrapper_world) {
		return array
	}
	array := &CookieListArray{
		items_: event.changed_.clone()
	}
	set_cached_changed(event, wrapper_world, array)
	return array
}

fn (event &CookieChangeEvent) deleted_array_for_world(wrapper_world u64) &CookieListArray {
	if array := cached_deleted(event, wrapper_world) {
		return array
	}
	array := &CookieListArray{
		items_: event.deleted_.clone()
	}
	set_cached_deleted(event, wrapper_world, array)
	return array
}

// The JS binding exposes cached frozen arrays. Typed V callers receive a clone
// from the default wrapper world's cached array.
pub fn (event &CookieChangeEvent) changed() []CookieListItem {
	return event.changed_array_for_world(0).items()
}

pub fn (event &CookieChangeEvent) deleted() []CookieListItem {
	return event.deleted_array_for_world(0).items()
}

pub fn (mut event CookieChangeEvent) finalize() {
	event.live_ = false
	for cache_entry in cookie_change_event_cache_entries {
		if cache_entry.event == voidptr(&event) {
			mut mutable_entry := unsafe { &CookieChangeEventCacheEntry(cache_entry) }
			mutable_entry.live_ = false
		}
	}
	prune_cookie_change_event_caches()
}
