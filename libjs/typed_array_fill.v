module libjs

// TypedArrayPrototype.cpp::fast_typed_array_fill. The V numeric-byte boundary
// supplies the source scalar's representation; the 256-byte chunk path and the
// per-element shared path retain the pinned implementation's write granularity.
fn fast_typed_array_fill(mut vm VM, array &TypedArray, begin u32, end u32, value Value) {
	if begin >= end { return }
	size := usize(array.element_size())
	offset := usize(array.byte_offset)
	maximum := ~usize(0)
	if usize(begin) > (maximum - offset) / size || usize(end) > (maximum - offset) / size { return }
	computed_begin := usize(begin) * size + offset
	computed_end := usize(end) * size + offset
	mut buffer := array.viewed_buffer
	if computed_begin >= buffer.byte_length() || computed_end > buffer.byte_length() { return }
	raw := numeric_to_raw_bytes(mut vm, array.kind, value, true)
	mut byte_index := computed_begin
	if !buffer.is_shared_array_buffer() {
		element_count := if size > 256 { usize(1) } else { usize(256) / size }
		mut pattern := []u8{cap: int(element_count * size)}
		for _ in 0 .. element_count {
			pattern << raw
		}
		mut remaining := usize(end - begin) * size
		for remaining > 0 {
			chunk := if remaining < usize(pattern.len) { remaining } else { usize(pattern.len) }
			buffer.overwrite(byte_index, pattern[..int(chunk)])
			byte_index += chunk
			remaining -= chunk
		}
		return
	}
	for _ in begin .. end {
		buffer.overwrite(byte_index, raw)
		byte_index += size
	}
}

pub fn typed_array_prototype_fill(mut vm VM, prototypes PrimitiveObjectPrototypes) !Value {
	value := vm.argument(0)
	start := vm.argument(1)
	end := vm.argument(2)
	mut array := typed_array_from_this(mut vm, prototypes)!
	mut record := validate_typed_array(mut vm, array.object, .seq_cst)!
	mut length := typed_array_length(record)
	numeric := if array.content_type() == .bigint {
		Value.from_bigint(value.to_bigint(mut vm)!)
	} else {
		value.to_number(mut vm)!
	}
	mut k := u32(buffer_slice_index(usize(length), start.to_integer_or_infinity(mut vm)!))
	relative_end := if end.is_undefined() {
		f64(length)
	} else {
		end.to_integer_or_infinity(mut vm)!
	}
	mut final_index := u32(buffer_slice_index(usize(length), relative_end))
	record = make_typed_array_with_buffer_witness_record(array, .seq_cst)
	if is_typed_array_out_of_bounds(record) {
		return vm.throw_error_type(.type_error, .buffer_out_of_bounds, 'TypedArray')
	}
	length = typed_array_length(record)
	if final_index > length { final_index = length }
	if numeric.is_int32()
		&& array.kind in [.uint8, .uint16, .uint32, .int8, .int16, .int32, .uint8_clamped] {
		fast_typed_array_fill(mut vm, array, k, final_index, numeric)
		return Value.from_object(array.object)
	}
	for k < final_index {
		typed_array_set_element(mut vm, mut array, CanonicalIndex.create(.index, k), numeric)!
		k++
	}
	return Value.from_object(array.object)
}
