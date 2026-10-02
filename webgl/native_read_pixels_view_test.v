module webgl

fn test_robust_read_pixels_uses_destination_capacity_and_element_offset() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	context.set_size(2, 2)
	context.clear_color(1, 0.25, 0.5, 1)
	context.clear(GLenum(0x4000))
	mut data := []u8{len: 12, init: 99}
	context.read_pixels_into(0, 0, 1, 1, rgba, unsigned_byte, mut data, 1, 4)
	assert data == [u8(99), 99, 99, 99, 255, 64, 128, 255, 99, 99, 99, 99]
	assert context.get_error() == no_error
	mut short := [u8(77)]
	context.read_pixels_into(0, 0, 1, 1, rgba, unsigned_byte, mut short, 0, 1)
	assert context.get_error() == invalid_operation
	assert short == [u8(77)]
	context.read_pixels_into(0, 0, 1, 1, rgba, unsigned_byte, mut data, u64(-1), 4)
	assert context.get_error() == invalid_operation
	context.read_pixels_into(0, 0, -1, 1, rgba, unsigned_byte, mut data, 0, 1)
	assert context.get_error() == invalid_value
	buffer := context.create_buffer()
	context.bind_buffer(pixel_pack_buffer, buffer)
	context.buffer_data_size(pixel_pack_buffer, 16, GLenum(0x88e4))
	context.read_pixels_into(0, 0, 1, 1, rgba, unsigned_byte, mut data, 0, 1)
	assert context.get_error() == invalid_operation
	context.bind_buffer(pixel_pack_buffer, none)
	context.read_pixels_null()
	assert context.get_error() == invalid_value
}

fn test_robust_read_pixels_obeys_pack_row_length_and_skipped_pixels() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	context.set_size(1, 1)
	context.clear_color(0, 1, 0, 1)
	context.clear(GLenum(0x4000))
	context.pixel_storei(pack_row_length, 3)
	context.pixel_storei(pack_skip_rows, 1)
	context.pixel_storei(pack_skip_pixels, 1)
	mut data := []u8{len: 24, init: 55}
	context.read_pixels_into(0, 0, 1, 1, rgba, unsigned_byte, mut data, 0, 1)
	assert data[..16] == []u8{len: 16, init: 55}
	assert data[16..20] == [u8(0), 255, 0, 255]
	assert data[20..] == []u8{len: 4, init: 55}
	assert context.get_error() == no_error
}
