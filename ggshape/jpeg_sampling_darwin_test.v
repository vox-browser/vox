// vtest build: macos
module ggshape

fn test_full_range_jpeg_filters_chroma_before_color_conversion() {
	source := [u8(128), 0, 0, 255, 128, 255, 255, 255, 128, 0, 0, 255, 128, 255, 255, 255]
	for samples in [1, 4] {
		mut pixels := []u8{len: 8 * 8 * 4, init: 255}
		assert draw_sampled_jpeg_clipped(pixels.data, 8, 8, 32, 1, source, 2, 2,
			2, 2, 1, 1, samples, 2, 2, [12]f32{}) == 1
		assert pixels[(2 * 8 + 2) * 4..(2 * 8 + 2) * 4 + 4] == [u8(127), 129, 127, 255]
		assert pixels[..4] == [u8(255), 255, 255, 255]
	}
}

fn test_full_range_jpeg_keeps_cpu_mip_weights_for_odd_planes() {
	mut source := []u8{len: 3 * 3 * 4, init: if index % 4 == 3 { u8(255) } else if index % 4 == 0 { u8(0) } else { u8(128) }}
	source[(1 * 3 + 1) * 4] = 255
	for samples in [1, 4] {
		mut pixels := []u8{len: 8 * 8 * 4, init: 255}
		assert draw_sampled_jpeg_clipped(pixels.data, 8, 8, 32, 1, source, 3, 3,
			2, 2, 1, 1, samples, 3, 3, [12]f32{}) == 1
		// CPU 1:2:1 weights give 63; a GPU linear mip would sample 255.
		assert pixels[(2 * 8 + 2) * 4..(2 * 8 + 2) * 4 + 4] == [u8(63), 63, 63, 255]
	}
}

fn test_full_range_jpeg_rejects_incomplete_or_translucent_uploads() {
	mut pixels := []u8{len: 64, init: 83}
	for source in [[u8(128)], [u8(128), 128, 128, 0]] {
		assert draw_sampled_jpeg_clipped(pixels.data, 4, 4, 16, 1, source, 1, 1,
			0, 0, 1, 1, 1, 1, 1, [12]f32{}) == 0
		assert pixels.all(it == 83)
	}
}
