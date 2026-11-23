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
		stages := [CanvasColorStage{...matrix, linear_rgb: linear_rgb},
			CanvasColorStage{...table, linear_rgb: linear_rgb}]
		mut pixels := source.clone()
		assert apply_canvas_color_chain_in_place(mut pixels, 3, 1, stages)
		assert pixels == [if linear_rgb { u8(82) } else { u8(38) }, 0, 0, 153,
			0, 0, 0, 153, 0, 0, 0, 153]
		pixels = source.clone()
		assert apply_canvas_color_chain_in_place(mut pixels, 3, 1, stages.reverse())
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
		[first, CanvasColorStage{is_table: true}, second])
	assert pixels == [u8(255), 0, 0, 255]

	mut channels := [4][]u8{}
	channels[3] = [u8(0)]
	assert !apply_canvas_color_chain_in_place(mut pixels, 1, 1,
		[first, CanvasColorStage{channels: channels, is_table: true}])
	assert pixels == [u8(255), 0, 0, 255]
}

fn test_canvas_color_chain_converts_straight_rgb_between_stages() {
	half := CanvasColorStage{
		matrix: [f32(.5), 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0]!
	}
	scale := CanvasColorStage{
		matrix: [f32(.75), 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0]!
	}
	source := [u8(255), 0, 0, 255, 128, 0, 0, 128]
	mut pixels := source.clone()
	assert apply_canvas_color_chain_in_place(mut pixels, 2, 1,
		[half, CanvasColorStage{...half, linear_rgb: true}, scale])
	assert pixels == [u8(69), 0, 0, 255, 35, 0, 0, 128]

	mut channels := [4][]u8{}
	channels[0] = []u8{len: 256}
	channels[0][55] = 64
	pixels = source.clone()
	assert apply_canvas_color_chain_in_place(mut pixels, 2, 1,
		[half, CanvasColorStage{channels: channels, is_table: true, linear_rgb: true}])
	assert pixels == [u8(137), 0, 0, 255, 69, 0, 0, 128]
}
