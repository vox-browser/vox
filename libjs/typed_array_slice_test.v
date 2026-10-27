module libjs

@[heap]
struct TypedSliceLog {
mut:
	events []string
}

fn typed_slice_call(mut vm VM, source &TypedArray, arguments []Value, parent &Object) !&TypedArray {
	constructor := NativeFunction.create_constructor(mut vm, vm.realm(),
		vm.realm().function_prototype, fn (mut vm VM) !Value {
		return js_undefined()
	}, fn (mut vm VM, target &Object) !&Object {
		panic('default Construct must be bypassed')
	}, 1, PropertyName.from_str('Intrinsic'))
	lookup := fn [constructor] (realm &Realm, kind BufferElementType) &Object {
		return constructor.object
	}
	getter := fn [parent] (realm &Realm, kind BufferElementType) &Object {
		return parent
	}
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [lookup, getter] (mut vm VM) !Value {
		return typed_array_prototype_slice(mut vm, PrimitiveObjectPrototypes{}, lookup, getter)
	}, 2, PropertyName.from_str('slice'), none)
	result := call(mut vm, Value.from_object(function.object), Value.from_object(source.object),
		arguments)!
	return result.as_object().typed_array or { panic('fixture') }
}

fn typed_slice_species(mut vm VM, source &TypedArray, destination &TypedArray) {
	constructor := NativeFunction.create_constructor(mut vm, vm.realm(),
		vm.realm().function_prototype, fn (mut vm VM) !Value {
		return js_undefined()
	}, fn [destination] (mut vm VM, target &Object) !&Object {
		return destination.object
	}, 1, PropertyName.from_str('Species'))
	mut holder := Object.create(vm.realm(), none)
	holder.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_species()),
		Value.from_object(constructor.object), 7)
	mut object := source.object
	object.define_direct_property(PropertyName.from_str('constructor'), Value.from_object(holder),
		7)
}

fn test_typed_array_slice_all_kinds_preserve_raw_bytes_and_view_offset_for_shared_and_ordinary_storage() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for shared_buffer in [false, true] {
		for kind in [BufferElementType.big_int64, .big_uint64, .float16, .float32, .float64, .int8,
			.int16, .int32, .uint8, .uint16, .uint32, .uint8_clamped] {
			mut bytes := []u8{len: int(kind.size() * 6)}
			for i in 0 .. bytes.len {
				bytes[i] = u8(i * 31 + 7)
			}
			// Deliberately noncanonical floating-point NaN encodings in the copied span.
			payload := match kind {
				.float64 { [u8(0x42), 0, 0, 0, 0, 0, 0xf8, 0x7f] }
				.float32 { [u8(0x42), 0, 0xc0, 0x7f] }
				.float16 { [u8(0x42), 0x7e] }
				else { []u8{} }
			}

			for i, value in payload {
				bytes[int(kind.size() * 2) + i] = value
			}
			buffer := ArrayBufferObject.create_from_bytes(vm.realm(), bytes, shared_buffer, parent)
			mut source := TypedArray.create(vm.realm(), kind, 0, buffer, parent)
			initialize_typed_array_from_array_buffer(mut vm, mut source, buffer,
				Value.from_f64(f64(kind.size())), Value.from_i32(4))!
			result := typed_slice_call(mut vm, source, [Value.from_i32(1),
				Value.from_i32(-1)], parent)!
			assert result.kind == kind && result.array_length.length() == 2
				&& result.byte_offset == 0
			assert !result.viewed_buffer.is_shared_array_buffer()
				&& result.viewed_buffer.is_fixed_length()
			assert !result.viewed_buffer.shares_storage_with(buffer)
			assert result.viewed_buffer.read_bytes(0, kind.size() * 2) == bytes[int(kind.size() * 2)..int(kind.size() * 4)]
			assert buffer.read_bytes(0, buffer.byte_length()) == bytes
		}
	}
}

