module webgl

fn test_drawing_buffer_clear_scissor_color_masks_and_read_pixels_are_real() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	context.set_size(4, 3)
	context.disable(dither)
	context.clear_color(0, 0, 1, 1)
	context.clear(GLenum(0x4000))
	context.enable(scissor_test)
	context.scissor(1, 1, 2, 1)
	context.clear_color(1, 1, 0, 1)
	context.clear(GLenum(0x4000))
	context.disable(scissor_test)
	pixels := context.read_pixels(0, 0, 4, 3, rgba, unsigned_byte)
	assert pixels.len == 48
	for y in 0 .. 3 {
		for x in 0 .. 4 {
			pixel := pixels[(y * 4 + x) * 4..(y * 4 + x + 1) * 4]
			assert pixel == if y == 1 && x in [1, 2] { [u8(255), 255, 0, 255] } else { [u8(0), 0, 255, 255] }
		}
	}
	context.color_mask(false, false, true, true)
	context.clear_color(0, 0, 0, 0.5)
	context.clear(GLenum(0x4000))
	assert context.read_pixels(1, 1, 1, 1, rgba, unsigned_byte) == [u8(255), 255, 0, 128]
	context.color_mask(true, true, true, true)
	context.set_size(2, 2)
	assert context.read_pixels(0, 0, 2, 2, rgba, unsigned_byte) == []u8{len: 16}
	assert context.get_error() == no_error
}

fn test_framebuffer_completeness_and_texture_upload_readback_use_gl() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut target := context.create_framebuffer()
	context.bind_framebuffer(framebuffer, target)
	assert context.check_framebuffer_status(framebuffer) == GLenum(0x8cd7) // missing attachment
	mut texture := context.create_texture()
	context.bind_texture(texture_2d, texture)
	upload := [u8(1), 2, 3, 255, 10, 20, 30, 255, 40, 50, 60, 255, 100, 110, 120, 255]
	context.tex_image2d(texture_2d, 0, int(rgba), 2, 2, 0, rgba, unsigned_byte, upload)
	context.framebuffer_texture2d(framebuffer, color_attachment0, texture_2d, texture, 0)
	assert context.check_framebuffer_status(framebuffer) == GLenum(0x8cd5)
	assert context.read_pixels(0, 0, 2, 2, rgba, unsigned_byte) == upload
	context.tex_sub_image2d(texture_2d, 0, 1, 1, 1, 1, rgba, unsigned_byte, [u8(200), 201, 202, 255])
	assert context.read_pixels(1, 1, 1, 1, rgba, unsigned_byte) == [u8(200), 201, 202, 255]
	context.framebuffer_texture2d(framebuffer, color_attachment0, texture_2d, none, 0)
	assert context.check_framebuffer_status(framebuffer) == GLenum(0x8cd7)
	assert context.read_pixels(0, 0, 1, 1, rgba, unsigned_byte).len == 0
	assert context.get_error() == invalid_framebuffer_operation
	mut render_target := context.create_renderbuffer()
	context.bind_renderbuffer(renderbuffer, render_target)
	context.renderbuffer_storage(renderbuffer, GLenum(0x8058), 2, 2)
	context.framebuffer_renderbuffer(framebuffer, color_attachment0, renderbuffer, render_target)
	assert context.check_framebuffer_status(framebuffer) == GLenum(0x8cd5)
	context.disable(dither)
	context.clear_color(1, 0.25, 0, 0.5)
	context.clear(GLenum(0x4000))
	assert context.read_pixels(0, 0, 1, 1, rgba, unsigned_byte) == [u8(255), 64, 0, 128]
	context.bind_framebuffer(framebuffer, none)
	assert context.check_framebuffer_status(framebuffer) == GLenum(0x8cd5)
	assert context.get_error() == no_error
}
