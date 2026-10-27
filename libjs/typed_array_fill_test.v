module libjs

import math

@[heap]
struct TypedFillLog {
mut:
	events []string
}

fn typed_fill_call(mut vm VM, receiver Value, arguments []Value) !Value {
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm VM) !Value {
		return typed_array_prototype_fill(mut vm, PrimitiveObjectPrototypes{})
	}, 1, PropertyName.from_str('fill'), none)
	return call(mut vm, Value.from_object(function.object), receiver, arguments)
}

fn test_typed_array_fill_all_kinds_shared_and_chunked_paths_preserve_offsets_and_numeric_conversion() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for shared_buffer in [false, true] {
		for kind in [BufferElementType.big_int64, .big_uint64, .float16, .float32, .float64, .int8,
			.int16, .int32, .uint8, .uint16, .uint32, .uint8_clamped] {
			size := int(kind.size())
			mut buffer := ArrayBufferObject.create_from_bytes(vm.realm(),
				[]u8{len: size * 302, init: 0x77}, shared_buffer, parent)
			mut array := TypedArray.create(vm.realm(), kind, 0, buffer, parent)
			initialize_typed_array_from_array_buffer(mut vm, mut array, buffer,
				Value.from_i32(size), Value.from_i32(300))!
			value := if kind.is_bigint() {
				Value.from_bigint(string_to_bigint(utf16_string('9007199254740993')) or { panic('invalid BigInt literal') })
			} else {
				Value.from_i32(-257)
			}
			result := typed_fill_call(mut vm, Value.from_object(array.object), [value])!
			assert voidptr(result.as_object()) == voidptr(array.object)
			for index in 0 .. 300 {
				element := typed_array_get_element(array, CanonicalIndex.create(.index, u32(index)))
				if kind.is_bigint() {
					assert element.as_bigint().big_integer.str() == '9007199254740993'
					continue
				}
				expected := match kind {
					.int8 { -1.0 }
					.uint8 { 255.0 }
					.uint16 { 65279.0 }
					.uint32 { 4294967039.0 }
					.uint8_clamped { 0.0 }
					else { -257.0 }
				}

				assert element.number == expected
			}
			assert buffer.read_bytes(0, uint(size)) == []u8{len: size, init: 0x77}
			assert buffer.read_bytes(uint(size * 301), uint(size)) == []u8{len: size, init: 0x77}
		}
	}
}

fn test_typed_array_fill_float_signed_zero_clamping_relative_limits_and_empty_ranges() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for kind in [BufferElementType.float16, .float32, .float64, .uint8_clamped] {
		buffer := ArrayBufferObject.create(mut vm, vm.realm(), kind.size() * 4, parent)!
		array := TypedArray.create(vm.realm(), kind, 4, buffer, parent)
		receiver := Value.from_object(array.object)
		typed_fill_call(mut vm, receiver, [Value.from_f64(2.5),
			Value.from_i32(-3), Value.from_i32(-1)])!
		for index in [1, 2] {
			assert typed_array_get_element(array, CanonicalIndex.create(.index, u32(index))).number == if kind == .uint8_clamped {
				2.0
			} else {
				2.5
			}
		}
		before := buffer.read_bytes(0, buffer.byte_length())
		typed_fill_call(mut vm, receiver, [Value.from_i32(99),
			Value.from_i32(-1), Value.from_i32(-3)])!
		assert buffer.read_bytes(0, buffer.byte_length()) == before
		typed_fill_call(mut vm, receiver, [Value.from_f64(-0.0),
			Value.from_f64(math.inf(-1)), Value.from_f64(math.inf(1))])!
		for index in 0 .. 4 {
			value := typed_array_get_element(array, CanonicalIndex.create(.index, u32(index)))
			assert value.number == 0
			assert math.signbit(value.number) == (kind != .uint8_clamped)
		}
		typed_fill_call(mut vm, receiver, []Value{})!
		assert if kind == .uint8_clamped {
			typed_array_get_element(array, CanonicalIndex.create(.index, 0)).number == 0
		} else {
			math.is_nan(typed_array_get_element(array, CanonicalIndex.create(.index, 0)).number)
		}
	}
}

