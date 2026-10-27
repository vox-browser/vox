module libjs

@[heap]
struct TypedReduceLog {
mut:
	indices []int
	values  []Value
}

fn typed_reduce_call(mut vm VM, name string, receiver Value, arguments []Value) !Value {
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [name] (mut vm VM) !Value {
		if name == 'reduce' {
			return typed_array_prototype_reduce(mut vm, PrimitiveObjectPrototypes{})
		}
		return typed_array_prototype_reduce_right(mut vm, PrimitiveObjectPrototypes{})
	}, 1, PropertyName.from_str(name), none)
	return call(mut vm, Value.from_object(function.object), receiver, arguments)
}

fn test_typed_array_reduce_initial_value_presence_empty_singleton_and_error_ordering() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	mut buffer := ArrayBufferObject.create(mut vm, vm.realm(), 0, parent)!
	empty := TypedArray.create(vm.realm(), .uint8, 0, buffer, parent)
	bytes := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(42)], false, parent)
	singleton := TypedArray.create(vm.realm(), .uint8, 1, bytes, parent)
	callback := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm VM) !Value {
		assert vm.this_value().is_undefined() && vm.argument_count() == 4
		assert vm.argument(0).is_undefined() && vm.argument(1).number == 42
			&& vm.argument(2).number == 0
		return Value.from_i32(43)
	}, 4, PropertyName.from_str('callback'), none)
	for name in ['reduce', 'reduceRight'] {
		function := Value.from_object(callback.object)
		assert typed_reduce_call(mut vm, name, Value.from_object(singleton.object), [
			function,
		])!.number == 42
		assert typed_reduce_call(mut vm, name, Value.from_object(singleton.object), [
			function,
			js_undefined(),
		])!.number == 43
		assert typed_reduce_call(mut vm, name, Value.from_object(empty.object), [
			function,
			js_undefined(),
		])!.is_undefined()
		result := typed_reduce_call(mut vm, name, Value.from_object(empty.object), [
			function,
			Value.from_object(parent),
		])!
		assert voidptr(result.as_object()) == voidptr(parent)
		for arguments in [([]Value{}), [js_undefined()], [function]] {
			if _ := typed_reduce_call(mut vm, name, Value.from_object(empty.object), arguments) {
				assert false
			} else {
				assert thrown_value(err).as_object().error_message()?.str() == match arguments.len {
					0 {
						'TypedArray.prototype.${name}() requires at least one argument'
					}
					else {
						if arguments[0].is_undefined() {
							'undefined is not a function'
						} else {
							'Reduce of empty array with no initial value'
						}
					}
				}
			}
		}
		if _ := typed_reduce_call(mut vm, name, js_null(), []Value{}) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str() == 'ToObject on null or undefined'
		}
	}
	detach_array_buffer(mut vm, mut buffer, none)!
	for name in ['reduce', 'reduceRight'] {
		if _ := typed_reduce_call(mut vm, name, Value.from_object(empty.object), []Value{}) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str().contains('bounds')
		}
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_typed_array_reduce_order_and_accumulator_are_observable_with_and_without_initial_value() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	buffer := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(1), 2, 3], false, parent)
	array := TypedArray.create(vm.realm(), .uint8, 3, buffer, parent)
	for name in ['reduce', 'reduceRight'] {
		for with_initial in [false, true] {
			mut log := &TypedReduceLog{}
			callback := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [array, mut log] (mut vm VM) !Value {
				assert vm.this_value().is_undefined() && vm.argument_count() == 4
				assert voidptr(vm.argument(3).as_object()) == voidptr(array.object)
				index := int(vm.argument(2).number)
				assert vm.argument(1).number == index + 1
				log.indices << index
				return Value.from_f64(vm.argument(0).number * 10 + vm.argument(1).number)
			}, 4, PropertyName.from_str('callback'), none)
			mut arguments := [Value.from_object(callback.object)]
			if with_initial { arguments << Value.from_i32(4) }
			result := typed_reduce_call(mut vm, name, Value.from_object(array.object), arguments)!
			assert result.number == if name == 'reduce' {
				if with_initial {
					4123
				} else {
					123
				}
			} else {
				if with_initial {
					4321
				} else {
					321
				}
			}
			assert log.indices == if name == 'reduce' {
				if with_initial {
					[0, 1, 2]
				} else {
					[1, 2]
				}
			} else {
				if with_initial {
					[2, 1, 0]
				} else {
					[1, 0]
				}
			}
		}
	}
}

