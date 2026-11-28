module cpuraster

fn test_dashed_centerline_has_open_contours_and_a_dash_budget() {
	mut builder := PathBuilder{}
	builder.move_to(0, 0)
	builder.line_to(18, 0)
	path := builder.detach()
	intervals := [f32(4), 6]
	dashed := dash_centerline(path, intervals, 2, Matrix{}, 2) or { panic(err) }
	assert dashed.verbs == [PathVerb.move, .line, .move, .line]
	assert dashed.points == [Point{0, 0}, Point{2, 0}, Point{8, 0}, Point{12, 0}]
	if _ := dash_centerline(path, intervals, 2, Matrix{}, 1) {
		assert false, 'Accepted geometry beyond the dash budget'
	}
}
