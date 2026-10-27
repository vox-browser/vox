module libjs

fn test_typed_array_iterators_ignore_shadowed_lengths_and_yield_keys_values_and_entries() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	buffer := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(17), 42], false, parent)
	array := TypedArray.create(vm.realm(), .uint8, 2, buffer, parent)
	mut object := array.object
	object.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('length'), fn (mut vm VM) !Value {
		return throw_completion(Value.from_i32(99))
	}, unsafe { nil }, 0, vm.realm().function_prototype)
	for kind in [PropertyKind.key, .value, .key_and_value] {
		mut iterator := ArrayIterator.create(vm.realm(), Value.from_object(object), kind, parent)
		for index, expected in [17, 42] {
			result := iterator.next(mut vm, parent)!
			assert !result.done && iterator.index == u64(index + 1)
			match kind {
				.key { assert result.value.number == f64(index) }
				.value { assert result.value.number == f64(expected) }
				.key_and_value { assert create_list_from_array_like(mut vm, result.value,
						unsafe { nil })! == [Value.from_i32(index),
						Value.from_i32(expected)] }
			}
		}
		assert iterator.next(mut vm, parent)!.done && iterator.array.is_undefined()
	}
}

fn test_typed_array_iterator_resize_errors_preserve_target_index_and_allow_recovery() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for tracking in [false, true] {
		mut buffer := ArrayBufferObject.create(mut vm, vm.realm(), 4, parent)!
		buffer.maximum_byte_length = uint(8)
		mut array := TypedArray.create(vm.realm(), .uint16, 0, buffer, parent)
		initialize_typed_array_from_array_buffer(mut vm, mut array, buffer, Value.from_i32(2), if tracking {
			js_undefined()
		} else {
			Value.from_i32(1)
		})!
		mut iterator := ArrayIterator.create(vm.realm(), Value.from_object(array.object), .key,
			parent)
		assert iterator.next(mut vm, parent)!.value.number == 0
		assert buffer.try_resize(1, true)
		if _ := iterator.next(mut vm, parent) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
		assert iterator.index == 1 && !iterator.array.is_undefined()
		assert buffer.try_resize(8, true)
		if tracking {
			assert iterator.next(mut vm, parent)!.value.number == 1
			assert iterator.next(mut vm, parent)!.value.number == 2
		}
		assert iterator.next(mut vm, parent)!.done && iterator.array.is_undefined()
		detach_array_buffer(mut vm, mut buffer, none)!
		assert iterator.next(mut vm, parent)!.done
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
}

fn test_typed_array_iterator_shared_growth_uses_fresh_witness_and_detachment_throws_before_increment() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	mut buffer := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(17)], true, parent)
	buffer.maximum_byte_length = uint(4)
	mut array := TypedArray.create(vm.realm(), .uint8, 0, buffer, parent)
	initialize_typed_array_from_array_buffer(mut vm, mut array, buffer, js_undefined(),
		js_undefined())!
	mut iterator := ArrayIterator.create(vm.realm(), Value.from_object(array.object), .value,
		parent)
	assert iterator.next(mut vm, parent)!.value.number == 17
	assert buffer.try_resize(3, true)
	assert iterator.next(mut vm, parent)!.value.number == 0
	assert iterator.next(mut vm, parent)!.value.number == 0
	assert iterator.next(mut vm, parent)!.done
	mut detached := ArrayBufferObject.create(mut vm, vm.realm(), 1, parent)!
	view := TypedArray.create(vm.realm(), .uint8, 1, detached, parent)
	mut detached_iterator := ArrayIterator.create(vm.realm(), Value.from_object(view.object),
		.value, parent)
	detach_array_buffer(mut vm, mut detached, none)!
	if _ := detached_iterator.next(mut vm, parent) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .type_error
	}
	assert detached_iterator.index == 0 && !detached_iterator.array.is_undefined()
}
