module cpuraster

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
