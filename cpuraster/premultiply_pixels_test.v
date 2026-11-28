module cpuraster

import crypto.sha256

fn test_truncated_premultiplication_preserves_the_source_and_partial_pixel() {
	bytes := 1024 * 513 * 4 + 7
	source := []u8{len: bytes, init: if index % 4 == 3 {
		u8(index / 1024)
	} else {
		u8(index / 4 + (index % 4) * 47)
	}}
	original := sha256.sum(source)
	mut expected := source.clone()
	for offset := 0; offset + 3 < expected.len; offset += 4 {
		alpha := u32(expected[offset + 3])
		for channel in 0 .. 3 {
			expected[offset + channel] = u8(u32(expected[offset + channel]) * alpha / 255)
		}
	}
	actual := premultiply_rgba_copy_truncated(source)
	matches := actual == expected
	assert matches
	assert sha256.sum(source) == original
	assert premultiply_rgba_copy_truncated([u8(254), 128, 1, 128, 201]) == [u8(127), 64, 0, 128, 201]
	assert premultiply_rgba_copy_truncated([]).len == 0
}

fn test_canvas_premultiplies_large_straight_surface_once_and_preserves_padding() {
	width, height := 1031, 513
	pitch := width * 4 + 12
	// The final row has no padding in the backing view.
	mut surface := []u8{len: (height - 1) * pitch + width * 4, init: u8((index * 59 + index / 4) & 255)}
	mut expected := surface.clone()
	for y in 0 .. height {
		for x in 0 .. width {
			offset := y * pitch + x * 4
			alpha := u32(expected[offset + 3])
			for channel in 0 .. 3 {
				expected[offset + channel] = u8((u32(expected[offset + channel]) * alpha + 127) / 255)
			}
		}
	}
	path := rect_path(Rect{0, 0, 1, 1})
	transform := [f32(1), 0, 0, 1, 0, 0]!
	// A transparent source-over draw still prepares the destination pixels.
	assert fill_canvas_path(mut surface, width, height, pitch, 1, path, transform, 0, none, 1,
		.src_over, 0, [], none)
	first_draw_matches := surface == expected
	assert first_draw_matches
	assert fill_canvas_path(mut surface, width, height, pitch, 2, path, transform, 0, none, 1,
		.src_over, 0, [], none)
	second_draw_matches := surface == expected
	assert second_draw_matches
}
