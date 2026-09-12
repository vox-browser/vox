module webgl

fn texture_source_frame() WebGLBitmap {
	return WebGLBitmap{
		width: 1
		height: 1
		pixels: [u8(10), 20, 30, 40]
	}
}

fn test_texture_image_source_propagates_unpack_flags_except_bitmap_flip() {
	mut context := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, [])
	context.pixel_storei(unpack_flip_y_webgl, 1)
	context.pixel_storei(unpack_premultiply_alpha_webgl, 1)

	image := context.read_texture_image_source(WebGLTextureImageSource{
		kind: .image_element
		frame: texture_source_frame()
	}, rgba, unsigned_byte) or { panic('image frame expected') }
	assert image.flip_y
	assert image.premultiply_alpha
	assert image.frame.pixels == [u8(10), 20, 30, 40]

	bitmap := context.read_texture_image_source(WebGLTextureImageSource{
		kind: .image_bitmap
		frame: texture_source_frame()
	}, rgba, unsigned_byte) or { panic('bitmap frame expected') }
	assert !bitmap.flip_y
	assert bitmap.premultiply_alpha
}

fn test_texture_image_source_rejects_invalid_image_data_storage() {
	for source in [
		WebGLTextureImageSource{ kind: .image_data, data_detached: true },
		WebGLTextureImageSource{ kind: .image_data, data_out_of_bounds: true },
		WebGLTextureImageSource{ kind: .image_data, bitmap_error: true },
	] {
		mut context := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, [])
		assert context.read_texture_image_source(source, rgba, unsigned_byte) == none
		assert context.get_error() == invalid_value
	}
}

fn test_texture_image_source_requires_a_frame_and_supported_export_format() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	assert context.read_texture_image_source(WebGLTextureImageSource{
		kind: .video
	}, rgba, unsigned_byte) == none
	assert context.get_error() == no_error
	assert context.read_texture_image_source(WebGLTextureImageSource{
		kind: .canvas
		frame: texture_source_frame()
	}, rgba, gl_float) == none
	assert context.get_error() == no_error
}
