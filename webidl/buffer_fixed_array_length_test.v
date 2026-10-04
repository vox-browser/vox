module webidl

fn test_source_fixed_array_length_is_initialized_in_elements_and_retained_after_witness_changes() {
	for kind in [BufferSourceKind.uint8_array, .uint16_array, .uint32_array, .float64_array] {
		size := element_size_for_kind(kind)
		mut source := BufferSource.view(kind, []u8{len: int(size * 5)}, size, size * 3)!
		assert source.fixed_array_length()? == 3
		assert source.byte_length() == size * 3
		assert get_buffer_source_copy(source).len == int(size * 3)
		source.out_of_bounds_ = true
		assert source.byte_length() == 0 && get_buffer_source_copy(source).len == 0
		assert source.fixed_array_length()? == 3
		source.out_of_bounds_ = false
		source.detached_ = true
		assert get_buffer_source_copy(source).len == 0
		assert source.fixed_array_length()? == 3
	}
}

fn test_source_fixed_array_length_uses_zero_for_empty_typed_views_and_no_slot_for_other_buffers() {
	empty := BufferSource.view(.uint8_array, [], 0, 0)!
	assert empty.fixed_array_length()? == 0
	assert BufferSource.array_buffer([u8(1), 2]).fixed_array_length() == none
	data := BufferSource.view(.data_view, [u8(1), 2], 0, 2)!
	assert data.fixed_array_length() == none
}
