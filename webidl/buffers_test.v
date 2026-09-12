module webidl

fn test_buffer_source_copy_views_detachment_and_writes() {
	backing := [u8(0), 1, 2, 3, 4, 5]
	array := BufferSource.array_buffer(backing)
	assert get_buffer_source_copy(array) == backing
	mut view := BufferSource.view(.uint16_array, backing, 2, 4)!
	assert view.element_size() == 2
	assert get_buffer_source_copy(view) == [u8(2), 3, 4, 5]
	view.write([u8(9), 8], 2)!
	assert get_buffer_source_copy(view) == [u8(2), 3, 9, 8]
	if _ := view.write([u8(1)], 0) {
		assert false
	} else {
		assert err.msg().contains('element size')
	}
	detached := BufferSource{
		kind: .array_buffer
		bytes_: backing
		byte_length_: 6
		detached_: true
	}
	assert get_buffer_source_copy(detached).len == 0
	assert BufferSource.is_detached(buffer_source_value(detached))
	assert is_buffer_source_detached(buffer_source_value(detached))
}

fn test_buffer_source_kind_predicates_and_accessors() {
	array := BufferSource.array_buffer([]u8{len: 8})
	data_view := BufferSource.view(.data_view, []u8{len: 8}, 0, 8)!
	typed := BufferSource.view(.float16_array, []u8{len: 8}, 2, 4)!
	assert BufferSource.from_object(array).is_array_buffer()
	assert data_view.is_data_view()
	assert typed.is_typed_array()
	assert typed.byte_offset() == 2
	assert typed.byte_length() == 4
	assert typed.element_size() == 2
	assert typed.typed_array_base()? == typed
	assert data_view.typed_array_base() == none
	assert is_buffer_source_type(buffer_source_value(typed))
}

fn test_buffer_source_validation_reports_view_metadata() {
	source := BufferSource.view(.uint16_array, [u8(0), 1, 2, 3], 2, 2)!
	validated := validate_buffer_source(source)!
	assert validated.buffer.is_array_buffer()
	assert validated.buffer.byte_length() == 4
	assert validated.byte_offset == 2
	assert validated.byte_length == 2
	assert validated.element_size == 2
	assert !validated.is_data_view
	assert !validated.is_array_buffer

	mut out_of_bounds := source
	out_of_bounds.out_of_bounds_ = true
	assert out_of_bounds.byte_length() == 0
	if _ := validate_buffer_source(out_of_bounds) {
		assert false
	} else {
		assert err.msg().contains('out of bounds')
	}
}

fn test_array_buffer_view_checked_write_and_forwarding_surface() {
	source := BufferSource.view(.uint16_array, [u8(0), 1, 2, 3], 2, 2)!
	mut view := ArrayBufferView.from_object(source)!
	assert view.array_buffer_view().kind == .uint16_array
	assert view.byte_length() == 2
	assert view.byte_offset() == 2
	assert view.element_size() == 2
	assert !view.is_out_of_bounds()
	assert !view.is_data_view()
	assert view.typed_array_base()?.kind == .uint16_array
	assert view.viewed_array_buffer().byte_length() == 4
	validated := validate_array_buffer_view(view)!
	assert validated.byte_offset == 2
	view.write_checked([u8(8), 9], 0)!
	assert get_buffer_source_copy(view.raw_object()) == [u8(8), 9]
	if _ := view.write_checked([u8(1), 2], 1) {
		assert false
	} else {
		assert err.msg().contains('fit in the view')
	}
}

fn test_empty_checked_write_does_not_validate_detachment() {
	mut source := BufferSource.view(.data_view, [u8(1)], 0, 1)!
	source.detached_ = true
	mut view := ArrayBufferView.create(source)!
	view.write_checked([], 0)!
	if _ := view.write_checked([u8(2)], 0) {
		assert false
	} else {
		assert err.msg().contains('detached')
	}
}
