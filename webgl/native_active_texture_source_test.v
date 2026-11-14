// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn active_texture_source_driver_unit() int {
	mut unit := i32(0)
	C.vox_gl_int_parameter(active_texture, &unit)
	return unit
}

fn test_source_active_texture_selects_owner_and_keeps_driver_unit_and_errors() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		context.active_texture(texture0 + 1)
		other.active_texture(texture0 + 2)
		context.native.make_current()
		C.vox_gl_active_texture(0xbad)
		expected := C.vox_gl_get_error()
		other.native.make_current()
		context.active_texture(0xbad)
		assert active_texture_source_driver_unit() == int(texture0 + 1)
		assert context.get_error() == expected
		context.native.make_current()
		C.vox_gl_enable(0xbad)
		other.native.make_current()
		context.active_texture(texture0 + 3)
		assert active_texture_source_driver_unit() == int(texture0 + 3)
		assert context.get_parameter(active_texture).integer == int(texture0 + 3)
		assert context.get_error() == invalid_enum
		assert context.get_error() == no_error
		other.native.make_current()
		assert active_texture_source_driver_unit() == int(texture0 + 2)
		assert other.get_error() == no_error
	}
}
