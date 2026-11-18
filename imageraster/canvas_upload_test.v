module imageraster

import crypto.sha256

fn test_canvas_upload_converts_alpha_without_mutating_the_surface() {
	pixels := [u8(64), 32, 16, 128, 255, 1, 2, 255, 100, 20, 1, 0, 255, 1, 0, 128]
	original := pixels.clone()
	assert unpremultiply_canvas_rgba(pixels) == [u8(128), 64, 32, 128, 255, 1, 2, 255, 0, 0, 0, 0, 255, 2, 0, 128]
	assert pixels == original
	assert unpremultiply_canvas_rgba([u8(1), 2, 3]) == []u8{}
}

fn test_parallel_canvas_upload_matches_integer_division_for_all_byte_inputs() {
	// Enumerate every color/alpha pair, including values outside valid
	// premultiplied RGB. Finish in the middle of a worker batch.
	source := []u8{len: (1027 * 513) * 4, init: if index % 4 == 3 {
		u8(index / 1024)
	} else {
		u8(index / 4 + (index % 4) * 47)
	}}
	original := sha256.sum(source)
	mut expected := source.clone()
	for offset := 0; offset < expected.len; offset += 4 {
		alpha := int(source[offset + 3])
		for channel in 0 .. 3 {
			value := if alpha == 0 { 0 } else { (int(source[offset + channel]) * 255 + alpha / 2) / alpha }
			expected[offset + channel] = u8(if value > 255 { 255 } else { value })
		}
	}
	actual := unpremultiply_canvas_rgba(source)
	matches := actual == expected
	assert matches
	assert sha256.sum(source) == original
}
