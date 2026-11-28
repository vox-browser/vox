module cpuraster

fn test_solid_mask_rows_match_checked_blits_for_clipped_and_repeated_coverage() {
	w, h := 1037, 523
	pitch := w * 4 + 13
	clip := IRect{2, 3, w - 4, h - 3}
	seed := []u8{len: pitch * h, init: u8(index * 17 + index / 359)}
	for source_pitch in [w + 11, 0] {
		mask := Mask{
			bounds:    IRect{0, 0, w, h}
			offset:    7
			row_bytes: source_pitch
			image:     []u8{len: 7 + (h - 1) * source_pitch + w, init: u8(index * 83 + index / 31)}
		}
		for color in [u32(0xff000000), 0xff307ba1, 0xad306ba1] {
			mut actual := seed.clone()
			mut expected := seed.clone()
			mut candidate := new_solid_blitter(mut actual, pitch, color)
			mut reference := new_solid_blitter(mut expected, pitch, color)
			candidate.blit_mask(&mask, clip)
			for y in clip.top .. clip.bottom {
				reference.blit_mask(&mask, IRect{clip.left, y, clip.right, y + 1})
			}
			matches := actual == expected
			assert matches
		}
	}
}

fn test_solid_mask_preserves_read_order_when_backings_overlap() {
	w, h := 512, 513
	pitch := w * 4
	bounds := IRect{0, 0, w, h}
	mut actual := []u8{len: pitch * h, init: u8(index * 37 + index / 101)}
	mut expected := actual.clone()
	actual_mask := Mask{ bounds: bounds, image: actual }
	expected_mask := Mask{ bounds: bounds, image: expected }
	assert actual_mask.image.data == actual.data
	assert expected_mask.image.data == expected.data
	mut candidate := new_solid_blitter(mut actual, pitch, 0xad306ba1)
	mut reference := new_solid_blitter(mut expected, pitch, 0xad306ba1)
	candidate.blit_mask(&actual_mask, bounds)
	for y in 0 .. h {
		reference.blit_mask(&expected_mask, IRect{0, y, w, y + 1})
	}
	matches := actual == expected
	assert matches
}
