module libjs

@[heap]
struct TypedArrayInitializationLog {
mut:
	events []string
}

fn test_typed_array_buffer_initialization_preserves_offsets_and_fixed_or_tracking_lengths() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	prototype := Object.create(vm.realm(), none)
	for kind in [BufferElementType.big_int64, .big_uint64, .float16, .float32, .float64, .int8,
		.int16, .int32, .uint8, .uint16, .uint32, .uint8_clamped] {
		for growable in [false, true] {
			mut buffer := ArrayBufferObject.create(mut vm, vm.realm(), 4 * kind.size(), prototype)!
			if growable { buffer.maximum_byte_length = 8 * kind.size() }
			mut array := TypedArray.create(vm.realm(), kind, 0, buffer, prototype)
			initialize_typed_array_from_array_buffer(mut vm, mut array, buffer,
				Value.from_f64(f64(kind.size())), js_undefined())!
			assert voidptr(array.viewed_buffer) == voidptr(buffer)
			assert array.byte_offset == u32(kind.size())
			assert array.array_length.is_auto() == growable
				&& array.byte_length.is_auto() == growable
			assert typed_array_length(make_typed_array_with_buffer_witness_record(array, .seq_cst)) == 3
			assert typed_array_byte_length(make_typed_array_with_buffer_witness_record(array,
				.seq_cst)) == 3 * u32(kind.size())
			mut explicit := TypedArray.create(vm.realm(), kind, 0, buffer, prototype)
			initialize_typed_array_from_array_buffer(mut vm, mut explicit, buffer,
				Value.from_f64(f64(kind.size())), Value.from_i32(2))!
			assert explicit.array_length.length() == 2
				&& explicit.byte_length.length() == 2 * u32(kind.size())
			mut empty := TypedArray.create(vm.realm(), kind, 0, buffer, prototype)
			initialize_typed_array_from_array_buffer(mut vm, mut empty, buffer,
				Value.from_f64(f64(4 * kind.size())), Value.from_i32(0))!
			assert !is_typed_array_out_of_bounds(make_typed_array_with_buffer_witness_record(empty,
				.seq_cst))
		}
	}
	mut odd := ArrayBufferObject.create(mut vm, vm.realm(), 5, prototype)!
	odd.maximum_byte_length = uint(9)
	mut array := TypedArray.create(vm.realm(), .uint16, 0, odd, prototype)
	initialize_typed_array_from_array_buffer(mut vm, mut array, odd, Value.from_i32(2),
		js_undefined())!
	assert typed_array_length(make_typed_array_with_buffer_witness_record(array, .seq_cst)) == 1
	assert odd.try_resize(9, true)
	assert typed_array_length(make_typed_array_with_buffer_witness_record(array, .seq_cst)) == 3
}

fn test_typed_array_buffer_initialization_rejects_alignment_before_lengths_and_checks_ranges() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	prototype := Object.create(vm.realm(), none)
	buffer := ArrayBufferObject.create(mut vm, vm.realm(), 5, prototype)!
	mut array := TypedArray.create(vm.realm(), .uint16, 0, buffer, prototype)
	for item in [
		[Value.from_i32(1), Value.from_i32(-1)],
		[Value.from_i32(6), js_undefined()],
		[Value.from_i32(2), Value.from_i32(2)],
		[Value.from_i32(-1), js_undefined()],
	] {
		if _ := initialize_typed_array_from_array_buffer(mut vm, mut array, buffer, item[0],
			item[1])
		{
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .range_error
			message := thrown_value(err).as_object().error_message()?.str()
			if item[0].number == 1 { assert message == 'Invalid byte offset for Uint16Array: must be a multiple of 2, got 1'
			 }
			if item[0].number == 6 { assert message == 'Invalid buffer length for Uint16Array: must be a multiple of 2, got 5'
			 }
			if item[0].number == 2 { assert message == 'Typed array range 2:6 is out of range for buffer with length 5'
			 }
		}
	}
	mut resizable := ArrayBufferObject.create(mut vm, vm.realm(), 5, prototype)!
	resizable.maximum_byte_length = uint(8)
	if _ := initialize_typed_array_from_array_buffer(mut vm, mut array, resizable,
		Value.from_i32(6), js_undefined())
	{
		assert false
	} else {
		assert thrown_value(err).as_object().error_message()?.str() == 'Typed array byte offset 6 is out of range for buffer with length 5'
	}
	for size in [uint(1), 2, 4, 8] {
		validate_typed_array_length(mut vm, uint(0x7fffffff) / size, size)!
		if _ := validate_typed_array_length(mut vm, uint(0x7fffffff) / size + 1, size) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str() == 'Invalid typed array length'
		}
	}
}

fn test_typed_array_buffer_initialization_orders_offset_length_coercions_before_detachment() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	prototype := Object.create(vm.realm(), none)
	for mode in ['detach', 'shrink', 'throw', 'misalign'] {
		mut buffer := ArrayBufferObject.create(mut vm, vm.realm(), 8, prototype)!
		buffer.maximum_byte_length = uint(16)
		mut array := TypedArray.create(vm.realm(), .uint16, 0, buffer, prototype)
		mut log := &TypedArrayInitializationLog{}
		mut offset := Object.create(vm.realm(), none)
		mut length := Object.create(vm.realm(), none)
		offset_method := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mut log, mode] (mut vm VM) !Value {
			log.events << 'offset'
			return Value.from_i32(if mode == 'misalign' { 1 } else { 2 })
		}, 0, PropertyName.from_str('valueOf'), none)
		length_method := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mut log, mut buffer, mode] (mut vm VM) !Value {
			log.events << 'length'
			if mode == 'throw' { return throw_completion(Value.from_i32(42)) }
			if mode == 'detach' { detach_array_buffer(mut vm, mut buffer, none)! }
			if mode == 'shrink' { assert buffer.try_resize(3, true)
			 }
			return Value.from_i32(2)
		}, 0, PropertyName.from_str('valueOf'), none)
		offset.define_direct_property(PropertyName.from_str('valueOf'),
			Value.from_object(offset_method.object), 7)
		length.define_direct_property(PropertyName.from_str('valueOf'),
			Value.from_object(length_method.object), 7)
		if _ := initialize_typed_array_from_array_buffer(mut vm, mut array, buffer,
			Value.from_object(offset), Value.from_object(length))
		{
			assert false
		} else {
			if mode == 'throw' {
				assert thrown_value(err).number == 42
			} else {
				assert thrown_value(err).as_object().error_kind()? == if mode == 'detach' {
					ErrorKind.type_error
				} else {
					ErrorKind.range_error
				}
			}
		}
		assert log.events == if mode == 'misalign' {
			['offset']
		} else {
			['offset', 'length']
		}
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
}
