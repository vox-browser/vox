// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_source_sync_handle_returns_actual_pointer_and_present_null_deletion_handle() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut other := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	for condition in [sync_gpu_commands_complete, GLenum(0)] {
		mut sync := context.fence_sync(condition, 0) or { panic('source sync record') }
		actual := sync.native_handle_
		assert (actual == unsafe { nil }) == (condition == 0)
		assert context.get_error() == if condition == 0 { invalid_enum } else { no_error }
		assert sync.sync_handle(context.identity(), context.context_generation())! == actual
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
		assert first.value == actual
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
		// Complete the same source split: returned pointer then genuine GL delete.
		context.native.make_current()
		C.vox_gl_delete_sync(first.value)
		assert C.vox_gl_get_error() == no_error
	}
}

fn test_source_sync_pointer_generation_validation_ignores_native_pointer_value() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	for condition in [sync_gpu_commands_complete, GLenum(0)] {
		mut sync := context.fence_sync(condition, 0) or { panic('source generation sync') }
		context.get_error()
		actual := sync.native_handle_
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
		assert sync.sync_handle(context.identity(), context.context_generation())! == actual
		context.delete_sync(mut sync)
		assert sync.object.invalidated()
		assert sync.native_handle_ == actual
		assert context.get_error() == no_error
	}
}
