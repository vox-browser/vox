// vtest build: macos
module ggshape

fn test_shadowed_image_converts_only_the_source_and_preserves_destination_shadow_color() {
	clip := [f32(2), 2, 4, 4, 2, 2, 2, 2, 2, 2, 2, 2]!
	shadow := C.VoxGraphiteShape{
		matrix: [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
		rect: [f32(1), 1, 6, 6, 3, 3, 3, 3, 3, 3, 3, 3]!
		underlay_rect: clip
		fill: 9
		anti_alias: 1
		red: 255
		green: 255
		alpha: 255
	}
	mut pixels := [u8(255), 255, 255, 255].repeat(64)
	swap_rb := [f32(0), 0, 1, 0, 1, 0, 1, 0, 0]!
	assert draw_sampled_srgb_gamut_with_shadow(pixels.data, 8, 8, 32, 1,
		[u8(255), 0, 0, 255].repeat(4), 2, 2, 2, 2, 4, 4, 4, 2, 2,
		clip, false, swap_rb, &shadow) == 1
	// The opaque source is blue after the gamut swap. The yellow shadow
	// already belongs to the destination and must retain red and green.
	assert pixels[(3 * 8 + 3) * 4..(3 * 8 + 3) * 4 + 4] == [u8(255), 0, 0, 255]
	border := (1 * 8 + 3) * 4
	assert pixels[border] < 255
	assert pixels[border + 1] == 255 && pixels[border + 2] == 255
	assert pixels[..4] == [u8(255), 255, 255, 255]
}
