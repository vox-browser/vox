// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn C.glIsSync(voidptr) u8

fn sync_source_owner(expected [4]i32) {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(viewport, &selected[0])
	assert selected == expected
}

fn test_source_sync_operations_select_owner_only_on_native_dispatch_and_preserve_pointers() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut other := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	context.viewport(1, 2, 3, 4)
	other.viewport(9, 10, 11, 12)
	mut owned := context.fence_sync(sync_gpu_commands_complete, 0) or { panic('owned fence') }
	mut foreign := other.fence_sync(sync_gpu_commands_complete, 0) or { panic('foreign fence') }
	context.native.make_current()
	C.vox_gl_vertex_attrib_enable(0xffff_ffff, 1)
	other.native.make_current()
	C.vox_gl_enable(0xbad)
	assert context.client_wait_sync(mut foreign, 2, 0) == wait_failed
	sync_source_owner([i32(9), 10, 11, 12]!)
	assert context.get_error() == invalid_value
	assert context.get_error() == invalid_operation
	other.native.make_current()
	context.wait_sync(mut foreign, 2, 0)
	sync_source_owner([i32(9), 10, 11, 12]!)
	assert context.get_error() == invalid_operation
	other.native.make_current()
	context.delete_sync(mut foreign)
	sync_source_owner([i32(9), 10, 11, 12]!)
	assert !foreign.object.invalidated()
	assert context.get_error() == invalid_operation
	other.native.make_current()
	mut absent := ?&WebGLSync(none)
	context.delete_sync(mut absent)
	sync_source_owner([i32(9), 10, 11, 12]!)
	assert context.get_error() == no_error
	other.native.make_current()
	assert context.get_sync_parameter(foreign, sync_condition).kind == .none
	sync_source_owner([i32(9), 10, 11, 12]!)
	assert context.get_error() == invalid_operation
	other.native.make_current()
	assert context.get_sync_parameter(owned, sync_condition).integer == sync_gpu_commands_complete
	sync_source_owner([i32(1), 2, 3, 4]!)
	assert context.get_error() == no_error
	// Invalid wait flags/timeout are still handled by the actual driver.
	expected_wait := C.vox_gl_client_wait_sync(owned.native_handle_, 2, 0)
	expected_wait_error := C.vox_gl_get_error()
	other.native.make_current()
	assert context.client_wait_sync(mut owned, 2, 0) == expected_wait
	sync_source_owner([i32(1), 2, 3, 4]!)
	assert context.get_error() == expected_wait_error
	C.vox_gl_wait_sync(owned.native_handle_, 0, 0)
	expected_server_error := C.vox_gl_get_error()
	other.native.make_current()
	context.wait_sync(mut owned, 0, 0)
	sync_source_owner([i32(1), 2, 3, 4]!)
	assert context.get_error() == expected_server_error
	retained_source := owned.source_handle_
	retained := owned.native_handle_
	assert retained != unsafe { nil }
	assert C.glIsSync(retained) == 1
	other.native.make_current()
	context.delete_sync(mut owned)
	sync_source_owner([i32(1), 2, 3, 4]!)
	assert C.glIsSync(retained) == 0
	assert owned.object.invalidated()
	assert owned.native_handle_ == retained
	assert owned.source_handle_ == retained_source
	assert context.get_error() == no_error
	other.native.make_current()
	context.delete_sync(mut owned)
	sync_source_owner([i32(9), 10, 11, 12]!)
	assert owned.native_handle_ == retained
	assert owned.source_handle_ == retained_source
	assert context.get_error() == no_error
	other.native.make_current()
	assert context.client_wait_sync(mut owned, 2, 0) == wait_failed
	sync_source_owner([i32(9), 10, 11, 12]!)
	assert context.get_error() == invalid_operation
	other.native.make_current()
	context.wait_sync(mut owned, 2, 0)
	sync_source_owner([i32(9), 10, 11, 12]!)
	assert context.get_error() == invalid_operation
	other.native.make_current()
	assert context.get_sync_parameter(owned, sync_condition).kind == .none
	sync_source_owner([i32(9), 10, 11, 12]!)
	assert context.get_error() == invalid_operation
	// The Source proxy pointer remains owned when the native fence result is null.
	mut null_handle := context.fence_sync(0, 0) or { panic('null native source fence') }
	assert null_handle.native_handle_ == unsafe { nil }
	assert context.get_error() == invalid_enum
	C.vox_gl_wait_sync(null_handle.native_handle_, 2, 0)
	expected_null_error := C.vox_gl_get_error()
	other.native.make_current()
	context.wait_sync(mut null_handle, 2, 0)
	sync_source_owner([i32(1), 2, 3, 4]!)
	assert context.get_error() == expected_null_error
	context.delete_sync(mut null_handle)
	assert context.get_error() == no_error
	assert null_handle.native_handle_ == unsafe { nil }
	assert other.get_error() == invalid_enum
	assert other.get_error() == no_error
}
