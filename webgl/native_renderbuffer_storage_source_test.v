// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_source_renderbuffer_storage_forwards_real_binding_and_depth_stencil_mapping() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		context.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		buffer := context.create_renderbuffer()
		C.vox_gl_bind_renderbuffer(renderbuffer, buffer.object.native_handle_)
		assert context.bound_renderbuffer_object == none
		C.vox_gl_renderbuffer_storage(renderbuffer, 0x88f0, 6, 8)
		expected_format := C.vox_gl_renderbuffer_parameter(renderbuffer, 0x8d44)
		mapped_error := C.vox_gl_get_error()
		assert mapped_error == no_error
		other.native.make_current()
		context.renderbuffer_storage(renderbuffer, 0x84f9, 7, 9)
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		assert context.get_renderbuffer_parameter(renderbuffer, 0x8d44).integer == expected_format
		assert context.get_renderbuffer_parameter(renderbuffer, 0x8d42).integer == 7
		assert context.get_renderbuffer_parameter(renderbuffer, 0x8d43).integer == 9
		assert context.get_renderbuffer_parameter(renderbuffer, 0x8d54).integer == 24
		assert context.get_renderbuffer_parameter(renderbuffer, 0x8d55).integer == 8
		assert context.get_error() == no_error
		// Competing invalid inputs retain the genuine driver's ordering.
		C.vox_gl_renderbuffer_storage(0xbad, 0x8056, -1, 2)
		expected := C.vox_gl_get_error()
		other.native.make_current()
		context.renderbuffer_storage(0xbad, 0x8056, -1, 2)
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		assert context.get_error() == expected
		if version == .webgl2 {
			other.native.make_current()
			context.renderbuffer_storage_multisample(renderbuffer, 0, 0x8058, 5, 6)
			C.vox_gl_int_parameter(viewport, &selected[0])
			assert selected == [i32(1), 2, 3, 4]!
			assert context.get_renderbuffer_parameter(renderbuffer, 0x8d44).integer == 0x8058
			assert context.get_renderbuffer_parameter(renderbuffer, 0x8d42).integer == 5
			assert context.get_renderbuffer_parameter(renderbuffer, 0x8d43).integer == 6
			assert context.get_renderbuffer_parameter(renderbuffer, 0x8cab).integer == 0
			assert context.get_error() == no_error
			C.vox_gl_renderbuffer_storage_multisample(0xbad, -1, 0x8058, -1, 2)
			expected_samples := C.vox_gl_get_error()
			other.native.make_current()
			context.renderbuffer_storage_multisample(0xbad, -1, 0x8058, -1, 2)
			C.vox_gl_int_parameter(viewport, &selected[0])
			assert selected == [i32(1), 2, 3, 4]!
			assert context.get_error() == expected_samples
		}
	}
}
