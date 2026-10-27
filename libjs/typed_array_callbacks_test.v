module libjs

@[heap]
struct TypedCallbackLog {
mut:
	indices []int
	values  []Value
}

fn typed_callback_call(mut vm VM, name string, receiver Value, arguments []Value) !Value {
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [name] (mut vm VM) !Value {
		return match name {
			'every' { typed_array_prototype_every(mut vm, PrimitiveObjectPrototypes{})! }
			'some' { typed_array_prototype_some(mut vm, PrimitiveObjectPrototypes{})! }
			else { typed_array_prototype_for_each(mut vm, PrimitiveObjectPrototypes{})! }
		}
	}, 1, PropertyName.from_str(name), none)
	return call(mut vm, Value.from_object(function.object), receiver, arguments)
}

fn test_typed_array_callback_errors_follow_receiver_and_bounds_validation_even_when_empty() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	mut buffer := ArrayBufferObject.create(mut vm, vm.realm(), 0, parent)!
	array := TypedArray.create(vm.realm(), .uint8, 0, buffer, parent)
	for name in ['every', 'some', 'forEach'] {
		for receiver in [js_null(), Value.from_object(parent)] {
			if _ := typed_callback_call(mut vm, name, receiver, []Value{}) {
				assert false
			} else {
				assert thrown_value(err).as_object().error_message()?.str() == if receiver.is_null() {
					'ToObject on null or undefined'
				} else {
					'Not an object of type TypedArray'
				}
			}
		}
		for arguments in [([]Value{}), [js_undefined()], [Value.from_i32(17)]] {
			if _ := typed_callback_call(mut vm, name, Value.from_object(array.object), arguments) {
				assert false
			} else {
				assert thrown_value(err).as_object().error_message()?.str() == if arguments.len == 0 {
					'TypedArray.prototype.${name}() requires at least one argument'
				} else if arguments[0].is_undefined() {
					'undefined is not a function'
				} else {
					'17 is not a function'
				}
			}
		}
	}
	detach_array_buffer(mut vm, mut buffer, none)!
	for name in ['every', 'some', 'forEach'] {
		if _ := typed_callback_call(mut vm, name, Value.from_object(array.object), []Value{}) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str() == "TypedArray contains a property which references a value at an index not contained within its buffer's bounds"
		}
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_typed_array_callbacks_deliver_exact_elements_indices_receiver_and_empty_results() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for shared_buffer in [false, true] {
		for kind in [BufferElementType.big_int64, .big_uint64, .float16, .float32, .float64, .int8,
			.int16, .int32, .uint8, .uint16, .uint32, .uint8_clamped] {
			mut buffer := ArrayBufferObject.create_from_bytes(vm.realm(),
				[]u8{len: int(kind.size() * 3)}, shared_buffer, parent)
			mut array := TypedArray.create(vm.realm(), kind, 3, buffer, parent)
			for index, number in [42, 17, 43] {
				value := if kind.is_bigint() {
					Value.from_bigint(string_to_bigint(utf16_string(number.str())) or { panic('invalid BigInt literal') })
				} else {
					Value.from_i32(number)
				}
				typed_array_set_element(mut vm, mut array,
					CanonicalIndex.create(.index, u32(index)), value)!
			}
			for name in ['every', 'some', 'forEach'] {
				mut log := &TypedCallbackLog{}
				callback := NativeFunction.create(mut vm, vm.realm(),
					vm.realm().function_prototype, fn [name, kind, array, parent, mut log] (mut vm VM) !Value {
					assert vm.argument_count() == 3
						&& voidptr(vm.this_value().as_object()) == voidptr(parent)
					assert voidptr(vm.argument(2).as_object()) == voidptr(array.object)
					index := int(vm.argument(1).number)
					value := vm.argument(0)
					assert if kind.is_bigint() { value.as_bigint().big_integer.str() == [
							42,
							17,
							43,
						][index].str() } else { value.number == [42, 17, 43][index] }
					log.indices << index
					return Value.from_bool(name == 'every')
				}, 3, PropertyName.from_str('callback'), none)
				arguments := [Value.from_object(callback.object),
					Value.from_object(parent)]
				result := typed_callback_call(mut vm, name, Value.from_object(array.object),
					arguments)!
				assert log.indices == [0, 1, 2]
				assert if name == 'forEach' {
					result.is_undefined()
				} else {
					result.as_bool() == (name == 'every')
				}
				// A valid zero-length view must check the callback but never invoke it.
				empty := TypedArray.create(vm.realm(), kind, 0, buffer, parent)
				assert same_value(typed_callback_call(mut vm, name,
					Value.from_object(empty.object), arguments)!, result)
				assert log.indices == [0, 1, 2]
			}
		}
	}
}

