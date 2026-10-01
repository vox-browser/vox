module libjs

fn test_byte_length_witness_tags_distinguish_empty_tracking_and_detached_views() {
	for value in [u32(0), 1, 0xffffffff] {
		length := ByteLength.from_u32(value)
		assert !length.is_auto() && !length.is_detached()
		assert length.length() == value
	}
	tracking := ByteLength.auto_length()
	detached := ByteLength.detached()
	assert tracking.is_auto() && !tracking.is_detached()
	assert detached.is_detached() && !detached.is_auto()
	assert tracking != detached && tracking != ByteLength.from_u32(0)
	assert detached != ByteLength.from_u32(0)
}
