module libjs

fn test_checked_js_string_length_arithmetic_retains_unsigned_32_bit_limit_without_allocating() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	limit := max_js_string_length()
	assert limit == 4294967295
	assert checked_js_string_length_sum(mut vm, limit, 0, .string_size_must_not_overflow)! == limit
	assert checked_js_string_length_sum(mut vm, limit - 1, 1, .string_size_must_not_overflow)! == limit
	assert checked_js_string_length_product(mut vm, limit, 1, .string_size_must_not_overflow)! == limit
	assert checked_js_string_length_product(mut vm, ~uint(0), 0, .string_size_must_not_overflow)! == 0
	for pair in [[limit, uint(1)], [~uint(0), uint(1)], [uint(0), ~uint(0)]] {
		if _ := checked_js_string_length_sum(mut vm, pair[0], pair[1],
			.string_size_must_not_overflow)
		{
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .range_error
			assert thrown_value(err).as_object().error_message()?.str() == 'string size must not overflow'
		}
	}
	for pair in [[limit, uint(2)], [~uint(0), uint(2)], [uint(2), ~uint(0)]] {
		if _ := checked_js_string_length_product(mut vm, pair[0], pair[1],
			.string_repeat_count_must_not_overflow)
		{
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .range_error
			assert thrown_value(err).as_object().error_message()?.str() == 'repeat count must not overflow'
		}
	}
}
