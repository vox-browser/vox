module webidl

fn test_buffer_source_copy_views_detachment_and_writes() {
	backing := [u8(0), 1, 2, 3, 4, 5]
	array := BufferSource.array_buffer(backing)
	assert get_buffer_source_copy(array) == backing
	mut view := BufferSource.view(.uint16_array, backing, 2, 4)!
	assert view.element_size() == 2
	assert get_buffer_source_copy(view) == [u8(2), 3, 4, 5]
	view.write([u8(9), 8], 2)!
	assert view.bytes == [u8(0), 1, 2, 3, 9, 8]
	if _ := view.write([u8(1)], 0) {
		assert false
	} else {
		assert err.msg().contains('element size')
	}
	detached := BufferSource{
		kind:        .array_buffer
		bytes:       backing
		byte_length: 6
		detached:    true
	}
	assert get_buffer_source_copy(detached).len == 0
	assert is_buffer_source_detached(buffer_source_value(detached))
}

fn test_buffer_source_kind_predicates() {
	array := BufferSource.array_buffer([]u8{len: 8})
	data_view := BufferSource.view(.data_view, []u8{len: 8}, 0, 8)!
	typed := BufferSource.view(.float64_array, []u8{len: 8}, 0, 8)!
	assert array.is_array_buffer()
	assert data_view.is_data_view()
	assert typed.is_typed_array()
	assert is_buffer_source_type(buffer_source_value(typed))
}
