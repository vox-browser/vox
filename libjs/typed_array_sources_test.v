module libjs

@[heap]
struct TypedArraySourceLog {
mut:
	events []string
}

fn test_typed_array_allocation_replaces_storage_resets_offsets_and_enforces_element_size_limit() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	old := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(42), 17], false, parent)
	for kind in [BufferElementType.big_int64, .big_uint64, .float16, .float32, .float64, .int8,
		.int16, .int32, .uint8, .uint16, .uint32, .uint8_clamped] {
		mut array := TypedArray.create(vm.realm(), kind, 0, old, parent)
		array.byte_offset = 1
		allocate_typed_array_buffer(mut vm, mut array, 2)!
		assert array.array_length.length() == 2
			&& array.byte_length.length() == 2 * array.element_size() && array.byte_offset == 0
		assert array.viewed_buffer.is_fixed_length()
			&& !array.viewed_buffer.shares_storage_with(old)
		assert array.viewed_buffer.read_bytes(0, 2 * kind.size()) == []u8{len: int(2 * kind.size())}
		installed := array.viewed_buffer
		if _ := allocate_typed_array_buffer(mut vm, mut array, uint(0x7fffffff) / kind.size() + 1) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str() == 'Invalid typed array length'
		}
		assert voidptr(array.viewed_buffer) == voidptr(installed)
		allocate_typed_array_buffer(mut vm, mut array, 0)!
		assert array.array_length.length() == 0 && array.byte_length.length() == 0
			&& !array.viewed_buffer.is_detached()
	}
	assert old.read_bytes(0, 2) == [u8(42), 17]
}

fn test_typed_array_list_initialization_allocates_before_conversions_and_keeps_partial_writes() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for mode in ['success', 'throw', 'detach'] {
		empty := ArrayBufferObject.create(mut vm, vm.realm(), 0, parent)!
		mut array := TypedArray.create(vm.realm(), .uint8, 0, empty, parent)
		mut log := &TypedArraySourceLog{}
		mut values := []Value{}
		for index in 0 .. 3 {
			mut object := Object.create(vm.realm(), none)
			convert := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mut array, mut log, index, mode] (mut vm VM) !Value {
				assert array.array_length.length() == 3 && array.byte_length.length() == 3
				assert array.byte_offset == 0
				log.events << 'convert ${index}'
				if index == 1 && mode == 'throw' { return throw_completion(Value.from_i32(17)) }
				if index == 1 && mode == 'detach' {
					mut buffer := array.viewed_buffer
					detach_array_buffer(mut vm, mut buffer, none)!
				}
				return Value.from_i32(42 + index)
			}, 0, PropertyName.from_str('valueOf'), none)
			object.define_direct_property(PropertyName.from_str('valueOf'),
				Value.from_object(convert.object), 7)
			values << Value.from_object(object)
		}
		if _ := initialize_typed_array_from_list(mut vm, mut array, values) {
			assert mode != 'throw'
		} else {
			assert mode == 'throw' && thrown_value(err).number == 17
		}
		assert log.events == if mode == 'throw' {
			['convert 0', 'convert 1']
		} else {
			['convert 0', 'convert 1', 'convert 2']
		}
		if mode == 'detach' {
			assert array.viewed_buffer.is_detached()
		} else {
			assert array.viewed_buffer.read_bytes(0, 3) == if mode == 'throw' {
				[u8(42), 0, 0]
			} else {
				[u8(42), 43, 44]
			}
		}
		assert values.len == 3 && values[0].is_object()
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
}

fn test_typed_array_array_like_reads_snapshot_length_and_interleaves_live_getters_with_conversion() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut parent := Object.create(vm.realm(), none)
	parent.define_direct_property(PropertyName.from_number(2), Value.from_i32(44), 7)
	mut source := Object.create(vm.realm(), parent)
	empty := ArrayBufferObject.create(mut vm, vm.realm(), 0, parent)!
	mut array := TypedArray.create(vm.realm(), .uint8, 0, empty, parent)
	mut log := &TypedArraySourceLog{}
	source.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('length'), fn [mut log] (mut vm VM) !Value {
		log.events << 'length'
		return Value.from_i32(3)
	}, unsafe { nil }, attribute_configurable, vm.realm().function_prototype)
	mut value := Object.create(vm.realm(), none)
	convert := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mut source, mut log] (mut vm VM) !Value {
		log.events << 'convert 0'
		source.define_direct_property(PropertyName.from_str('length'), Value.from_i32(1), 7)
		source.define_direct_property(PropertyName.from_number(1), Value.from_i32(43), 7)
		return Value.from_i32(42)
	}, 0, PropertyName.from_str('valueOf'), none)
	value.define_direct_property(PropertyName.from_str('valueOf'),
		Value.from_object(convert.object), 7)
	source.define_native_accessor(mut vm, vm.realm(), PropertyName.from_number(0), fn [array, mut log, value] (mut vm VM) !Value {
		assert array.array_length.length() == 3 && array.viewed_buffer.byte_length() == 3
		log.events << 'get 0'
		return Value.from_object(value)
	}, unsafe { nil }, 0, vm.realm().function_prototype)
	initialize_typed_array_from_array_like(mut vm, mut array, source)!
	assert log.events == ['length', 'get 0', 'convert 0']
	assert array.viewed_buffer.read_bytes(0, 3) == [u8(42), 43, 44]
	assert source.get(mut vm, PropertyName.from_str('length'))!.number == 1
}

fn test_typed_array_array_like_length_errors_precede_indexed_getters_and_getter_errors_keep_partial_state() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for mode in ['length throws', 'excessive', 'element throws', 'sparse'] {
		empty := ArrayBufferObject.create(mut vm, vm.realm(), 0, parent)!
		mut array := TypedArray.create(vm.realm(), .float64, 0, empty, parent)
		mut source := Object.create(vm.realm(), none)
		mut log := &TypedArraySourceLog{}
		source.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('length'), fn [mode] (mut vm VM) !Value {
			if mode == 'length throws' { return throw_completion(Value.from_i32(17)) }
			return Value.from_f64(if mode == 'excessive' { 9007199254740991.0 } else { 3.0 })
		}, unsafe { nil }, 0, vm.realm().function_prototype)
		for index in 0 .. 2 {
			source.define_native_accessor(mut vm, vm.realm(), PropertyName.from_number(u32(index)), fn [mut log, index, mode] (mut vm VM) !Value {
				log.events << 'get ${index}'
				if index == 1 && mode == 'element throws' {
					return throw_completion(Value.from_i32(42))
				}
				return Value.from_i32(17)
			}, unsafe { nil }, 0, vm.realm().function_prototype)
		}
		if _ := initialize_typed_array_from_array_like(mut vm, mut array, source) {
			assert mode == 'sparse'
		} else {
			if mode == 'excessive' {
				assert thrown_value(err).as_object().error_kind()? == .range_error
			} else {
				assert thrown_value(err).number == if mode == 'length throws' {
					17
				} else {
					42
				}
			}
		}
		if mode in ['length throws', 'excessive'] {
			assert log.events.len == 0 && voidptr(array.viewed_buffer) == voidptr(empty)
		} else {
			assert log.events == ['get 0', 'get 1'] && array.array_length.length() == 3
			assert typed_array_get_element(array, CanonicalIndex.create(.index, 0)).number == 17
			if mode == 'sparse' { assert typed_array_get_element(array, CanonicalIndex.create(.index, 2)).str() == 'NaN'
			 }
		}
	}
}
