module libjs

import math

// Test-only native entry points. The actual intrinsic graph remains pending.
fn typed_access_call(mut vm VM, name string, receiver Value, arguments []Value) !Value {
	prototypes := PrimitiveObjectPrototypes{
		number: fn (realm &Realm) &Object { return realm.data_view_prototype_record() }
		bigint: fn (realm &Realm) &Object { return realm.data_view_prototype_record() }
		string: fn (realm &Realm) &Object { return realm.data_view_prototype_record() }
	}
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [name, prototypes] (mut vm VM) !Value {
		return match name {
			'at' { typed_array_prototype_at(mut vm, prototypes)! }
			'buffer' { typed_array_prototype_buffer_getter(mut vm, prototypes)! }
			'byteLength' { typed_array_prototype_byte_length_getter(mut vm, prototypes)! }
			'byteOffset' { typed_array_prototype_byte_offset_getter(mut vm, prototypes)! }
			'length' { typed_array_prototype_length_getter(mut vm, prototypes)! }
			else { typed_array_prototype_to_string_tag_getter(mut vm)! }
		}
	}, 0, PropertyName.from_str(name), none)
	return call(mut vm, Value.from_object(function.object), receiver, arguments)
}

fn test_typed_array_accessors_follow_live_fixed_tracking_shared_and_detached_witnesses() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for shared_buffer in [false, true] {
		mut buffer := ArrayBufferObject.create_from_bytes(vm.realm(), []u8{len: 9}, shared_buffer, parent)
		buffer.maximum_byte_length = usize(16)
		mut fixed := TypedArray.create(vm.realm(), .uint16, 0, buffer, parent)
		mut tracking := TypedArray.create(vm.realm(), .uint16, 0, buffer, parent)
		initialize_typed_array_from_array_buffer(mut vm, mut fixed, buffer, Value.from_i32(2), Value.from_i32(3))!
		initialize_typed_array_from_array_buffer(mut vm, mut tracking, buffer, Value.from_i32(2), js_undefined())!
		for position, size in [9, 12, 5, 2, 1, 8] {
			assert buffer.try_resize(usize(size), true)
			for variant, array in [fixed, tracking] {
				receiver := Value.from_object(array.object)
				length := if variant == 0 {
					[3, 3, 0, 0, 0, 3][position]
				} else {
					[3, 5, 1, 0, 0, 3][position]
				}
				offset := if variant == 0 {
					[2, 2, 0, 0, 0, 2][position]
				} else {
					[2, 2, 2, 2, 0, 2][position]
				}
				assert typed_access_call(mut vm, 'length', receiver, []Value{})!.number == f64(length)
				assert typed_access_call(mut vm, 'byteLength', receiver, []Value{})!.number == f64(length * 2)
				assert typed_access_call(mut vm, 'byteOffset', receiver, []Value{})!.number == f64(offset)
				assert voidptr(typed_access_call(mut vm, 'buffer', receiver, []Value{})!.as_object()) == voidptr(buffer.object)
			}
		}
		if !shared_buffer {
			detach_array_buffer(mut vm, mut buffer, none)!
			for array in [fixed, tracking] {
				receiver := Value.from_object(array.object)
				for name in ['length', 'byteLength', 'byteOffset'] {
					assert typed_access_call(mut vm, name, receiver, []Value{})!.number == 0
				}
				assert voidptr(typed_access_call(mut vm, 'buffer', receiver, []Value{})!.as_object()) == voidptr(buffer.object)
			}
		}
	}
}

