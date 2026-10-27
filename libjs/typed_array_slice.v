module libjs

// TypedArrayPrototype.cpp::slice. Species creation precedes the second bounds
// witness; matching kinds preserve bytes, including NaN payloads and -0.
pub fn typed_array_prototype_slice(mut vm VM, prototypes PrimitiveObjectPrototypes, constructor_getter TypedArrayIntrinsicConstructorGetter, prototype_getter TypedArrayIntrinsicPrototypeGetter) !Value {
	start := vm.argument(0)
	end := vm.argument(1)
	source := typed_array_from_this(mut vm, prototypes)!
	record := validate_typed_array(mut vm, source.object, .seq_cst)!
	length := typed_array_length(record)
	relative_start := start.to_integer_or_infinity(mut vm)!
	mut k := u32(buffer_slice_index(uint(length), relative_start))
	relative_end := if end.is_undefined() {
		f64(length)
	} else {
		end.to_integer_or_infinity(mut vm)!
	}
	mut final := u32(buffer_slice_index(uint(length), relative_end))
	mut count := if final > k { final - k } else { u32(0) }
	realm := vm.realm()
	factory := fn [source, realm, count, prototype_getter] (mut vm VM) !&TypedArray {
		return source.create_default(mut vm, realm, count, prototype_getter)
	}
	array := typed_array_species_create(mut vm, source, factory, [
		Value.from_f64(f64(count)),
	], constructor_getter)!
	if count > 0 {
		fresh := make_typed_array_with_buffer_witness_record(source, .seq_cst)
		if is_typed_array_out_of_bounds(fresh) {
			return vm.throw_error_type(.type_error, .buffer_out_of_bounds, 'TypedArray')
		}
		updated_length := typed_array_length(fresh)
		if final > updated_length { final = updated_length }
		count = if final > k { final - k } else { u32(0) }
		if count == 0 { return Value.from_object(array.object) }
		if source.kind == array.kind
			|| (source.kind == .uint8 && array.kind == .uint8_clamped)
			|| (source.kind == .uint8_clamped && array.kind == .uint8) {
			source_buffer := source.viewed_buffer
			mut target_buffer := array.viewed_buffer
			size := u64(source.element_size())
			checked_source := u64(k) * size + u64(source.byte_offset)
			if checked_source > u64(0xffffffff) { return Value.from_object(array.object) }
			mut source_index := uint(checked_source)
			mut target_index := uint(array.byte_offset)
			checked_limit := u64(count) * size + u64(target_index)
			if checked_limit > u64(0xffffffff) { return Value.from_object(array.object) }
			limit := uint(checked_limit)
			if !target_buffer.is_detached() && !target_buffer.is_shared_array_buffer()
				&& !source_buffer.is_detached() && !source_buffer.is_shared_array_buffer()
				&& !target_buffer.shares_storage_with(source_buffer) {
				source_buffer.copy_data_to(mut target_buffer, source_index, target_index,
					limit - target_index)
			} else {
				// Aliased storage follows the upstream forward byte loop, not memmove.
				for target_index < limit {
					value := source_buffer.get_value(mut vm, source_index, .uint8, true,
						.unordered, true)
					target_buffer.set_value(mut vm, target_index, .uint8, value, true, .unordered,
						true)
					source_index++
					target_index++
				}
			}
		} else {
			mut n := u32(0)
			mut object := array.object
			for k < final {
				value := source.object.get(mut vm, PropertyName.from_number(k))!
				object.set(mut vm, PropertyName.from_number(n), value, .yes) or { panic(err) }
				k++
				n++
			}
		}
	}
	return Value.from_object(array.object)
}