fn test_typed_array_reduce_keeps_exact_bigints_and_object_accumulators_without_conversion() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	buffer := ArrayBufferObject.create(mut vm, vm.realm(), 0, parent)!
	mut array := TypedArray.create(vm.realm(), .big_int64, 0, buffer, parent)
	initialize_typed_array_from_list(mut vm, mut array, [
		Value.from_bigint(string_to_bigint(utf16_string('9007199254740993')) or { panic('invalid BigInt literal') }),
		Value.from_bigint(string_to_bigint(utf16_string('-42')) or { panic('invalid BigInt literal') }),
	])!
	for name in ['reduce', 'reduceRight'] {
		callback := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [parent] (mut vm VM) !Value {
			assert voidptr(vm.argument(0).as_object()) == voidptr(parent)
			assert vm.argument(1).is_bigint()
			return vm.argument(0)
		}, 4, PropertyName.from_str('callback'), none)
		result := typed_reduce_call(mut vm, name, Value.from_object(array.object), [
			Value.from_object(callback.object),
			Value.from_object(parent),
		])!
		assert voidptr(result.as_object()) == voidptr(parent)
		identity := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm VM) !Value {
			assert vm.argument(0).is_bigint() && vm.argument(1).is_bigint()
			return vm.argument(0)
		}, 4, PropertyName.from_str('identity'), none)
		big := typed_reduce_call(mut vm, name, Value.from_object(array.object), [
			Value.from_object(identity.object),
		])!
		assert big.as_bigint().big_integer.str() == if name == 'reduce' {
			'9007199254740993'
		} else {
			'-42'
		}
	}
}

fn test_typed_array_reduce_keeps_snapshot_length_and_live_reads_through_mutations_and_abrupt_callbacks() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for name in ['reduce', 'reduceRight'] {
		for mode in ['mutate', 'shrink', 'grow', 'detach', 'throw'] {
			mut buffer := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(1), 2, 3], false,
				parent)
			buffer.maximum_byte_length = uint(8)
			mut array := TypedArray.create(vm.realm(), .uint8, 0, buffer, parent)
			initialize_typed_array_from_array_buffer(mut vm, mut array, buffer, Value.from_i32(0),
				js_undefined())!
			mut log := &TypedReduceLog{}
			callback := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mode, mut array, mut buffer, mut log] (mut vm VM) !Value {
				log.indices << int(vm.argument(2).number)
				log.values << vm.argument(1)
				if log.indices.len == 1 {
					if mode == 'mutate' {
						typed_array_set_element(mut vm, mut array,
							CanonicalIndex.create(.index, 1), Value.from_i32(42))!
					}
					if mode == 'shrink' { assert buffer.try_resize(0, true)
					 }
					if mode == 'grow' { assert buffer.try_resize(6, true)
					 }
					if mode == 'detach' { detach_array_buffer(mut vm, mut buffer, none)! }
				}
				if mode == 'throw' && log.indices.len == 2 {
					return throw_completion(Value.from_i32(99))
				}
				assert vm.argument(0).number == f64(log.indices.len - 1)
				return Value.from_i32(log.indices.len)
			}, 4, PropertyName.from_str('callback'), none)
			if result := typed_reduce_call(mut vm, name, Value.from_object(array.object), [
				Value.from_object(callback.object),
				Value.from_i32(0),
			])
			{
				assert mode != 'throw' && result.number == 3
				assert log.indices == if name == 'reduce' {
					[0, 1, 2]
				} else {
					[2, 1, 0]
				}
				assert log.values[0].number == if name == 'reduce' {
					1
				} else {
					3
				}
				if mode in ['shrink', 'detach'] {
					assert log.values[1].is_undefined() && log.values[2].is_undefined()
				} else {
					assert log.values[1].number == if mode == 'mutate' {
						42
					} else {
						2
					}
					assert log.values[2].number == if name == 'reduce' {
						3
					} else {
						1
					}
				}
			} else {
				assert mode == 'throw' && thrown_value(err).number == 99 && log.indices.len == 2
			}
			assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
		}
	}
}
