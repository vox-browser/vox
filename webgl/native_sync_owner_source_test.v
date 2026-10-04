// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn C.glIsSync(voidptr) u8

fn sync_source_owner() {
	mut selected := [0, 0, 0, 0]!
	C.vox_gl_int_parameter(viewport, &selected[0])
	assert selected == [1, 2, 3, 4]!
}

fn test_source_sync_operations_select_owner_before_returns_and_preserve_deleted_pointer() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut other := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	context.viewport(1, 2, 3, 4)
	other.viewport(9, 10, 11, 12)
	mut owned := context.fence_sync(sync_gpu_commands_complete, 0) or { panic('owned fence') }
	mut foreign := other.fence_sync(sync_gpu_commands_complete, 0) or { panic('foreign fence') }
	assert context.client_wait_sync(mut foreign, 2, 0) == wait_failed
	sync_source_owner()
	assert context.get_error() == invalid_operation
	other.native.make_current()
	context.wait_sync(mut foreign, 2, 0)
	sync_source_owner()
	assert context.get_error() == invalid_operation
	other.native.make_current()
	context.delete_sync(mut foreign)
	sync_source_owner()
	assert !foreign.object.invalidated()
	assert context.get_error() == invalid_operation
	other.native.make_current()
	mut absent := ?&WebGLSync(none)
	context.delete_sync(mut absent)
	sync_source_owner()
	assert context.get_error() == no_error
	// Invalid wait flags/timeout are still handled by the actual driver.
	expected_wait := C.vox_gl_client_wait_sync(owned.native_handle_, 2, 0)
	expected_wait_error := C.vox_gl_get_error()
	other.native.make_current()
	assert context.client_wait_sync(mut owned, 2, 0) == expected_wait
	sync_source_owner()
	assert context.get_error() == expected_wait_error
	C.vox_gl_wait_sync(owned.native_handle_, 0, 0)
	expected_server_error := C.vox_gl_get_error()
	other.native.make_current()
	context.wait_sync(mut owned, 0, 0)
	sync_source_owner()
	assert context.get_error() == expected_server_error
	retained := owned.native_handle_
	assert retained != unsafe { nil }
	assert C.glIsSync(retained) == 1
	other.native.make_current()
	context.delete_sync(mut owned)
	sync_source_owner()
	assert C.glIsSync(retained) == 0
	assert owned.object.invalidated()
	assert owned.native_handle_ == retained
	assert context.get_error() == no_error
	other.native.make_current()
	context.delete_sync(mut owned)
	sync_source_owner()
	assert owned.native_handle_ == retained
	assert context.get_error() == no_error
	other.native.make_current()
	assert context.client_wait_sync(mut owned, 2, 0) == wait_failed
	sync_source_owner()
	assert context.get_error() == invalid_operation
	other.native.make_current()
	context.wait_sync(mut owned, 2, 0)
	sync_source_owner()
	assert context.get_error() == invalid_operation
	// The source also owns records whose genuine fence result was null.
	mut null_handle := context.fence_sync(0, 0) or { panic('null native source fence') }
	assert null_handle.native_handle_ == unsafe { nil }
	assert context.get_error() == invalid_enum
	C.vox_gl_wait_sync(null_handle.native_handle_, 2, 0)
	expected_null_error := C.vox_gl_get_error()
	other.native.make_current()
	context.wait_sync(mut null_handle, 2, 0)
	sync_source_owner()
	assert context.get_error() == expected_null_error
	context.delete_sync(mut null_handle)
	assert context.get_error() == no_error
	assert null_handle.native_handle_ == unsafe { nil }
}
