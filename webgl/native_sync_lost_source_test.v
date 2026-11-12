// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_source_lost_client_wait_returns_default_without_touching_other_native_mapping() {
	mut owner := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut other := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut before_loss := owner.fence_sync(sync_gpu_commands_complete, 0) or { panic('source fence before loss') }
	owner.lose_context_from_compositor_loss()
	other.viewport(9, 10, 11, 12)
	mut sentinel := other.fence_sync(sync_gpu_commands_complete, 0) or { panic('other genuine fence') }
	other.native.make_current()
	C.vox_gl_vertex_attrib_enable(0xffff_ffff, 1)
	mut after_loss := owner.fence_sync(sync_gpu_commands_complete, 0) or { panic('source owned fence after loss') }
	assert after_loss.native_pointer() == unsafe { nil }
	assert uint(after_loss.sync_handle(owner.identity(), owner.context_generation())!) == 2
	for flags in [GLenum(0), sync_flush_commands_bit, GLenum(2)] {
		for timeout in [u64(0), u64(1), u64(-1)] {
			assert owner.client_wait_sync(mut before_loss, flags, timeout) == 0
			assert owner.client_wait_sync(mut after_loss, flags, timeout) == 0
			mut selected := [i32(0), 0, 0, 0]!
			C.vox_gl_int_parameter(viewport, &selected[0])
			assert selected == [i32(9), 10, 11, 12]!
			assert C.vox_gl_get_sync_parameter(sentinel.native_pointer(), sync_condition) == int(sync_gpu_commands_complete)
		}
	}
	assert C.vox_gl_get_error() == invalid_value
	assert C.vox_gl_get_error() == no_error
	assert owner.get_error() == context_lost_webgl
	assert owner.get_error() == no_error
	assert other.get_error() == no_error
	other.delete_sync(mut sentinel)
}

fn test_source_live_rejected_native_fence_retains_actual_wait_failed_driver_result() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut rejected := context.fence_sync(0, 0) or { panic('source rejected fence record') }
	assert context.get_error() == invalid_enum
	assert rejected.native_pointer() == unsafe { nil }
	assert uint(rejected.sync_handle(context.identity(), context.context_generation())!) == 1
	context.native.make_current()
	expected := C.vox_gl_client_wait_sync(rejected.native_pointer(), 0, 0)
	expected_error := C.vox_gl_get_error()
	assert expected == wait_failed
	assert context.client_wait_sync(mut rejected, 0, 0) == expected
	assert context.get_error() == expected_error
}
