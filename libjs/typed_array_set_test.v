module libjs

import math

@[heap]
struct TypedSetLog {
mut:
	events []string
}

fn typed_set_call(mut vm VM, target &TypedArray, arguments []Value, parent &Object) !Value {
	getter := fn [parent] (realm &Realm) &Object {
		return parent
	}
	prototypes := PrimitiveObjectPrototypes{
		number: getter
		bigint: getter
		string: getter
	}
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [prototypes] (mut vm VM) !Value {
		return typed_array_prototype_set(mut vm, prototypes)
	}, 1, PropertyName.from_str('set'), none)
	return call(mut vm, Value.from_object(function.object), Value.from_object(target.object),
		arguments)
}

fn test_typed_array_set_all_kinds_preserve_bytes_and_snapshot_aliased_storage() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for kind in [BufferElementType.big_int64, .big_uint64, .float16, .float32, .float64, .int8,
		.int16, .int32, .uint8, .uint16, .uint32, .uint8_clamped] {
		for shared_buffer in [false, true] {
			mut bytes := []u8{len: int(kind.size() * 6)}
			for i in 0 .. bytes.len {
				bytes[i] = u8(i * 31 + 7)
			}
			mut storage := &ByteBufferStorage{
				bytes: bytes.clone()
			}
			buffer := ArrayBufferObject.create_from_host_buffer(vm.realm(), storage, shared_buffer,
				parent)
			source_buffer := if shared_buffer {
				ArrayBufferObject.create_from_host_buffer(vm.realm(), storage, true, parent)
			} else {
				buffer
			}
			mut source := TypedArray.create(vm.realm(), kind, 0, source_buffer, parent)
			mut target := TypedArray.create(vm.realm(), kind, 0, buffer, parent)
			initialize_typed_array_from_array_buffer(mut vm, mut source, source_buffer,
				Value.from_f64(f64(kind.size())), Value.from_i32(3))!
			initialize_typed_array_from_array_buffer(mut vm, mut target, buffer,
				Value.from_f64(f64(kind.size())), Value.from_i32(4))!
			result := typed_set_call(mut vm, target, [
				Value.from_object(source.object),
				Value.from_i32(1),
			], parent)!
			assert result.is_undefined()
			assert buffer.read_bytes(kind.size() * 2, kind.size() * 3) == bytes[int(kind.size())..int(kind.size() * 4)]
			assert buffer.read_bytes(0, kind.size() * 2) == bytes[..int(kind.size() * 2)]
		}
	}
}

fn test_typed_array_set_bit_encoding_equivalence_and_different_kind_numeric_conversion() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for pair in [[BufferElementType.int8, .uint8], [.uint8_clamped, .uint8],
		[.int16, .uint16], [.int32, .uint32], [.big_int64, .big_uint64],
		[.float32, .float32]] {
		kind := pair[0]
		bytes := []u8{len: int(kind.size() * 2), init: 0xff}
		source := TypedArray.create(vm.realm(), kind, 2, ArrayBufferObject.create_from_bytes(vm.realm(),
			bytes, false, parent), parent)
		target := TypedArray.create(vm.realm(), pair[1], 2, ArrayBufferObject.create(mut vm,
			vm.realm(), kind.size() * 2, parent)!, parent)
		assert typed_array_element_types_have_same_bit_encoding(source, target)
		typed_set_call(mut vm, target, [Value.from_object(source.object)], parent)!
		assert target.viewed_buffer.read_bytes(0, kind.size() * 2) == bytes
	}
	source := TypedArray.create(vm.realm(), .int16, 2, ArrayBufferObject.create_from_bytes(vm.realm(), [
		u8(0xff),
		0xff,
		0x2c,
		1,
	], false, parent), parent)
	target := TypedArray.create(vm.realm(), .uint8_clamped, 2, ArrayBufferObject.create(mut vm,
		vm.realm(), 2, parent)!, parent)
	assert !typed_array_element_types_have_same_bit_encoding(source, target)
	typed_set_call(mut vm, target, [Value.from_object(source.object)], parent)!
	assert target.viewed_buffer.read_bytes(0, 2) == [u8(0), 255]
}

fn test_typed_array_set_preserves_pinned_original_view_read_after_conversion_path_clone() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	buffer := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(10), 0, 20, 0, 30, 0, 40, 0],
		false, parent)
	mut source := TypedArray.create(vm.realm(), .int16, 0, buffer, parent)
	mut target := TypedArray.create(vm.realm(), .int8, 0, buffer, parent)
	initialize_typed_array_from_array_buffer(mut vm, mut source, buffer, Value.from_i32(2),
		Value.from_i32(2))!
	initialize_typed_array_from_array_buffer(mut vm, mut target, buffer, Value.from_i32(4),
		Value.from_i32(2))!
	typed_set_call(mut vm, target, [Value.from_object(source.object)], parent)!
	// The pinned C++ body resets the clone index to zero but reads the original
	// view in this path. Keep that behavior visible rather than claiming parity.
	assert buffer.read_bytes(0, 8) == [u8(10), 0, 20, 0, 10, 20, 40, 0]
}

