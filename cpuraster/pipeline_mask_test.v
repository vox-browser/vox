module cpuraster

fn test_pipeline_mask_rows_match_ordered_blits() {
	w, h := 1037, 523
	pitch := w * 4 + 13
	clip := IRect{2, 3, w - 4, h - 3}
	seed := []u8{len: pitch * h, init: u8(index * 17 + index / 359)}
	gradient := make_linear(Point{2, 1}, Point{830, 490},
		[[f32(0.2), 0.3, 0.5, 0.8]!, [f32(0.7), 0.3, 0.1, 0.6]!], []f32{},
		Matrix{1, 0, 0, 1, 0, 0}, .pad).gradient
	for source_pitch in [w + 11, 0] {
		mask := Mask{
			bounds:    IRect{0, 0, w, h}
			offset:    7
			row_bytes: source_pitch
			image:     []u8{len: 7 + (h - 1) * source_pitch + w, init: u8(index * 83 + index / 31)}
		}
		for mode in [BlendMode.multiply, .src_over, .soft_light] {
			mut actual := seed.clone()
			mut expected := seed.clone()
			mut candidate := if mode == .multiply {
				new_pipeline_blitter(mut actual, pitch, 0xad306ba1, 0.67, mode)
			} else {
				new_gradient_blitter(mut actual, pitch, gradient, 0.67, mode)
			}
			mut reference := unsafe { candidate }
			reference.pixels = unsafe { expected }
			candidate.blit_mask(&mask, clip)
			for y in clip.top .. clip.bottom {
				reference.blit_mask(&mask, IRect{clip.left, y, clip.right, y + 1})
			}
			matches := actual == expected
			changed := actual != seed
			assert matches
			assert changed
		}
	}
}

fn test_pipeline_mask_preserves_order_when_coverage_shares_target() {
	w, h := 512, 513
	pitch := w * 4
	bounds := IRect{0, 0, w, h}
	mut actual := []u8{len: pitch * h, init: u8(index * 37 + index / 101)}
	mut expected := actual.clone()
	actual_mask := Mask{ bounds: bounds, image: actual }
	expected_mask := Mask{ bounds: bounds, image: expected }
	assert actual_mask.image.data == actual.data
	assert expected_mask.image.data == expected.data
	mut candidate := new_pipeline_blitter(mut actual, pitch, 0xad306ba1, 0.67, .multiply)
	mut reference := new_pipeline_blitter(mut expected, pitch, 0xad306ba1, 0.67, .multiply)
	candidate.blit_mask(&actual_mask, bounds)
	for y in 0 .. h {
		reference.blit_mask(&expected_mask, IRect{0, y, w, y + 1})
	}
	matches := actual == expected
	assert matches
}
