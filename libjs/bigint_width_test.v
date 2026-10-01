module libjs

import math
import math.big

@[heap]
struct BigIntWidthLog {
mut:
	events []string
}

fn bigint_width_value(text string) Value {
	return Value.from_bigint(string_to_bigint(utf16_string(text)) or { panic(text) })
}

fn bigint_width_call(mut vm VM, signed bool, arguments []Value) !Value {
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [signed] (mut vm VM) !Value {
		if signed { return bigint_constructor_as_int_n(mut vm) }
		return bigint_constructor_as_uint_n(mut vm)
	}, 2, PropertyName.from_str('width'), none)
	return call(mut vm, Value.from_object(function.object), js_null(), arguments)
}

fn test_bigint_width_matches_upstream_small_values_and_byte_and_word_boundaries() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for width in [0, 1, 2, 4, 7, 8, 9, 31, 32, 33, 59, 60, 61, 63, 64, 65, 127, 128, 129] {
		modulus := big.integer_from_int(1).left_shift(u32(width))
		for source in [big.integer_from_int(0), big.integer_from_int(1),
			big.integer_from_int(-1), modulus, modulus.neg(), modulus - big.integer_from_int(1),
			modulus + big.integer_from_int(1), (modulus + big.integer_from_int(1)).neg()] {
			value := Value.from_bigint(BigInt.create(source))
			unsigned := bigint_width_call(mut vm, false, [Value.from_i32(width), value])!.as_bigint().big_integer
			assert unsigned.signum >= 0 && unsigned < modulus
			assert (source - unsigned) % modulus == big.integer_from_int(0)
			signed := bigint_width_call(mut vm, true, [Value.from_i32(width), value])!.as_bigint().big_integer
			if width == 0 {
				assert signed.signum == 0
			} else {
				half := modulus.right_shift(1)
				assert signed >= half.neg() && signed < half
				assert (source - signed) % modulus == big.integer_from_int(0)
			}
		}
	}
	// Tests/LibJS/Runtime/builtins/BigInt/{BigInt.asIntN,BigInt.asUintN}.js.
	large := bigint_width_value('123456789123456789123456789123456789123456789123456789')
	negative := Value.from_bigint(BigInt.create(large.as_bigint().big_integer.neg()))
	for index, value in [large, negative] {
		signed := ['-99061374399389259395070030194384019691n',
			'99061374399389259395070030194384019691n'][index]
		unsigned := ['241220992521549204068304577237384191765n',
			'99061374399389259395070030194384019691n'][index]
		assert bigint_width_call(mut vm, true, [Value.from_i32(128), value])!.str() == signed
		assert bigint_width_call(mut vm, false, [Value.from_i32(128), value])!.str() == unsigned
		assert same_value(bigint_width_call(mut vm, true, [Value.from_i32(256), value])!, value)
	}
	assert bigint_width_call(mut vm, false, [Value.from_i32(256), negative])!.str() == '115792089237316195423570861551898784396480861208851440582668460551124006183147n'
	wide := bigint_width_call(mut vm, false, [Value.from_i32(0x4000),
		bigint_width_value('-2')])!
	assert (wide.as_bigint().big_integer % big.integer_from_int(100000000)).str() == '64066814'
}

