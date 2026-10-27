module libjs

import math

fn test_typed_array_records_read_and_write_every_numeric_kind_through_shared_buffer_storage() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	prototype := Object.create(vm.realm(), none)
	kinds := [BufferElementType.big_int64, .big_uint64, .float16, .float32, .float64, .int8, .int16,
		.int32, .uint8, .uint16, .uint32, .uint8_clamped]
	for kind in kinds {
		buffer := ArrayBufferObject.create(mut vm, vm.realm(), 2 * kind.size(), prototype)!
		mut array := TypedArray.create(vm.realm(), kind, 2, buffer, prototype)
		mut alias := TypedArray.create(vm.realm(), kind, 2, buffer, prototype)
		assert voidptr(array.object.typed_array?) == voidptr(array)
		assert voidptr(array.object.prototype?) == voidptr(prototype)
		assert array.object.class_name == kind.typed_array_name()
		assert array.is_bigint_element_type() == kind.is_bigint()
		assert (array.content_type() == .bigint) == kind.is_bigint()
		assert array.is_unclamped_integer_element_type() == (kind in [.int8, .int16, .int32, .uint8,
			.uint16, .uint32])
		input := if kind.is_bigint() {
			Value.from_bigint(string_to_bigint(utf16_string('42')) or { panic('invalid BigInt literal') })
		} else {
			Value.from_i32(42)
		}
		typed_array_set_element(mut vm, mut array, CanonicalIndex.create(.index, 0), input)!
		actual := typed_array_get_element(alias, CanonicalIndex.create(.index, 0))
		assert actual.str() == if kind.is_bigint() {
			'42n'
		} else {
			'42'
		}
		assert alias.get_value_from_buffer(mut vm, 0, .seq_cst, true).str() == actual.str()
		alias.set_value_in_buffer(mut vm, kind.size(), input, .unordered, true)
		assert typed_array_get_element(array, CanonicalIndex.create(.index, 1)).str() == actual.str()
		descriptor := array.object.internal_get_own_property(PropertyName.from_number(0))?
		assert descriptor.value?.str() == actual.str()
		assert descriptor.writable? && descriptor.configurable? && descriptor.enumerable?
		assert typed_array_get_element(array, CanonicalIndex.create(.index, 2)).is_undefined()
		if kind.is_bigint() {
			if _ := typed_array_set_element(mut vm, mut array, CanonicalIndex.create(.numeric, 0),
				Value.from_i32(1))
			{
				assert false
			} else {
				assert thrown_value(err).as_object().error_kind()? == .type_error
			}
		} else {
			if _ := typed_array_set_element(mut vm, mut array, CanonicalIndex.create(.numeric, 0),
				Value.from_bigint(string_to_bigint(utf16_string('1')) or { panic('invalid BigInt literal') }))
			{
				assert false
			} else {
				assert thrown_value(err).as_object().error_kind()? == .type_error
			}
		}
	}
	mut buffer := ArrayBufferObject.create(mut vm, vm.realm(), 4, prototype)!
	mut clamped := TypedArray.create(vm.realm(), .uint8_clamped, 4, buffer, prototype)
	for index, number in [2.5, 3.5, -1.0, 300.0] {
		typed_array_set_element(mut vm, mut clamped, CanonicalIndex.create(.index, u32(index)),
			Value.from_f64(number))!
	}
	assert buffer.read_bytes(0, 4) == [u8(2), 4, 0, 255]
	float_buffer := ArrayBufferObject.create(mut vm, vm.realm(), 8, prototype)!
	mut floating := TypedArray.create(vm.realm(), .float64, 1, float_buffer, prototype)
	typed_array_set_element(mut vm, mut floating, CanonicalIndex.create(.index, 0),
		Value.from_f64(math.nan()))!
	assert math.is_nan(floating.object.internal_get_own_property(PropertyName.from_number(0))?.value?.number)
	// The virtual buffer modify operation returns the old value and shares writes.
	old := clamped.get_modify_set_value_in_buffer(mut vm, 0, Value.from_i32(42), fn (read []u8, argument []u8) []u8 {
		return argument.clone()
	}, true)
	assert old.number == 2 && buffer.read_bytes(0, 1) == [u8(42)]
}

