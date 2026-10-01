module libjs

import math

// Decimal forms are fixture inputs to the untranslated Dragonbox boundary.
// Expected output comes from the pinned Number prototype tests; these records
// do not replace that backend in production.
struct NumberScientificCase {
	number   f64
	fraction u64
	exponent int
	digits   int
	text     string
}

fn number_scientific_call(mut vm VM, exponential bool, decimal NumberDecimalExponentialFormGetter, receiver Value, arguments []Value) !Value {
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [exponential, decimal] (mut vm VM) !Value {
		if exponential { return number_prototype_to_exponential(mut vm, decimal) }
		return number_prototype_to_precision(mut vm, decimal)
	}, 1, PropertyName.from_str(if exponential { 'toExponential' } else { 'toPrecision' }), none)
	return call(mut vm, Value.from_object(function.object), receiver, arguments)
}

fn test_number_exponential_exact_upstream_rounding_shortest_forms_and_extreme_exponents() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	cases := [
		NumberScientificCase{123.456, 123456, -3, -1, '1.23456e+2'},
		NumberScientificCase{13, 13, 0, -1, '1.3e+1'},
		NumberScientificCase{100, 1, 2, -1, '1e+2'},
		NumberScientificCase{345, 345, 0, -1, '3.45e+2'},
		NumberScientificCase{6789, 6789, 0, -1, '6.789e+3'},
		NumberScientificCase{0.13, 13, -2, -1, '1.3e-1'},
		NumberScientificCase{0.0345, 345, -4, -1, '3.45e-2'},
		NumberScientificCase{0.006789, 6789, -6, -1, '6.789e-3'},
		NumberScientificCase{1.1e-32, 11, -33, -1, '1.1e-32'},
		NumberScientificCase{1, 1, 0, 0, '1e+0'},
		NumberScientificCase{5, 5, 0, 1, '5.0e+0'},
		NumberScientificCase{9, 9, 0, 3, '9.000e+0'},
		NumberScientificCase{12, 12, 0, 0, '1e+1'},
		NumberScientificCase{345, 345, 0, 1, '3.5e+2'},
		NumberScientificCase{6789, 6789, 0, 3, '6.789e+3'},
		NumberScientificCase{0.12, 12, -2, 0, '1e-1'},
		NumberScientificCase{0.0345, 345, -4, 1, '3.5e-2'},
		NumberScientificCase{0.006789, 6789, -6, 3, '6.789e-3'},
		NumberScientificCase{123.456, 123456, -3, 17, '1.23456000000000003e+2'},
		NumberScientificCase{0.0001, 1, -4, 17, '1.00000000000000005e-4'},
		NumberScientificCase{0.9999, 9999, -4, 17, '9.99900000000000011e-1'},
		NumberScientificCase{0.9999, 9999, -4, 0, '1e+0'},
		NumberScientificCase{3, 3, 0, 100, '3.' + '0'.repeat(100) + 'e+0'},
		NumberScientificCase{math.f64_from_bits(1), 5, -324, 2, '4.94e-324'},
		NumberScientificCase{math.f64_from_bits(0x7fefffffffffffff), 17976931348623157, 292, 16, '1.7976931348623157e+308'},
	]
	parent := Object.create(vm.realm(), none)
	for fixture in cases {
		decimal := fn [fixture] (number f64) NumberDecimalExponentialForm {
			assert number == fixture.number
			return NumberDecimalExponentialForm{
				fraction: fixture.fraction
				exponent: fixture.exponent
			}
		}
		for negative in [false, true] {
			number := if negative { -fixture.number } else { fixture.number }
			wrapper := NumberObject.create(vm.realm(), number, parent)
			for receiver in [Value.from_f64(number), Value.from_object(wrapper.object)] {
				mut arguments := []Value{}
				if fixture.digits >= 0 { arguments << Value.from_i32(fixture.digits) }
				result := number_scientific_call(mut vm, true, decimal, receiver, arguments)!
				assert result.as_string().str() == (if negative {
					'-'
				} else {
					''
				}) + fixture.text
			}
		}
	}
}