fn test_typed_array_accessors_preserve_to_object_errors_and_require_own_internal_slots() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	buffer := ArrayBufferObject.create(mut vm, vm.realm(), 2, parent)!
	array := TypedArray.create(vm.realm(), .uint8, 2, buffer, parent)
	mut fake := Object.create(vm.realm(), array.object)
	fake.class_name = 'Uint8Array'
	receivers := [js_null(), js_undefined(), Value.from_bool(true), Value.from_i32(42),
		Value.from_string(vm.create_string_from_str('42')),
		Value.from_bigint(string_to_bigint(utf16_string('42')) or { panic('invalid BigInt literal') }),
		Value.from_symbol(Symbol.create(none, .unique)), Value.from_object(fake)]
	for receiver in receivers {
		for name in ['buffer', 'byteLength', 'byteOffset', 'length', 'at'] {
			if _ := typed_access_call(mut vm, name, receiver, []Value{}) {
				assert false
			} else {
				assert thrown_value(err).as_object().error_kind()? == .type_error
				assert thrown_value(err).as_object().error_message()?.str() == if receiver.is_nullish() {
					'ToObject on null or undefined'
				} else {
					'Not an object of type TypedArray'
				}
			}
		}
		assert typed_access_call(mut vm, 'tag', receiver, []Value{})!.is_undefined()
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_typed_array_to_string_tag_names_all_kinds_without_validating_buffer_bounds() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for kind in [BufferElementType.big_int64, .big_uint64, .float16, .float32, .float64, .int8,
		.int16, .int32, .uint8, .uint16, .uint32, .uint8_clamped] {
		mut buffer := ArrayBufferObject.create(mut vm, vm.realm(), kind.size(), parent)!
		array := TypedArray.create(vm.realm(), kind, 1, buffer, parent)
		detach_array_buffer(mut vm, mut buffer, none)!
		assert typed_access_call(mut vm, 'tag', Value.from_object(array.object), []Value{})!.as_string().str() == kind.typed_array_name()
	}
}

fn test_typed_array_at_resolves_relative_indices_and_preserves_bigint_elements() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	buffer := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(42), 17, 43], false, parent)
	array := TypedArray.create(vm.realm(), .uint8, 3, buffer, parent)
	receiver := Value.from_object(array.object)
	for position, index in [0.0, 1.9, -1.0, -3.0, -2.9] {
		assert typed_access_call(mut vm, 'at', receiver, [Value.from_f64(index)])!.number == [
			42,
			17,
			43,
			42,
			17,
		][position]
	}
	for index in [3.0, -4.0, math.inf(1), math.inf(-1)] {
		assert typed_access_call(mut vm, 'at', receiver, [Value.from_f64(index)])!.is_undefined()
	}
	assert typed_access_call(mut vm, 'at', receiver, []Value{})!.number == 42
	assert typed_access_call(mut vm, 'at', receiver, [Value.from_f64(math.nan())])!.number == 42
	mut big := TypedArray.create(vm.realm(), .big_int64, 0, buffer, parent)
	initialize_typed_array_from_list(mut vm, mut big, [Value.from_bigint(string_to_bigint(utf16_string('-42')) or { panic('invalid BigInt literal') })])!
	assert typed_access_call(mut vm, 'at', Value.from_object(big.object), [Value.from_i32(-1)])!.as_bigint().big_integer.str() == '-42'
	for index in [Value.from_bigint(string_to_bigint(utf16_string('0')) or { panic('invalid BigInt literal') }),
		Value.from_symbol(Symbol.create(none, .unique))] {
		if _ := typed_access_call(mut vm, 'at', receiver, [index]) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
	}
}

fn test_typed_array_at_snapshots_length_before_index_coercion_and_reads_current_storage() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for mode in ['shrink', 'grow', 'detach', 'initially detached', 'throw'] {
		mut buffer := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(42), 17, 43], false, parent)
		buffer.maximum_byte_length = usize(8)
		mut array := TypedArray.create(vm.realm(), .uint8, 0, buffer, parent)
		initialize_typed_array_from_array_buffer(mut vm, mut array, buffer, Value.from_i32(0), js_undefined())!
		mut index := Object.create(vm.realm(), none)
		method := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mut buffer, mode] (mut vm VM) !Value {
			assert mode != 'initially detached'
			if mode == 'throw' { return throw_completion(Value.from_i32(99)) }
			if mode == 'detach' { detach_array_buffer(mut vm, mut buffer, none)! }
			if mode == 'shrink' {
				assert buffer.try_resize(1, true)
			}
			if mode == 'grow' {
				assert buffer.try_resize(5, true)
			}
			return Value.from_i32(-1)
		}, 0, PropertyName.from_str('valueOf'), none)
		index.define_direct_property(PropertyName.from_str('valueOf'), Value.from_object(method.object), 7)
		if mode == 'initially detached' { detach_array_buffer(mut vm, mut buffer, none)! }
		if result := typed_access_call(mut vm, 'at', Value.from_object(array.object), [Value.from_object(index)]) {
			assert mode in ['shrink', 'grow', 'detach']
			if mode == 'grow' {
				assert result.number == 43
			} else {
				assert result.is_undefined()
			}
		} else {
			if mode == 'throw' {
				assert thrown_value(err).number == 99
			} else {
				assert mode == 'initially detached' && thrown_value(err).as_object().error_kind()? == .type_error
			}
		}
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
}
