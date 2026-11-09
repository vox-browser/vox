module cpuraster

import math

fn test_path_distance_queries_cross_contours_clamp_and_retain_curve_geometry() {
	mut builder := PathBuilder{}
	builder.move_to(0,0)
	builder.line_to(30,0)
	builder.move_to(100,100)
	builder.line_to(100,140)
	path := builder.detach()
	assert path.point_at_distance(-10) == Point{0,0}
	assert path.point_at_distance(35) == Point{100,105}
	assert path.point_at_distance(1000) == Point{100,140}
	mut curve := PathBuilder{}
	curve.move_to(1,0)
	curve.conic_to(1,1,0,1,f32(math.sqrt(0.5)))
	midpoint := curve.detach().point_at_distance(math.pi/4)
	assert math.abs(midpoint.x-math.sqrt(0.5)) < 0.001
	assert math.abs(midpoint.y-math.sqrt(0.5)) < 0.001
}
