// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_source_buffer_and_renderbuffer_deletion_preserve_retained_binding_slots() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut owner := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		buffer := owner.create_buffer()
		owner.bind_buffer(array_buffer, buffer)
		owner.buffer_data(array_buffer, [u8(1), 2], GLenum(0x88e4))
		owner.vertex_attrib_pointer(0, 1, unsigned_byte, false, 0, 0)
		owner.delete_buffer(buffer)
		assert buffer.object.invalidated()
		assert owner.get_parameter(array_buffer_binding).object == buffer.object.handle_
		assert C.vox_gl_vertex_attrib_parameter(0, vertex_attrib_array_buffer_binding) == 0
		mut actual_buffer := i32(-1)
		C.vox_gl_int_parameter(array_buffer_binding, &actual_buffer)
		assert actual_buffer == 0
		assert !owner.is_buffer(buffer)
		assert owner.get_buffer_parameter(array_buffer, buffer_size).integer == 0
		assert owner.get_error() == invalid_operation
		assert owner.get_error() == no_error
		owner.bind_buffer(array_buffer, none)
		assert owner.get_parameter(array_buffer_binding).kind == .none
		if version == .webgl2 {
			copy_buffer := owner.create_buffer()
			owner.bind_buffer(copy_write_buffer, copy_buffer)
			owner.delete_buffer(copy_buffer)
			assert owner.get_parameter(copy_write_buffer).object == copy_buffer.object.handle_
			owner.bind_buffer(copy_write_buffer, none)
			assert owner.get_parameter(copy_write_buffer).kind == .none
		}
		rbo := owner.create_renderbuffer()
		owner.bind_renderbuffer(renderbuffer, rbo)
		owner.delete_renderbuffer(rbo)
		assert rbo.object.invalidated()
		assert owner.get_parameter(renderbuffer_binding).object == rbo.object.handle_
		mut actual_rbo := i32(-1)
		C.vox_gl_int_parameter(renderbuffer_binding, &actual_rbo)
		assert actual_rbo == 0
		assert !owner.is_renderbuffer(rbo)
		owner.bind_renderbuffer(renderbuffer, none)
		assert owner.get_parameter(renderbuffer_binding).kind == .none
		// Source early deletion returns still select the owning GL context.
		owner.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		other.native.make_current()
		owner.delete_buffer(none)
		mut current_viewport := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(viewport, &current_viewport[0])
		assert current_viewport == [i32(1), 2, 3, 4]!
		other.native.make_current()
		owner.delete_renderbuffer(rbo)
		C.vox_gl_int_parameter(viewport, &current_viewport[0])
		assert current_viewport == [i32(1), 2, 3, 4]!
		assert owner.get_error() == no_error
	}
}
