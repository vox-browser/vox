// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Fetch/Infrastructure/PreflightCache.{h,cpp}.
@[has_globals]
module fetch

import dom
import time

pub const preflight_cache_max_age_limit = 7200 * time.second

@[heap]
struct Entry {
mut:
	stored_at              i64
	key                    NetworkPartitionKey
	byte_serialized_origin []u8
	url                    dom.URL
	max_age                time.Duration
	credentials            bool
	method                 ?string
	header_name            ?string
}

fn (entry &Entry) has_expired() bool {
	return time.sys_mono_now() - entry.stored_at >= i64(entry.max_age)
}

fn (mut entry Entry) update_max_age(max_age time.Duration) {
	entry.max_age = max_age
	entry.stored_at = time.sys_mono_now()
}

@[heap]
pub struct PreflightCache {
mut:
	entries []Entry
}

__global cors_preflight_cache_ = &PreflightCache{}

pub fn PreflightCache.the() &PreflightCache {
	return cors_preflight_cache_
}

fn (mut cache PreflightCache) create_a_new_cache_entry(request &Request, max_age time.Duration, method ?string, header_name ?string) {
	if max_age <= 0 {
		return
	}
	key := determine_the_http_cache_partition(request) or { return }
	cache.entries << Entry{
		stored_at: time.sys_mono_now()
		key: key
		byte_serialized_origin: request.byte_serialize_origin()
		url: request.current_url()
		max_age: max_age
		credentials: request.credentials_mode == .include
		method: method
		header_name: header_name
	}
}

pub fn (mut cache PreflightCache) is_a_method_cache_entry_match(request &Request, method string) bool {
	cache.evict_expired_entries()
	return cache.method_cache_entry_match(request, method) != none
}

fn (mut cache PreflightCache) method_cache_entry_match(request &Request, method string) ?&Entry {
	for mut entry in cache.entries {
		cached_method := entry.method or { continue }
		// Like a live preflight, '*' covers other methods only without credentials.
		wildcard_matches := request.credentials_mode != .include && cached_method == '*'
		if !equals_ignoring_ascii_case(cached_method, method) && !wildcard_matches {
			continue
		}
		if PreflightCache.is_cache_entry_match(entry, request) {
			return entry
		}
	}
	return none
}

pub fn (mut cache PreflightCache) cache_method(request &Request, method string, max_age time.Duration) {
	cache.evict_expired_entries()
	if mut entry := cache.method_cache_entry_match(request, method) {
		entry.update_max_age(max_age)
		return
	}
	cache.create_a_new_cache_entry(request, max_age, method, none)
}

pub fn (mut cache PreflightCache) is_a_header_name_cache_entry_match(request &Request, header_name string) bool {
	cache.evict_expired_entries()
	return cache.header_name_cache_entry_match(request, header_name) != none
}

fn (mut cache PreflightCache) header_name_cache_entry_match(request &Request, header_name string) ?&Entry {
	for mut entry in cache.entries {
		cached_header_name := entry.header_name or { continue }
		wildcard_matches := request.credentials_mode != .include && cached_header_name == '*'
			&& !is_cors_non_wildcard_request_header_name(header_name)
		if !wildcard_matches && !equals_ignoring_ascii_case(cached_header_name, header_name) {
			continue
		}
		if PreflightCache.is_cache_entry_match(entry, request) {
			return entry
		}
	}
	return none
}

pub fn (mut cache PreflightCache) cache_header_name(request &Request, header_name string, max_age time.Duration) {
	cache.evict_expired_entries()
	if mut entry := cache.header_name_cache_entry_match(request, header_name) {
		entry.update_max_age(max_age)
		return
	}
	cache.create_a_new_cache_entry(request, max_age, none, header_name)
}

pub fn PreflightCache.is_cache_entry_match(entry &Entry, request &Request) bool {
	if entry.has_expired() {
		return false
	}
	key := determine_the_http_cache_partition(request) or { return false }
	if entry.key != key {
		return false
	}
	if entry.byte_serialized_origin != request.byte_serialize_origin() {
		return false
	}
	if entry.url != request.current_url() {
		return false
	}
	return entry.credentials || request.credentials_mode != .include
}

pub fn (mut cache PreflightCache) evict_expired_entries() {
	mut active := []Entry{cap: cache.entries.len}
	for entry in cache.entries {
		if !entry.has_expired() {
			active << entry
		}
	}
	cache.entries = active.clone()
}

pub fn (mut cache PreflightCache) clear_cache_entries(request &Request) {
	request_key := determine_the_http_cache_partition(request)
	mut retained := []Entry{cap: cache.entries.len}
	for entry in cache.entries {
		if entry.has_expired() {
			continue
		}
		key_matches := if key := request_key { entry.key == key } else { false }
		if key_matches && entry.byte_serialized_origin == request.byte_serialize_origin()
			&& entry.url == request.current_url() {
			continue
		}
		retained << entry
	}
	cache.entries = retained.clone()
}
