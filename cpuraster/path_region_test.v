module cpuraster

fn test_path_rectangle_queries_preserve_holes_and_curve_extrema() {
	mut builder := PathBuilder{}
	builder.move_to(0, 0)
	builder.line_to(100, 0)
	builder.line_to(100, 100)
	builder.line_to(0, 100)
	builder.close()
	builder.move_to(25, 25)
	builder.line_to(75, 25)
	builder.line_to(75, 75)
	builder.line_to(25, 75)
	builder.close()
	source := builder.detach()
	path := Path{ ...source, fill_type: .even_odd }
	assert !path.relates_to_rect(Rect{40, 40, 60, 60}, false)
	assert path.relates_to_rect(Rect{10, 10, 20, 20}, false)
	assert path.relates_to_rect(Rect{99, 40, 101, 60}, false)
	assert path.relates_to_rect(Rect{-1, -1, 101, 101}, true)
	assert !path.relates_to_rect(Rect{1, 1, 99, 99}, true)
	mut curved := PathBuilder{}
	curved.move_to(0, 0)
	curved.cubic_to(0, 100, 100, 100, 100, 0)
	curved.close()
	curve := curved.detach()
	assert curve.relates_to_rect(Rect{0, 0, 100, 75}, true)
	assert !curve.relates_to_rect(Rect{0, 0, 100, 74}, true)
	assert !curve.relates_to_rect(Rect{0, 90, 100, 100}, false)
	assert curve.relates_to_rect(Rect{49, 74, 51, 76}, false)
}

fn test_stroked_path_rectangle_queries_use_outline_and_dashes() {
	mut builder := PathBuilder{}
	builder.move_to(5, 5)
	builder.line_to(10, 5)
	builder.line_to(10, 10)
	builder.line_to(5, 10)
	builder.close()
	stroke := path_stroke_outline(PathHitTest{ path: builder.detach(), width: 5 })
	assert stroke.relates_to_rect(Rect{10, 10, 60, 60}, false)
	assert stroke.relates_to_rect(Rect{0, 0, 50, 50}, true)
	assert !stroke.relates_to_rect(Rect{5, 5, 10, 10}, true)
}
