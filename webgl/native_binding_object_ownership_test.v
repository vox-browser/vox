// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn bind_and_delete_local_records(mut context WebGLRenderingContext) (voidptr, voidptr) {
	buffer := context.create_buffer()
	context.bind_buffer(array_buffer, buffer)
	context.delete_buffer(buffer)
	rbo := context.create_renderbuffer()
	context.bind_renderbuffer(renderbuffer, rbo)
	context.delete_renderbuffer(rbo)
	return voidptr(buffer), voidptr(rbo)
}

fn test_source_binding_slots_own_actual_deleted_objects_after_caller_returns() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		buffer_address, rbo_address := bind_and_delete_local_records(mut context)
		assert context.buffers.len == 0
		assert context.renderbuffers.len == 0
		buffer := context.get_parameter(array_buffer_binding).buffer or { panic('owned buffer binding') }
		rbo := context.get_parameter(renderbuffer_binding).renderbuffer or { panic('owned renderbuffer binding') }
		assert voidptr(buffer) == buffer_address
		assert voidptr(rbo) == rbo_address
		assert buffer.object.invalidated()
		assert rbo.object.invalidated()
		retained_buffer := context.bound_buffer_objects[array_buffer] or { panic('buffer retained slot') }
		assert voidptr(retained_buffer) == buffer_address
		retained_rbo := context.bound_renderbuffer_object or { panic('renderbuffer retained slot') }
		assert voidptr(retained_rbo) == rbo_address
		if version == .webgl2 {
			copy := context.create_buffer()
			context.bind_buffer(copy_write_buffer, copy)
			context.delete_buffer(copy)
			queried := context.get_parameter(copy_write_buffer).buffer or { panic('copy buffer record') }
			assert voidptr(queried) == voidptr(copy)
		}
		context.bind_buffer(array_buffer, none)
		context.bind_renderbuffer(renderbuffer, none)
		assert array_buffer !in context.bound_buffer_objects
		assert context.bound_renderbuffer_object == none
		context.reset_client_side_webgl_state()
		assert context.bound_buffer_objects.len == 0
		assert context.get_error() == no_error
	}
}
