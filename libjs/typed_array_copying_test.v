module libjs

import math

@[heap]
struct TypedCopyingLog {
mut:
	events  []string
	created ?&TypedArray
	calls   int
}

fn typed_copying_constructor(mut vm VM, kind BufferElementType, parent &Object) &Object {
	constructor := NativeFunction.create_constructor(mut vm, vm.realm(),
		vm.realm().function_prototype, fn (mut vm VM) !Value {
		return js_undefined()
	}, fn [kind, parent] (mut vm VM, target &Object) !&Object {
		getter := fn [parent] (realm &Realm) &Object {
			return parent
		}
		return construct_typed_array(mut vm, kind, target, getter)!.object
	}, 3, PropertyName.from_str('Host'))
	return constructor.object
}

fn typed_copying_call(mut vm VM, name string, receiver Value, arguments []Value, getter TypedArrayIntrinsicConstructorGetter) !Value {
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [name, getter] (mut vm VM) !Value {
		return match name {
			'toReversed' {
				typed_array_prototype_to_reversed(mut vm, PrimitiveObjectPrototypes{}, getter)!
			}
			'toSorted' {
				typed_array_prototype_to_sorted(mut vm, PrimitiveObjectPrototypes{}, getter)!
			}
			else {
				typed_array_prototype_with(mut vm, PrimitiveObjectPrototypes{}, getter)!
			}
		}
	}, 1, PropertyName.from_str(name), none)
	return call(mut vm, Value.from_object(function.object), receiver, arguments)
}

fn test_typed_array_copying_methods_all_kinds_create_independent_fixed_storage_without_species() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for shared_buffer in [false, true] {
		for kind in [BufferElementType.big_int64, .big_uint64, .float16, .float32, .float64, .int8,
			.int16, .int32, .uint8, .uint16, .uint32, .uint8_clamped] {
			buffer := ArrayBufferObject.create_from_bytes(vm.realm(),
				[]u8{len: int(kind.size() * 5), init: 0x77}, shared_buffer, parent)
			mut source := TypedArray.create(vm.realm(), kind, 0, buffer, parent)
			initialize_typed_array_from_array_buffer(mut vm, mut source, buffer,
				Value.from_f64(f64(kind.size())), Value.from_i32(3))!
			for index, number in [3, 1, 2] {
				value := if kind.is_bigint() {
					Value.from_bigint(string_to_bigint(utf16_string(number.str())) or { panic('invalid BigInt literal') })
				} else {
					Value.from_i32(number)
				}
				typed_array_set_element(mut vm, mut source, CanonicalIndex.create(.index,
					u32(index)), value)!
			}
			mut object := source.object
			object.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('constructor'), fn (mut vm VM) !Value {
				return throw_completion(Value.from_i32(99))
			}, unsafe { nil }, attribute_configurable, vm.realm().function_prototype)
			constructor := typed_copying_constructor(mut vm, kind, parent)
			getter := fn [kind, constructor] (realm &Realm, requested BufferElementType) &Object {
				assert requested == kind
				return constructor
			}
			before := buffer.read_bytes(0, buffer.byte_length())
			for name in ['toReversed', 'toSorted', 'with'] {
				replacement := if kind.is_bigint() {
					Value.from_bigint(string_to_bigint(utf16_string('42')) or { panic('invalid BigInt literal') })
				} else {
					Value.from_i32(42)
				}
				arguments := if name == 'with' {
					[Value.from_i32(-2), replacement]
				} else {
					[]Value{}
				}
				result := typed_copying_call(mut vm, name, Value.from_object(source.object),
					arguments, getter)!.as_object().typed_array?
				assert voidptr(result.object) != voidptr(source.object) && result.kind == kind
				assert result.array_length.length() == 3 && result.byte_offset == 0
				assert result.viewed_buffer.is_fixed_length()
					&& !result.viewed_buffer.is_shared_array_buffer()
				assert !result.viewed_buffer.shares_storage_with(buffer)
				assert voidptr(result.object.prototype?) == voidptr(parent)
				expected := match name {
					'toReversed' { [2, 1, 3] }
					'toSorted' { [1, 2, 3] }
					else { [3, 42, 2] }
				}

				for index, number in expected {
					value := typed_array_get_element(result, CanonicalIndex.create(.index,
						u32(index)))
					assert if kind.is_bigint() {
						value.as_bigint().big_integer.str() == number.str()
					} else {
						value.number == number
					}
				}
				assert buffer.read_bytes(0, buffer.byte_length()) == before
			}
		}
	}
}

