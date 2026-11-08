// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of IndexedDB/Internal/RequestList.{h,cpp}. Database tasks are
// invoked synchronously at the standalone event-loop boundary, while the same
// one-at-a-time dispatch, blocking and completion-callback rules are retained.
module indexeddb

pub type RequestSteps = fn (mut IDBRequest)

struct RequestListEntry {
	request &IDBRequest
mut:
	steps      ?RequestSteps
	dispatched bool
}

@[heap]
pub struct RequestList {
mut:
	entries          []RequestListEntry
	blocked          bool
	on_all_processed ?fn ()
pub mut:
	all_processed_notifications int
}

pub fn (list &RequestList) is_empty() bool {
	return list.entries.len == 0
}

pub fn (list &RequestList) length() int {
	return list.entries.len
}

// Compatibility helper for callers which only need request ownership. Such an
// entry is considered already executing until the request is marked processed.
pub fn (mut list RequestList) append(request &IDBRequest) {
	if list.contains(request) {
		return
	}
	list.entries << RequestListEntry{
		request:    request
		dispatched: true
	}
}

pub fn (mut list RequestList) enqueue(request &IDBRequest, steps RequestSteps) {
	list.entries << RequestListEntry{
		request: request
		steps:   steps
	}
	list.maybe_process_next_request()
}

fn (mut list RequestList) reuse(request &IDBRequest, steps RequestSteps) {
	// Finish the old iteration without firing all-processed notifications in
	// between. A cursor continuation joins the tail behind earlier requests.
	for index, entry in list.entries {
		if voidptr(entry.request) == voidptr(request) {
			list.entries.delete(index)
			break
		}
	}
	list.enqueue(request, steps)
}

pub fn (mut list RequestList) maybe_process_next_request() {
	if list.blocked {
		return
	}
	for mut entry in list.entries {
		if entry.request.processed || entry.request.aborted {
			continue
		}
		if entry.dispatched {
			return
		}
		steps := entry.steps or { return }
		entry.steps = none
		entry.dispatched = true
		mut request := unsafe { &IDBRequest(entry.request) }
		queue_a_database_task_for_global_scope(request.global_scope, fn [steps, request] () {
			mut queued_request := unsafe { &IDBRequest(request) }
			steps(mut queued_request)
		})
		return
	}
}

pub fn (mut list RequestList) on_request_processed() {
	list.maybe_process_next_request()
	list.check_all_processed()
}

pub fn (mut list RequestList) remove(request &IDBRequest) bool {
	for index, entry in list.entries {
		if voidptr(entry.request) == voidptr(request) {
			list.entries.delete(index)
			list.check_all_processed()
			return true
		}
	}
	return false
}

pub fn (list &RequestList) contains(request &IDBRequest) bool {
	return list.entries.any(voidptr(it.request) == voidptr(request))
}

pub fn (list &RequestList) all_processed() bool {
	return list.entries.all(it.request.processed)
}

pub fn (mut list RequestList) block_execution() {
	list.blocked = true
}

pub fn (list &RequestList) execution_is_blocked() bool {
	return list.blocked
}

pub fn (mut list RequestList) unblock_execution() {
	list.blocked = false
	list.maybe_process_next_request()
}

pub fn (mut list RequestList) set_on_all_processed(callback fn ()) {
	list.on_all_processed = callback
	list.check_all_processed()
}

pub fn (mut list RequestList) clear_on_all_processed() {
	list.on_all_processed = none
}

pub fn (mut list RequestList) check_all_processed() {
	if !list.all_processed() {
		return
	}
	callback := list.on_all_processed or { return }
	list.on_all_processed = none
	list.all_processed_notifications++
	callback()
}

pub fn (list &RequestList) requests() []&IDBRequest {
	return list.entries.map(it.request)
}
