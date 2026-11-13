module imageraster

fn test_canvas_upload_converts_alpha_without_mutating_the_surface() {
	pixels := [u8(64), 32, 16, 128, 255, 1, 2, 255, 100, 20, 1, 0, 255, 1, 0, 128]
	original := pixels.clone()
	assert unpremultiply_canvas_rgba(pixels) == [u8(128), 64, 32, 128, 255, 1, 2, 255, 0, 0, 0, 0, 255, 2, 0, 128]
	assert pixels == original
	assert unpremultiply_canvas_rgba([u8(1), 2, 3]) == []u8{}
}
