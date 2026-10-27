module libjs

import math

// TypedArrayPrototype.cpp::typed_array_element_types_have_same_bit_encoding.
fn typed_array_element_types_have_same_bit_encoding(source &TypedArray, target &TypedArray) bool {
	if source.kind == target.kind { return true }
	if (source.kind == .uint8 && target.kind == .uint8_clamped)
		|| (source.kind == .uint8_clamped && target.kind == .uint8) {
		return true
	}
	if source.element_size() != target.element_size() { return false }
	if source.is_unclamped_integer_element_type() && target.is_unclamped_integer_element_type() {
		return true
	}
	return source.is_bigint_element_type() && target.is_bigint_element_type()
}

fn check_typed_array_set_range(mut vm VM, offset f64, source_length u64, target_length u32) ! {
	if math.is_inf(offset, 1) {
		return vm.throw_error_type(.range_error, .typed_array_invalid_target_offset, 'finite')
	}
	if offset > f64(0x1fffffffffffff) {
		return vm.throw_error_type(.range_error, .typed_array_overflow_or_out_of_bounds,
			'target offset')
	}
	if source_length > u64(~uint(0)) || uint(offset) > (~uint(0)) - uint(source_length)
		|| uint(source_length) + uint(offset) > uint(target_length) {
		return vm.throw_error_type(.range_error, .typed_array_overflow_or_out_of_bounds,
			'target length')
	}
}

// SetTypedArrayFromTypedArray: bounds precede range/content checks; aliased
// ordinary and shared buffers are cloned before choosing the encoding path.
fn set_typed_array_from_typed_array(mut vm VM, mut target TypedArray, target_offset f64, source &TypedArray) ! {
	mut target_buffer := target.viewed_buffer
	target_record := make_typed_array_with_buffer_witness_record(target, .seq_cst)
	if is_typed_array_out_of_bounds(target_record) {
		return vm.throw_error_type(.type_error, .buffer_out_of_bounds, 'TypedArray')
	}
	target_length := typed_array_length(target_record)
	mut source_buffer := source.viewed_buffer
	source_record := make_typed_array_with_buffer_witness_record(source, .seq_cst)
	if is_typed_array_out_of_bounds(source_record) {
		return vm.throw_error_type(.type_error, .buffer_out_of_bounds, 'TypedArray')
	}
	source_length := typed_array_length(source_record)
	target_size := uint(target.element_size())
	source_size := uint(source.element_size())
	check_typed_array_set_range(mut vm, target_offset, u64(source_length), target_length)!
	if target.content_type() != source.content_type() {
		return vm.throw_error_type(.type_error, .typed_array_invalid_copy,
			target.object.class_name, source.object.class_name)
	}
	same_shared_buffer := source_buffer.is_shared_array_buffer()
		&& target_buffer.is_shared_array_buffer()
		&& source_buffer.shares_storage_with(target_buffer)
	mut source_index := uint(source.byte_offset)
	if same_shared_buffer || voidptr(source_buffer) == voidptr(target_buffer) {
		source_buffer = clone_array_buffer(mut vm, source_buffer, uint(source.byte_offset),
			uint(typed_array_byte_length(source_record)))!
		source_index = 0
	}
	maximum := ~uint(0)
	if uint(target_offset) > maximum / target_size
		|| uint(target_offset) * target_size > maximum - uint(target.byte_offset) {
		return vm.throw_error_type(.range_error, .typed_array_overflow, 'target byte index')
	}
	mut target_index := uint(target_offset) * target_size + uint(target.byte_offset)
	if uint(source_length) > maximum / target_size
		|| uint(source_length) * target_size > maximum - target_index {
		return vm.throw_error_type(.range_error, .typed_array_overflow, 'target limit')
	}
	limit := target_index + uint(source_length) * target_size
	if typed_array_element_types_have_same_bit_encoding(source, target) {
		source_buffer.copy_data_to(mut target_buffer, source_index, target_index,
			limit - target_index)
	} else {
		for target_index < limit {
			// Preserve the pinned active body: it reads through the original
			// source view even when the local source_buffer was cloned above.
			value := source.get_value_from_buffer(mut vm, source_index, .unordered, true)
			target.set_value_in_buffer(mut vm, target_index, value, .unordered, true)
			source_index += source_size
			target_index += target_size
		}
	}
}

// SetTypedArrayFromArrayLike: length is captured before the range check, while
// indexed getters and conversions remain live across resize/detachment.
fn set_typed_array_from_array_like(mut vm VM, mut target TypedArray, target_offset f64, source Value, prototypes PrimitiveObjectPrototypes) ! {
	record := make_typed_array_with_buffer_witness_record(target, .seq_cst)
	if is_typed_array_out_of_bounds(record) {
		return vm.throw_error_type(.type_error, .buffer_out_of_bounds, 'TypedArray')
	}
	target_length := typed_array_length(record)
	source_object := source.to_object_with_prototypes(mut vm, prototypes)!
	source_length := length_of_array_like(mut vm, source_object)!
	check_typed_array_set_range(mut vm, target_offset, source_length, target_length)!
	for k := u64(0); k < source_length; k++ {
		value := source_object.get(mut vm, PropertyName.from_number(u32(k)))!
		index := CanonicalIndex.from_double(mut vm, .index, target_offset + f64(k)) or {
			panic(err)
		}
		typed_array_set_element(mut vm, mut target, index, value)!
	}
}

pub fn typed_array_prototype_set(mut vm VM, prototypes PrimitiveObjectPrototypes) !Value {
	source := vm.argument(0)
	offset := vm.argument(1)
	mut target := typed_array_from_this(mut vm, prototypes)!
	target_offset := offset.to_integer_or_infinity(mut vm)!
	if target_offset < 0 {
		return vm.throw_error_type(.range_error, .typed_array_invalid_target_offset, 'positive')
	}
	if source.is_object() {
		if array := source.as_object().typed_array {
			set_typed_array_from_typed_array(mut vm, mut target, target_offset, array)!
			return js_undefined()
		}
	}
	set_typed_array_from_array_like(mut vm, mut target, target_offset, source, prototypes)!
	return js_undefined()
}
