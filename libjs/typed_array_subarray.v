module libjs

// TypedArrayPrototype.cpp::subarray. An out-of-bounds source contributes zero
// length; default view initialization still checks the original buffer.
pub fn typed_array_prototype_subarray(mut vm VM, prototypes PrimitiveObjectPrototypes, constructor_getter TypedArrayIntrinsicConstructorGetter, prototype_getter TypedArrayIntrinsicPrototypeGetter) !Value {
	begin := vm.argument(0)
	end := vm.argument(1)
	source := typed_array_from_this(mut vm, prototypes)!
	buffer := source.viewed_buffer
	record := make_typed_array_with_buffer_witness_record(source, .seq_cst)
	length := if is_typed_array_out_of_bounds(record) { u32(0) } else { typed_array_length(record) }
	relative_begin := begin.to_integer_or_infinity(mut vm)!
	begin_index := u32(buffer_slice_index(uint(length), relative_begin))
	checked_offset := u64(source.byte_offset) + u64(begin_index) * u64(source.element_size())
	if checked_offset > u64(0xffffffff) { return Value.from_object(source.object) }
	byte_offset := u32(checked_offset)
	mut arguments := [Value.from_object(buffer.object), Value.from_f64(f64(byte_offset))]
	mut new_length := ?u32(none)
	if !source.array_length.is_auto() || !end.is_undefined() {
		relative_end := if end.is_undefined() {
			f64(length)
		} else {
			end.to_integer_or_infinity(mut vm)!
		}
		end_index := u32(buffer_slice_index(uint(length), relative_end))
		count := if end_index > begin_index { end_index - begin_index } else { u32(0) }
		new_length = count
		arguments << Value.from_f64(f64(count))
	}
	realm := vm.realm()
	factory := fn [source, realm, buffer, byte_offset, new_length, prototype_getter] (mut vm VM) !&TypedArray {
		mut view := source.create_default_view_on_buffer(realm, buffer, prototype_getter)
		length_value := if count := new_length { Value.from_f64(f64(count)) } else { js_undefined() }
		initialize_typed_array_from_array_buffer(mut vm, mut view, buffer,
			Value.from_f64(f64(byte_offset)), length_value)!
		return view
	}
	array := typed_array_species_create(mut vm, source, factory, arguments, constructor_getter)!
	return Value.from_object(array.object)
}