fn test_typed_array_slice_species_aliases_follow_forward_byte_copy_and_numeric_kind_conversion() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for shared_buffer in [false, true] {
		for kind in [BufferElementType.uint8, .uint8_clamped] {
			buffer := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(1), 2, 3, 4],
				shared_buffer, parent)
			source := TypedArray.create(vm.realm(), .uint8, 3, buffer, parent)
			mut destination := TypedArray.create(vm.realm(), kind, 0, buffer, parent)
			initialize_typed_array_from_array_buffer(mut vm, mut destination, buffer,
				Value.from_i32(1), Value.from_i32(3))!
			typed_slice_species(mut vm, source, destination)
			result := typed_slice_call(mut vm, source, []Value{}, parent)!
			assert voidptr(result) == voidptr(destination)
			assert buffer.read_bytes(0, 4) == [u8(1), 1, 1, 1]
		}
	}
	buffer := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(0xff), 1, 0x80], false, parent)
	source := TypedArray.create(vm.realm(), .int8, 3, buffer, parent)
	destination := TypedArray.create(vm.realm(), .uint16, 3, ArrayBufferObject.create(mut vm,
		vm.realm(), 6, parent)!, parent)
	typed_slice_species(mut vm, source, destination)
	result := typed_slice_call(mut vm, source, []Value{}, parent)!
	assert voidptr(result) == voidptr(destination)
	for index, expected in [65535, 1, 65408] {
		assert typed_array_get_element(result, CanonicalIndex.create(.index, u32(index))).number == expected
	}
}

fn test_typed_array_slice_allocates_original_count_then_copies_only_live_prefix_after_shrink() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for begin in [0, 2, 3] {
		mut buffer := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(1), 2, 3, 4], false,
			parent)
		buffer.maximum_byte_length = uint(8)
		mut source := TypedArray.create(vm.realm(), .uint8, 0, buffer, parent)
		initialize_typed_array_from_array_buffer(mut vm, mut source, buffer, Value.from_i32(0),
			js_undefined())!
		mut object := source.object
		object.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('constructor'), fn [mut buffer] (mut vm VM) !Value {
			assert buffer.try_resize(2, true)
			return js_undefined()
		}, unsafe { nil }, attribute_configurable, vm.realm().function_prototype)
		result := typed_slice_call(mut vm, source, [Value.from_i32(begin)], parent)!
		assert result.array_length.length() == 4 - begin
		assert result.viewed_buffer.read_bytes(0, uint(4 - begin)) == if begin == 0 {
			[u8(1), 2, 0, 0]
		} else {
			[]u8{len: 4 - begin}
		}
	}
}

fn test_typed_array_slice_coercion_species_and_late_bounds_validation_order_for_empty_and_nonempty_ranges() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for empty in [false, true] {
		mut buffer := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(1), 2, 3], false, parent)
		source := TypedArray.create(vm.realm(), .uint8, 3, buffer, parent)
		mut log := &TypedSliceLog{}
		mut arguments := []Value{}
		for name in ['start', 'end'] {
			mut object := Object.create(vm.realm(), none)
			function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [name, empty, mut log] (mut vm VM) !Value {
				log.events << name
				return Value.from_i32(if name == 'start' && empty {
					3
				} else if name == 'start' {
					0
				} else {
					3
				})
			}, 1, PropertyName.from_str('convert'), none)
			object.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
				Value.from_object(function.object), 7)
			arguments << Value.from_object(object)
		}
		mut object := source.object
		object.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('constructor'), fn [mut buffer, mut log] (mut vm VM) !Value {
			log.events << 'species'
			detach_array_buffer(mut vm, mut buffer, none)!
			return js_undefined()
		}, unsafe { nil }, attribute_configurable, vm.realm().function_prototype)
		if result := typed_slice_call(mut vm, source, arguments, parent) {
			assert empty && result.array_length.length() == 0
		} else {
			assert !empty && thrown_value(err).as_object().error_kind()? == .type_error
		}
		assert log.events == ['start', 'end', 'species']
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
}