fn test_typed_array_predicate_truthiness_short_circuits_without_object_conversion() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	buffer := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(1), 2, 3], false, parent)
	array := TypedArray.create(vm.realm(), .uint8, 3, buffer, parent)
	mut truthy := Object.create(vm.realm(), none)
	conversion := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm VM) !Value {
		return throw_completion(Value.from_i32(99))
	}, 0, PropertyName.from_str('valueOf'), none)
	truthy.define_direct_property(PropertyName.from_str('valueOf'),
		Value.from_object(conversion.object), 7)
	for name in ['every', 'some'] {
		mut log := &TypedCallbackLog{}
		callback := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [name, truthy, mut log] (mut vm VM) !Value {
			assert vm.this_value().is_undefined()
			index := int(vm.argument(1).number)
			log.indices << index
			if (index == 1) == (name == 'some') { return Value.from_object(truthy) }
			return Value.from_i32(0)
		}, 3, PropertyName.from_str('callback'), none)
		assert typed_callback_call(mut vm, name, Value.from_object(array.object), [
			Value.from_object(callback.object),
		])!.as_bool() == (name == 'some')
		assert log.indices == [0, 1]
	}
}

fn test_typed_array_callbacks_capture_length_but_read_mutated_shrunk_or_detached_elements() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for name in ['every', 'some', 'forEach'] {
		for mode in ['mutate', 'shrink', 'grow', 'detach', 'throw'] {
			for tracking in [false, true] {
				mut buffer := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(1), 2, 3], false,
					parent)
				buffer.maximum_byte_length = uint(8)
				mut array := TypedArray.create(vm.realm(), .uint8, 0, buffer, parent)
				length := if tracking { js_undefined() } else { Value.from_i32(3) }
				initialize_typed_array_from_array_buffer(mut vm, mut array, buffer,
					Value.from_i32(0), length)!
				mut log := &TypedCallbackLog{}
				callback := NativeFunction.create(mut vm, vm.realm(),
					vm.realm().function_prototype, fn [name, mode, mut array, mut buffer, mut log] (mut vm VM) !Value {
					index := int(vm.argument(1).number)
					log.indices << index
					log.values << vm.argument(0)
					if index == 0 {
						if mode == 'mutate' {
							typed_array_set_element(mut vm, mut array, CanonicalIndex.create(.index,
								1), Value.from_i32(42))!
						}
						if mode == 'shrink' { assert buffer.try_resize(1, true)
						 }
						if mode == 'grow' { assert buffer.try_resize(5, true)
						 }
						if mode == 'detach' { detach_array_buffer(mut vm, mut buffer, none)! }
					}
					if mode == 'throw' && index == 1 { return throw_completion(Value.from_i32(99)) }
					return Value.from_bool(name == 'every')
				}, 3, PropertyName.from_str('callback'), none)
				if _ := typed_callback_call(mut vm, name, Value.from_object(array.object), [
					Value.from_object(callback.object),
				])
				{
					assert mode != 'throw' && log.indices == [0, 1, 2]
					assert log.values == match mode {
						'shrink', 'detach' { [Value.from_i32(1),
								js_undefined(), js_undefined()] }
						'mutate' { [Value.from_i32(1), Value.from_i32(42),
								Value.from_i32(3)] }
						else { [Value.from_i32(1), Value.from_i32(2),
								Value.from_i32(3)] }
					}
				} else {
					assert mode == 'throw' && thrown_value(err).number == 99
						&& log.indices == [0, 1]
				}
				assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
			}
		}
	}
}
