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

fn test_canvas_opacity_layer_band_restores_only_its_rows() {
	width, rows, height := 7, 3, 9
	first := 2
	pitch := width * 4 + 12
	mut source := []u8{len: pitch * height}
	for y in first .. first + rows {
		for x in 0 .. width {
			offset := y * pitch + x * 4
			alpha := u8(17 * x + 37 * y)
			source[offset] = alpha
			source[offset + 1] = alpha / 2
			source[offset + 3] = alpha
		}
	}
	full := CanvasBitmap{
		pixels:        source
		width:         width
		height:        height
		pitch:         pitch
		premultiplied: true
	}
	band := CanvasBitmap{ ...full, pixels: source[first * pitch..], height: rows }
	seed := []u8{len: pitch * height, init: u8(index * 23 + index / 5)}
	rect := [f32(0), 0, f32(width), f32(height)]!
	for opacity in [f32(0.125), 0.5, 1] {
		mut expected := seed.clone()
		mut actual := seed.clone()
		assert draw_canvas_image(mut expected, width, height, pitch, 2,
			[f32(1), 0, 0, 1, 0, 0]!, full, rect, rect, false, opacity, .src_over, [])
		assert restore_canvas_opacity_layer(mut actual, pitch, height, first, band, opacity)
		assert actual == expected
		assert actual[..first * pitch] == seed[..first * pitch]
		assert actual[(first + rows) * pitch..] == seed[(first + rows) * pitch..]

		mut lowp := seed.clone()
		mut pipeline := seed.clone()
		assert draw_canvas_image_sampled(mut pipeline, width, height, pitch, 2,
			[f32(1), 0, 0, 1, 0, 0]!, full, rect, rect, false, opacity, .src_over, [], false,
			false)
		mut lowp_rows := lowp[first * pitch..]
		assert restore_lowp_canvas_layer(mut lowp_rows, pitch, band, opacity)
		assert lowp == pipeline
	}

	mut target := seed.clone()
	assert !restore_canvas_opacity_layer(mut target, pitch, first + rows - 1, first, band, 0.5)
	assert !restore_canvas_opacity_layer(mut target, pitch, 8192, first, band, 0.5)
	assert !restore_canvas_opacity_layer(mut target, pitch, height, -1, band, 0.5)
	assert target == seed
}

fn test_canvas_mask_path_band_uses_original_geometry_and_shader_coordinates() {
	width, height := 41, 151
	pitch := width * 4 + 12
	first, end := 73, 113
	mut builder := PathBuilder{}
	builder.move_to(-0.375, 0.125)
	builder.line_to(22.5, 1.25)
	builder.line_to(33.1875, 11.75)
	builder.line_to(5.25, 31.125)
	builder.close()
	path := builder.detach()
	matrices := [
		[f32(0.97), -0.125, 0.1875, 0.9, -4.625, 80.25]!,
		[f32(0.72), -0.125, 0.1875, 0.7, -4.625, 80.25]!,
	]
	gradient := CanvasGradient{
		kind:            1
		x0:              3.75
		y0:              1.25
		x1:              27.5
		y1:              24.125
		stops:           [f32(0), 0.923, 0.183, 0.095, 0.937, 0.73, 0.11, 0.81, 0.076, 0.38, 1,
			0.552, 0.29, 0.916, 0.97]
		local_transform: [f32(0.875), 0.125, -0.0625, 0.93, 2.125, -1.25]!
	}
	seed := []u8{len: height * pitch, init: u8(index * 23 + index / 113)}
	for matrix in matrices {
		for legacy in [false, true] {
			mut full := seed.clone()
			mut band := seed[first * pitch..end * pitch].clone()
			for use_gradient in [false, true] {
				mut style := ?CanvasPaintStyle(none)
				if use_gradient {
					style = CanvasPaintStyle(gradient)
				}
				assert fill_canvas_path_surface(mut full, width, height, pitch, 2, path, matrix,
					0xb7ea25a9, style, 0.63, .src_over, 0, [], none, legacy)
				assert fill_canvas_mask_path_surface(mut band, width, first, end - first, pitch,
					path, matrix, 0xb7ea25a9, style, 0.63, legacy)
				assert band == full[first * pitch..end * pitch]
				assert full[..first * pitch] == seed[..first * pitch]
				assert full[end * pitch..] == seed[end * pitch..]
			}
			assert band != seed[first * pitch..end * pitch]
		}
	}
}
