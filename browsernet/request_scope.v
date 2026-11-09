module browsernet

import time

// The supported Windows toolchain provides winpthreads (docs/WINDOWS.md).
#flag windows -lpthread
#include "request_scope.h"

fn C.vox_resource_scope_create() voidptr
fn C.vox_resource_scope_retain(scope voidptr)
fn C.vox_resource_scope_release(scope voidptr) bool
fn C.vox_resource_scope_cancel(scope voidptr)
fn C.vox_resource_scope_cancelled(scope voidptr) bool
fn C.vox_resource_scope_begin_publication(scope voidptr) bool
fn C.vox_resource_scope_end_publication(scope voidptr)
fn C.vox_resource_scope_wait(scope voidptr, nanoseconds i64) bool
fn C.vox_resource_scope_acquire_slot(scope voidptr, limit u32) bool
fn C.vox_resource_release_slot()

pub const max_concurrent_requests = 16
const request_cancelled_code = 1499

// One document/navigation owns the initial reference. Workers retain their
// own references before spawning and release them after transport cleanup.
// Native allocation keeps the handle independent of a retired document arena.
@[heap]
pub struct RequestScope {
	native voidptr
}

pub fn new_request_scope() &RequestScope {
	scope := unsafe { &RequestScope(C.malloc(sizeof(RequestScope))) }
	if scope == unsafe { nil } { panic('Resource request scope allocation failed') }
	unsafe { *scope = RequestScope{ native: C.vox_resource_scope_create() } }
	return scope
}

pub fn (scope &RequestScope) retain() {
	C.vox_resource_scope_retain(scope.native)
}

pub fn (scope &RequestScope) release() {
	if C.vox_resource_scope_release(scope.native) { unsafe { C.free(scope) } }
}

pub fn (scope &RequestScope) cancel() {
	C.vox_resource_scope_cancel(scope.native)
}

pub fn (scope &RequestScope) is_cancelled() bool {
	return C.vox_resource_scope_cancelled(scope.native)
}

pub fn (scope &RequestScope) check() ! {
	if scope.is_cancelled() {
		return error_with_code('Resource request cancelled', request_cancelled_code)
	}
}

// Cancellation and publication share one gate. Hold it only for a cache
// commit or a nonblocking result send, never while waiting on the network.
pub fn (scope &RequestScope) begin_publication() ! {
	if !C.vox_resource_scope_begin_publication(scope.native) {
		return error_with_code('Resource request cancelled', request_cancelled_code)
	}
}

pub fn (scope &RequestScope) end_publication() {
	C.vox_resource_scope_end_publication(scope.native)
}

pub fn (scope &RequestScope) wait_for_cancellation(timeout time.Duration) bool {
	return C.vox_resource_scope_wait(scope.native, i64(timeout))
}

// The service budget spans overlapping batches. Cancelled waiters wake
// immediately; active requests return their permit only after transport exit.
fn (scope &RequestScope) acquire_request_slot() ! {
	if !C.vox_resource_scope_acquire_slot(scope.native, u32(max_concurrent_requests)) {
		return error_with_code('Resource request cancelled', request_cancelled_code)
	}
	scope.check() or {
		release_request_slot()
		return err
	}
}

fn release_request_slot() {
	C.vox_resource_release_slot()
}

// Channels normally fit a batch, but a retired or slower consumer may leave
// one full. Cancellation must still retire the producer. Only the nonblocking
// send holds the publication gate, so cancel can wake the waiter immediately.
pub fn publish_result[T](result T, results chan T, scope &RequestScope) bool {
	for {
		scope.begin_publication() or { return false }
		mut sent := false
		select {
			results <- result {
				sent = true
			}
			else {
			}
		}
		scope.end_publication()
		if sent { return true }
		if scope.wait_for_cancellation(5 * time.millisecond) { return false }
	}
	return false
}
