module cpuraster

fn test_copy_raster_rectangle_preserves_padded_rows() {
	for size in [[7, 1]!, [1023, 1025]!, [1024, 1024]!, [1025, 1027]!] {
		w, h := size[0], size[1]
		row_bytes := w * 4
		source_pitch := row_bytes + 8
		target_pitch := row_bytes + 13
		source_start := source_pitch + 4
		target_start := 3
		source := []u8{len: source_pitch * (h + 2), init: u8(index * 83 + index / 31)}
		mut target := []u8{len: target_start + target_pitch * h + 5, init: 0xa5}
		mut expected := target.clone()
		for y in 0 .. h {
			src := source_start + y * source_pitch
			dst := target_start + y * target_pitch
			copy(mut expected[dst..dst + row_bytes], source[src..src + row_bytes])
		}
		copy_raster_rectangle(source[source_start..], mut target[target_start..], source_pitch,
			target_pitch, row_bytes, h)
		matches := target == expected
		assert matches
	}
}
