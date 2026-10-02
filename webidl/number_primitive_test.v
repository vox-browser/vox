module webidl

import math

fn test_number_primitive_preserves_number_brand_without_numeric_coercion() {
	assert (number_value(0).number_primitive() or { panic('missing zero') }) == 0
	assert (number_value(-3).number_primitive() or { panic('missing negative') }) == -3
	assert math.is_nan(number_value(math.nan()).number_primitive() or { panic('missing NaN') })
	for value in [undefined_value(), null_value(), boolean_value(true), string_value('1'), bigint_value(1), object_value({})] {
		assert value.number_primitive() == none
	}
	actual := runtime_value(RuntimeValue{
		number_primitive: 2.5
		string_conversion: fn () !string { panic('number projection must not convert') }
	})
	assert (actual.number_primitive() or { panic('missing actual number') }) == 2.5
	object := runtime_value(RuntimeValue{
		string_conversion: fn () !string { panic('non-number projection must not convert') }
	})
	assert object.number_primitive() == none
}
