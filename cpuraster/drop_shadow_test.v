module cpuraster

fn test_scaled_and_oversized_drop_shadows_decline_without_changing_pixels() {
	mut px := []u8{len: 8 * 8 * 4, init: u8(index % 4 * 60)}
	before := px.clone()
	path := rect_path(Rect{1, 1, 4, 4})
	filter := new_canvas_filter([CanvasFilterStep{kind: .drop_shadow, sigma: 2, color: 0x80000000}])
	assert !fill_canvas_path(mut px, 8, 8, 32, 1, path, [f32(1.2), 0, 0, 0.9, 0, 0]!,
		0xff0000ff, none, 1, .src_over, 0, [], filter)
	assert px == before
	large := new_canvas_filter([CanvasFilterStep{kind: .drop_shadow, offset_x: f32(1 << 25), color: 0x80000000}])
	assert !fill_canvas_path(mut px, 8, 8, 32, 1, path, [f32(1), 0, 0, 1, 0, 0]!,
		0xff0000ff, none, 1, .src_over, 0, [], large)
	assert px == before
}

fn test_drop_shadow_applies_source_and_tint_alpha_once() {
	mut px := []u8{len: 8 * 8 * 4}
	path := rect_path(Rect{1, 1, 4, 4})
	filter := new_canvas_filter([CanvasFilterStep{kind: .drop_shadow, offset_x: 2, color: 0x80ff0000}])
	assert fill_canvas_path(mut px, 8, 8, 32, 2, path, [f32(1), 0, 0, 1, 0, 0]!,
		0xff0000ff, none, 0.5, .src_over, 0, [], filter)
	assert px[36..40] == [u8(0), 0, 128, 128]
	assert px[48..52] == [u8(64), 0, 0, 64]
	assert px[44..48] == [u8(32), 0, 128, 160]
}
