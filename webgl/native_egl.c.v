// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module webgl

#pkgconfig egl glesv2
#flag darwin -Wl,-rpath,/opt/homebrew/lib
#include "@DIR/native_egl.h"

fn C.vox_egl_create(int) voidptr
fn C.vox_egl_make_current(voidptr) int
fn C.vox_egl_destroy(voidptr)
fn C.vox_gl_fence_sync(u32, u32) voidptr
fn C.vox_gl_client_wait_sync(voidptr, u32, u64) u32
fn C.vox_gl_wait_sync(voidptr, u32, u64)
fn C.vox_gl_delete_sync(voidptr)
fn C.vox_gl_get_sync_parameter(voidptr, u32) int
fn C.vox_gl_get_error() u32

fn (mut context OpenGLContext) collect_native_error() {
	error_value := GLenum(C.vox_gl_get_error())
	if error_value != no_error { context.set_pending_local_error(error_value) }
}

fn (mut context OpenGLContext) native_fence_sync(condition GLenum, flags GLenum) voidptr {
	context.make_current()
	if !context.current_ { return unsafe { nil } }
	handle := C.vox_gl_fence_sync(condition, flags)
	context.collect_native_error()
	return handle
}

fn (mut context OpenGLContext) native_client_wait_sync(handle voidptr, flags GLenum, timeout u64) GLenum {
	context.make_current()
	if !context.current_ { return wait_failed }
	result := GLenum(C.vox_gl_client_wait_sync(handle, flags, timeout))
	context.collect_native_error()
	return result
}

fn (mut context OpenGLContext) native_wait_sync(handle voidptr, flags GLenum, timeout u64) {
	context.make_current()
	if !context.current_ { return }
	C.vox_gl_wait_sync(handle, flags, timeout)
	context.collect_native_error()
}

fn (mut context OpenGLContext) native_delete_sync(handle voidptr) {
	context.make_current()
	if !context.current_ { return }
	C.vox_gl_delete_sync(handle)
	context.collect_native_error()
}

fn (mut context OpenGLContext) native_sync_parameter(handle voidptr, pname GLenum) int {
	context.make_current()
	if !context.current_ { return 0 }
	result := C.vox_gl_get_sync_parameter(handle, pname)
	context.collect_native_error()
	return result
}
