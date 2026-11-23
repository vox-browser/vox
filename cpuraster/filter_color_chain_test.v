module cpuraster

fn test_canvas_color_chain_resets_transparent_color_before_lookup() {
	matrix := CanvasColorStage{
		matrix: [f32(.5), 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0]!
	}
	mut channels := [4][]u8{}
	channels[0] = []u8{len: 256}
	channels[0][128] = 64
	channels[3] = []u8{len: 256, init: 153}
	table := CanvasColorStage{channels: channels, is_table: true}
	for linear_rgb in [false, true] {
		source := [u8(255), 0, 0, 255, 0, 0, 255, 255, 0, 0, 0, 0]
		mut pixels := source.clone()
		assert apply_canvas_color_chain_in_place(mut pixels, 3, 1, [matrix, table], linear_rgb)
		assert pixels == [if linear_rgb { u8(82) } else { u8(38) }, 0, 0, 153,
			0, 0, 0, 153, 0, 0, 0, 153]
		pixels = source.clone()
		assert apply_canvas_color_chain_in_place(mut pixels, 3, 1, [table, matrix], linear_rgb)
		assert pixels == []u8{len: pixels.len}
	}
}

fn test_canvas_color_chain_leaves_unspecified_channels_at_matrix_precision() {
	first := CanvasColorStage{
		matrix: [f32(.001), 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0]!
	}
	second := CanvasColorStage{
		matrix: [f32(1000), 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0]!
	}
	mut pixels := [u8(255), 0, 0, 255]
	assert apply_canvas_color_chain_in_place(mut pixels, 1, 1,
		[first, CanvasColorStage{is_table: true}, second], false)
	assert pixels == [u8(255), 0, 0, 255]

	mut channels := [4][]u8{}
	channels[3] = [u8(0)]
	assert !apply_canvas_color_chain_in_place(mut pixels, 1, 1,
		[first, CanvasColorStage{channels: channels, is_table: true}], false)
	assert pixels == [u8(255), 0, 0, 255]
}
