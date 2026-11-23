module cpuraster

fn test_canvas_color_filters_restrict_writes_to_strided_rows() {
	width, height, pitch, origin := 3, 2, 24, 28
	source := [u8(0), 0, 0, 0, 91, 55, 6, 120, 255, 8, 0, 255,
		94, 7, 8, 120, 0, 0, 0, 0, 1, 0, 2, 45]
	matrix := [f32(.5), 0, 0, 0, 0, 0, 1, 0, 0, 0,
		0, 0, 1, 0, .25, 0, 0, 0, 1, .25]!
	mut channels := [4][]u8{}
	channels[1] = []u8{len: 256, init: u8(255 - index)}
	channels[3] = []u8{len: 256, init: u8((index + 255) / 2)}
	chain := [CanvasColorStage{matrix: matrix, linear_rgb: true},
		CanvasColorStage{channels: channels, is_table: true}]
	for linear_rgb in [false, true] {
		for filter in 0 .. 3 {
			mut actual := []u8{len: pitch * 4, init: u8(137)}
			for y in 0 .. height {
				start := origin + y * pitch
				copy(mut actual[start..start + width * 4], source[y * width * 4..][..width * 4])
			}
			mut expected := actual.clone()
			mut packed := source.clone()
			mut visible := actual[origin..]
			match filter {
				0 {
					assert apply_canvas_color_matrices_in_place(mut packed, width, height, [matrix], linear_rgb)
					assert apply_canvas_color_matrices_in_place(mut visible, width, height,
						[matrix], linear_rgb, pitch: pitch)
				}
				1 {
					assert apply_canvas_color_tables_in_place(mut packed, width, height, [channels], linear_rgb)
					assert apply_canvas_color_tables_in_place(mut visible, width, height,
						[channels], linear_rgb, pitch: pitch)
				}
				else {
					assert apply_canvas_color_chain_in_place(mut packed, width, height, chain)
					assert apply_canvas_color_chain_in_place(mut visible, width, height, chain,
						pitch: pitch)
				}
			}
			for y in 0 .. height {
				start := origin + y * pitch
				copy(mut expected[start..start + width * 4], packed[y * width * 4..][..width * 4])
			}
			assert actual == expected
			assert actual[origin + 3] > 0
		}
	}
	mut invalid := source.clone()
	assert !apply_canvas_color_chain_in_place(mut invalid, width, height, chain, pitch: source.len)
	assert invalid == source
}

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
