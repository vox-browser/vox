module libjs

import math
import math.big

fn bigint_value(text string) Value {
	return Value.from_bigint(string_to_bigint(utf16_string(text)) or { panic(text) })
}

fn test_bigint_string_conversion_matches_upstream_prefix_and_utf16_regressions() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for source, expected in {
		'':                      '0n'
		'\u00a0\ufeff42\u2028':  '42n'
		'-00042':                '-42n'
		'+42':                   '42n'
		'-0':                    '0n'
		'0Xff':                  '255n'
		'0B101':                 '5n'
		'0O77':                  '63n'
		'184467440737095516160': '184467440737095516160n'
	} {
		value := Value.from_string(vm.create_string_from_str(source))
		integer := value.to_bigint(mut vm)!
		assert Value.from_bigint(integer).str() == expected, source
	}
	for source in ['0x', '0O', '0b', '0x+1', '0x1_0', '0b2', '0o8', '-0xff', '1.0', '1e2', '1n',
		'\u00851', '\u180e1', '1' + [u8(0)].bytestr()] {
		assert string_to_bigint(utf16_string(source)) == none, source
		value := Value.from_string(vm.create_string_from_str(source))
		if _ := value.to_bigint(mut vm) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .syntax_error
		}
	}
	assert string_to_bigint(Utf16String{ data: [u16(0xd800)] }) == none
	assert Value.from_bool(true).to_bigint(mut vm)!.big_integer.str() == '1'
	for value in [js_undefined(), js_null(), Value.from_i32(1),
		Value.from_symbol(Symbol.create(utf16_string('key'), .unique))] {
		if _ := value.to_bigint(mut vm) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
	}
}

fn test_number_to_bigint_preserves_binary_significand_and_checks_integrality() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for number, expected in {
		0.0:                '0'
		-42.0:              '-42'
		9007199254740994.0: '9007199254740994'
		1e30:               '1000000000000000019884624838656'
		-1e30:              '-1000000000000000019884624838656'
	} {
		integer := number_to_bigint(mut vm, Value.from_f64(number))!
		assert integer.big_integer.str() == expected
	}
	for number in [1.5, math.nan(), math.inf(1), math.inf(-1),
		math.f64_from_bits(1)] {
		if _ := number_to_bigint(mut vm, Value.from_f64(number)) {
			assert false, number.str()
		} else {
			assert thrown_value(err).as_object().error_kind()? == .range_error
		}
	}
	maximum := number_to_bigint(mut vm, Value.from_f64(math.max_f64))!
	assert maximum.big_integer.bit_len() == 1024
	assert compare_big_integer_to_double(maximum.big_integer, math.max_f64) == .equal
}

fn test_bigint_cells_and_fixed_width_conversions_preserve_value_semantics() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	zero := bigint_value('-0')
	assert !zero.to_boolean()
	assert zero.is_cell()
	assert zero.is_bigint()
	assert bigint_value('-1').to_boolean()
	assert same_value(bigint_value('42'), bigint_value('42'))
	assert !same_value(bigint_value('42'), bigint_value('43'))
	assert is_strictly_equal(bigint_value('42'), bigint_value('42'))
	assert !is_strictly_equal(bigint_value('42'), Value.from_i32(42))
	assert bigint_value('18446744073709551617').to_bigint_uint64(mut vm)! == 1
	assert bigint_value('-18446744073709551617').to_bigint_uint64(mut vm)! == 0xffffffffffffffff
	assert bigint_value('9223372036854775808').to_bigint_int64(mut vm)! == i64(-9223372036854775807) - 1
	assert bigint_value('-1').to_bigint_int64(mut vm)! == -1
	text := bigint_value('123').to_primitive_string(mut vm)!
	assert text.str() == '123'
	assert add(mut vm, Value.from_string(vm.empty_string()), bigint_value('123'))!.as_string().str() == '123'
}

