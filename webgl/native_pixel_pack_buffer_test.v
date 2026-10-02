module webgl

fn test_native_pixel_pack_buffer_readback_and_driver_packing_bounds() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	context.set_size(2, 2)
	context.clear_color(1, 0.25, 0.5, 1)
	context.clear(GLenum(0x4000))
	context.read_pixels_into_pixel_pack_buffer(0, 0, 1, 1, rgba, unsigned_byte, 0)
	assert context.get_error() == invalid_operation
	buffer := context.create_buffer()
	context.bind_buffer(pixel_pack_buffer, buffer)
	context.buffer_data(pixel_pack_buffer, []u8{len: 32, init: 99}, GLenum(0x88e4))
	context.read_pixels_into_pixel_pack_buffer(0, 0, 1, 1, rgba, unsigned_byte, 4)
	mut output := []u8{len: 32}
	context.get_buffer_sub_data_into(pixel_pack_buffer, 0, mut output, 0, 0, 1)
	assert output[..4] == [u8(99), 99, 99, 99]
	assert output[4..8] == [u8(255), 64, 128, 255]
	assert output[8..] == []u8{len: 24, init: 99}
	assert context.get_error() == no_error
	context.pixel_storei(GLenum(0x0d02), 2)
	context.pixel_storei(GLenum(0x0d04), 1)
	context.pixel_storei(GLenum(0x0d03), 1)
	context.read_pixels_into_pixel_pack_buffer(0, 0, 1, 1, rgba, unsigned_byte, 4)
	context.get_buffer_sub_data_into(pixel_pack_buffer, 0, mut output, 0, 0, 1)
	assert output[16..20] == [u8(255), 64, 128, 255]
	assert output[8..16] == []u8{len: 8, init: 99}
	assert output[20..] == []u8{len: 12, init: 99}
	assert context.get_error() == no_error
	context.read_pixels_into_pixel_pack_buffer(0, 0, 1, 1, rgba, unsigned_byte, 30)
	assert context.get_error() == invalid_operation
	context.read_pixels_into_pixel_pack_buffer(0, 0, -1, 1, rgba, unsigned_byte, 0)
	assert context.get_error() == invalid_value
	context.bind_buffer(pixel_pack_buffer, none)
	context.read_pixels_into_pixel_pack_buffer(0, 0, 1, 1, rgba, unsigned_byte, 0)
	assert context.get_error() == invalid_operation
}
