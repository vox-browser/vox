// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_source_texture_copy_selects_owner_and_delegates_competing_validation() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		context.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		context.native.make_current()
		C.vox_gl_copy_tex_image2d(0xbad, 0, rgba, 0, 0, -1, 1, 1)
		expected_image := C.vox_gl_get_error()
		other.native.make_current()
		context.copy_tex_image2d(0xbad, 0, rgba, 0, 0, -1, 1, 1)
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		assert context.get_error() == expected_image
		C.vox_gl_copy_tex_sub_image2d(0xbad, 0, 0, 0, 0, 0, -1, 1)
		expected_sub_image := C.vox_gl_get_error()
		other.native.make_current()
		context.copy_tex_sub_image2d(0xbad, 0, 0, 0, 0, 0, -1, 1)
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		assert context.get_error() == expected_sub_image
	}
}
