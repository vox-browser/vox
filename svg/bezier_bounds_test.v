module svg

import math

fn test_quadratic_bezier_bounds_use_the_curve_extremum() {
	low, high := quadratic_bezier_bounds(18, -2, 18)
	assert low == 8 && high == 18
	first, last := quadratic_bezier_bounds(0, 2, 5)
	assert first == 0 && last == 5
}

fn test_cubic_bezier_bounds_cover_linear_derivatives_and_two_roots() {
	low, high := cubic_bezier_bounds(28, 4, 4, 28)
	assert low == 10 && high == 28
	start, peak := cubic_bezier_bounds(0, 2, 2, 0)
	assert start == 0 && peak == 1.5
	negative, positive := cubic_bezier_bounds(0, 6, -6, 0)
	assert math.abs(negative + math.sqrt(3)) < 1e-12
	assert math.abs(positive - math.sqrt(3)) < 1e-12
}
