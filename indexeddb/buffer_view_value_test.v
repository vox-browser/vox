module indexeddb

fn test_buffer_view_values_clone_the_full_backing_and_use_only_view_bytes_as_keys() {
	mut bytes := [u8(0), 1, 2, 3, 4, 5]
	view := array_buffer_view_value('Uint16Array', bytes, 2, 4, u32(2))!
	bytes[2] = 90
	assert view.bytes == [u8(0), 1, 2, 3, 4, 5]
	mut copy := view.clone()
	copy.bytes[3] = 91
	assert view.bytes[3] == 3
	assert copy.view_name == 'Uint16Array' && copy.view_offset == 2
	assert copy.view_byte_length == 4 && copy.view_length == ?u32(2)
	assert value_to_key(view).bytes == [u8(2), 3, 4, 5]
	data_view := array_buffer_view_value('DataView', view.bytes, 1, 3, none)!
	assert data_view.view_length == none
	assert value_to_key(data_view).bytes == [u8(1), 2, 3]
}

fn test_buffer_view_values_reject_unknown_unaligned_and_out_of_bounds_records() {
	if _ := array_buffer_view_value('Unknown', []u8{}, 0, 0, none) {
		assert false
	} else {
		assert err.msg().starts_with('DataCloneError:')
	}
	if _ := array_buffer_view_value('Uint16Array', [u8(0), 1, 2, 3], 1, 2, u32(1)) {
		assert false
	} else {
		assert err.msg().starts_with('DataCloneError:')
	}
	if _ := array_buffer_view_value('Uint32Array', [u8(0), 1, 2, 3], 0, 4, u32(2)) {
		assert false
	} else {
		assert err.msg().starts_with('DataCloneError:')
	}
	if _ := array_buffer_view_value('DataView', [u8(0)], 1, 1, none) {
		assert false
	} else {
		assert err.msg().starts_with('DataCloneError:')
	}
}
