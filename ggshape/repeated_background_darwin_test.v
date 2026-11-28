// vtest build: macos
module ggshape

import stbi

fn test_repeated_sprite_and_border_match_the_unchanged_brave_corner_pixels() {
	assert_repeated_sprite_reference(4, $embed_file('@VMODROOT/Tests/Browser/Brave/expected/rounded-repeated-sprite-border.png').to_bytes(), 1)
}

fn test_repeated_sprite_matches_brave_without_a_multisample_trigger() {
	assert_repeated_sprite_reference(1, $embed_file('@VMODROOT/Tests/Browser/Brave/expected/rounded-repeated-sprite-border-single-sample.png').to_bytes(), 1)
}

fn test_repeated_sprite_above_the_worker_cutoff_matches_brave() {
	// Stacking two copies preserves the repeated image and doubles the work.
	assert_repeated_sprite_reference(4, $embed_file('@VMODROOT/Tests/Browser/Brave/expected/rounded-repeated-sprite-border.png').to_bytes(), 2)
}

fn assert_repeated_sprite_reference(samples int, expected_bytes []u8, copies int) {
	bytes := $embed_file('@VMODROOT/Tests/Browser/Brave/resources/reddit-ui-sprite.png').to_bytes()
	image := stbi.load_from_memory(bytes.data, bytes.len, desired_channels: 4) or { panic(err) }
	defer { image.free() }
	expected := stbi.load_from_memory(expected_bytes.data, expected_bytes.len, desired_channels: 4) or { panic(err) }
	defer { expected.free() }
	border := repeated_sprite_test_border()
	clip := [f32(719), 186, 35, 16, 3, 3, 3, 3, 3, 3, 3, 3]!
	original := unsafe { image.data.vbytes(image.width * image.height * 4) }
	source := if copies > 1 {
		mut stacked := []u8{len: original.len * copies}
		for i in 0 .. copies {
			copy(mut stacked[i * original.len..(i + 1) * original.len], original)
		}
		stacked
	} else {
		original
	}
	mut pixels := []u8{len: 1024 * 256 * 4, init: 255}
	assert draw_repeated_background(pixels.data, 1024, 256, 4096, source, image.width, image.height * copies,
		720, 187, clip, samples, [u8(255), 255, 255, 255]!, &border)
	for y in 0 .. 256 {
		for x in 0 .. 1024 {
			i := (y * 1024 + x) * 4
			if x < 719 || x >= 754 || y < 186 || y >= 202 {
				assert pixels[i..i + 4] == [u8(255), 255, 255, 255]
			} else if !(x >= 725 && x < 748 && y >= 188 && y < 201) {
				// The engine paints the label later; retain every decoration edge pixel.
				assert pixels[i..i + 4] == unsafe {
					[expected.data[i + 2], expected.data[i + 1], expected.data[i],
						expected.data[i + 3]]
				}
			}
		}
	}
}

fn test_repeated_background_rejects_unsupported_input_without_modifying_the_backdrop() {
	mut pixels := []u8{len: 16 * 16 * 4, init: 147}
	before := pixels.clone()
	border := repeated_sprite_test_border()
	clip := [f32(0), 0, 16, 16, 3, 3, 3, 3, 3, 3, 3, 3]!
	assert !draw_repeated_background(pixels.data, 16, 16, 64, [u8(0)], 140, 1751, 0, 0, clip, 4, [
		u8(255),
		255,
		255,
		255,
	]!, &border)
	assert pixels == before
	assert !draw_repeated_background(pixels.data, 16, 16, 64, []u8{len: 4}, 1, 1, 0, 0, clip, 2, [
		u8(255),
		255,
		255,
		255,
	]!, &border)
	assert pixels == before
}

fn repeated_sprite_test_border() C.VoxGraphiteShape {
	return C.VoxGraphiteShape{
		matrix:     [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
		rect:       [f32(719.5), 186.5, 34, 15, 2.5, 2.5, 2.5, 2.5, 2.5, 2.5, 2.5, 2.5]!
		thickness:  1
		fill:       0
		anti_alias: 1
		force_msaa: 1
		red:        68
		green:      68
		blue:       68
		alpha:      255
	}
}
