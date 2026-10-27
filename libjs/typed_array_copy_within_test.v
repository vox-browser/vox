module libjs

import math

@[heap]
struct TypedCopyWithinLog {
mut:
	events []string
}

fn typed_copy_within_call(mut vm VM, receiver Value, arguments []Value) !Value {
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm VM) !Value {
		return typed_array_prototype_copy_within(mut vm, PrimitiveObjectPrototypes{})
	}, 2, PropertyName.from_str('copyWithin'), none)
	return call(mut vm, Value.from_object(function.object), receiver, arguments)
}

fn test_typed_array_copy_within_moves_raw_encodings_in_both_overlap_directions_for_all_kinds() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for shared_buffer in [false, true] {
		for kind in [BufferElementType.big_int64, .big_uint64, .float16, .float32, .float64, .int8,
			.int16, .int32, .uint8, .uint16, .uint32, .uint8_clamped] {
			size := int(kind.size())
			original := []u8{len: size * 7, init: u8(index * 17 + 0x31)}
			for mode in ['right', 'left', 'self', 'negative', 'infinite', 'empty'] {
				mut buffer := ArrayBufferObject.create_from_bytes(vm.realm(), original,
					shared_buffer, parent)
				mut array := TypedArray.create(vm.realm(), kind, 0, buffer, parent)
				initialize_typed_array_from_array_buffer(mut vm, mut array, buffer,
					Value.from_i32(size), Value.from_i32(5))!
				arguments := match mode {
					'right' { [Value.from_i32(1), Value.from_i32(0),
							Value.from_i32(4)] }
					'left' { [Value.from_i32(0), Value.from_i32(1)] }
					'self' { [Value.from_i32(1), Value.from_i32(1),
							Value.from_i32(4)] }
					'negative' { [Value.from_i32(-2), Value.from_i32(-5),
							Value.from_i32(-3)] }
					'infinite' { [Value.from_f64(math.inf(-1)),
							Value.from_i32(3), Value.from_f64(math.inf(1))] }
					else { [Value.from_i32(0), Value.from_i32(4),
							Value.from_i32(2)] }
				}

				result :=
					typed_copy_within_call(mut vm, Value.from_object(array.object), arguments)!
				assert voidptr(result.as_object()) == voidptr(array.object)
				indices := match mode {
					'right' { [0, 0, 1, 2, 3] }
					'left' { [1, 2, 3, 4, 4] }
					'negative' { [0, 1, 2, 0, 1] }
					'infinite' { [3, 4, 2, 3, 4] }
					else { [0, 1, 2, 3, 4] }
				}

				assert buffer.read_bytes(0, uint(size)) == original[..size]
				assert buffer.read_bytes(uint(size * 6), uint(size)) == original[size * 6..]
				for index, source in indices {
					assert buffer.read_bytes(uint((index + 1) * size), uint(size)) == original[(
						source + 1) * size..(source + 2) * size]
				}
			}
		}
	}
	// A payload NaN must be copied verbatim, rather than canonicalized numerically.
	for shared_buffer in [false, true] {
		mut buffer := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(0x17), 0, 0, 0, 0, 0,
			0xf8, 0x7f, 0, 0, 0, 0, 0, 0, 0, 0x80], shared_buffer, parent)
		array := TypedArray.create(vm.realm(), .float64, 2, buffer, parent)
		typed_copy_within_call(mut vm, Value.from_object(array.object), [
			Value.from_i32(1),
			Value.from_i32(0),
		])!
		assert buffer.read_bytes(8, 8) == [u8(0x17), 0, 0, 0, 0, 0, 0xf8, 0x7f]
	}
}

fn test_typed_array_copy_within_coerces_indices_in_order_and_rechecks_only_a_nonempty_copy() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for mode in ['shrink', 'shrink past start', 'grow', 'detach', 'empty detached', 'fixed shrink',
		'throw', 'initially detached'] {
		mut buffer := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(1), 2, 3, 4], false,
			parent)
		buffer.maximum_byte_length = uint(8)
		mut array := TypedArray.create(vm.realm(), .uint8, 0, buffer, parent)
		initialize_typed_array_from_array_buffer(mut vm, mut array, buffer, Value.from_i32(0), if mode == 'fixed shrink' {
			Value.from_i32(4)
		} else {
			js_undefined()
		})!
		mut log := &TypedCopyWithinLog{}
		mut arguments := []Value{}
		for label in ['target', 'start', 'end'] {
			mut object := Object.create(vm.realm(), none)
			convert := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [label, mode, mut buffer, mut log] (mut vm VM) !Value {
				log.events << label
				if label == 'target' {
					if mode in ['detach', 'empty detached'] {
						detach_array_buffer(mut vm, mut buffer, none)!
					}
					if mode in ['shrink', 'fixed shrink'] { assert buffer.try_resize(3, true)
					 }
					if mode == 'shrink past start' { assert buffer.try_resize(0, true)
					 }
					if mode == 'grow' { assert buffer.try_resize(8, true)
					 }
					return Value.from_i32(1)
				}
				if label == 'start' {
					if mode == 'throw' { return throw_completion(Value.from_i32(99)) }
					return Value.from_i32(0)
				}
				return Value.from_i32(if mode == 'empty detached' { 0 } else { 4 })
			}, 0, PropertyName.from_str('valueOf'), none)
			object.define_direct_property(PropertyName.from_str('valueOf'),
				Value.from_object(convert.object), 7)
			arguments << Value.from_object(object)
		}
		if mode == 'initially detached' { detach_array_buffer(mut vm, mut buffer, none)! }
		if result := typed_copy_within_call(mut vm, Value.from_object(array.object), arguments) {
			assert mode !in ['detach', 'fixed shrink', 'throw', 'initially detached']
			assert voidptr(result.as_object()) == voidptr(array.object)
			if mode == 'shrink' { assert buffer.read_bytes(0, 3) == [u8(1), 1, 2]
			 }
			if mode == 'grow' { assert buffer.read_bytes(0, 8) == [u8(1), 1, 2, 3, 0, 0, 0, 0]
			 }
		} else {
			assert mode in ['detach', 'fixed shrink', 'throw', 'initially detached']
			if mode == 'throw' {
				assert thrown_value(err).number == 99
			} else {
				assert thrown_value(err).as_object().error_message()?.str().contains('bounds')
			}
		}
		assert log.events == if mode == 'initially detached' {
			[]string{}
		} else if mode == 'throw' {
			['target', 'start']
		} else {
			['target', 'start', 'end']
		}
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
}
