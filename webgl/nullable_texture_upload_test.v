module webgl

fn test_native_webgl1_null_allocates_source_zeroed_pixels_and_validates_format_first() {
	mut context := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, [])
	texture := context.create_texture()
	context.bind_texture(texture_2d, texture)
	context.tex_image2d_null(texture_2d, 0, int(rgba), 2, 2, 0, rgba, unsigned_byte)
	fbo := context.create_framebuffer()
	context.bind_framebuffer(framebuffer, fbo)
	context.framebuffer_texture2d(framebuffer, color_attachment0, texture_2d, texture, 0)
	assert context.read_pixels(0, 0, 2, 2, rgba, unsigned_byte) == []u8{len: 16}
	assert context.get_error() == no_error
	context.tex_sub_image2d_null(texture_2d, 0, 0, 0, 0, 0, rgba, unsigned_byte)
	assert context.get_error() == invalid_value
	context.tex_image2d_null(texture_2d, 0, int(rgba), 1, 1, 0, rgba, unsigned_short_5_6_5)
	assert context.get_error() == invalid_operation
	context.tex_image2d_null(texture_2d, 0, int(rgba), -1, 1, 0, GLenum(0xbad), unsigned_byte)
	assert context.get_error() == invalid_enum
	context.tex_image2d_null(texture_2d, 0, int(rgba), -1, 1, 0, rgba, unsigned_byte)
	assert context.get_error() == invalid_operation
}

fn test_native_webgl2_null_is_distinct_from_empty_view_and_ignores_upload_span() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	texture := context.create_texture()
	context.bind_texture(texture_2d, texture)
	context.pixel_storei(GLenum(0x0cf2), 1)
	context.pixel_storei(GLenum(0x0cf4), 1)
	context.tex_image2d_null(texture_2d, 0, int(rgba), 1, 1, 0, rgba, unsigned_byte)
	assert context.get_error() == no_error
	context.tex_image2d(texture_2d, 0, rgba, 1, 1, 0, rgba, unsigned_byte, []u8{})
	assert context.get_error() == invalid_operation
	context.tex_sub_image2d_null(texture_2d, 0, 0, 0, 1, 1, rgba, unsigned_byte)
	assert context.get_error() == invalid_operation
	context.pixel_storei(GLenum(0x0cf2), 0)
	context.pixel_storei(GLenum(0x0cf4), 0)
	fbo := context.create_framebuffer()
	context.bind_framebuffer(framebuffer, fbo)
	context.framebuffer_texture2d(framebuffer, color_attachment0, texture_2d, texture, 0)
	assert context.read_pixels(0, 0, 1, 1, rgba, unsigned_byte) == [u8(0), 0, 0, 0]
	array_texture := context.create_texture()
	context.bind_texture(texture_2d_array, array_texture)
	context.tex_image3d_null(texture_2d_array, 0, 0x8058, 1, 1, 1, 0, rgba, unsigned_byte)
	context.framebuffer_texture_layer(framebuffer, color_attachment0, array_texture, 0, 0)
	assert context.read_pixels(0, 0, 1, 1, rgba, unsigned_byte) == [u8(0), 0, 0, 0]
	assert context.get_error() == no_error
}
