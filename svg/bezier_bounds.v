module svg

import math

// Bounds of one coordinate of a quadratic Bézier segment.
pub fn quadratic_bezier_bounds(start f64, control f64, end f64) (f64, f64) {
	mut low := math.min(start, end)
	mut high := math.max(start, end)
	if control >= low && control <= high { return low, high }
	first := control - start
	second := end - control
	t := -first / (second - first)
	if t > 0 && t < 1 {
		left := start + t * first
		right := control + t * second
		value := left + t * (right - left)
		low = math.min(low, value)
		high = math.max(high, value)
	}
	return low, high
}

// Bounds of one coordinate of a cubic Bézier segment. The roots of its
// derivative identify the only possible extrema between the endpoints.
pub fn cubic_bezier_bounds(start f64, first_control f64, second_control f64, end f64) (f64, f64) {
	mut low := math.min(start, end)
	mut high := math.max(start, end)
	if first_control >= low && first_control <= high && second_control >= low
		&& second_control <= high { return low, high }
	first := first_control - start
	second := second_control - first_control
	third := end - second_control
	a := first - 2 * second + third
	b := 2 * (second - first)
	mut roots := [2]f64{}
	if a == 0 {
		if b != 0 { roots[0] = -first / b }
	} else {
		discriminant := b * b - 4 * a * first
		if discriminant > 0 {
			root := math.sqrt(discriminant)
			q := -0.5 * (b + if b < 0 { -root } else { root })
			roots = [q / a, first / q]!
		} else if discriminant == 0 {
			roots[0] = -b / (2 * a)
		}
	}
	for t in roots {
		if t <= 0 || t >= 1 || !math.is_finite(t) { continue }
		left := start + t * first
		middle := first_control + t * second
		right := second_control + t * third
		first_half := left + t * (middle - left)
		second_half := middle + t * (right - middle)
		value := first_half + t * (second_half - first_half)
		low = math.min(low, value)
		high = math.max(high, value)
	}
	return low, high
}