fn test_typed_array_set_array_like_getters_convert_after_resize_and_stop_on_conversion_error() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for mode in ['shrink', 'detach', 'throw'] {
		mut buffer := ArrayBufferObject.create(mut vm, vm.realm(), 4, parent)!
		buffer.maximum_byte_length = uint(8)
		mut target := TypedArray.create(vm.realm(), .uint8, 0, buffer, parent)
		initialize_typed_array_from_array_buffer(mut vm, mut target, buffer, Value.from_i32(0),
			js_undefined())!
		mut log := &TypedSetLog{}
		mut source := Object.create(vm.realm(), none)
		source.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('length'), fn [mut log] (mut vm VM) !Value {
			log.events << 'length'
			return Value.from_i32(3)
		}, unsafe { nil }, attribute_configurable, vm.realm().function_prototype)
		for index in 0 .. 3 {
			mut value := Object.create(vm.realm(), none)
			convert := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [index, mode, mut log] (mut vm VM) !Value {
				log.events << 'convert${index}'
				if mode == 'throw' && index == 1 { return throw_completion(Value.from_i32(77)) }
				return Value.from_i32(index + 1)
			}, 1, PropertyName.from_str('convert'), none)
			value.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
				Value.from_object(convert.object), 7)
			source.define_native_accessor(mut vm, vm.realm(), PropertyName.from_number(u32(index)), fn [index, value, mode, mut buffer, mut log] (mut vm VM) !Value {
				log.events << 'get${index}'
				if index == 1 {
					if mode == 'shrink' { assert buffer.try_resize(1, true)
					 }
					if mode == 'detach' { detach_array_buffer(mut vm, mut buffer, none)! }
				}
				return Value.from_object(value)
			}, unsafe { nil }, attribute_configurable, vm.realm().function_prototype)
		}
		if result := typed_set_call(mut vm, target, [Value.from_object(source)], parent) {
			assert mode != 'throw' && result.is_undefined()
		} else {
			assert mode == 'throw' && thrown_value(err).number == 77
		}
		assert log.events == if mode == 'throw' {
			['length', 'get0', 'convert0', 'get1', 'convert1']
		} else {
			['length', 'get0', 'convert0', 'get1', 'convert1', 'get2', 'convert2']
		}
		if mode == 'shrink' { assert buffer.read_bytes(0, 1) == [u8(1)]
		 }
		if mode == 'throw' { assert buffer.read_bytes(0, 4) == [u8(1), 0, 0, 0]
		 }
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
}

fn test_typed_array_set_range_bounds_and_array_like_length_error_order_and_string_boxing() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	mut target_buffer := ArrayBufferObject.create(mut vm, vm.realm(), 3, parent)!
	target := TypedArray.create(vm.realm(), .uint8, 3, target_buffer, parent)
	typed_set_call(mut vm, target, [
		Value.from_string(vm.create_string_from_str('123')),
	], parent)!
	assert target_buffer.read_bytes(0, 3) == [u8(1), 2, 3]
	mut source := Object.create(vm.realm(), none)
	source.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('length'), fn (mut vm VM) !Value {
		return throw_completion(Value.from_i32(99))
	}, unsafe { nil }, attribute_configurable, vm.realm().function_prototype)
	if _ := typed_set_call(mut vm, target, [Value.from_object(source),
		Value.from_f64(math.inf(1))], parent)
	{
		assert false
	} else {
		assert thrown_value(err).number == 99
	}
	detach_array_buffer(mut vm, mut target_buffer, none)!
	for offset in [f64(-1), math.inf(1)] {
		if _ := typed_set_call(mut vm, target, [js_null(), Value.from_f64(offset)], parent) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == if offset < 0 {
				ErrorKind.range_error
			} else {
				ErrorKind.type_error
			}
		}
	}
	valid_target := TypedArray.create(vm.realm(), .uint8, 3, ArrayBufferObject.create(mut vm,
		vm.realm(), 3, parent)!, parent)
	big_source := TypedArray.create(vm.realm(), .big_int64, 1, ArrayBufferObject.create(mut vm,
		vm.realm(), 8, parent)!, parent)
	for offset in [f64(4), 0] {
		if _ := typed_set_call(mut vm, valid_target, [
			Value.from_object(big_source.object),
			Value.from_f64(offset),
		], parent)
		{
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == if offset > 0 {
				ErrorKind.range_error
			} else {
				ErrorKind.type_error
			}
		}
	}
}