fn test_bigint_arithmetic_and_signed_bitwise_match_upstream_cases() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert add(mut vm, bigint_value('12'), bigint_value('34'))!.str() == '46n'
	assert sub(mut vm, bigint_value('12'), bigint_value('34'))!.str() == '-22n'
	assert mul(mut vm, bigint_value('8'), bigint_value('12'))!.str() == '96n'
	assert div(mut vm, bigint_value('-123'), bigint_value('10'))!.str() == '-12n'
	assert mod_(mut vm, bigint_value('-5'), bigint_value('3'))!.str() == '-2n'
	assert exp(mut vm, bigint_value('2'), bigint_value('100'))!.str() == '1267650600228229401496703205376n'
	assert exp(mut vm, bigint_value('0'), bigint_value('0'))!.str() == '1n'
	assert unary_minus(mut vm, bigint_value('0'))!.str() == '0n'
	assert bitwise_and(mut vm, bigint_value('3'), bigint_value('-2'))!.str() == '2n'
	assert bitwise_and(mut vm, bigint_value('-3'), bigint_value('-2'))!.str() == '-4n'
	assert bitwise_and(mut vm, bigint_value('-3'), bigint_value('2'))!.str() == '0n'
	assert bitwise_and(mut vm, bigint_value('0xffffffff'), bigint_value('-1'))!.str() == '4294967295n'
	assert bitwise_or(mut vm, bigint_value('0'), bigint_value('-2'))!.str() == '-2n'
	assert bitwise_xor(mut vm, bigint_value('5'), bigint_value('3'))!.str() == '6n'
	assert bitwise_not(mut vm, bigint_value('-1'))!.str() == '0n'
	assert bitwise_not(mut vm, bigint_value('1'))!.str() == '-2n'
	assert left_shift(mut vm, bigint_value('5'), bigint_value('2'))!.str() == '20n'
	assert left_shift(mut vm, bigint_value('-7'), bigint_value('-1'))!.str() == '-4n'
	assert right_shift(mut vm, bigint_value('-8'), bigint_value('1'))!.str() == '-4n'
	assert right_shift(mut vm, bigint_value('7'), bigint_value('-2'))!.str() == '28n'
	// Exercise sign extension and carry propagation across multiple payload words.
	for a in [-1025, -256, -1, 0, 1, 255, 1024] {
		for b in [-1025, -256, -1, 0, 1, 255, 1024] {
			x := big.integer_from_int(a)
			y := big.integer_from_int(b)
			assert big_integer_bitwise(x, y, true) == big.integer_from_int(a & b)
			assert big_integer_bitwise(x, y, false) == big.integer_from_int(a | b)
		}
	}
	large := bigint_value('1267650600228229401496703205377')
	assert bitwise_and(mut vm, large, bigint_value('-2'))!.str() == '1267650600228229401496703205376n'
	assert bitwise_xor(mut vm, large, bigint_value('-1'))!.str() == '-1267650600228229401496703205378n'
}

fn test_bigint_comparisons_do_not_round_through_number() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for source, expected in {
		'9007199254740991': ComparisonResult.less
		'9007199254740992': ComparisonResult.equal
		'9007199254740993': ComparisonResult.greater
	} {
		integer := bigint_value(source)
		assert compare_primitive_values(mut vm, integer, Value.from_f64(9007199254740992.0))! == expected
		assert is_loosely_equal(mut vm, integer, Value.from_f64(9007199254740992.0))! == (expected == .equal)
	}
	for number in [math.f64_from_bits(1), 0.5, 1.25, 1e30, math.max_f64] {
		integer := big_integer_from_double(number)
		expected := if math.trunc(number) == number {
			ComparisonResult.equal
		} else {
			ComparisonResult.less
		}
		assert compare_big_integer_to_double(integer, number) == expected
		assert compare_big_integer_to_double(integer.neg(), -number) == reverse_comparison(expected)
		assert compare_big_integer_to_double(integer + big.integer_from_int(1), number) == .greater
	}
	assert compare_primitive_values(mut vm, bigint_value('1'), Value.from_f64(math.inf(1)))! == .less
	assert compare_primitive_values(mut vm, bigint_value('-1'), Value.from_f64(math.inf(-1)))! == .greater
	assert compare_primitive_values(mut vm, bigint_value('1'), Value.from_f64(math.nan()))! == .unordered
	assert compare_primitive_values(mut vm, bigint_value('1'),
		Value.from_string(vm.create_string_from_str('1.23')))! == .unordered
	assert is_loosely_equal(mut vm, bigint_value('16'),
		Value.from_string(vm.create_string_from_str('0X10')))!
	assert !is_loosely_equal(mut vm, bigint_value('16'),
		Value.from_string(vm.create_string_from_str('0x1_0')))!
	assert is_loosely_equal(mut vm, bigint_value('1'), Value.from_bool(true))!
	assert !is_loosely_equal(mut vm, bigint_value('1'), Value.from_f64(1.25))!
}

fn test_bigint_errors_keep_upstream_operator_messages_and_range_checks() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	operations := [add, sub, mul, div, mod_, exp, bitwise_and, bitwise_or, bitwise_xor, left_shift,
		right_shift]
	names := ['addition', 'subtraction', 'multiplication', 'division', 'modulo', 'exponentiation',
		'bitwise AND', 'bitwise OR', 'bitwise XOR', 'left-shift', 'right-shift']
	for i, operation in operations {
		for other in [Value.from_i32(1), js_null(), js_undefined()] {
			if _ := operation(mut vm, bigint_value('1'), other) {
				assert false
			} else {
				object := thrown_value(err).as_object()
				assert object.error_kind()? == .type_error
				assert object.error_message()? == 'Cannot use ${names[i]} operator with BigInt and other type'
			}
		}
	}
	for operation in [div, mod_] {
		if _ := operation(mut vm, bigint_value('1'), bigint_value('0')) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()? == 'Division by zero'
		}
	}
	if _ := exp(mut vm, bigint_value('2'), bigint_value('-1')) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_message()? == 'Exponent must be positive'
	}
	for operation in [exp, left_shift, right_shift] {
		if _ := operation(mut vm, bigint_value('2'), bigint_value('4294967296')) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()? == 'Maximum BigInt size exceeded'
		}
	}
	if _ := unsigned_right_shift(mut vm, bigint_value('1'), bigint_value('0')) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_message()? == 'Cannot use unsigned right-shift operator with BigInt'
	}
}
