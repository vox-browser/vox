module cpuraster

fn test_lowp_canvas_layer_restore_matches_image_replay_for_every_opacity_byte() {
	width, height := 257, 3
	source_pitch := width * 4 + 12
	target_pitch := width * 4 + 16
	mut source := []u8{len: source_pitch * height, init: 0xe5}
	for y in 0 .. height {
		for x in 0 .. width {
			offset := y * source_pitch + x * 4
			alpha := u32(x % 256)
			source[offset] = u8(alpha * u32(y + 1) / 3)
			source[offset + 1] = u8(alpha / 2)
			source[offset + 2] = u8(alpha)
			source[offset + 3] = u8(alpha)
		}
	}
	image := CanvasBitmap{
		pixels:        source
		width:         width
		height:        height
		pitch:         source_pitch
		premultiplied: true
	}
	seed := []u8{len: target_pitch * height, init: u8(index * 7 + index / 11)}
	rect := [f32(0), 0, f32(width), f32(height)]!
	for level in 0 .. 256 {
		opacity := if level == 255 { f32(1) } else { (f32(level) + 0.5) / 255 }
		mut expected := seed.clone()
		mut actual := seed.clone()
		assert draw_canvas_image_sampled(mut expected, width, height, target_pitch, 2,
			[f32(1), 0, 0, 1, 0, 0]!, image, rect, rect, false, opacity, .src_over, [], false,
			false)
		assert restore_lowp_canvas_layer(mut actual, target_pitch, image, opacity)
		assert actual == expected
	}
}

fn test_lowp_canvas_layer_restore_matches_image_replay_with_workers() {
	width, height := 1051, 333
	pitch := (width + 2) * 4
	source := []u8{len: pitch * height, init: u8(index / 4 * 113 + index / 101)}
	image := CanvasBitmap{ pixels: source, width: width, height: height, pitch: pitch, premultiplied: true }
	mut actual := []u8{len: pitch * height, init: u8(index * 37 + index / 97)}
	mut expected := actual.clone()
	rect := [f32(0), 0, f32(width), f32(height)]!
	assert draw_canvas_image_sampled(mut expected, width, height, pitch, 2,
		[f32(1), 0, 0, 1, 0, 0]!, image, rect, rect, false, 0.625, .src_over, [], false,
		false)
	assert restore_lowp_canvas_layer(mut actual, pitch, image, 0.625)
	assert actual == expected
}

fn test_lowp_canvas_layer_restore_declines_incompatible_backings() {
	mut pixels := []u8{len: 44, init: 0x80}
	before := pixels.clone()
	image := CanvasBitmap{
		pixels:        pixels
		width:         4
		height:        2
		pitch:         20
		premultiplied: true
	}
	assert !restore_lowp_canvas_layer(mut pixels, 20, image, 0.5)
	separate := CanvasBitmap{ ...image, pixels: before }
	assert !restore_lowp_canvas_layer(mut pixels, 20, CanvasBitmap{ ...separate, display_p3: true }, 0.5)
	assert !restore_lowp_canvas_layer(mut pixels, 20, CanvasBitmap{ ...separate, premultiplied: false }, 0.5)
	assert !restore_lowp_canvas_layer(mut pixels, 20, CanvasBitmap{ ...separate, pitch: 17 }, 0.5)
	assert !restore_lowp_canvas_layer(mut pixels, 16, CanvasBitmap{ ...separate, height: 3 }, 0.5)
	assert pixels == before
}
