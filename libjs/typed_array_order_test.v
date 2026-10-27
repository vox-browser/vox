module libjs

import math

@[heap]
struct TypedOrderLog {
mut:
	calls int
}

fn typed_order_call(mut vm VM, name string, receiver Value, arguments []Value) !Value {
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [name] (mut vm VM) !Value {
		if name == 'reverse' {
			return typed_array_prototype_reverse(mut vm, PrimitiveObjectPrototypes{})
		}
		return typed_array_prototype_sort(mut vm, PrimitiveObjectPrototypes{})
	}, 0, PropertyName.from_str(name), none)
	return call(mut vm, Value.from_object(function.object), receiver, arguments)
}

fn test_typed_array_reverse_all_kinds_preserves_identity_offsets_and_unpaired_middle_element() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for shared_buffer in [false, true] {
		for kind in [BufferElementType.big_int64, .big_uint64, .float16, .float32, .float64, .int8,
			.int16, .int32, .uint8, .uint16, .uint32, .uint8_clamped] {
			mut buffer := ArrayBufferObject.create_from_bytes(vm.realm(), []u8{len: int(kind.size() * 7), init: 0x17}, shared_buffer, parent)
			mut array := TypedArray.create(vm.realm(), kind, 0, buffer, parent)
			initialize_typed_array_from_array_buffer(mut vm, mut array, buffer, Value.from_f64(f64(kind.size())), Value.from_i32(5))!
			for index, number in [42, 17, 7, 99, 43] {
				value := if kind.is_bigint() {
					Value.from_bigint(string_to_bigint(utf16_string(number.str())) or { panic('invalid BigInt literal') })
				} else {
					Value.from_i32(number)
				}
				typed_array_set_element(mut vm, mut array, CanonicalIndex.create(.index, u32(index)), value)!
			}
			result := typed_order_call(mut vm, 'reverse', Value.from_object(array.object), []Value{})!
			assert voidptr(result.as_object()) == voidptr(array.object)
			for index, number in [43, 99, 7, 17, 42] {
				value := typed_array_get_element(array, CanonicalIndex.create(.index, u32(index)))
				assert if kind.is_bigint() {
					value.as_bigint().big_integer.str() == number.str()
				} else {
					value.number == number
				}
			}
			assert buffer.read_bytes(0, kind.size()) == []u8{len: int(kind.size()), init: 0x17}
			assert buffer.read_bytes(kind.size() * 6, kind.size()) == []u8{len: int(kind.size()), init: 0x17}
		}
	}
}

fn test_typed_array_sort_default_is_numeric_orders_nan_and_signed_zero_and_handles_bigints() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	empty := ArrayBufferObject.create(mut vm, vm.realm(), 0, parent)!
	mut array := TypedArray.create(vm.realm(), .float64, 0, empty, parent)
	initialize_typed_array_from_list(mut vm, mut array, [Value.from_f64(math.nan()),
		Value.from_i32(100), Value.from_i32(20), Value.from_i32(0), Value.from_f64(-0.0),
		Value.from_i32(-42), Value.from_f64(math.nan())])!
	result := typed_order_call(mut vm, 'sort', Value.from_object(array.object), []Value{})!
	assert voidptr(result.as_object()) == voidptr(array.object)
	for index, number in [-42, 0, 0, 20, 100] {
		assert typed_array_get_element(array, CanonicalIndex.create(.index, u32(index))).number == number
	}
	assert math.signbit(typed_array_get_element(array, CanonicalIndex.create(.index, 1)).number)
	assert !math.signbit(typed_array_get_element(array, CanonicalIndex.create(.index, 2)).number)
	for index in [5, 6] {
		assert math.is_nan(typed_array_get_element(array, CanonicalIndex.create(.index, u32(index))).number)
	}
	mut big := TypedArray.create(vm.realm(), .big_int64, 0, empty, parent)
	initialize_typed_array_from_list(mut vm, mut big, [
		Value.from_bigint(string_to_bigint(utf16_string('9007199254740993')) or { panic('invalid BigInt literal') }),
		Value.from_bigint(string_to_bigint(utf16_string('-1')) or { panic('invalid BigInt literal') }),
		Value.from_bigint(string_to_bigint(utf16_string('9007199254740992')) or { panic('invalid BigInt literal') }),
	])!
	typed_order_call(mut vm, 'sort', Value.from_object(big.object), []Value{})!
	for index, number in ['-1', '9007199254740992', '9007199254740993'] {
		assert typed_array_get_element(big, CanonicalIndex.create(.index, u32(index))).as_bigint().big_integer.str() == number
	}
}

