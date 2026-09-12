// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Fetch/Headers.cpp and HeadersIterator.cpp.
module fetch

import http

pub enum HeadersGuard {
	immutable
	request
	request_no_cors
	response
	none
}

pub struct HeaderPair {
pub:
	name  string
	value string
}

@[heap]
pub struct Headers {
mut:
	header_list_ &http.HeaderList = http.HeaderList.create()
	guard_       HeadersGuard     = .none
}

pub fn Headers.create(header_list &http.HeaderList) &Headers {
	return &Headers{
		header_list_: header_list
	}
}

pub fn Headers.create_from_init(init ?[]HeaderPair) !&Headers {
	mut headers := Headers.create(http.HeaderList.create())
	if pairs := init {
		headers.fill(pairs)!
	}
	return headers
}

pub fn Headers.construct(init []HeaderPair) !&Headers {
	return Headers.create_from_init(init)
}

pub fn Headers.construct_impl(init []HeaderPair) !&Headers {
	return Headers.construct(init)
}

pub fn Headers.from_header_list(list &http.HeaderList, guard HeadersGuard) &Headers {
	mut headers := Headers.create(list)
	headers.guard_ = guard
	return headers
}

pub fn (headers &Headers) header_list() &http.HeaderList {
	return headers.header_list_
}

pub fn (headers &Headers) guard() HeadersGuard {
	return headers.guard_
}

pub fn (mut headers Headers) set_guard(guard HeadersGuard) {
	headers.guard_ = guard
}

fn (headers &Headers) validate(header http.Header) !bool {
	if !http.is_header_name(header.name) {
		return error('TypeError: Invalid header name')
	}
	if !http.is_header_value(header.value) {
		return error('TypeError: Invalid header value')
	}
	if headers.guard_ == .immutable {
		return error('TypeError: Headers object is immutable')
	}
	if headers.guard_ == .request && http.is_forbidden_request_header(header) {
		return false
	}
	if headers.guard_ == .response && is_forbidden_response_header_name(header.name) {
		return false
	}
	return true
}

pub fn (mut headers Headers) append(name string, value string) ! {
	normalized := http.normalize_header_value(value)
	header := http.Header{
		name:  name
		value: normalized
	}
	if !headers.validate(header)! {
		return
	}
	if headers.guard_ == .request_no_cors {
		current := headers.header_list_.get(name)
		temporary := if existing := current { '${existing}, ${normalized}' } else { normalized }
		if !is_no_cors_safelisted_request_header(http.Header{ name: name, value: temporary }) {
			return
		}
	}
	headers.header_list_.append(header)
	if headers.guard_ == .request_no_cors {
		headers.remove_privileged_no_cors_request_headers()
	}
}

pub fn (mut headers Headers) delete(name string) ! {
	if !headers.validate(http.Header{ name: name })! {
		return
	}
	if headers.guard_ == .request_no_cors && !is_no_cors_safelisted_request_header_name(name)
		&& !is_privileged_no_cors_request_header_name(name) {
		return
	}
	headers.replace_without(name, none)
	if headers.guard_ == .request_no_cors {
		headers.remove_privileged_no_cors_request_headers()
	}
}

pub fn (mut headers Headers) delete_(name string) ! {
	headers.delete(name)!
}

pub fn (mut headers Headers) fill(init []HeaderPair) ! {
	for pair in init {
		headers.append(pair.name, pair.value)!
	}
}

pub fn (mut headers Headers) set_header_list(header_list &http.HeaderList) {
	headers.header_list_ = header_list
}

pub fn (headers &Headers) get(name string) ?string {
	if !http.is_header_name(name) { return none }
	return headers.header_list_.get(name)
}

pub fn (headers &Headers) get_set_cookie() []string {
	mut values := []string{}
	for header in headers.header_list_.headers() {
		if equals_ignoring_ascii_case(header.name, 'set-cookie') {
			values << header.value
		}
	}
	return values
}

pub fn (headers &Headers) has(name string) !bool {
	if !http.is_header_name(name) {
		return error('TypeError: Invalid header name')
	}
	return headers.header_list_.contains(name)
}

pub fn (mut headers Headers) set(name string, value string) ! {
	normalized := http.normalize_header_value(value)
	header := http.Header{
		name:  name
		value: normalized
	}
	if !headers.validate(header)! {
		return
	}
	if headers.guard_ == .request_no_cors && !is_no_cors_safelisted_request_header(header) {
		return
	}
	headers.replace_without(name, header)
	if headers.guard_ == .request_no_cors {
		headers.remove_privileged_no_cors_request_headers()
	}
}

fn (mut headers Headers) replace_without(name string, replacement ?http.Header) {
	mut list := http.HeaderList.create()
	mut inserted := false
	for existing in headers.header_list_.headers() {
		if equals_ignoring_ascii_case(existing.name, name) {
			if !inserted {
				if header := replacement {
					list.append(header)
				}
				inserted = true
			}
			continue
		}
		list.append(existing)
	}
	if !inserted {
		if header := replacement {
			list.append(header)
		}
	}
	headers.header_list_ = list
}

fn (mut headers Headers) remove_privileged_no_cors_request_headers() {
	headers.replace_without('range', none)
}

pub fn (headers &Headers) sorted_and_combined() []HeaderPair {
	mut names := []string{}
	for header in headers.header_list_.headers() {
		name := ascii_lowercase(header.name)
		if name !in names {
			names << name
		}
	}
	names.sort()
	mut pairs := []HeaderPair{cap: names.len}
	for name in names {
		pairs << HeaderPair{
			name:  name
			value: headers.header_list_.get(name) or { '' }
		}
	}
	return pairs
}

pub enum IterationDecision {
	continue_
	break_
}

pub fn (headers &Headers) for_each(callback fn (string, string) IterationDecision) {
	mut index := 0
	for {
		pairs := headers.sorted_and_combined()
		if index >= pairs.len {
			break
		}
		pair := pairs[index]
		if callback(pair.name, pair.value) == .break_ {
			break
		}
		index++
	}
}

pub enum HeadersIterationKind {
	key
	value
	key_and_value
}

pub struct HeadersIteratorResult {
pub:
	done  bool
	name  string
	value string
}

pub struct HeadersIterator {
	headers &Headers
	kind    HeadersIterationKind
mut:
	index           int
	prototype_name_ string
}

fn set_headers_iterator_prototype(mut iterator HeadersIterator) {
	iterator.prototype_name_ = 'HeadersIterator'
}

pub fn HeadersIterator.create(headers &Headers, kind HeadersIterationKind) &HeadersIterator {
	mut iterator := &HeadersIterator{
		headers: headers
		kind: kind
	}
	set_headers_iterator_prototype(mut iterator)
	return iterator
}

pub fn (iterator &HeadersIterator) prototype_name() string {
	return iterator.prototype_name_
}

pub fn (mut iterator HeadersIterator) next() HeadersIteratorResult {
	pairs := iterator.headers.sorted_and_combined()
	if iterator.index >= pairs.len {
		return HeadersIteratorResult{
			done: true
		}
	}
	pair := pairs[iterator.index]
	iterator.index++
	return match iterator.kind {
		.key {
			HeadersIteratorResult{
				name: pair.name
			}
		}
		.value {
			HeadersIteratorResult{
				value: pair.value
			}
		}
		.key_and_value {
			HeadersIteratorResult{
				name:  pair.name
				value: pair.value
			}
		}
	}
}