fn test_typed_array_to_sorted_numeric_nan_signed_zero_bigint_order_and_stable_callbacks() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	buffer := ArrayBufferObject.create(mut vm, vm.realm(), 0, parent)!
	mut source := TypedArray.create(vm.realm(), .float64, 0, buffer, parent)
	initialize_typed_array_from_list(mut vm, mut source, [Value.from_i32(100),
		Value.from_f64(math.nan()), Value.from_i32(20), Value.from_i32(0),
		Value.from_f64(-0.0)])!
	constructor := typed_copying_constructor(mut vm, .float64, parent)
	getter := fn [constructor] (realm &Realm, kind BufferElementType) &Object {
		return constructor
	}
	result := typed_copying_call(mut vm, 'toSorted', Value.from_object(source.object), []Value{},
		getter)!.as_object().typed_array?
	assert math.signbit(typed_array_get_element(result, CanonicalIndex.create(.index, 0)).number)
	assert !math.signbit(typed_array_get_element(result, CanonicalIndex.create(.index, 1)).number)
	assert typed_array_get_element(result, CanonicalIndex.create(.index, 2)).number == 20
	assert typed_array_get_element(result, CanonicalIndex.create(.index, 3)).number == 100
	assert math.is_nan(typed_array_get_element(result, CanonicalIndex.create(.index, 4)).number)
	mut big := TypedArray.create(vm.realm(), .big_int64, 0, buffer, parent)
	initialize_typed_array_from_list(mut vm, mut big, [
		Value.from_bigint(string_to_bigint(utf16_string('9007199254740993')) or { panic('invalid BigInt literal') }),
		Value.from_bigint(string_to_bigint(utf16_string('9007199254740992')) or { panic('invalid BigInt literal') }),
		Value.from_bigint(string_to_bigint(utf16_string('-42')) or { panic('invalid BigInt literal') }),
	])!
	big_constructor := typed_copying_constructor(mut vm, .big_int64, parent)
	big_getter := fn [big_constructor] (realm &Realm, kind BufferElementType) &Object {
		return big_constructor
	}
	big_result := typed_copying_call(mut vm, 'toSorted', Value.from_object(big.object), []Value{},
		big_getter)!.as_object().typed_array?
	for index, expected in ['-42', '9007199254740992', '9007199254740993'] {
		assert typed_array_get_element(big_result, CanonicalIndex.create(.index, u32(index))).as_bigint().big_integer.str() == expected
	}
	callback := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm VM) !Value {
		return Value.from_f64(math.nan())
	}, 2, PropertyName.from_str('compare'), none)
	stable := typed_copying_call(mut vm, 'toSorted', Value.from_object(big.object), [
		Value.from_object(callback.object),
	], big_getter)!.as_object().typed_array?
	for index in 0 .. 3 {
		assert same_value(typed_array_get_element(stable, CanonicalIndex.create(.index, u32(index))), typed_array_get_element(big, CanonicalIndex.create(.index,
			u32(index))))
	}
}

fn test_typed_array_to_sorted_allocates_before_comparisons_snapshots_input_and_retains_result_after_detachment() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for mode in ['mutate', 'detach', 'throw'] {
		mut buffer := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(3), 1, 2], false, parent)
		mut source := TypedArray.create(vm.realm(), .uint8, 3, buffer, parent)
		mut log := &TypedCopyingLog{}
		constructor := NativeFunction.create_constructor(mut vm, vm.realm(),
			vm.realm().function_prototype, fn (mut vm VM) !Value {
			return js_undefined()
		}, fn [parent, mut log] (mut vm VM, target &Object) !&Object {
			log.events << 'construct'
			getter := fn [parent] (realm &Realm) &Object {
				return parent
			}
			array := construct_typed_array(mut vm, .uint8, target, getter)!
			log.created = array
			return array.object
		}, 1, PropertyName.from_str('Host'))
		getter := fn [constructor] (realm &Realm, kind BufferElementType) &Object {
			return constructor.object
		}
		callback := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mode, mut source, mut buffer, mut log] (mut vm VM) !Value {
			assert vm.this_value().is_undefined() && vm.argument_count() == 2
			assert log.events[0] == 'construct'
			log.events << 'compare'
			if log.calls == 0 {
				if mode == 'detach' { detach_array_buffer(mut vm, mut buffer, none)! }
				if mode == 'mutate' {
					typed_array_set_element(mut vm, mut source, CanonicalIndex.create(.index, 0),
						Value.from_i32(99))!
				}
			}
			log.calls++
			if mode == 'throw' { return throw_completion(Value.from_i32(99)) }
			assert vm.argument(0).number in [1.0, 2.0, 3.0]
				&& vm.argument(1).number in [1.0, 2.0, 3.0]
			return Value.from_f64(vm.argument(0).number - vm.argument(1).number)
		}, 2, PropertyName.from_str('compare'), none)
		if result := typed_copying_call(mut vm, 'toSorted', Value.from_object(source.object), [
			Value.from_object(callback.object),
		], getter)
		{
			assert mode != 'throw'
			assert result.as_object().typed_array?.viewed_buffer.read_bytes(0, 3) == [
				u8(1),
				2,
				3,
			]
			if mode == 'mutate' { assert buffer.read_bytes(0, 3) == [u8(99), 1, 2]
			 }
		} else {
			assert mode == 'throw' && thrown_value(err).number == 99
			assert log.created?.viewed_buffer.read_bytes(0, 3) == [u8(0), 0, 0]
		}
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
	constructor := typed_copying_constructor(mut vm, .uint8, parent)
	getter := fn [constructor] (realm &Realm, kind BufferElementType) &Object {
		return constructor
	}
	if _ := typed_copying_call(mut vm, 'toSorted', js_null(), [
		Value.from_i32(17),
	], getter)
	{
		assert false
	} else {
		assert thrown_value(err).as_object().error_message()?.str() == '17 is not a function'
	}
}

