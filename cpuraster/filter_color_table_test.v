module cpuraster

fn test_canvas_color_table_maps_straight_channels_and_alpha() {
	mut channels := [4][]u8{}
	channels[0] = []u8{len: 256, init: u8(index)}
	channels[0][0] = 255
	channels[0][128] = 64
	channels[3] = []u8{len: 256}
	channels[3][0] = 102
	channels[3][128] = 153
	mut pixels := [u8(0), 0, 0, 0, 64, 128, 0, 128, 0, 0, 255, 255]
	assert apply_canvas_color_tables_in_place(mut pixels, 3, 1, [channels], false)
	assert pixels == [u8(102), 0, 0, 102, 38, 153, 0, 153, 0, 0, 0, 0]
}

fn test_canvas_color_table_rounds_in_linear_space_before_encoding() {
	mut channels := [4][]u8{}
	channels[0] = []u8{len: 256}
	channels[0][55] = 128
	mut pixels := [u8(128), 0, 0, 255, 64, 0, 0, 128]
	assert apply_canvas_color_tables_in_place(mut pixels, 2, 1, [channels], true)
	assert pixels == [u8(188), 0, 0, 255, 94, 0, 0, 128]

	channels[1] = [u8(0)]
	assert !apply_canvas_color_tables_in_place(mut pixels, 2, 1, [channels], true)
	assert pixels == [u8(188), 0, 0, 255, 94, 0, 0, 128]
}

fn test_canvas_color_table_chain_restores_alpha_from_transparent_black() {
	mut first := [4][]u8{}
	first[0] = []u8{len: 256, init: u8(102)}
	first[3] = []u8{len: 256, init: u8(index)}
	first[3][128] = 0
	mut second := [4][]u8{}
	second[0] = []u8{len: 256}
	second[0][0] = 64
	second[0][102] = 204
	second[3] = []u8{len: 256, init: u8(153)}
	mut third := [4][]u8{}
	third[0] = []u8{len: 256, init: u8(index)}
	third[0][64] = 85
	third[0][204] = 170
	mut pixels := [u8(255), 0, 0, 255, 128, 0, 0, 128, 0, 0, 0, 0]
	assert apply_canvas_color_tables_in_place(mut pixels, 3, 1, [first, second, third], false)
	assert pixels == [u8(102), 0, 0, 153, 51, 0, 0, 153, 51, 0, 0, 153]
}
