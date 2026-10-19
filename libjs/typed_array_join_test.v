module libjs

import math

@[heap]
struct TypedJoinLog {
mut:
	calls int
}

fn typed_join_call(mut vm VM, receiver Value, arguments []Value) !Value {
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm VM) !Value {
		return typed_array_prototype_join(mut vm, PrimitiveObjectPrototypes{})
	}, 1, PropertyName.from_str('join'), none)
	return call(mut vm, Value.from_object(function.object), receiver, arguments)
}

fn test_typed_array_join_formats_numbers_bigints_and_preserves_utf16_separator_code_units() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	buffer := ArrayBufferObject.create(mut vm, vm.realm(), 0, parent)!
	mut array := TypedArray.create(vm.realm(), .float64, 0, buffer, parent)
	initialize_typed_array_from_list(mut vm, mut array, [Value.from_i32(42),
		Value.from_f64(-0.0), Value.from_f64(math.nan()), Value.from_f64(math.inf(1)),
		Value.from_f64(math.inf(-1))])!
	receiver := Value.from_object(array.object)
	assert typed_join_call(mut vm, receiver, []Value{})!.as_string().str() == '42,0,NaN,Infinity,-Infinity'
	assert typed_join_call(mut vm, receiver, [Value.from_string(vm.empty_string())])!.as_string().str() == '420NaNInfinity-Infinity'
	assert typed_join_call(mut vm, receiver, [js_null()])!.as_string().str() == '42null0nullNaNnullInfinitynull-Infinity'
	mut big := TypedArray.create(vm.realm(), .big_int64, 0, buffer, parent)
	initialize_typed_array_from_list(mut vm, mut big, [
		Value.from_bigint(string_to_bigint(utf16_string('9007199254740993')) or { panic('invalid BigInt literal') }),
		Value.from_bigint(string_to_bigint(utf16_string('-42')) or { panic('invalid BigInt literal') }),
	])!
	separator := vm.create_string(Utf16String{ data: [u16(0xd800), 0x007c, 0xdc00] })
	result := typed_join_call(mut vm, Value.from_object(big.object), [
		Value.from_string(separator),
	])!
	mut expected := utf16('9007199254740993')
	expected << [u16(0xd800), 0x007c, 0xdc00]
	expected << utf16('-42')
	assert result.as_string().utf16.data == expected
}

fn test_typed_array_join_captures_length_before_separator_conversion_but_reads_live_elements() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for mode in ['grow', 'tracking shrink', 'fixed shrink', 'detach', 'throw', 'initially detached'] {
		mut buffer := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(42), 17, 43, 44], false,
			parent)
		buffer.maximum_byte_length = usize(8)
		mut array := TypedArray.create(vm.realm(), .uint8, 0, buffer, parent)
		initialize_typed_array_from_array_buffer(mut vm, mut array, buffer, Value.from_i32(0), if mode == 'fixed shrink' {
			Value.from_i32(4)
		} else {
			js_undefined()
		})!
		mut log := &TypedJoinLog{}
		mut separator := Object.create(vm.realm(), none)
		convert := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mode, mut buffer, mut log] (mut vm VM) !Value {
			log.calls++
			if mode == 'throw' { return throw_completion(Value.from_i32(99)) }
			if mode == 'grow' { assert buffer.try_resize(8, true)
			 }
			if mode in ['tracking shrink', 'fixed shrink'] { assert buffer.try_resize(2, true)
			 }
			if mode == 'detach' { detach_array_buffer(mut vm, mut buffer, none)! }
			return Value.from_string(vm.create_string_from_str('|'))
		}, 0, PropertyName.from_str('toString'), none)
		separator.define_direct_property(PropertyName.from_str('toString'),
			Value.from_object(convert.object), 7)
		if mode == 'initially detached' { detach_array_buffer(mut vm, mut buffer, none)! }
		if result := typed_join_call(mut vm, Value.from_object(array.object), [
			Value.from_object(separator),
		])
		{
			assert result.as_string().str() == match mode {
				'grow' { '42|17|43|44' }
				'tracking shrink' { '42|17||' }
				else { '|||' }
			}
		} else {
			assert mode in ['throw', 'initially detached']
			if mode == 'throw' {
				assert thrown_value(err).number == 99
			} else {
				assert thrown_value(err).as_object().error_message()?.str().contains('bounds')
			}
		}
		assert log.calls == if mode == 'initially detached' {
			0
		} else {
			1
		}
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
}

fn test_typed_array_join_still_converts_separator_for_empty_arrays_after_receiver_validation() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	buffer := ArrayBufferObject.create(mut vm, vm.realm(), 0, parent)!
	array := TypedArray.create(vm.realm(), .uint8, 0, buffer, parent)
	mut log := &TypedJoinLog{}
	mut separator := Object.create(vm.realm(), none)
	convert := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mut log] (mut vm VM) !Value {
		log.calls++
		return Value.from_string(vm.create_string_from_str('x'))
	}, 0, PropertyName.from_str('toString'), none)
	separator.define_direct_property(PropertyName.from_str('toString'),
		Value.from_object(convert.object), 7)
	assert typed_join_call(mut vm, Value.from_object(array.object), [
		Value.from_object(separator),
	])!.as_string().is_empty()
	assert log.calls == 1
	if _ := typed_join_call(mut vm, Value.from_object(array.object), [
		Value.from_symbol(Symbol.create(none, .unique)),
	])
	{
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .type_error
	}
	if _ := typed_join_call(mut vm, js_null(), [Value.from_object(separator)]) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_message()?.str() == 'ToObject on null or undefined'
	}
	assert log.calls == 1
}
