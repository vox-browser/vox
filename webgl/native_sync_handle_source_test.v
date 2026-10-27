// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_source_sync_handle_returns_proxy_pointer_with_separate_actual_driver_mapping() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut other := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	// ANGLE can use small integer native GLsync values, so independent real
	// driver fences force the tested Source IDs away from their native mapping.
	context.native.make_current()
	mut reserved := []voidptr{}
	for _ in 0 .. 8 {
		pointer := C.vox_gl_fence_sync(sync_gpu_commands_complete, 0)
		assert pointer != unsafe { nil }
		reserved << pointer
	}
	for condition in [sync_gpu_commands_complete, GLenum(0)] {
		mut sync := context.fence_sync(condition, 0) or { panic('source sync record') }
		actual := sync.native_handle_
		source := sync.source_handle_
		assert uint(source) == if condition == sync_gpu_commands_complete {
			uint(1)
		} else {
			uint(2)
		}
		assert source != actual
		assert (actual == unsafe { nil }) == (condition == 0)
		assert context.get_error() == if condition == 0 { invalid_enum } else { no_error }
		assert sync.sync_handle(context.identity(), context.context_generation())! == source
		// Context validation runs before invalidation in both source handle APIs.
		mut rejected := false
		sync.sync_handle(other.identity(), other.context_generation()) or {
			assert err.msg() == 'GL_INVALID_OPERATION'
			rejected = true
		}
		assert rejected
		rejected = false
		sync.sync_handle_for_deletion(other.identity(), other.context_generation()) or {
			assert err.msg() == 'GL_INVALID_OPERATION'
			rejected = true
		}
		assert rejected
		assert !sync.object.invalidated()
		first := sync.sync_handle_for_deletion(context.identity(), context.context_generation())!
		assert first.has_value
		assert first.value == source
		assert sync.object.invalidated()
		assert sync.native_handle_ == actual
		repeat := sync.sync_handle_for_deletion(context.identity(), context.context_generation())!
		assert !repeat.has_value
		rejected = false
		sync.sync_handle_for_deletion(other.identity(), other.context_generation()) or {
			assert err.msg() == 'GL_INVALID_OPERATION'
			rejected = true
		}
		assert rejected
		rejected = false
		sync.sync_handle(context.identity(), context.context_generation()) or {
			assert err.msg() == 'GL_INVALID_OPERATION'
			rejected = true
		}
		assert rejected
		// Source returns the proxy pointer; the actual compositor mapping supplies
		// the distinct native pointer for the genuine GL deletion.
		context.native.make_current()
		C.vox_gl_delete_sync(sync.native_pointer())
		assert C.vox_gl_get_error() == no_error
		for pointer in reserved {
			assert C.vox_gl_get_sync_parameter(pointer, sync_condition) == int(sync_gpu_commands_complete)
			assert C.vox_gl_get_error() == no_error
		}
	}
	for pointer in reserved { C.vox_gl_delete_sync(pointer) }
	assert C.vox_gl_get_error() == no_error
}

fn test_source_sync_pointer_generation_validation_ignores_native_pointer_value() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	for condition in [sync_gpu_commands_complete, GLenum(0)] {
		mut sync := context.fence_sync(condition, 0) or { panic('source generation sync') }
		context.get_error()
		actual := sync.native_handle_
		source := sync.source_handle_
		stale_generation := context.context_generation() + 1
		mut rejected := false
		sync.sync_handle(context.identity(), stale_generation) or {
			assert err.msg() == 'GL_INVALID_OPERATION'
			rejected = true
		}
		assert rejected
		absent := sync.sync_handle_for_deletion(context.identity(), stale_generation)!
		assert !absent.has_value
		assert !sync.object.invalidated()
		assert sync.native_handle_ == actual
		assert sync.sync_handle(context.identity(), context.context_generation())! == source
		context.delete_sync(mut sync)
		assert sync.object.invalidated()
		assert sync.native_handle_ == actual
		assert context.get_error() == no_error
	}
}
