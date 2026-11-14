module webgl

fn test_native_presentation_reads_flipped_default_pixels_and_respects_preservation() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{preserve_drawing_buffer:true}, [])
	context.set_size(2,2)
	context.clear_color(0,0,1,1)
	context.clear(0x4000)
	context.enable(scissor_test)
	context.scissor(0,1,2,1)
	context.clear_color(1,0,0,1)
	context.clear(0x4000)
	context.disable(scissor_test)
	assert context.prepare_for_compositing()
	frame := context.native.painting_surface() or { panic('painting surface') }
	assert frame.width == 2 && frame.height == 2
	assert frame.pixels == [u8(255),0,0,255,255,0,0,255,0,0,255,255,0,0,255,255]
	assert context.read_pixels(0,0,1,1,rgba,unsigned_byte) == [u8(0),0,255,255]
	mut discarded := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, [])
	discarded.clear_color(0,1,0,1)
	discarded.clear(0x4000)
	assert discarded.present()
	assert (discarded.native.painting_surface() or { panic('presented') }).pixels == [u8(0),255,0,255]
	assert discarded.read_pixels(0,0,1,1,rgba,unsigned_byte) == [u8(0),0,0,0]
	assert discarded.get_parameter(color_clear_value).numbers == [f64(0),1,0,1]
	assert discarded.get_error() == no_error
}

fn test_native_drawing_buffer_readback_preserves_pack_buffers_and_framebuffer_state() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	context.set_size(2,2)
	context.clear_color(1,0.5,0,1)
	context.clear(0x4000)
	pack := context.create_buffer()
	context.bind_buffer(pixel_pack_buffer,pack)
	context.buffer_data_size(pixel_pack_buffer,64,0x88e8)
	context.pixel_storei(pack_alignment,8)
	context.pixel_storei(pack_row_length,4)
	context.pixel_storei(pack_skip_pixels,1)
	context.pixel_storei(pack_skip_rows,2)
	fbo := context.create_framebuffer()
	context.bind_framebuffer(0x8ca8,fbo)
	frame := context.native.read_back_drawing_buffer() or { panic('source readback') }
	for offset := 0; offset < frame.pixels.len; offset+=4 { assert frame.pixels[offset..offset+4] == [u8(255),128,0,255] }
	mut native_binding := i32(0)
	C.vox_gl_int_parameter(0x8caa,&native_binding)
	assert native_binding == int(fbo.object.native_handle_)
	C.vox_gl_int_parameter(pixel_pack_buffer_binding,&native_binding)
	assert native_binding == int(pack.object.native_handle_)
	C.vox_gl_int_parameter(pack_alignment,&native_binding)
	assert native_binding == 8
	C.vox_gl_int_parameter(pack_row_length,&native_binding)
	assert native_binding == 4
	C.vox_gl_int_parameter(pack_skip_pixels,&native_binding)
	assert native_binding == 1
	C.vox_gl_int_parameter(pack_skip_rows,&native_binding)
	assert native_binding == 2
	assert context.get_error() == no_error
}