fn test_typed_array_fill_coercion_order_and_fresh_bounds_even_for_an_empty_range() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for mode in ['shrink', 'grow', 'fixed shrink', 'detach', 'empty detached', 'value throw',
		'start throw', 'end throw', 'initially detached'] {
		mut buffer := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(1), 2, 3, 4], false,
			parent)
		buffer.maximum_byte_length = uint(8)
		mut array := TypedArray.create(vm.realm(), .uint8, 0, buffer, parent)
		initialize_typed_array_from_array_buffer(mut vm, mut array, buffer, Value.from_i32(0), if mode == 'fixed shrink' {
			Value.from_i32(4)
		} else {
			js_undefined()
		})!
		mut log := &TypedFillLog{}
		mut arguments := []Value{}
		for label in ['value', 'start', 'end'] {
			mut object := Object.create(vm.realm(), none)
			convert := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [label, mode, mut buffer, mut log] (mut vm VM) !Value {
				log.events << label
				if mode == '${label} throw' { return throw_completion(Value.from_i32(99)) }
				if label == 'value' {
					if mode == 'grow' { assert buffer.try_resize(8, true)
					 }
					return Value.from_i32(42)
				}
				if label == 'start' {
					if mode in ['shrink', 'fixed shrink'] { assert buffer.try_resize(3, true)
					 }
					return Value.from_i32(if mode == 'grow' { -1 } else { 1 })
				}
				if mode in ['detach', 'empty detached'] {
					detach_array_buffer(mut vm, mut buffer, none)!
				}
				return Value.from_i32(if mode == 'empty detached' { 0 } else { 4 })
			}, 0, PropertyName.from_str('valueOf'), none)
			object.define_direct_property(PropertyName.from_str('valueOf'),
				Value.from_object(convert.object), 7)
			arguments << Value.from_object(object)
		}
		if mode == 'initially detached' { detach_array_buffer(mut vm, mut buffer, none)! }
		if result := typed_fill_call(mut vm, Value.from_object(array.object), arguments) {
			assert mode in ['shrink', 'grow']
				&& voidptr(result.as_object()) == voidptr(array.object)
			if mode == 'shrink' { assert buffer.read_bytes(0, 3) == [u8(1), 42, 42]
			 }
			if mode == 'grow' { assert buffer.read_bytes(0, 8) == [u8(1), 2, 3, 42, 0, 0, 0, 0]
			 }
		} else {
			assert mode !in ['shrink', 'grow']
			if mode.ends_with('throw') {
				assert thrown_value(err).number == 99
			} else {
				assert thrown_value(err).as_object().error_message()?.str().contains('bounds')
			}
		}
		assert log.events == if mode == 'initially detached' {
			[]string{}
		} else if mode == 'value throw' {
			['value']
		} else if mode == 'start throw' {
			['value', 'start']
		} else {
			['value', 'start', 'end']
		}
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
}

fn test_typed_array_fill_content_type_errors_precede_index_conversion_and_do_not_write() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for kind in [BufferElementType.big_int64, .uint8] {
		buffer := ArrayBufferObject.create(mut vm, vm.realm(), kind.size(), parent)!
		array := TypedArray.create(vm.realm(), kind, 1, buffer, parent)
		mut index := Object.create(vm.realm(), none)
		thrower := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm VM) !Value {
			return throw_completion(Value.from_i32(99))
		}, 0, PropertyName.from_str('valueOf'), none)
		index.define_direct_property(PropertyName.from_str('valueOf'),
			Value.from_object(thrower.object), 7)
		value := if kind.is_bigint() {
			Value.from_i32(42)
		} else {
			Value.from_bigint(string_to_bigint(utf16_string('42')) or { panic('invalid BigInt literal') })
		}
		if _ := typed_fill_call(mut vm, Value.from_object(array.object), [value,
			Value.from_object(index)])
		{
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
		assert buffer.read_bytes(0, kind.size()) == []u8{len: int(kind.size())}
	}
}
