// vtest build: macos
module ggshape

fn test_rotated_ellipse_blur_matches_the_equivalent_axis_aligned_ellipse() {
	base := C.VoxGraphiteShape{
		matrix: [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
		rect: [f32(96), 32, 96, 160, 48, 80, 48, 80, 48, 80, 48, 80]!
		underlay_rect: [f32(96), 32, 96, 160, 48, 80, 48, 80, 48, 80, 48, 80]!
		fill: 10
		thickness: 12
		anti_alias: 1
		has_float_color: 1
		float_color: [f32(.2), .4, .8, .3]!
	}
	rotated := C.VoxGraphiteShape{
		...base
		matrix: [f32(0), -1, 240, 1, 0, 0, 0, 0, 1]!
		rect: [f32(32), 48, 160, 96, 80, 48, 80, 48, 80, 48, 80, 48]!
		underlay_rect: [f32(32), 48, 160, 96, 80, 48, 80, 48, 80, 48, 80, 48]!
	}
	mut expected := []u8{len: 320*320*4}
	mut actual := expected.clone()
	assert draw(expected.data, 320, 320, 320*4, 0, &base) == 1
	assert draw(actual.data, 320, 320, 320*4, 0, &rotated) == 1
	mut visible := 0
	for i in 0 .. expected.len {
		assert actual[i] == expected[i], 'channel=${i}'
		if i % 4 == 3 && expected[i] > 0 { visible++ }
	}
	assert visible > 1000
	assert actual[(100*320 + 144)*4 + 3] == 0
}

fn test_rotated_shadow_rejects_anisotropic_and_sheared_kernels() {
	base := C.VoxGraphiteShape{
		rect: [f32(32), 48, 160, 96, 80, 48, 80, 48, 80, 48, 80, 48]!
		thickness: 12
	}
	for matrix in [[f32(1), .1, 0, 0, 1, 0, 0, 0, 1]!,
		[f32(0), -2, 0, 1, 0, 0, 0, 0, 1]!] {
		shape := C.VoxGraphiteShape{...base, matrix: matrix}
		if _ := shadow_filter_scale(&shape) { assert false }
	}
}
