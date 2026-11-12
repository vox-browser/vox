// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn compressed_upload_current_viewport() [4]i32 {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(viewport, &selected[0])
	return selected
}

fn test_source_compressed_upload_format_checks_precede_driver_validation() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		context.get_extension('WEBGL_compressed_texture_s3tc', false) or { panic('native S3TC') }
		context.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		pixels := [u8(0), 248, 224, 7, 0, 0, 0, 0]
		context.native.make_current()
		C.vox_gl_compressed_tex_image2d(0xbad, 0, 0x83f0, -4, 4, 1, pixels.len, pixels.data)
		expected_image := C.vox_gl_get_error()
		other.native.make_current()
		context.compressed_tex_image2d(0xbad, 0, 0x83f0, -4, 4, 1, pixels)
		assert compressed_upload_current_viewport() == [i32(1), 2, 3, 4]!
		assert context.get_error() == expected_image
		C.vox_gl_compressed_tex_sub_image2d(0xbad, 0, 0, 0, -4, 4, 0x83f0, pixels.len, pixels.data)
		expected_sub_image := C.vox_gl_get_error()
		other.native.make_current()
		context.compressed_tex_sub_image2d(0xbad, 0, 0, 0, -4, 4, 0x83f0, pixels)
		assert compressed_upload_current_viewport() == [i32(1), 2, 3, 4]!
		assert context.get_error() == expected_sub_image
		other.native.make_current()
		context.compressed_tex_image2d(0xbad, 0, 0xbad, -4, 4, 1, [])
		assert compressed_upload_current_viewport() == [i32(1), 2, 3, 4]!
		assert context.get_error() == invalid_enum
		other.native.make_current()
		context.compressed_tex_sub_image2d(0xbad, 0, 0, 0, -4, 4, 0xbad, [])
		assert compressed_upload_current_viewport() == [i32(1), 2, 3, 4]!
		assert context.get_error() == invalid_enum
		if version == .webgl2 {
			other.native.make_current()
			context.compressed_tex_image3d(0xbad, 0, 0xbad, -4, 4, 1, 1, pixels, 9, 0)
			assert compressed_upload_current_viewport() == [i32(1), 2, 3, 4]!
			assert context.get_error() == invalid_enum
			other.native.make_current()
			context.compressed_tex_sub_image3d(0xbad, 0, 0, 0, 0, -4, 4, 1, 0xbad, pixels, 9, 0)
			assert compressed_upload_current_viewport() == [i32(1), 2, 3, 4]!
			assert context.get_error() == invalid_enum
			other.native.make_current()
			context.compressed_tex_image3d(0xbad, 0, 0x83f0, -4, 4, 1, 1, pixels, 9, 0)
			assert compressed_upload_current_viewport() == [i32(1), 2, 3, 4]!
			assert context.get_error() == invalid_value
			other.native.make_current()
			context.compressed_tex_sub_image3d(0xbad, 0, 0, 0, 0, -4, 4, 1, 0x83f0, pixels, 9, 0)
			assert compressed_upload_current_viewport() == [i32(1), 2, 3, 4]!
			assert context.get_error() == invalid_value
		}
	}
}