fn test_typed_array_sort_callback_errors_precede_receiver_checks_and_leave_storage_unwritten() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for receiver in [js_null(), js_undefined()] {
		if _ := typed_order_call(mut vm, 'sort', receiver, [Value.from_i32(17)]) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str() == '17 is not a function'
		}
		if _ := typed_order_call(mut vm, 'sort', receiver, []Value{}) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str() == 'ToObject on null or undefined'
		}
	}
	mut buffer := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(3), 1, 2], false, parent)
	array := TypedArray.create(vm.realm(), .uint8, 3, buffer, parent)
	callback := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm VM) !Value {
		return throw_completion(Value.from_i32(99))
	}, 2, PropertyName.from_str('compare'), none)
	if _ := typed_order_call(mut vm, 'sort', Value.from_object(array.object), [Value.from_object(callback.object)]) {
		assert false
	} else {
		assert thrown_value(err).number == 99
	}
	assert buffer.read_bytes(0, 3) == [u8(3), 1, 2]
	detach_array_buffer(mut vm, mut buffer, none)!
	if _ := typed_order_call(mut vm, 'sort', Value.from_object(array.object), [Value.from_i32(17)]) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_message()?.str() == '17 is not a function'
	}
	for name in ['sort', 'reverse'] {
		if _ := typed_order_call(mut vm, name, Value.from_object(array.object), []Value{}) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_typed_array_sort_snapshots_elements_before_callback_mutations_and_writes_only_live_indices() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for mode in ['mutate', 'shrink', 'detach', 'nan', 'bigint result', 'conversion throws'] {
		mut buffer := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(3), 1, 2], false, parent)
		buffer.maximum_byte_length = uint(8)
		mut array := TypedArray.create(vm.realm(), .uint8, 0, buffer, parent)
		initialize_typed_array_from_array_buffer(mut vm, mut array, buffer, Value.from_i32(0), js_undefined())!
		mut log := &TypedOrderLog{}
		callback := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mode, mut array, mut buffer, mut log] (mut vm VM) !Value {
			assert vm.this_value().is_undefined() && vm.argument_count() == 2
			assert vm.argument(0).number in [1.0, 2.0, 3.0] && vm.argument(1).number in [
				1.0,
				2.0,
				3.0,
			]
			log.calls++
			if log.calls == 1 {
				if mode == 'mutate' {
					typed_array_set_element(mut vm, mut array, CanonicalIndex.create(.index, 0), Value.from_i32(99))!
				}
				if mode == 'shrink' {
					assert buffer.try_resize(1, true)
				}
				if mode == 'detach' { detach_array_buffer(mut vm, mut buffer, none)! }
			}
			if mode == 'nan' { return Value.from_f64(math.nan()) }
			if mode == 'bigint result' {
				return Value.from_bigint(string_to_bigint(utf16_string('1')) or { panic('invalid fixture') })
			}
			if mode == 'conversion throws' {
				mut object := Object.create(vm.realm(), none)
				convert := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm VM) !Value {
					return throw_completion(Value.from_i32(17))
				}, 0, PropertyName.from_str('valueOf'), none)
				object.define_direct_property(PropertyName.from_str('valueOf'), Value.from_object(convert.object), 7)
				return Value.from_object(object)
			}
			return Value.from_f64(vm.argument(0).number - vm.argument(1).number)
		}, 2, PropertyName.from_str('compare'), none)
		if result := typed_order_call(mut vm, 'sort', Value.from_object(array.object), [Value.from_object(callback.object)]) {
			assert voidptr(result.as_object()) == voidptr(array.object)
			if mode == 'detach' {
				assert buffer.is_detached()
			}
			if mode == 'shrink' {
				assert buffer.read_bytes(0, 1) == [u8(1)]
			}
			if mode == 'mutate' {
				assert buffer.read_bytes(0, 3) == [u8(1), 2, 3]
			}
			if mode == 'nan' {
				assert buffer.read_bytes(0, 3) == [u8(3), 1, 2]
			}
		} else {
			assert mode in ['bigint result', 'conversion throws']
			if mode == 'conversion throws' {
				assert thrown_value(err).number == 17
			} else {
				assert thrown_value(err).as_object().error_kind()? == .type_error
			}
			assert buffer.read_bytes(0, 3) == [u8(3), 1, 2]
		}
		assert log.calls > 0 && vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
}
