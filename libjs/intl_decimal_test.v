// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn test_intl_mathematical_values_preserve_decimal_strings_bigints_and_signed_zero() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	for text in ['9007199254740993.125', '0x20000000000001', '  12.3400e2\u00a0'] {
		value := intl_mathematical_value(mut vm, Value.from_string(vm.create_string_from_str(text)))!
		assert intl_decimal_fixed(value, 0) == if text.starts_with('9007') { '9007199254740993.125' } else if text.starts_with('0x') { '9007199254740993' } else { '1234' }
	}
	assert intl_mathematical_value(mut vm, Value.from_f64(-0.0))!.negative
	assert intl_mathematical_value(mut vm, Value.from_string(vm.create_string_from_str('-0')))!.negative
	assert intl_mathematical_value(mut vm, Value.from_string(vm.create_string_from_str('1e999')))!.special == 'infinity'
	assert intl_mathematical_value(mut vm, Value.from_string(vm.create_string_from_str('1_000')))!.special == 'nan'
	bigint := string_to_bigint(utf16_string('999999999999999999999999999999999999999999'))?
	assert intl_mathematical_value(mut vm, Value.from_bigint(bigint))!.digits == bigint.big_integer.str()
}

fn test_intl_rounding_uses_decimal_number_spelling_and_all_signed_tie_modes() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	value := intl_mathematical_value(mut vm, Value.from_f64(1.005))!
	assert intl_decimal_fixed(intl_decimal_round(mut vm, value, -2, 1, 'halfExpand')!, 2) == '1.01'
	for mode, result in {'ceil':'1.3', 'floor':'1.2', 'expand':'1.3', 'trunc':'1.2', 'halfCeil':'1.3', 'halfFloor':'1.2', 'halfExpand':'1.3', 'halfTrunc':'1.2', 'halfEven':'1.2'} {
		assert intl_decimal_fixed(intl_decimal_round(mut vm, intl_decimal_parse('1.25', false), -1, 1, mode)!, 1) == result
	}
	assert intl_decimal_fixed(intl_decimal_round(mut vm, intl_decimal_parse('-1.25', false), -1, 1, 'halfFloor')!, 1) == '1.3'
	assert intl_decimal_fixed(intl_decimal_round(mut vm, intl_decimal_parse('-1.25', false), -1, 1, 'halfCeil')!, 1) == '1.2'
	assert intl_decimal_fixed(intl_decimal_round(mut vm, intl_decimal_parse('1.375', false), -2, 25, 'halfEven')!, 2) == '1.50'
	assert intl_decimal_fixed(intl_decimal_round(mut vm, intl_decimal_parse('0.0001', false), -2, 1, 'ceil')!, 2) == '0.01'
	assert intl_decimal_fixed(intl_decimal_round(mut vm, intl_decimal_parse('999.99', false), 0, 1, 'halfExpand')!, 0) == '1000'
}

fn test_intl_plural_operands_keep_visible_zeroes_and_exact_large_integer_modulo() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert intl_plural_category(mut vm, 'en-US', '1', 0, false)! == 'one'
	assert intl_plural_category(mut vm, 'en-US', '1.0', 0, false)! == 'other'
	assert intl_plural_category(mut vm, 'ru-RU', '100000000000000000000000000000000000000021', 0, false)! == 'one'
	assert intl_plural_category(mut vm, 'ru', '22', 0, false)! == 'few'
	assert intl_plural_category(mut vm, 'ru', '12', 0, false)! == 'many'
	assert intl_plural_category(mut vm, 'ar', '0', 0, false)! == 'zero'
	assert intl_plural_category(mut vm, 'ar', '2.0', 0, false)! == 'two'
	assert intl_plural_category(mut vm, 'ar', '3.5', 0, false)! == 'other'
	assert intl_plural_category(mut vm, 'fr', '1', 6, false)! == 'one'
	assert intl_plural_category(mut vm, 'en', '22', 0, true)! == 'two'
	assert intl_plural_category(mut vm, 'en', '12', 0, true)! == 'other'
}
