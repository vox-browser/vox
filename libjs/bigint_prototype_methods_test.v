module libjs

import math

@[heap]
struct BigIntPrototypeMethodLog {
mut:
	calls int
}

fn bigint_method_value(text string) Value {
	return Value.from_bigint(string_to_bigint(utf16_string(text)) or { panic(text) })
}

fn bigint_method_call(mut vm VM, to_string bool, receiver Value, arguments []Value) !Value {
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [to_string] (mut vm VM) !Value {
		if to_string { return bigint_prototype_to_string(mut vm) }
		return bigint_prototype_value_of(mut vm)
	}, 0, PropertyName.from_str('bigintMethod'), none)
	return call(mut vm, Value.from_object(function.object), receiver, arguments)
}

fn test_bigint_to_string_retains_exact_radix_digits_sign_and_zero_without_literal_suffix() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for source, expected in {
		'0':                                                       '0'
		'-0':                                                      '0'
		'123':                                                     '123'
		'-123':                                                    '-123'
		'3323214327642987348732109829832143298746432437532197321': '3323214327642987348732109829832143298746432437532197321'
	} {
		value := bigint_method_value(source)
		wrapper := BigIntObject.create(vm.realm(), value.as_bigint(), parent)
		for receiver in [value, Value.from_object(wrapper.object)] {
			assert bigint_method_call(mut vm, true, receiver, []Value{})!.as_string().str() == expected
			assert bigint_method_call(mut vm, true, receiver, [
				js_undefined()])!.as_string().str() == expected
		}
	}
	// Every supported radix for 42, with source-prescribed lowercase digits.
	texts := ['101010', '1120', '222', '132', '110', '60', '52', '46', '42', '39', '36', '33',
		'30', '2c', '2a', '28', '26', '24', '22', '20', '1k', '1j', '1i', '1h', '1g', '1f', '1e',
		'1d', '1c', '1b', '1a', '19', '18', '17', '16']
	for index, expected in texts {
		for source in ['42', '-42'] {
			prefix := if source.starts_with('-') { '-' } else { '' }
			assert bigint_method_call(mut vm, true, bigint_method_value(source), [
				Value.from_i32(index + 2),
			])!.as_string().str() == prefix + expected
		}
		assert bigint_method_call(mut vm, true, bigint_method_value('0'), [
			Value.from_i32(index + 2),
		])!.as_string().str() == '0'
	}
	value := bigint_method_value('1267650600228229401496703205375')
	assert bigint_method_call(mut vm, true, value, [Value.from_i32(2)])!.as_string().str() == '1'.repeat(100)
	assert bigint_method_call(mut vm, true, value, [Value.from_i32(8)])!.as_string().str() == '1' +
		'7'.repeat(33)
	assert bigint_method_call(mut vm, true, value, [Value.from_i32(16)])!.as_string().str() == 'f'.repeat(25)
}

fn test_bigint_prototype_brand_check_precedes_radix_coercion_and_ignores_inherited_slots() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut log := &BigIntPrototypeMethodLog{}
	mut radix := Object.create(vm.realm(), none)
	coercion := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mut log] (mut vm VM) !Value {
		log.calls++
		return Value.from_i32(16)
	}, 1, PropertyName.from_str('coerce'), none)
	radix.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
		Value.from_object(coercion.object), 7)
	parent := Object.create(vm.realm(), none)
	value := bigint_method_value('42')
	wrapper := BigIntObject.create(vm.realm(), value.as_bigint(), parent)
	mut spoof := Object.create(vm.realm(), wrapper.object)
	spoof.class_name = 'BigInt'
	spoof.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
		Value.from_object(coercion.object), 7)
	for receiver in [js_undefined(), js_null(), Value.from_i32(42),
		Value.from_bool(true), Value.from_string(vm.create_string_from_str('42')),
		Value.from_symbol(Symbol.create(none, .unique)), Value.from_object(spoof),
		Value.from_object(parent), Value.from_object(vm.realm().boolean_prototype_record())] {
		for to_string in [false, true] {
			if _ := bigint_method_call(mut vm, to_string, receiver, [
				Value.from_object(radix),
			])
			{
				assert false
			} else {
				assert thrown_value(err).as_object().error_kind()? == .type_error
				assert thrown_value(err).as_object().error_message()?.str() == 'Not an object of type BigInt'
			}
		}
	}
	assert log.calls == 0
	assert bigint_method_call(mut vm, true, value, [Value.from_object(radix)])!.as_string().str() == '2a'
	assert log.calls == 1
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_bigint_to_string_radix_conversion_range_checks_and_abrupt_completion_order() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	value := bigint_method_value('42')
	for radix in [Value.from_i32(1), Value.from_i32(37), Value.from_i32(-2),
		js_null(), Value.from_bool(false), Value.from_bool(true),
		Value.from_f64(math.nan()), Value.from_f64(math.inf(1)),
		Value.from_f64(math.inf(-1))] {
		if _ := bigint_method_call(mut vm, true, value, [radix]) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .range_error
			assert thrown_value(err).as_object().error_message()?.str() == 'Radix must be an integer no less than 2, and no greater than 36'
		}
	}
	assert bigint_method_call(mut vm, true, value, [Value.from_f64(16.9)])!.as_string().str() == '2a'
	assert bigint_method_call(mut vm, true, value, [Value.from_f64(36.9)])!.as_string().str() == '16'
	assert bigint_method_call(mut vm, true, value, [
		Value.from_string(vm.create_string_from_str('16')),
	])!.as_string().str() == '2a'
	for radix in [value, Value.from_symbol(Symbol.create(none, .unique))] {
		if _ := bigint_method_call(mut vm, true, value, [radix]) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
	}
	mut radix := Object.create(vm.realm(), none)
	thrower := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm VM) !Value {
		assert vm.argument(0).as_string().str() == 'number'
		return throw_completion(Value.from_i32(77))
	}, 1, PropertyName.from_str('thrower'), none)
	radix.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
		Value.from_object(thrower.object), 7)
	if _ := bigint_method_call(mut vm, true, value, [Value.from_object(radix)]) {
		assert false
	} else {
		assert thrown_value(err).number == 77
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_bigint_value_of_preserves_primitive_cell_and_wrapper_payload_without_argument_coercion() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for source in ['0', '-1', '123', '1267650600228229401496703205375'] {
		value := bigint_method_value(source)
		wrapper := BigIntObject.create(vm.realm(), value.as_bigint(), parent)
		for receiver in [value, Value.from_object(wrapper.object)] {
			result := bigint_method_call(mut vm, false, receiver, [
				Value.from_symbol(Symbol.create(none, .unique)),
			])!
			assert voidptr(result.as_bigint()) == voidptr(value.as_bigint())
		}
	}
}
