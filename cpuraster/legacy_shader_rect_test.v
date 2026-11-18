module cpuraster

fn test_legacy_shader_rect_matches_ordered_rows() {
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
	seed := []u8{len: pitch * (h + 4), init: u8(index * 17 + index / 359)}
	for kind in 0 .. 3 {
		tile := if kind == 2 { TileMode.repeat } else { TileMode.clamp }
		transform := if kind == 2 {
			SkAffine{ sx: 1.95, sy: 1.99, kx: 0.18, ky: 0.04, tx: 1.2, ty: 2.3 }
		} else {
			SkAffine{ sx: 1.95, sy: 1.99, tx: 1.2, ty: 2.3 }
		}
		shader := new_image_shader(bitmap, tile, tile, kind != 0, transform).image
		state := legacy_image_context(shader, if kind == 0 { 255 } else { 211 }) or {
			panic('legacy context declined')
		}
		mut actual := seed.clone()
		mut expected := seed.clone()
		mut candidate := new_legacy_shader_blitter(mut actual, pitch, state)
		mut reference := new_legacy_shader_blitter(mut expected, pitch, state)
		candidate.blit_rect(3, 2, w, h)
		for y in 2 .. 2 + h {
			reference.blit_h(3, y, w)
		}
		matches := actual == expected
		changed := actual != seed
		assert matches
		assert changed
	}
}

fn test_legacy_shader_rect_preserves_order_for_aliased_bitmap() {
	w, h := 512, 513
	pitch := (w + 3) * 4
	mut actual := []u8{len: pitch * (h + 3), init: u8(index * 37 + index / 101)}
	mut expected := actual.clone()
	actual_state := legacy_rect_alias_state(actual, w, h, pitch)
	expected_state := legacy_rect_alias_state(expected, w, h, pitch)
	assert actual_state.pixels.data == actual.data
	assert expected_state.pixels.data == expected.data
	mut candidate := new_legacy_shader_blitter(mut actual, pitch, actual_state)
	mut reference := new_legacy_shader_blitter(mut expected, pitch, expected_state)
	candidate.blit_rect(2, 2, w, h)
	for y in 2 .. 2 + h {
		reference.blit_h(2, y, w)
	}
	matches := actual == expected
	assert matches
}

fn legacy_rect_alias_state(pixels []u8, w int, h int, pitch int) BitmapProcState {
	bitmap := CanvasBitmap{
		pixels:        pixels
		width:         w + 3
		height:        h + 3
		pitch:         pitch
		premultiplied: true
	}
	image := new_image_shader(bitmap, .clamp, .clamp, false, affine_translate(1, 1)).image
	return legacy_image_context(image, 255) or { panic('legacy context declined') }
}
