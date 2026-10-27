module libjs

import math

fn typed_search_call(mut vm VM, name string, array &TypedArray, arguments []Value) !Value {
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [name] (mut vm VM) !Value {
		return match name {
			'includes' { typed_array_prototype_includes(mut vm, PrimitiveObjectPrototypes{})! }
			'indexOf' { typed_array_prototype_index_of(mut vm, PrimitiveObjectPrototypes{})! }
			else { typed_array_prototype_last_index_of(mut vm, PrimitiveObjectPrototypes{})! }
		}
	}, 1, PropertyName.from_str(name), none)
	return call(mut vm, Value.from_object(function.object), Value.from_object(array.object), arguments)
}

fn test_typed_array_search_distinguishes_nan_signed_zero_and_strict_type_identity() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	empty := ArrayBufferObject.create(mut vm, vm.realm(), 0, parent)!
	mut array := TypedArray.create(vm.realm(), .float64, 0, empty, parent)
	initialize_typed_array_from_list(mut vm, mut array, [Value.from_f64(math.nan()),
		Value.from_f64(-0.0), Value.from_i32(42), Value.from_i32(0), Value.from_i32(42)])!
	assert typed_search_call(mut vm, 'includes', array, [Value.from_f64(math.nan())])!.as_bool()
	assert typed_search_call(mut vm, 'indexOf', array, [Value.from_f64(math.nan())])!.number == -1
	assert typed_search_call(mut vm, 'lastIndexOf', array, [Value.from_f64(math.nan())])!.number == -1
	for zero in [Value.from_i32(0), Value.from_f64(-0.0)] {
		assert typed_search_call(mut vm, 'includes', array, [zero])!.as_bool()
		assert typed_search_call(mut vm, 'indexOf', array, [zero])!.number == 1
		assert typed_search_call(mut vm, 'lastIndexOf', array, [zero])!.number == 3
	}
	assert typed_search_call(mut vm, 'indexOf', array, [Value.from_i32(42)])!.number == 2
	assert typed_search_call(mut vm, 'lastIndexOf', array, [Value.from_i32(42)])!.number == 4
	for value in [Value.from_string(vm.create_string_from_str('42')),
		Value.from_bigint(string_to_bigint(utf16_string('42')) or { panic('invalid BigInt literal') }), js_undefined(), js_null()] {
		assert !typed_search_call(mut vm, 'includes', array, [value])!.as_bool()
		assert typed_search_call(mut vm, 'indexOf', array, [value])!.number == -1
	}
	mut big := TypedArray.create(vm.realm(), .big_int64, 0, empty, parent)
	initialize_typed_array_from_list(mut vm, mut big, [
		Value.from_bigint(string_to_bigint(utf16_string('9007199254740993')) or { panic('invalid BigInt literal') }),
		Value.from_bigint(string_to_bigint(utf16_string('9007199254740992')) or { panic('invalid BigInt literal') }),
	])!
	assert typed_search_call(mut vm, 'indexOf', big, [Value.from_bigint(string_to_bigint(utf16_string('9007199254740993')) or { panic('invalid BigInt literal') })])!.number == 0
	assert !typed_search_call(mut vm, 'includes', big, [Value.from_f64(9007199254740992)])!.as_bool()
}

fn test_typed_array_search_from_index_clamps_infinities_large_indices_and_argument_presence() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	buffer := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(42), 17, 42], false, parent)
	array := TypedArray.create(vm.realm(), .uint8, 3, buffer, parent)
	indices := [js_undefined(), Value.from_f64(math.nan()), Value.from_f64(math.inf(-1)),
		Value.from_f64(math.inf(1)), Value.from_f64(1e100), Value.from_i32(-100), Value.from_i32(-1),
		Value.from_f64(1.9), Value.from_i32(3)]
	forward := [0, 0, 0, -1, -1, 0, 2, 2, -1]
	backward := [0, 0, -1, 2, 2, -1, 2, 0, 2]
	for position, index in indices {
		args := [Value.from_i32(42), index]
		assert typed_search_call(mut vm, 'indexOf', array, args)!.number == forward[position]
		assert typed_search_call(mut vm, 'includes', array, args)!.as_bool() == (forward[position] >= 0)
		assert typed_search_call(mut vm, 'lastIndexOf', array, args)!.number == backward[position]
	}
	assert typed_search_call(mut vm, 'lastIndexOf', array, [Value.from_i32(42)])!.number == 2
	assert typed_search_call(mut vm, 'lastIndexOf', array, [Value.from_i32(42), js_undefined()])!.number == 0
}

fn test_typed_array_search_empty_and_invalid_views_precede_from_index_coercion() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	mut from := Object.create(vm.realm(), none)
	convert := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm VM) !Value {
		return throw_completion(Value.from_i32(99))
	}, 0, PropertyName.from_str('valueOf'), none)
	from.define_direct_property(PropertyName.from_str('valueOf'), Value.from_object(convert.object), 7)
	for mode in ['empty', 'detached', 'out of bounds', 'valid'] {
		mut buffer := ArrayBufferObject.create(mut vm, vm.realm(), if mode == 'empty' {
			uint(0)
		} else {
			uint(2)
		}, parent)!
		buffer.maximum_byte_length = uint(4)
		array := TypedArray.create(vm.realm(), .uint8, if mode == 'empty' { u32(0) } else { u32(2) }, buffer, parent)
		if mode == 'detached' { detach_array_buffer(mut vm, mut buffer, none)! }
		if mode == 'out of bounds' {
			assert buffer.try_resize(1, true)
		}
		for name in ['includes', 'indexOf', 'lastIndexOf'] {
			if result := typed_search_call(mut vm, name, array, [js_undefined(),
				Value.from_object(from)]) {
				assert mode == 'empty'
				if name == 'includes' {
					assert !result.as_bool()
				} else {
					assert result.number == -1
				}
			} else {
				if mode == 'valid' {
					assert thrown_value(err).number == 99
				} else {
					assert mode in ['detached', 'out of bounds'] && thrown_value(err).as_object().error_kind()? == .type_error
				}
			}
		}
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_typed_array_search_keeps_snapshot_length_but_observes_current_validity_after_coercion() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut parent := Object.create(vm.realm(), none)
	parent.define_direct_property(PropertyName.from_number(2), js_undefined(), 7)
	for mode in ['detach', 'shrink', 'grow'] {
		for name in ['includes', 'indexOf', 'lastIndexOf'] {
			mut buffer := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(42), 17, 43], false, parent)
			buffer.maximum_byte_length = uint(8)
			mut array := TypedArray.create(vm.realm(), .uint8, 0, buffer, parent)
			initialize_typed_array_from_array_buffer(mut vm, mut array, buffer, Value.from_i32(0), js_undefined())!
			mut from := Object.create(vm.realm(), none)
			convert := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mut buffer, mode, name] (mut vm VM) !Value {
				if mode == 'detach' { detach_array_buffer(mut vm, mut buffer, none)! }
				if mode == 'shrink' {
					assert buffer.try_resize(1, true)
				}
				if mode == 'grow' {
					assert buffer.try_resize(5, true)
				}
				return Value.from_i32(if name == 'lastIndexOf' { 2 } else { 0 })
			}, 0, PropertyName.from_str('valueOf'), none)
			from.define_direct_property(PropertyName.from_str('valueOf'), Value.from_object(convert.object), 7)
			result := typed_search_call(mut vm, name, array, [js_undefined(), Value.from_object(from)])!
			if name == 'includes' {
				assert result.as_bool() == (mode != 'grow')
			} else {
				assert result.number == -1
			}
		}
	}
}
