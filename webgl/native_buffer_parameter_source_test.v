// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_source_buffer_parameters_return_initialized_driver_integer_without_retained_binding_gate() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut owner := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		owner.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		mut selected := [i32(0), 0, 0, 0]!
		for pname in [buffer_size, buffer_usage] {
			other.native.make_current()
			unbound := owner.get_buffer_parameter(array_buffer, pname)
			C.vox_gl_int_parameter(viewport, &selected[0])
			assert selected == [i32(1), 2, 3, 4]!
			assert unbound.kind == .integer
			assert unbound.integer == 0
			assert owner.get_error() == invalid_operation
			assert owner.get_error() == no_error
			invalid_target := owner.get_buffer_parameter(GLenum(0xbad), pname)
			assert invalid_target.kind == .integer
			assert invalid_target.integer == 0
			assert owner.get_error() == invalid_enum
			assert owner.get_error() == no_error
		}
		owner.native.make_current()
		C.vox_gl_vertex_attrib_enable(0xffff_ffff, 1)
		other.native.make_current()
		unknown := owner.get_buffer_parameter(GLenum(0xbad), GLenum(0xbad))
		assert unknown.kind == .none
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert C.vox_gl_get_error() == no_error
		assert owner.get_error() == invalid_value
		assert owner.get_error() == invalid_enum
		assert owner.get_error() == no_error
		buffer := owner.create_buffer()
		owner.native.make_current()
		C.vox_gl_bind_buffer(array_buffer, buffer.object.native_handle_)
		C.vox_gl_buffer_data(array_buffer, 17, unsafe { nil }, GLenum(0x88e8))
		assert array_buffer !in owner.bound_buffers
		other.native.make_current()
		size := owner.get_buffer_parameter(array_buffer, buffer_size)
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		usage := owner.get_buffer_parameter(array_buffer, buffer_usage)
		assert size.kind == .integer
		assert size.integer == 17
		assert usage.kind == .integer
		assert usage.integer == 0x88e8
		assert owner.get_error() == no_error
		assert other.get_error() == no_error
	}
}
