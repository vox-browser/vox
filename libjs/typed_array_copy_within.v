module libjs

import math

// TypedArrayPrototype.cpp::copy_within. Index conversion captures the original
// length, then a fresh witness limits the bit-preserving copy to live storage.
pub fn typed_array_prototype_copy_within(mut vm VM, prototypes PrimitiveObjectPrototypes) !Value {
	target := vm.argument(0)
	start := vm.argument(1)
	end := vm.argument(2)
	array := typed_array_from_this(mut vm, prototypes)!
	mut record := validate_typed_array(mut vm, array.object, .seq_cst)!
	mut length := typed_array_length(record)
	target_index := f64(buffer_slice_index(uint(length), target.to_integer_or_infinity(mut vm)!))
	start_index := f64(buffer_slice_index(uint(length), start.to_integer_or_infinity(mut vm)!))
	relative_end := if end.is_undefined() {
		f64(length)
	} else {
		end.to_integer_or_infinity(mut vm)!
	}
	end_index := f64(buffer_slice_index(uint(length), relative_end))
	mut count := math.min(end_index - start_index, f64(length) - target_index)
	if count > 0 {
		mut buffer := array.viewed_buffer
		record = make_typed_array_with_buffer_witness_record(array, .seq_cst)
		if is_typed_array_out_of_bounds(record) {
			return vm.throw_error_type(.type_error, .buffer_out_of_bounds, 'TypedArray')
		}
		length = typed_array_length(record)
		count = math.min(count, math.min(f64(length) - start_index, f64(length) - target_index))
		if count <= 0 { return Value.from_object(array.object) }
		size := uint(array.element_size())
		offset := uint(array.byte_offset)
		maximum := ~uint(0)
		// Checked<size_t> failures in the pinned source return the receiver.
		if uint(target_index) > (maximum - offset) / size { return Value.from_object(array.object) }
		mut to_byte_index := uint(target_index) * size + offset
		if uint(start_index) > (maximum - offset) / size { return Value.from_object(array.object) }
		mut from_byte_index := uint(start_index) * size + offset
		if uint(count) > maximum / size { return Value.from_object(array.object) }
		mut count_bytes := uint(count) * size
		if count_bytes > maximum - from_byte_index { return Value.from_object(array.object) }
		from_plus_count := from_byte_index + count_bytes
		if !buffer.is_shared_array_buffer() {
			buffer.move_data(to_byte_index, from_byte_index, count_bytes)
			return Value.from_object(array.object)
		}
		mut direction := i8(1)
		if from_byte_index < to_byte_index && to_byte_index < from_plus_count {
			direction = -1
			from_byte_index = from_plus_count - 1
			if count_bytes > maximum - to_byte_index { return Value.from_object(array.object) }
			to_byte_index += count_bytes - 1
		}
		for count_bytes > 0 {
			value := buffer.get_value(mut vm, from_byte_index, .uint8, true, .unordered, true)
			buffer.set_value(mut vm, to_byte_index, .uint8, value, true, .unordered, true)
			// Unsigned subtraction preserves the source's final unused wraparound.
			if direction < 0 {
				from_byte_index--
				to_byte_index--
			} else {
				from_byte_index++
				to_byte_index++
			}
			count_bytes--
		}
	}
	return Value.from_object(array.object)
}