fn test_typed_array_witnesses_track_whole_elements_and_preserve_snapshot_lengths() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	prototype := Object.create(vm.realm(), none)
	mut buffer := ArrayBufferObject.create(mut vm, vm.realm(), 9, prototype)!
	buffer.maximum_byte_length = uint(16)
	mut fixed := TypedArray.create(vm.realm(), .uint16, 2, buffer, prototype)
	fixed.byte_offset = 2
	fixed.byte_length = ByteLength.from_u32(4)
	mut tracking := TypedArray.create(vm.realm(), .uint16, 0, buffer, prototype)
	tracking.byte_offset = 2
	tracking.byte_length = ByteLength.auto_length()
	tracking.array_length = ByteLength.auto_length()
	old := make_typed_array_with_buffer_witness_record(tracking, .seq_cst)
	assert typed_array_length(old) == 3 && typed_array_byte_length(old) == 6
	for order in [BufferOrder.seq_cst, .unordered] {
		assert typed_array_length(make_typed_array_with_buffer_witness_record(fixed, order)) == 2
		assert typed_array_byte_length(make_typed_array_with_buffer_witness_record(fixed, order)) == 4
	}
	assert buffer.try_resize(5, true)
	assert is_typed_array_out_of_bounds(make_typed_array_with_buffer_witness_record(fixed, .seq_cst))
	assert typed_array_byte_length(make_typed_array_with_buffer_witness_record(fixed, .seq_cst)) == 0
	assert typed_array_length(make_typed_array_with_buffer_witness_record(tracking, .seq_cst)) == 1
	assert typed_array_length(old) == 3
	assert !is_valid_integer_index(fixed, CanonicalIndex.create(.index, 0))
	assert is_valid_integer_index(tracking, CanonicalIndex.create(.index, 0))
	assert !is_valid_integer_index(tracking, CanonicalIndex.create(.index, 1))
	assert buffer.try_resize(1, true)
	assert is_typed_array_out_of_bounds(make_typed_array_with_buffer_witness_record(tracking,
		.seq_cst))
	assert buffer.try_resize(12, true)
	assert typed_array_length(validate_typed_array(mut vm, tracking.object, .seq_cst)!) == 5
	assert is_valid_integer_index(fixed, CanonicalIndex.create(.index, 1))
	detach_array_buffer(mut vm, mut buffer, none)!
	for array in [fixed, tracking] {
		record := make_typed_array_with_buffer_witness_record(array, .seq_cst)
		assert record.cached_buffer_byte_length.is_detached()
			&& is_typed_array_out_of_bounds(record)
		assert typed_array_byte_length(record) == 0
		assert !is_valid_integer_index(array, CanonicalIndex.create(.index, 0))
		if _ := validate_typed_array(mut vm, array.object, .seq_cst) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str() == "TypedArray contains a property which references a value at an index not contained within its buffer's bounds"
		}
	}
	if _ := validate_typed_array(mut vm, prototype, .unordered) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .type_error
	}
}

fn test_typed_array_empty_views_and_fixed_length_rules_distinguish_resizable_and_shared_buffers() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	prototype := Object.create(vm.realm(), none)
	for is_shared in [false, true] {
		for growable in [false, true] {
			mut buffer := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(0), 0, 0, 0],
				is_shared, prototype)
			if growable { buffer.maximum_byte_length = uint(8) }
			for auto_length in [false, true] {
				if auto_length && !growable { continue
				 }
				mut array := TypedArray.create(vm.realm(), .uint16, 0, buffer, prototype)
				array.byte_offset = 4
				array.array_length = if auto_length {
					ByteLength.auto_length()
				} else {
					ByteLength.from_u32(0)
				}
				array.byte_length = if auto_length {
					ByteLength.auto_length()
				} else {
					ByteLength.from_u32(0)
				}
				record := make_typed_array_with_buffer_witness_record(array, .unordered)
				assert !is_typed_array_out_of_bounds(record)
				assert typed_array_length(record) == 0 && typed_array_byte_length(record) == 0
				expected_fixed := !auto_length && (!growable || is_shared)
				assert is_typed_array_fixed_length(array) == expected_fixed
				mut object := array.object
				assert object.internal_prevent_extensions() == expected_fixed
				assert object.internal_is_extensible() == !expected_fixed
				array.byte_offset = 5
				assert is_typed_array_out_of_bounds(make_typed_array_with_buffer_witness_record(array,
					.seq_cst))
			}
		}
	}
}
