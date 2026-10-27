module libjs

fn test_data_view_witnesses_preserve_fixed_and_tracking_lengths_across_buffer_resizes() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	prototype := Object.create(vm.realm(), none)
	mut buffer := ArrayBufferObject.create(mut vm, vm.realm(), 8, prototype)!
	buffer.maximum_byte_length = uint(16)
	fixed := DataView.create(vm.realm(), buffer, ByteLength.from_u32(4), 2, prototype)
	tracking := DataView.create(vm.realm(), buffer, ByteLength.auto_length(), 2, prototype)
	assert voidptr(fixed.object.data_view?) == voidptr(fixed)
	assert voidptr(fixed.object.prototype?) == voidptr(prototype)
	assert fixed.object.own_property_keys().len == 0 && fixed.object.class_name == 'DataView'
	assert fixed.byte_offset() == 2
	old := make_data_view_with_buffer_witness_record(tracking, .seq_cst)
	for order in [BufferOrder.seq_cst, .unordered] {
		fixed_record := make_data_view_with_buffer_witness_record(fixed, order)
		tracking_record := make_data_view_with_buffer_witness_record(tracking, order)
		assert !is_view_out_of_bounds(fixed_record) && !is_view_out_of_bounds(tracking_record)
		assert get_view_byte_length(fixed_record) == 4 && get_view_byte_length(tracking_record) == 6
	}
	assert buffer.try_resize(4, true)
	assert is_view_out_of_bounds(make_data_view_with_buffer_witness_record(fixed, .seq_cst))
	fresh := make_data_view_with_buffer_witness_record(tracking, .seq_cst)
	assert !is_view_out_of_bounds(fresh) && get_view_byte_length(fresh) == 2
	// Cached length is a witness snapshot, rather than a live buffer-size read.
	assert !is_view_out_of_bounds(old) && get_view_byte_length(old) == 6
	assert buffer.try_resize(1, true)
	assert is_view_out_of_bounds(make_data_view_with_buffer_witness_record(tracking, .seq_cst))
	assert buffer.try_resize(12, true)
	assert get_view_byte_length(make_data_view_with_buffer_witness_record(fixed, .seq_cst)) == 4
	assert get_view_byte_length(make_data_view_with_buffer_witness_record(tracking, .seq_cst)) == 10
	detach_array_buffer(mut vm, mut buffer, none)!
	for view in [fixed, tracking] {
		record := make_data_view_with_buffer_witness_record(view, .seq_cst)
		assert record.cached_buffer_byte_length.is_detached()
		assert is_view_out_of_bounds(record)
	}
}

fn test_data_view_zero_length_is_in_bounds_at_buffer_end_but_not_past_it() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	prototype := Object.create(vm.realm(), none)
	mut buffer := ArrayBufferObject.create(mut vm, vm.realm(), 4, prototype)!
	buffer.maximum_byte_length = uint(8)
	for length in [ByteLength.from_u32(0), ByteLength.auto_length()] {
		at_end := DataView.create(vm.realm(), buffer, length, 4, prototype)
		past_end := DataView.create(vm.realm(), buffer, length, 5, prototype)
		record := make_data_view_with_buffer_witness_record(at_end, .unordered)
		assert !is_view_out_of_bounds(record) && get_view_byte_length(record) == 0
		assert is_view_out_of_bounds(make_data_view_with_buffer_witness_record(past_end, .unordered))
	}
	empty_buffer := ArrayBufferObject.create(mut vm, vm.realm(), 0, prototype)!
	empty_view := DataView.create(vm.realm(), empty_buffer, ByteLength.from_u32(0), 0, prototype)
	empty_record := make_data_view_with_buffer_witness_record(empty_view, .seq_cst)
	assert !empty_record.cached_buffer_byte_length.is_detached()
	assert !is_view_out_of_bounds(empty_record) && get_view_byte_length(empty_record) == 0
}