fn test_number_precision_exact_candidates_on_both_sides_of_decimal_powers() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	cases := [
		NumberScientificCase{2e-7, 2, -7, 5, '2.0000e-7'},
		NumberScientificCase{1.89e-9, 189, -11, 3, '1.89e-9'},
		NumberScientificCase{1.89e-9, 189, -11, 2, '1.9e-9'},
		NumberScientificCase{100, 1, 2, 1, '1e+2'},
		NumberScientificCase{100, 1, 2, 2, '1.0e+2'},
		NumberScientificCase{1234589, 1234589, 0, 3, '1.23e+6'},
		NumberScientificCase{1234589, 1234589, 0, 4, '1.235e+6'},
		NumberScientificCase{1234589, 1234589, 0, 5, '1.2346e+6'},
		NumberScientificCase{1, 1, 0, 1, '1'},
		NumberScientificCase{123, 123, 0, 3, '123'},
		NumberScientificCase{123.45, 12345, -2, 3, '123'},
		NumberScientificCase{1, 1, 0, 4, '1.000'},
		NumberScientificCase{123, 123, 0, 4, '123.0'},
		NumberScientificCase{123.45, 12345, -2, 4, '123.5'},
		NumberScientificCase{0.1, 1, -1, 1, '0.1'},
		NumberScientificCase{0.0123, 123, -4, 3, '0.0123'},
		NumberScientificCase{0.0012345, 12345, -7, 3, '0.00123'},
		NumberScientificCase{0.0012345, 12345, -7, 4, '0.001234'},
		NumberScientificCase{1 + 11.0 / 31, 13548387096774194, -16, 16, '1.354838709677419'},
		NumberScientificCase{1.2345e27, 12345, 23, 21, '1.23449999999999996184e+27'},
		NumberScientificCase{1e-21, 1, -21, 16, '9.999999999999999e-22'},
		NumberScientificCase{1e-21, 1, -21, 17, '9.9999999999999991e-22'},
		NumberScientificCase{1e-21, 1, -21, 18, '9.99999999999999908e-22'},
		NumberScientificCase{1e-21, 1, -21, 19, '9.999999999999999075e-22'},
		NumberScientificCase{1e-21, 1, -21, 20, '9.9999999999999990754e-22'},
		NumberScientificCase{1e-21, 1, -21, 21, '9.99999999999999907537e-22'},
		NumberScientificCase{3, 3, 0, 100, '3.' + '0'.repeat(99)},
		NumberScientificCase{1e-6, 1, -6, 1, '0.000001'},
		NumberScientificCase{math.f64_from_bits(1), 5, -324, 1, '5e-324'},
	]
	for fixture in cases {
		decimal := fn [fixture] (number f64) NumberDecimalExponentialForm {
			assert number == fixture.number
			return NumberDecimalExponentialForm{
				fraction: fixture.fraction
				exponent: fixture.exponent
			}
		}
		for negative in [false, true] {
			result := number_scientific_call(mut vm, false, decimal, Value.from_f64(if negative {
				-fixture.number
			} else {
				fixture.number
			}), [Value.from_i32(fixture.digits)])!
			assert result.as_string().str() == (if negative {
				'-'
			} else {
				''
			}) + fixture.text
		}
	}
}

fn test_number_scientific_brand_conversion_range_order_zero_and_nonfinite_skip_decimal_backend() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	decimal := fn (number f64) NumberDecimalExponentialForm {
		assert false, 'this fast path must not consult Dragonbox'
		return NumberDecimalExponentialForm{}
	}
	mut poison := Object.create(vm.realm(), none)
	thrower := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm VM) !Value {
		assert vm.argument(0).as_string().str() == 'number'
		return throw_completion(Value.from_i32(77))
	}, 1, PropertyName.from_str('thrower'), none)
	poison.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
		Value.from_object(thrower.object), 7)
	for exponential in [false, true] {
		for receiver in [js_undefined(), js_null(), Value.from_bool(true),
			Value.from_object(poison)] {
			if _ := number_scientific_call(mut vm, exponential, decimal, receiver, [
				Value.from_object(poison),
			])
			{
				assert false
			} else {
				assert thrown_value(err).as_object().error_message()?.str() == 'Not an object of type Number'
			}
		}
		for number in [math.nan(), math.inf(1), math.inf(-1), 0.0] {
			if _ := number_scientific_call(mut vm, exponential, decimal, Value.from_f64(number), [
				Value.from_object(poison),
			])
			{
				assert false
			} else {
				assert thrown_value(err).number == 77
			}
			for digits in [f64(-1), f64(101), math.inf(1), math.inf(-1)] {
				if !Value.from_f64(number).is_finite_number() {
					result := number_scientific_call(mut vm, exponential, decimal,
						Value.from_f64(number), [Value.from_f64(digits)])!
					assert result.as_string().str() == format_f64_value(number)
				} else if _ := number_scientific_call(mut vm, exponential, decimal,
					Value.from_f64(number), [Value.from_f64(digits)])
				{
					assert false
				} else {
					assert thrown_value(err).as_object().error_kind()? == .range_error
				}
			}
		}
		for number in [0.0, -0.0] {
			for digits in [1, 3, 100] {
				result := number_scientific_call(mut vm, exponential, decimal,
					Value.from_f64(number), [Value.from_i32(digits)])!
				assert result.as_string().str() == if exponential {
					'0.' + '0'.repeat(digits) + 'e+0'
				} else {
					if digits == 1 {
						'0'
					} else {
						'0.' + '0'.repeat(digits - 1)
					}
				}
			}
		}
	}
	result := number_scientific_call(mut vm, false, decimal, Value.from_f64(3.14), []Value{})!
	assert result.as_string().str() == '3.14'
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
