module libjs

fn test_regex_string_properties_preserve_packing_order_and_buffer_boundaries() {
	mut data := regex_get_string_property_data('Emoji_Keycap_Sequence')
	assert data.len == 49 && data[0] == 12
	assert data[1..5] == [u32(3), 0x23, 0xfe0f, 0x20e3]
	assert data[5..9] == [u32(3), 0x2a, 0xfe0f, 0x20e3]
	assert data[45..49] == [u32(3), 0x39, 0xfe0f, 0x20e3]
	for capacity in [0, 1, 48, 49, 51] {
		mut output := []u32{len: capacity, init: 0xffffffff}
		assert regex_get_string_property_data_into('Emoji_Keycap_Sequence', mut output) == 49
		if capacity < 49 {
			assert output.all(it == 0xffffffff)
		} else {
			assert output[..49] == data
			assert output[49..].all(it == 0xffffffff)
		}
	}
	data[1] = 0
	assert regex_get_string_property_data('Emoji_Keycap_Sequence')[1] == 3
}

fn test_regex_string_properties_reject_scalar_properties_and_keep_supplementary_points() {
	for name in ['Emoji', 'ASCII', 'unknown', 'rgi_emoji', 'RGI_Emoji\x00'] {
		assert regex_get_string_property_data(name).len == 0
		mut output := [u32(42), 42]
		assert regex_get_string_property_data_into(name, mut output) == 0
		assert output == [u32(42), 42]
	}
	data := regex_get_string_property_data('RGI_Emoji_Flag_Sequence')
	assert data.len > 1 && data[0] > 0
	for offset := 1; offset < data.len; offset += 3 {
		assert data[offset] == 2
		assert data[offset + 1] >= 0x1f1e6 && data[offset + 1] <= 0x1f1ff
		assert data[offset + 2] >= 0x1f1e6 && data[offset + 2] <= 0x1f1ff
	}
}
