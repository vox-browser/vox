// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn bitmap_upload_current_viewport() [4]i32 {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(viewport, &selected[0])
	return selected
}

fn test_source_bitmap_uploads_select_owner_before_missing_frames_and_source_errors() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		context.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		missing := WebGLTextureImageSource{ kind: .image_element }
		other.native.make_current()
		context.tex_image2d_source(0xbad, 0, int(rgba), rgba, unsigned_byte, missing, none, 0)!
		assert bitmap_upload_current_viewport() == [i32(1), 2, 3, 4]!
		assert context.get_error() == no_error
		other.native.make_current()
		context.tex_sub_image2d_source(0xbad, 0, 0, 0, rgba, unsigned_byte, missing, none)!
		assert bitmap_upload_current_viewport() == [i32(1), 2, 3, 4]!
		assert context.get_error() == no_error
		invalid_data := WebGLTextureImageSource{ kind: .image_data, data_out_of_bounds: true }
		other.native.make_current()
		context.tex_image2d_source(0xbad, 0, int(rgba), rgba, unsigned_byte, invalid_data, none, 0)!
		assert bitmap_upload_current_viewport() == [i32(1), 2, 3, 4]!
		assert context.get_error() == invalid_value
		other.native.make_current()
		context.tex_sub_image2d_source(0xbad, 0, 0, 0, rgba, unsigned_byte, invalid_data, none)!
		assert bitmap_upload_current_viewport() == [i32(1), 2, 3, 4]!
		assert context.get_error() == invalid_value
		if version == .webgl2 {
			size := WebGLIntSize{ width: 1, height: 1 }
			other.native.make_current()
			context.tex_image2d_source(0xbad, 0, int(rgba), rgba, unsigned_byte, missing, size, 1)!
			assert bitmap_upload_current_viewport() == [i32(1), 2, 3, 4]!
			assert context.get_error() == invalid_value
			other.native.make_current()
			context.tex_image3d_source(0xbad, 0, int(rgba), 1, rgba, unsigned_byte, missing, size, 0)!
			assert bitmap_upload_current_viewport() == [i32(1), 2, 3, 4]!
			assert context.get_error() == no_error
			other.native.make_current()
			context.tex_sub_image3d_source(0xbad, 0, 0, 0, 0, 1, rgba, unsigned_byte, missing, size)!
			assert bitmap_upload_current_viewport() == [i32(1), 2, 3, 4]!
			assert context.get_error() == no_error
			other.native.make_current()
			context.tex_image3d_source(0xbad, 0, int(rgba), 1, rgba, unsigned_byte, missing, size, 1)!
			assert bitmap_upload_current_viewport() == [i32(1), 2, 3, 4]!
			assert context.get_error() == invalid_value
			other.native.make_current()
			context.tex_sub_image3d_source(0xbad, 0, 0, 0, 0, 1, rgba, unsigned_byte, invalid_data, size)!
			assert bitmap_upload_current_viewport() == [i32(1), 2, 3, 4]!
			assert context.get_error() == invalid_value
		}
	}
}
