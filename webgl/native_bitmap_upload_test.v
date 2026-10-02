module webgl

fn test_native_bitmap_source_upload_alpha_flip_scaling_and_metadata() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	texture := context.create_texture()
	context.bind_texture(texture_2d, texture)
	source := WebGLTextureImageSource{
		kind:  .image_data
		frame: WebGLBitmap{
			width:  2
			height: 2
			pixels: [u8(200), 100, 50, 128, 0, 255, 0, 255, 0, 0, 255, 255, 255, 255, 0, 255]
		}
	}
	context.tex_image2d_source(texture_2d, 0, int(rgba), rgba, unsigned_byte, source, none, 0)!
	fbo := context.create_framebuffer()
	context.bind_framebuffer(framebuffer, fbo)
	context.framebuffer_texture2d(framebuffer, color_attachment0, texture_2d, texture, 0)
	assert context.read_pixels(0, 0, 2, 2, rgba, unsigned_byte) == (source.frame or { panic('source frame') }).pixels
	context.pixel_storei(unpack_flip_y_webgl, 1)
	context.pixel_storei(unpack_premultiply_alpha_webgl, 1)
	context.tex_image2d_source(texture_2d, 0, int(rgba), rgba, unsigned_byte, source, WebGLIntSize{ width: 4, height: 4 }, 0)!
	assert context.read_pixels(0, 0, 1, 1, rgba, unsigned_byte) == [u8(0), 0, 255, 255]
	assert context.read_pixels(0, 3, 1, 1, rgba, unsigned_byte) == [u8(100), 50, 25, 128]
	context.tex_sub_image2d_source(texture_2d, 0, 0, 0, rgba, unsigned_byte, WebGLTextureImageSource{
		kind:  .image_bitmap
		frame: WebGLBitmap{ width: 1, height: 1, layout: 1, alpha_type: 2, pixels: [
			u8(25),
			50,
			100,
			128,
		] }
	}, none)!
	assert context.read_pixels(0, 0, 1, 1, rgba, unsigned_byte) == [u8(100), 50, 25, 128]
	context.pixel_storei(unpack_premultiply_alpha_webgl, 0)
	context.tex_sub_image2d_source(texture_2d, 0, 1, 0, rgba, unsigned_byte, WebGLTextureImageSource{
		kind:  .image_bitmap
		frame: WebGLBitmap{ width: 1, height: 1, layout: 1, alpha_type: 2, pixels: [
			u8(25),
			50,
			100,
			128,
		] }
	}, none)!
	assert context.read_pixels(1, 0, 1, 1, rgba, unsigned_byte) == [u8(199), 100, 50, 128]
	assert context.get_error() == no_error
}

fn test_native_bitmap_source_3d_layer_update_and_validation() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	texture := context.create_texture()
	context.bind_texture(texture_2d_array, texture)
	source := WebGLTextureImageSource{ kind: .canvas, frame: WebGLBitmap{ width: 1, height: 1, pixels: [
		u8(0),
		255,
		0,
		255,
	] } }
	context.tex_image3d_source(texture_2d_array, 0, int(rgba), 1, rgba, unsigned_byte, source, WebGLIntSize{ width: 2, height: 2 }, 0)!
	fbo := context.create_framebuffer()
	context.bind_framebuffer(framebuffer, fbo)
	context.framebuffer_texture_layer(framebuffer, color_attachment0, texture, 0, 0)
	assert context.read_pixels(1, 1, 1, 1, rgba, unsigned_byte) == [u8(0), 255, 0, 255]
	context.tex_sub_image3d_source(texture_2d_array, 0, 1, 1, 0, 1, rgba, unsigned_byte, WebGLTextureImageSource{
		kind:  .video
		frame: WebGLBitmap{ width: 1, height: 1, pixels: [u8(255), 0, 0, 255] }
	}, WebGLIntSize{ width: 1, height: 1 })!
	assert context.read_pixels(1, 1, 1, 1, rgba, unsigned_byte) == [u8(255), 0, 0, 255]
	assert context.get_error() == no_error
	context.tex_image2d_source(texture_2d, 0, int(rgba), rgba, unsigned_byte, WebGLTextureImageSource{}, none, 1)!
	assert context.get_error() == invalid_value
	context.tex_image3d_source(texture_2d_array, 0, int(rgba), 1, rgba, unsigned_byte, source, WebGLIntSize{ width: -1, height: 1 }, 0)!
	assert context.get_error() == invalid_value
	context.tex_sub_image3d_source(texture_2d_array, 0, 0, 0, 0, 2, rgba, unsigned_byte, source, WebGLIntSize{ width: 1, height: 1 })!
	assert context.get_error() == invalid_value
	context.tex_sub_image2d_source(texture_2d, 0, 0, 0, rgba, gl_float, source, none)!
	assert context.get_error() == no_error
}
