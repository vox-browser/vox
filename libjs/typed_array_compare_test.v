module libjs

import math

@[heap]
struct TypedArrayCompareLog {
mut:
	events []string
}

fn test_typed_array_default_comparison_orders_numbers_nan_and_signed_zero() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	ordered := [Value.from_f64(math.inf(-1)), Value.from_i32(-42),
		Value.from_f64(-0.0), Value.from_i32(0), Value.from_f64(1.5),
		Value.from_i32(42), Value.from_f64(math.inf(1)), Value.from_f64(math.nan())]
	for i, x in ordered {
		for j, y in ordered {
			assert compare_typed_array_elements(mut vm, x, y, none)! == if i < j {
				-1
			} else if i > j {
				1
			} else {
				0
			}
		}
	}
	// Reuse the translated stable sort, retaining negative zero and NaN order.
	mut values := [Value.from_f64(math.nan()), Value.from_i32(42),
		Value.from_i32(0), Value.from_f64(-0.0), Value.from_i32(-42),
		Value.from_f64(math.nan())]
	array_merge_sort(mut vm, fn (mut vm VM, x Value, y Value) !f64 {
		return compare_typed_array_elements(mut vm, x, y, none)
	}, mut values)!
	assert values[0].number == -42 && math.signbit(values[1].number)
		&& !math.signbit(values[2].number) && values[3].number == 42
	assert math.is_nan(values[4].number) && math.is_nan(values[5].number)
}

fn test_typed_array_bigint_comparison_is_exact_beyond_double_precision() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut values := []Value{}
	for source in ['-18446744073709551616', '-1', '0', '9007199254740992', '9007199254740993',
		'18446744073709551616'] {
		values << Value.from_bigint(string_to_bigint(utf16_string(source)) or { panic('invalid BigInt literal') })
	}
	for i, x in values {
		for j, y in values {
			assert compare_typed_array_elements(mut vm, x, y, none)! == if i < j {
				-1
			} else if i > j {
				1
			} else {
				0
			}
		}
	}
}

fn test_typed_array_comparator_runs_before_default_rules_and_converts_callback_results() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	realm := vm.realm()
	for mode in ['nan', 'negative zero', 'object', 'throw', 'conversion throws', 'bigint'] {
		mut log := &TypedArrayCompareLog{}
		mut object := Object.create(realm, none)
		convert := NativeFunction.create(mut vm, realm, realm.function_prototype, fn [mut log, mode] (mut vm VM) !Value {
			log.events << 'convert'
			if mode == 'conversion throws' { return throw_completion(Value.from_i32(42)) }
			return Value.from_i32(-17)
		}, 0, PropertyName.from_str('valueOf'), none)
		object.define_direct_property(PropertyName.from_str('valueOf'),
			Value.from_object(convert.object), 7)
		callback := NativeFunction.create(mut vm, realm, realm.function_prototype, fn [mut log, object, mode] (mut vm VM) !Value {
			assert vm.this_value().is_undefined() && vm.argument_count() == 2
			assert math.is_nan(vm.argument(0).number) && vm.argument(1).number == 42
			log.events << 'call'
			if mode == 'throw' { return throw_completion(Value.from_i32(17)) }
			if mode == 'nan' { return Value.from_f64(math.nan()) }
			if mode == 'negative zero' { return Value.from_f64(-0.0) }
			if mode == 'bigint' { return Value.from_bigint(string_to_bigint(utf16_string('1')) or {
					panic('invalid fixture')}) }
			return Value.from_object(object)
		}, 2, PropertyName.from_str('compare'), none)
		if result := compare_typed_array_elements(mut vm, Value.from_f64(math.nan()),
			Value.from_i32(42), callback.object)
		{
			assert mode in ['nan', 'negative zero', 'object']
			if mode == 'nan' { assert result == 0 && !math.signbit(result)
			 }
			if mode == 'negative zero' { assert result == 0 && math.signbit(result)
			 }
			if mode == 'object' { assert result == -17
			 }
		} else {
			if mode == 'bigint' {
				assert thrown_value(err).as_object().error_kind()? == .type_error
			} else {
				assert thrown_value(err).number == if mode == 'throw' {
					17
				} else {
					42
				}
			}
		}
		assert log.events == if mode in ['object', 'conversion throws'] {
			['call', 'convert']
		} else {
			['call']
		}
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
}
