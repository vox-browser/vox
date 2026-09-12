module css

import math

fn test_numeric_token_accessors_clamp_to_the_single_precision_range() {
	large := f64(math.max_f32) * 2
	assert Token.create_number(Number.with_type(.number, large), '').number_value() == f64(math.max_f32)
	assert Token.create_dimension_from_double(-large, 'px', '').dimension_value() == -f64(math.max_f32)
	assert Token.create_percentage(Number.with_type(.number, large), '').percentage() == f64(math.max_f32)

	ordinary := 123.456789
	assert Token.create_number(Number.with_type(.number, ordinary), '').number_value() == ordinary
}
