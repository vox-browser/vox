module cpuraster

fn hit_path_segment(kind f32, x f32, y f32) []f32 {
	return [kind, x, y, 0, 0, 0, 0, 0, 0, 0, 0, 0]
}

fn hit_path_rectangle(x f32, y f32, width f32, height f32) []f32 {
	mut data := hit_path_segment(0, x, y)
	data << hit_path_segment(1, x + width, y)
	data << hit_path_segment(1, x + width, y + height)
	data << hit_path_segment(1, x, y + height)
	data << hit_path_segment(5, x, y)
	return data
}

fn test_path_hits_distinguish_fill_stroke_and_miter_corners() {
	path := PackedPath{ segments: hit_path_rectangle(10, 10, 40, 40) }
	assert packed_path_hit_test(PackedPathHitTest{ path: path, x: 30, y: 30, areas: 1 })
	assert !packed_path_hit_test(PackedPathHitTest{ path: path, x: 30, y: 30, areas: 2, width: 20 })
	assert packed_path_hit_test(PackedPathHitTest{ path: path, x: 5, y: 5, areas: 2, width: 20 })
	assert !packed_path_hit_test(PackedPathHitTest{ path: path, x: 5, y: 5, areas: 1 })
	assert !packed_path_hit_test(PackedPathHitTest{ path: path, x: 5, y: 5, areas: 2, width: 0 })
	assert !packed_path_hit_test(PackedPathHitTest{ path: path, x: 1, y: 1, areas: 2, width: 20, join: 0 })
}

fn test_path_hits_preserve_compound_fill_rules_and_invalid_input() {
	mut segments := hit_path_rectangle(0, 0, 40, 40)
	segments << hit_path_rectangle(10, 10, 20, 20)
	assert packed_path_hit_test(PackedPathHitTest{ path: PackedPath{ segments: segments }, x: 20, y: 20, areas: 1 })
	assert !packed_path_hit_test(PackedPathHitTest{ path: PackedPath{ segments: segments, even_odd: true }, x: 20, y: 20, areas: 1 })
	assert packed_path_hit_test(PackedPathHitTest{ path: PackedPath{ segments: segments, even_odd: true }, x: 5, y: 5, areas: 1 })
	assert !packed_path_hit_test(PackedPathHitTest{})
	assert !packed_path_hit_test(PackedPathHitTest{ path: PackedPath{ segments: [f32(0), 1] }, x: 0, y: 0 })
}

fn test_path_hits_apply_caps_dashes_and_non_scaling_strokes() {
	mut segments := hit_path_segment(0, 0, 0)
	segments << hit_path_segment(1, 20, 0)
	path := PackedPath{ segments: segments }
	base := PackedPathHitTest{ path: path, areas: 2, width: 4 }
	assert !packed_path_hit_test(PackedPathHitTest{ ...base, x: -1, cap: 0 })
	assert packed_path_hit_test(PackedPathHitTest{ ...base, x: -1, cap: 1 })
	assert !packed_path_hit_test(PackedPathHitTest{ ...base, x: 7, dashes: [f32(5), 5] })
	assert packed_path_hit_test(PackedPathHitTest{ ...base, x: 2, dashes: [f32(5), 5] })
	assert packed_path_hit_test(PackedPathHitTest{ ...base, x: 10, y: 1.5 })
	assert !packed_path_hit_test(PackedPathHitTest{ ...base, x: 20, y: 3, non_scaling: true, transform: [
		f32(2),
		0,
		0,
		2,
		0,
		0,
	]! })
	assert packed_path_hit_test(PackedPathHitTest{ ...base, x: 30, y: 1, non_scaling: true, transform: [
		f32(2),
		0,
		0,
		2,
		0,
		0,
	]! })
}
