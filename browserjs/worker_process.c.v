// Copyright (c) 2026, Vox contributors
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import platform

#include "@DIR/worker_process.h"

fn C.vox_js_worker_spawn(&char) voidptr
fn C.vox_js_worker_begin_child() voidptr
fn C.vox_js_worker_queue(voidptr, u32, &u8, usize) int
fn C.vox_js_worker_flush(voidptr) int
fn C.vox_js_worker_receive(voidptr, &u32, &&u8, &usize) int
fn C.vox_js_worker_wait(voidptr, i32) int
fn C.vox_js_worker_destroy(voidptr)

// Transport only. A script Worker constructor must not be exposed until its
// agent installs a realm, script loader, event loop and structured-clone IPC.
@[heap]
pub struct WorkerProcess {
mut:
	channel voidptr
}

pub struct WorkerProcessFrame {
pub:
	kind  u32
	bytes []u8
}

pub struct WorkerProcessRead {
pub:
	frame ?WorkerProcessFrame
	ended bool
}

pub fn WorkerProcess.spawn(executable string) !&WorkerProcess {
	if executable.contains('\x00') { return error('Invalid script worker executable path') }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	channel := C.vox_js_worker_spawn(&char(executable.str))
	if channel == unsafe { nil } { return error('Cannot start script worker process') }
	return &WorkerProcess{ channel: channel }
}

// Call only after recognizing the private worker command-line role, before
// initializing the browser GUI or any script engine.
pub fn WorkerProcess.begin_child() !&WorkerProcess {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	channel := C.vox_js_worker_begin_child()
	if channel == unsafe { nil } { return error('Invalid script worker process descriptors') }
	return &WorkerProcess{ channel: channel }
}

pub fn (process &WorkerProcess) queue(kind u32, bytes []u8) ! {
	if process.channel == unsafe { nil } { return error('Script worker process is closed') }
	if C.vox_js_worker_queue(process.channel, kind, bytes.data, usize(bytes.len)) != 0 {
		return error('Cannot queue script worker frame')
	}
}

pub fn (process &WorkerProcess) flush() !bool {
	if process.channel == unsafe { nil } { return error('Script worker process is closed') }
	status := C.vox_js_worker_flush(process.channel)
	if status < 0 { return error('Cannot flush script worker frames') }
	return status == 1
}

pub fn (process &WorkerProcess) receive() !WorkerProcessRead {
	if process.channel == unsafe { nil } { return error('Script worker process is closed') }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut kind := u32(0)
	mut bytes := unsafe { &u8(nil) }
	mut length := usize(0)
	status := C.vox_js_worker_receive(process.channel, &kind, &bytes, &length)
	if status < 0 { return error('Invalid or interrupted script worker frame') }
	if status == 2 { return WorkerProcessRead{ ended: true } }
	if status == 0 { return WorkerProcessRead{} }
	defer { unsafe { C.free(bytes) } }
	return WorkerProcessRead{
		frame: WorkerProcessFrame{
			kind:  kind
			bytes: if length == 0 { []u8{} } else { unsafe { bytes.vbytes(int(length)).clone() } }
		}
	}
}

// A helper can wait between event-loop turns. Browser callers use zero so
// script agents can never block document rendering while awaiting messages.
pub fn (process &WorkerProcess) wait(timeout_ms int) !bool {
	if process.channel == unsafe { nil } { return error('Script worker process is closed') }
	if timeout_ms < 0 || timeout_ms > 2147483647 {
		return error('Invalid script worker poll timeout')
	}
	status := C.vox_js_worker_wait(process.channel, i32(timeout_ms))
	if status < 0 {
		return error('Cannot poll script worker process')
	}
	return status > 0
}

pub fn (mut process WorkerProcess) close() {
	if process.channel == unsafe { nil } { return }
	C.vox_js_worker_destroy(process.channel)
	process.channel = unsafe { nil }
}
