module libjs

fn typed_iterator_call(mut vm VM, name string, receiver Value, iterator_prototype &Object) !Value {
	prototypes := PrimitiveObjectPrototypes{
		number: fn (realm &Realm) &Object {
			return realm.data_view_prototype_record()
		}
		bigint: fn (realm &Realm) &Object {
			return realm.data_view_prototype_record()
		}
		string: fn (realm &Realm) &Object {
			return realm.data_view_prototype_record()
		}
	}
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [name, prototypes, iterator_prototype] (mut vm VM) !Value {
		return match name {
			'entries' { typed_array_prototype_entries(mut vm, prototypes, iterator_prototype)! }
			'keys' { typed_array_prototype_keys(mut vm, prototypes, iterator_prototype)! }
			else { typed_array_prototype_values(mut vm, prototypes, iterator_prototype)! }
		}
	}, 0, PropertyName.from_str(name), none)
	return call(mut vm, Value.from_object(function.object), receiver, []Value{})
}

fn test_typed_array_iterator_methods_yield_exact_all_kind_values_keys_and_real_entry_arrays() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	prototype := ArrayIteratorPrototype.create(mut vm, vm.realm(), parent, parent, parent)
	for shared_buffer in [false, true] {
		for kind in [BufferElementType.big_int64, .big_uint64, .float16, .float32, .float64, .int8,
			.int16, .int32, .uint8, .uint16, .uint32, .uint8_clamped] {
			buffer := ArrayBufferObject.create_from_bytes(vm.realm(),
				[]u8{len: int(kind.size() * 2)}, shared_buffer, parent)
			mut array := TypedArray.create(vm.realm(), kind, 2, buffer, parent)
			for index, number in [42, 17] {
				value := if kind.is_bigint() {
					Value.from_bigint(string_to_bigint(utf16_string(number.str())) or { panic('invalid BigInt literal') })
				} else {
					Value.from_i32(number)
				}
				typed_array_set_element(mut vm, mut array,
					CanonicalIndex.create(.index, u32(index)), value)!
			}
			for name in ['entries', 'keys', 'values'] {
				result := typed_iterator_call(mut vm, name, Value.from_object(array.object),
					prototype.object)!
				iterator := result.as_object().array_iterator?
				assert voidptr(result.as_object().prototype?) == voidptr(prototype.object)
				assert voidptr(iterator.array.as_object()) == voidptr(array.object)
					&& iterator.index == 0
				mut record := get_iterator_direct(mut vm, result.as_object())!
				values := iterator_to_list(mut vm, mut record)!
				assert values.len == 2 && record.done && iterator.array.is_undefined()
				for index, value in values {
					if name == 'keys' {
						assert value.number == f64(index)
						continue
					}
					element := if name == 'entries' {
						pair := value.as_object()
						assert pair.array_object?.length == 2
							&& voidptr(pair.prototype?) == voidptr(parent)
						assert pair.get(mut vm, PropertyName.from_number(0))!.number == f64(index)
						pair.get(mut vm, PropertyName.from_number(1))!
					} else {
						value
					}
					assert if kind.is_bigint() {
						element.as_bigint().big_integer.str() == [42, 17][index].str()
					} else {
						element.number == [42, 17][index]
					}
				}
			}
		}
	}
}

fn test_typed_array_iterator_creation_requires_own_brand_and_valid_buffer_before_allocating() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	mut buffer := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(42), 17], false, parent)
	buffer.maximum_byte_length = usize(8)
	array := TypedArray.create(vm.realm(), .uint8, 2, buffer, parent)
	fake := Object.create(vm.realm(), array.object)
	for name in ['entries', 'keys', 'values'] {
		for receiver in [js_null(), js_undefined(), Value.from_i32(42),
			Value.from_bool(true), Value.from_string(vm.create_string_from_str('42')),
			Value.from_object(fake)] {
			if _ := typed_iterator_call(mut vm, name, receiver, parent) {
				assert false
			} else {
				assert thrown_value(err).as_object().error_message()?.str() == if receiver.is_nullish() {
					'ToObject on null or undefined'
				} else {
					'Not an object of type TypedArray'
				}
			}
		}
	}
	assert buffer.try_resize(1, true)
	for name in ['entries', 'keys', 'values'] {
		if _ := typed_iterator_call(mut vm, name, Value.from_object(array.object), parent) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str().contains('bounds')
		}
	}
	assert buffer.try_resize(2, true)
	detach_array_buffer(mut vm, mut buffer, none)!
	for name in ['entries', 'keys', 'values'] {
		if _ := typed_iterator_call(mut vm, name, Value.from_object(array.object), parent) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str().contains('bounds')
		}
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_typed_array_iterators_see_live_growth_recover_from_bounds_errors_and_remain_exhausted() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for name in ['entries', 'keys', 'values'] {
		mut buffer := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(42), 17], false, parent)
		buffer.maximum_byte_length = usize(8)
		mut array := TypedArray.create(vm.realm(), .uint8, 0, buffer, parent)
		initialize_typed_array_from_array_buffer(mut vm, mut array, buffer, Value.from_i32(1),
			js_undefined())!
		result := typed_iterator_call(mut vm, name, Value.from_object(array.object), parent)!
		mut iterator := result.as_object().array_iterator?
		first := iterator.next(mut vm, parent)!
		assert !first.done && iterator.index == 1
		assert buffer.try_resize(0, true)
		assert array.byte_offset == 1
		assert is_typed_array_out_of_bounds(make_typed_array_with_buffer_witness_record(array,
			.seq_cst))
		assert !iterator.array.is_undefined()
		if _ := iterator.next(mut vm, parent) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str().contains('bounds')
		}
		assert iterator.index == 1 && !iterator.array.is_undefined()
		assert buffer.try_resize(4, true)
		typed_array_set_element(mut vm, mut array, CanonicalIndex.create(.index, 1),
			Value.from_i32(43))!
		next := iterator.next(mut vm, parent)!
		assert !next.done && iterator.index == 2
		if name == 'keys' { assert next.value.number == 1
		 }
		if name == 'values' { assert next.value.number == 43
		 }
		if name == 'entries' { assert create_list_from_array_like(mut vm, next.value, unsafe { nil })! == [
				Value.from_i32(1),
				Value.from_i32(43),
			]
		 }
		assert !iterator.next(mut vm, parent)!.done
		done := iterator.next(mut vm, parent)!
		assert done.done && iterator.array.is_undefined()
		assert buffer.try_resize(8, true)
		assert iterator.next(mut vm, parent)!.done
		detach_array_buffer(mut vm, mut buffer, none)!
		assert iterator.next(mut vm, parent)!.done
	}
}
