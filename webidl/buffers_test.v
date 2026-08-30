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

fn test_bufferable_object_and_array_buffer_view_surfaces() {
	source := BufferSource.view(.uint16_array, [u8(0), 1, 2, 3], 2, 2)!
	base := BufferableObjectBase.create(source)
	assert base.byte_length() == 2
	assert base.byte_offset() == 2
	assert base.element_size() == 2
	assert base.is_typed_array_base()
	assert !base.is_data_view()
	assert !base.is_array_buffer()
	assert base.viewed_array_buffer().byte_length == 4
	assert BufferableObjectBase.bufferable_object_from_raw_object(source).kind == .uint16_array
	mut view := ArrayBufferView.create(source)!
	view.write([u8(8), 9], 0)!
	assert view.raw_object().bytes == [u8(0), 1, 8, 9]
}
