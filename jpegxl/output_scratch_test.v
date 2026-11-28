module jpegxl

import platform

fn test_output_dither_cache_survives_a_released_decode_scope() {
	input := []f32{len: 1024, init: .5}
	mut expected := []u8{}
	mut first := platform.begin_thread_scratch('JPEG XL first output')
	row := quantize_output_row(input, 0, 0, 0, 8)!
	persistent := platform.enter_persistent()
	expected = row.clone()
	platform.leave_persistent(persistent)
	first.finish()
	for _ in 0 .. 3 {
		mut next := platform.begin_thread_scratch('JPEG XL reused output')
		filler := []u8{len: 1024 * 1024, init: 0xa5}
		actual := quantize_output_row(input, 0, 0, 0, 8)!
		assert filler[0] == 0xa5
		assert actual == expected
		next.finish()
	}
}
