// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_source_buffer_binding_checks_owner_and_mutates_compatibility_before_target_table() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut owner := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		foreign := other.create_buffer()
		owner.bind_buffer(GLenum(0xbad), foreign)
		assert owner.get_error() == invalid_operation
		buffer := owner.create_buffer()
		owner.bind_buffer(GLenum(0xbad), buffer)
		assert owner.get_error() == invalid_enum
		assert buffer.target_ or { panic('source target mutation') } == GLenum(0xbad)
		owner.bind_buffer(element_array_buffer, buffer)
		assert owner.get_error() == invalid_operation
		owner.bind_buffer(array_buffer, buffer)
		assert owner.get_error() == no_error
		assert owner.get_parameter(array_buffer_binding).object == buffer.object.handle_
		assert owner.is_buffer(buffer)
	}
}

fn test_source_retained_buffer_binding_is_written_before_driver_error_collection() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut owner := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		previous := owner.create_buffer()
		next := owner.create_buffer()
		owner.bind_buffer(array_buffer, previous)
		owner.native.make_current()
		C.vox_gl_enable(0xbad)
		owner.bind_buffer(array_buffer, next)
		assert owner.get_parameter(array_buffer_binding).object == next.object.handle_
		mut actual := i32(0)
		C.vox_gl_int_parameter(array_buffer_binding, &actual)
		assert u32(actual) == next.object.native_handle_
		assert owner.get_error() == invalid_enum
		assert owner.get_error() == no_error
	}
}
