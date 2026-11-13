// vtest build: macos
module ggshape

fn test_short_rounded_shadow_filters_when_no_nine_patch_fits() {
	for height in [f32(40), 100] {
		shape := C.VoxGraphiteShape{
			matrix: [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
			rect: [f32(48), 48, 220, height, 6, 6, 6, 6, 0, 0, 0, 0]!
			underlay_rect: [f32(48), 48, 220, height, 6, 6, 6, 6, 0, 0, 0, 0]!
			fill: 10
			thickness: 60
			anti_alias: 1
			has_float_color: 1
			float_color: [f32(.4), .6, .8, .5]!
		}
		mut pixels := []u8{len: 320*240*4}
		assert draw(pixels.data, 320, 240, 320*4, 0, &shape) == 1
		assert pixels[(40*320+140)*4+3] > 0
		assert pixels[(60*320+140)*4+3] == 0
		assert pixels[(239*320+319)*4+3] == 0
	}
}
