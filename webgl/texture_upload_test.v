module webgl

fn test_texture_export_format_accepts_webgl1_bitmap_layouts() {
	assert texture_export_format(rgb, unsigned_byte)? == .rgb888
	assert texture_export_format(rgb, unsigned_short_5_6_5)? == .rgb565
	assert texture_export_format(rgba, unsigned_byte)? == .rgba8888
	assert texture_export_format(rgba, unsigned_short_4_4_4_4)? == .rgba4444
	assert texture_export_format(rgba, unsigned_short_5_5_5_1)? == .rgba5551
	assert texture_export_format(alpha, unsigned_byte)? == .alpha8
	assert texture_export_format(luminance, unsigned_byte)? == .gray8
	assert texture_export_format(luminance_alpha, unsigned_byte) == none
	assert texture_export_format(rgb, gl_float) == none
}

fn test_texture_upload_size_accounts_for_components_packing_and_alignment() {
	default_state := PixelUnpackState{}
	assert required_2d_texture_data_size(3, 2, rgba, unsigned_byte, default_state)? == 24
	assert required_2d_texture_data_size(3, 2, rgb, unsigned_byte, default_state)? == 21
	assert required_2d_texture_data_size(3, 2, rgba, unsigned_short_4_4_4_4, default_state)? == 14
	assert required_2d_texture_data_size(2, 2, rg, gl_float, default_state)? == 32

	offset_state := PixelUnpackState{
		alignment: 8
		row_length: 5
		skip_pixels: 1
		skip_rows: 2
	}
	assert required_2d_texture_data_size(3, 2, red, unsigned_byte, offset_state)? == 28
}

fn test_texture_upload_size_rejects_invalid_and_overflowing_state() {
	assert is_valid_2d_pixel_unpack_state(-1, PixelUnpackState{})
	assert !is_valid_2d_pixel_unpack_state(3, PixelUnpackState{
		row_length: 4
		skip_pixels: 2
	})
	assert !is_valid_2d_pixel_unpack_state(1, PixelUnpackState{
		row_length: max_u64
		skip_pixels: max_u64
	})
	assert required_2d_texture_data_size(-1, 1, rgba, unsigned_byte, PixelUnpackState{}) == none
	assert required_2d_texture_data_size(1, -1, rgba, unsigned_byte, PixelUnpackState{}) == none
	assert required_2d_texture_data_size(0, 1, GLenum(0), GLenum(0), PixelUnpackState{})? == 0
	assert required_2d_texture_data_size(1, 1, GLenum(0), GLenum(0), PixelUnpackState{}) == none
	assert required_2d_texture_data_size(1, 1, rgba, unsigned_byte, PixelUnpackState{
		alignment: 3
	}) == none
	assert required_2d_texture_data_size(1, 2, rgba, unsigned_byte, PixelUnpackState{
		skip_rows: max_u64
	}) == none
}

fn test_context_2d_upload_uses_webgl2_unpack_state_and_exact_prefix() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	context.native.set_native_call_recording(true)
	context.pixel_storei(unpack_row_length, 4)
	context.tex_image2d(texture_2d, 0, rgba, 3, 2, 0, rgba, unsigned_byte, []u8{len: 64})
	calls := context.native.native_calls()
	assert calls.last().name == 'tex_image2d'
	assert calls.last().args.last() == 28

	context.pixel_storei(unpack_skip_pixels, 2)
	before := context.native.native_calls().len
	context.tex_image2d(texture_2d, 0, rgba, 3, 2, 0, rgba, unsigned_byte, []u8{len: 64})
	assert context.get_error() == invalid_operation
	assert context.native.native_calls().len == before
}
