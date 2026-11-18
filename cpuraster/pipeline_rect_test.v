module cpuraster

fn test_pipeline_rect_matches_ordered_gradient_and_image_rows() {
	w, h := 1037, 523
	pitch := (w + 5) * 4 + 12
	source_pitch := 521 * 4 + 8
	bitmap := CanvasBitmap{
		pixels:        []u8{len: source_pitch * 269, init: u8(index * 83 + index / 31)}
		width:         521
		height:        269
		pitch:         source_pitch
		premultiplied: true
	}
	shader := new_image_shader(bitmap, .clamp, .clamp, true,
		SkAffine{ sx: 1.95, sy: 1.99, tx: 1.2, ty: 2.3 }).image
	mipmap := ImageShader{
		...shader
		mipmap_linear: true
		lower:         &ImageShader{ ...shader, mipmap_linear: true }
		lower_weight:  0.5
		lower_scale_x: 0.5
		lower_scale_y: 0.5
	}
	gradient := make_linear(Point{2, 1}, Point{830, 490},
		[[f32(0.2), 0.3, 0.5, 0.8]!, [f32(0.7), 0.3, 0.1, 0.6]!], []f32{},
		Matrix{1, 0, 0, 1, 0, 0}).gradient
	seed := []u8{len: pitch * (h + 4), init: u8(index * 17 + index / 359)}
	for kind in 0 .. 4 {
		mut actual := seed.clone()
		mut expected := seed.clone()
		mut candidate := if kind == 0 {
			new_gradient_blitter(mut actual, pitch, gradient, 1, .src_over)
		} else {
			mode := if kind == 1 { BlendMode.src_over } else { BlendMode.soft_light }
			new_image_blitter(mut actual, pitch, if kind == 3 { mipmap } else { shader },
				0.83, mode)
		}
		mut reference := unsafe { candidate }
		reference.pixels = unsafe { expected }
		candidate.blit_rect(3, 2, w, h)
		for y in 2 .. 2 + h {
			reference.blit_rect(3, y, w, 1)
		}
		matches := actual == expected
		changed := actual != seed
		assert matches
		assert changed
	}
}

fn test_pipeline_rect_preserves_read_order_for_aliased_mipmap_levels() {
	w, h := 512, 513
	pitch := (w + 3) * 4
	seed := []u8{len: pitch * (h + 3), init: u8(index * 37 + index / 101)}
	for lower_alias in [false, true] {
		mut actual := seed.clone()
		mut expected := seed.clone()
		actual_shader := rect_test_alias_shader(actual, seed, w, h, pitch, lower_alias)
		expected_shader := rect_test_alias_shader(expected, seed, w, h, pitch, lower_alias)
		aliased := if lower_alias { actual_shader.lower.pixels } else { actual_shader.pixels }
		assert aliased.data == actual.data
		mut candidate := new_image_blitter(mut actual, pitch, actual_shader, 1, .src)
		mut reference := new_image_blitter(mut expected, pitch, expected_shader, 1, .src)
		assert !candidate.rect_rows_independent(2, 2, w, h)
		candidate.blit_rect(2, 2, w, h)
		for y in 2 .. 2 + h {
			reference.blit_rect(2, y, w, 1)
		}
		matches := actual == expected
		assert matches
	}
}

fn rect_test_alias_shader(target []u8, source []u8, w int, h int, pitch int, lower_alias bool) ImageShader {
	bitmap := CanvasBitmap{
		pixels:        source
		width:         w
		height:        h
		pitch:         pitch
		premultiplied: true
	}
	base := new_image_shader(CanvasBitmap{
		...bitmap
		pixels: if lower_alias {
			source
		} else {
			target
		}
	},
		.clamp, .clamp, false, affine_translate(1, 1)).image
	lower := new_image_shader(CanvasBitmap{
		...bitmap
		pixels: if lower_alias {
			target
		} else {
			source
		}
	},
		.clamp, .clamp, false, affine_translate(1, 1)).image
	return ImageShader{
		...base
		mipmap_linear: true
		lower:         &ImageShader{ ...lower, mipmap_linear: true }
		lower_weight:  0.5
		lower_scale_x: 0.5
		lower_scale_y: 0.5
	}
}
