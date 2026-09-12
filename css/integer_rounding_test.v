module css

import math

fn test_css_integer_rounding_ties_toward_positive_infinity() {
	assert round_to_nearest_integer(2.5) == 3
	assert round_to_nearest_integer(-2.5) == -2
	assert round_to_nearest_integer(-2.51) == -3
	assert round_to_nearest_integer(-2.49) == -2
}

fn test_css_integer_rounding_censors_non_finite_values() {
	assert round_to_nearest_integer(math.nan()) == 0
	assert round_to_nearest_integer(math.inf(1)) == max_i64
	assert round_to_nearest_integer(math.inf(-1)) == min_i64
}
