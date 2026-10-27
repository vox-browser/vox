module libjs

@[heap]
struct TypedFindLog {
mut:
	indices []int
	values  []Value
}

fn typed_find_call(mut vm VM, name string, receiver Value, arguments []Value) !Value {
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [name] (mut vm VM) !Value {
		return match name {
			'find' { typed_array_prototype_find(mut vm, PrimitiveObjectPrototypes{})! }
			'findIndex' { typed_array_prototype_find_index(mut vm, PrimitiveObjectPrototypes{})! }
			'findLast' { typed_array_prototype_find_last(mut vm, PrimitiveObjectPrototypes{})! }
			else { typed_array_prototype_find_last_index(mut vm, PrimitiveObjectPrototypes{})! }
		}
	}, 1, PropertyName.from_str(name), none)
	return call(mut vm, Value.from_object(function.object), receiver, arguments)
}

fn test_typed_array_find_direction_early_exit_and_value_captured_before_predicate_mutation() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for name in ['find', 'findIndex', 'findLast', 'findLastIndex'] {
		mut buffer := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(17), 42, 43], false,
			parent)
		mut array := TypedArray.create(vm.realm(), .uint8, 3, buffer, parent)
		mut log := &TypedFindLog{}
		callback := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [parent, mut array, mut log] (mut vm VM) !Value {
			assert vm.argument_count() == 3
				&& voidptr(vm.this_value().as_object()) == voidptr(parent)
			assert voidptr(vm.argument(2).as_object()) == voidptr(array.object)
			index := int(vm.argument(1).number)
			log.indices << index
			if index == 1 {
				typed_array_set_element(mut vm, mut array, CanonicalIndex.create(.index, 1),
					Value.from_i32(99))!
				// ToBoolean on an object must succeed without converting its value.
				return Value.from_object(parent)
			}
			return Value.from_i32(0)
		}, 3, PropertyName.from_str('predicate'), none)
		result := typed_find_call(mut vm, name, Value.from_object(array.object), [
			Value.from_object(callback.object),
			Value.from_object(parent),
		])!
		assert result.number == if name.ends_with('Index') {
			1
		} else {
			42
		}
		assert log.indices == if name.starts_with('findLast') {
			[2, 1]
		} else {
			[0, 1]
		}
		assert buffer.read_bytes(0, 3) == [u8(17), 99, 43]
	}
}

fn test_typed_array_find_uses_snapshot_indices_with_live_values_after_resize_or_detach() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for name in ['find', 'findIndex', 'findLast', 'findLastIndex'] {
		for mode in ['grow', 'shrink', 'detach', 'throw'] {
			mut buffer := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(17), 42, 43], false,
				parent)
			buffer.maximum_byte_length = uint(8)
			mut array := TypedArray.create(vm.realm(), .uint8, 0, buffer, parent)
			initialize_typed_array_from_array_buffer(mut vm, mut array, buffer, Value.from_i32(0),
				js_undefined())!
			mut log := &TypedFindLog{}
			callback := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mode, mut buffer, mut log] (mut vm VM) !Value {
				assert vm.this_value().is_undefined()
				log.indices << int(vm.argument(1).number)
				log.values << vm.argument(0)
				if log.indices.len == 1 {
					if mode == 'grow' { assert buffer.try_resize(6, true)
					 }
					if mode == 'shrink' { assert buffer.try_resize(0, true)
					 }
					if mode == 'detach' { detach_array_buffer(mut vm, mut buffer, none)! }
				}
				if mode == 'throw' && log.indices.len == 2 {
					return throw_completion(Value.from_i32(99))
				}
				return Value.from_bool(vm.argument(0).is_undefined())
			}, 3, PropertyName.from_str('predicate'), none)
			descending := name.starts_with('findLast')
			if result := typed_find_call(mut vm, name, Value.from_object(array.object), [
				Value.from_object(callback.object),
			])
			{
				assert mode != 'throw'
				if mode == 'grow' {
					assert log.indices == if descending {
						[2, 1, 0]
					} else {
						[0, 1, 2]
					}
					assert result.number == -1 || result.is_undefined()
				} else {
					assert log.indices == if descending {
						[2, 1]
					} else {
						[0, 1]
					}
					assert log.values[0].number == if descending {
						43
					} else {
						17
					}
					assert log.values[1].is_undefined()
					assert if name.ends_with('Index') {
						result.number == 1
					} else {
						result.is_undefined()
					}
				}
			} else {
				assert mode == 'throw' && thrown_value(err).number == 99 && log.indices.len == 2
			}
			assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
		}
	}
}

fn test_typed_array_find_empty_nonmatching_bigint_and_callback_validation() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	mut buffer := ArrayBufferObject.create(mut vm, vm.realm(), 0, parent)!
	mut big := TypedArray.create(vm.realm(), .big_int64, 0, buffer, parent)
	initialize_typed_array_from_list(mut vm, mut big, [
		Value.from_bigint(string_to_bigint(utf16_string('9007199254740993')) or { panic('invalid BigInt literal') }),
	])!
	empty := TypedArray.create(vm.realm(), .uint8, 0, buffer, parent)
	for name in ['find', 'findIndex', 'findLast', 'findLastIndex'] {
		predicate := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm VM) !Value {
			assert vm.argument(0).as_bigint().big_integer.str() == '9007199254740993'
			return Value.from_bool(true)
		}, 3, PropertyName.from_str('predicate'), none)
		result := typed_find_call(mut vm, name, Value.from_object(big.object), [
			Value.from_object(predicate.object),
		])!
		assert if name.ends_with('Index') {
			result.number == 0
		} else {
			result.as_bigint().big_integer.str() == '9007199254740993'
		}
		empty_result := typed_find_call(mut vm, name, Value.from_object(empty.object), [
			Value.from_object(predicate.object),
		])!
		assert if name.ends_with('Index') {
			empty_result.number == -1
		} else {
			empty_result.is_undefined()
		}
		if _ := typed_find_call(mut vm, name, Value.from_object(empty.object), []Value{}) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str() == 'TypedArray.prototype.${name}() requires at least one argument'
		}
		if _ := typed_find_call(mut vm, name, Value.from_object(empty.object), [
			js_undefined(),
		])
		{
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str() == 'undefined is not a function'
		}
		if _ := typed_find_call(mut vm, name, js_null(), []Value{}) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str() == 'ToObject on null or undefined'
		}
	}
	detach_array_buffer(mut vm, mut buffer, none)!
	for name in ['find', 'findIndex', 'findLast', 'findLastIndex'] {
		if _ := typed_find_call(mut vm, name, Value.from_object(empty.object), []Value{}) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str().contains('bounds')
		}
	}
}