fn test_typed_array_with_coerces_value_before_bounds_rejection_and_checks_live_indices_against_captured_length() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for mode in ['negative', 'shrink', 'grow', 'detach', 'invalid', 'value throw'] {
		mut buffer := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(1), 2, 3], false, parent)
		buffer.maximum_byte_length = usize(8)
		mut source := TypedArray.create(vm.realm(), .uint8, 0, buffer, parent)
		initialize_typed_array_from_array_buffer(mut vm, mut source, buffer, Value.from_i32(0),
			js_undefined())!
		mut log := &TypedCopyingLog{}
		mut index := Object.create(vm.realm(), none)
		index_fn := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mode, mut log] (mut vm VM) !Value {
			log.events << 'index'
			return Value.from_i32(if mode == 'negative' {
				-1
			} else if mode == 'grow' {
				4
			} else if mode == 'invalid' || mode == 'value throw' {
				99
			} else {
				0
			})
		}, 0, PropertyName.from_str('valueOf'), none)
		index.define_direct_property(PropertyName.from_str('valueOf'),
			Value.from_object(index_fn.object), 7)
		mut value := Object.create(vm.realm(), none)
		value_fn := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mode, mut buffer, mut log] (mut vm VM) !Value {
			log.events << 'value'
			if mode == 'value throw' { return throw_completion(Value.from_i32(99)) }
			if mode == 'shrink' { assert buffer.try_resize(1, true)
			 }
			if mode == 'grow' { assert buffer.try_resize(5, true)
			 }
			if mode == 'detach' { detach_array_buffer(mut vm, mut buffer, none)! }
			return Value.from_i32(42)
		}, 0, PropertyName.from_str('valueOf'), none)
		value.define_direct_property(PropertyName.from_str('valueOf'),
			Value.from_object(value_fn.object), 7)
		constructor := typed_copying_constructor(mut vm, .uint8, parent)
		getter := fn [constructor, mut log] (realm &Realm, kind BufferElementType) &Object {
			log.events << 'constructor'
			return constructor
		}
		if result := typed_copying_call(mut vm, 'with', Value.from_object(source.object), [
			Value.from_object(index),
			Value.from_object(value),
		], getter)
		{
			assert mode !in ['detach', 'invalid', 'value throw']
			assert result.as_object().typed_array?.viewed_buffer.read_bytes(0, 3) == match mode {
				'negative' { [u8(1), 2, 42] }
				'shrink' { [u8(42), 0, 0] }
				else { [u8(1), 2, 3] }
			}

			assert log.events == ['index', 'value', 'constructor']
		} else {
			if mode == 'value throw' {
				assert thrown_value(err).number == 99
			} else {
				assert thrown_value(err).as_object().error_kind()? == .range_error
			}
			assert log.events == ['index', 'value']
		}
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
}

fn test_typed_array_copying_receiver_bounds_and_with_content_type_errors_precede_allocation() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	mut log := &TypedCopyingLog{}
	constructor := typed_copying_constructor(mut vm, .big_int64, parent)
	getter := fn [constructor, mut log] (realm &Realm, kind BufferElementType) &Object {
		log.calls++
		return constructor
	}
	mut buffer := ArrayBufferObject.create(mut vm, vm.realm(), 8, parent)!
	array := TypedArray.create(vm.realm(), .big_int64, 1, buffer, parent)
	if _ := typed_copying_call(mut vm, 'with', Value.from_object(array.object), [
		Value.from_i32(99),
		Value.from_i32(42),
	], getter)
	{
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .type_error
	}
	for index in [Value.from_i32(-2), Value.from_i32(1), Value.from_f64(math.inf(1)),
		Value.from_f64(math.inf(-1))] {
		if _ := typed_copying_call(mut vm, 'with', Value.from_object(array.object), [
			index,
			Value.from_bigint(string_to_bigint(utf16_string('42')) or { panic('invalid BigInt literal') }),
		], getter)
		{
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .range_error
		}
	}
	detach_array_buffer(mut vm, mut buffer, none)!
	for name in ['toReversed', 'toSorted', 'with'] {
		for receiver in [js_null(), Value.from_object(parent),
			Value.from_object(array.object)] {
			if _ := typed_copying_call(mut vm, name, receiver, []Value{}, getter) {
				assert false
			} else {
				assert thrown_value(err).as_object().error_kind()? == .type_error
			}
		}
	}
	assert log.calls == 0 && vm.running_execution_context() == base
		&& vm.interpreter_stack().depth() == 0
}