fn test_bigint_width_preserves_huge_width_fast_paths_and_upstream_oom_errors() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	for width in [f64(2147483648), f64(0x4000000000000), f64(0x8ffffffffffff), 9007199254740991.0] {
		for source in ['0', '1', '2', '-1', '-2'] {
			value := bigint_width_value(source)
			result := bigint_width_call(mut vm, true, [Value.from_f64(width), value])!
			assert same_value(result, value)
			if source.starts_with('-') {
				assert voidptr(result.as_bigint()) == voidptr(value.as_bigint())
				if _ := bigint_width_call(mut vm, false, [Value.from_f64(width), value]) {
					assert false
				} else {
					assert thrown_value(err).as_object().error_kind()? == .internal_error
					assert thrown_value(err).as_object().error_message()?.str() == 'Out of memory'
				}
			} else {
				unsigned := bigint_width_call(mut vm, false, [
					Value.from_f64(width), value])!
				assert same_value(unsigned, value)
				assert voidptr(unsigned.as_bigint()) != voidptr(value.as_bigint())
			}
		}
	}
	if _ := big_integer_not_fill(mut vm, big.integer_from_int(1), 2147483648) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_message()?.str() == 'Out of memory'
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_bigint_width_coerces_bits_before_bigint_even_for_zero_and_propagates_errors() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut log := &BigIntWidthLog{}
	for signed in [false, true] {
		mut bits := Object.create(vm.realm(), none)
		mut integer := Object.create(vm.realm(), none)
		for index, object in [bits, integer] {
			function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [index, mut log] (mut vm VM) !Value {
				assert vm.argument(0).as_string().str() == 'number'
				log.events << ['bits', 'bigint'][index]
				return if index == 0 { Value.from_i32(0) } else { bigint_width_value('-1') }
			}, 1, PropertyName.from_str('coerce'), none)
			mut target := object
			target.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
				Value.from_object(function.object), 7)
		}
		assert bigint_width_call(mut vm, signed, [Value.from_object(bits),
			Value.from_object(integer)])!.str() == '0n'
		assert log.events == ['bits', 'bigint']
		log.events.clear()
		if _ := bigint_width_call(mut vm, signed, [Value.from_i32(-1),
			Value.from_object(integer)])
		{
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .range_error
		}
		assert log.events.len == 0
		thrower := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm VM) !Value {
			return throw_completion(Value.from_i32(77))
		}, 1, PropertyName.from_str('thrower'), none)
		integer.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
			Value.from_object(thrower.object), 7)
		if _ := bigint_width_call(mut vm, signed, [Value.from_object(bits),
			Value.from_object(integer)])
		{
			assert false
		} else {
			assert thrown_value(err).number == 77
		}
		assert log.events == ['bits']
		log.events.clear()
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_bigint_width_index_conversion_and_bigint_rejections_match_upstream() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for signed in [false, true] {
		for width in [js_undefined(), js_null(), Value.from_f64(math.nan()),
			Value.from_f64(-0.5)] {
			assert bigint_width_call(mut vm, signed, [width, bigint_width_value('-2')])!.str() == '0n'
		}
		assert bigint_width_call(mut vm, signed, [Value.from_f64(4.9),
			Value.from_bool(true)])!.str() == '1n'
		assert bigint_width_call(mut vm, signed, [
			Value.from_string(vm.create_string_from_str('4')),
			Value.from_string(vm.create_string_from_str('0x1')),
		])!.str() == '1n'
		for width in [Value.from_i32(-1), Value.from_f64(math.inf(1)),
			Value.from_f64(9007199254740992.0)] {
			if _ := bigint_width_call(mut vm, signed, [width, bigint_width_value('0')]) {
				assert false
			} else {
				assert thrown_value(err).as_object().error_kind()? == .range_error
			}
		}
		for value in [Value.from_i32(1), js_null(), js_undefined(),
			Value.from_symbol(Symbol.create(none, .unique))] {
			if _ := bigint_width_call(mut vm, signed, [Value.from_i32(0), value]) {
				assert false
			} else {
				assert thrown_value(err).as_object().error_kind()? == .type_error
			}
		}
		if _ := bigint_width_call(mut vm, signed, [Value.from_i32(0),
			Value.from_string(vm.create_string_from_str('foo'))])
		{
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str() == 'Invalid value for BigInt: foo'
		}
		if _ := bigint_width_call(mut vm, signed, [bigint_width_value('1'),
			bigint_width_value('1')])
		{
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str() == 'Cannot convert BigInt to number'
		}
	}
}
