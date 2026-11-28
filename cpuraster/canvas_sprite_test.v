module cpuraster

fn test_sprite_rect_matches_ordered_rows_with_clipped_origins_and_padding() {
	h := 1025
	for w in [1031, 1032] {
		pitch := (w + 7) * 4 + 13
		source_pitch := (w + 4) * 4 + 11
		bitmap := CanvasBitmap{
			pixels:        []u8{len: source_pitch * (h + 2), init: u8(index * 83 + index / 31)}
			width:         w + 4
			height:        h + 2
			pitch:         source_pitch
			premultiplied: true
		}
		seed := []u8{len: pitch * (h + 3), init: u8(index * 17 + index / 359)}
		for alpha in [u32(0), 141, 255] {
			mut actual := seed.clone()
			mut expected := seed.clone()
			mut candidate := SpriteBlitter{
				source:    bitmap
				left:      1
				top:       2
				row_bytes: pitch
				copy:      alpha == 0
				alpha:     alpha
				pixels:    actual
			}
			mut reference := SpriteBlitter{
				...candidate
				pixels: expected
			}
			candidate.blit_rect(3, 3, w, h)
			for y in 3 .. 3 + h {
				reference.blit_rect(3, y, w, 1)
			}
			changed := actual != seed
			matches := actual == expected
			assert changed
			assert matches
		}
	}
}

fn test_sprite_rect_preserves_read_order_when_backings_overlap() {
	w, h := 1025, 1025
	pitch := (w + 2) * 4
	seed := []u8{len: pitch * (h + 1), init: u8(index * 37 + index / 101)}
	for copy_source in [false, true] {
		mut actual := seed.clone()
		mut expected := seed.clone()
		actual_source := CanvasBitmap{
			pixels:        actual
			width:         w + 2
			height:        h + 1
			pitch:         pitch
			premultiplied: true
		}
		expected_source := CanvasBitmap{
			...actual_source
			pixels: expected
		}
		assert actual_source.pixels.data == actual.data
		assert expected_source.pixels.data == expected.data
		mut candidate := SpriteBlitter{
			source:    actual_source
			left:      1
			top:       1
			row_bytes: pitch
			copy:      copy_source
			alpha:     141
			pixels:    actual
		}
		mut reference := SpriteBlitter{
			...candidate
			source: expected_source
			pixels: expected
		}
		candidate.blit_rect(1, 1, w, h)
		for y in 1 .. 1 + h {
			reference.blit_rect(1, y, w, 1)
		}
		matches := actual == expected
		assert matches
	}
}
