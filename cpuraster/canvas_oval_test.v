module cpuraster

import math

fn test_canvas_path_decodes_a_packed_ellipse() {
	bounds := Rect{2, 5, 26, 17}
	packed := [f32(6), bounds.left, bounds.top, bounds.right, bounds.bottom, 0, 0, 0, 0, 0, 0, 0]
	path := canvas_path(packed, true)
	mut expected := PathBuilder{}
	expected.add_oval_dir(bounds, true, 1)
	oval := expected.detach()
	assert path.verbs == oval.verbs
	assert path.points == oval.points
	assert path.weights == oval.weights
	assert path.bounds()? == bounds
	assert path.fill_type == .even_odd
}

fn test_canvas_path_skips_invalid_packed_ellipses() {
	for bounds in [Rect{2, 5, 2, 17}, Rect{2, 17, 26, 5}, Rect{2, 5, f32(math.inf(1)), 17},
		Rect{f32(math.nan()), 5, 26, 17}] {
		path := canvas_path([f32(6), bounds.left, bounds.top, bounds.right, bounds.bottom,
			0, 0, 0, 0, 0, 0, 0], false)
		assert path.verbs.len == 0
		assert path.points.len == 0
	}
}
