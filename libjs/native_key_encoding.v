module libjs

$if test {
	__global native_key_encoding_disabled bool
	pub fn set_native_key_encoding_for_testing(enabled bool) { native_key_encoding_disabled = !enabled }
}

fn use_native_key_encoding() bool {
	$if test { if native_key_encoding_disabled { return false } }
	return true
}

fn native_key_u32(mut bytes []u8, value u32) {
	if use_native_key_encoding() {
		// The key builder owns this vector and creates no views while encoding.
		// grow_len bounds the four stores and handles capacity/length overflow.
		start := bytes.len
		unsafe {
			bytes.grow_len(4)
			mut output := &u8(bytes.data)
			output[start] = u8(value)
			output[start + 1] = u8(value >> 8)
			output[start + 2] = u8(value >> 16)
			output[start + 3] = u8(value >> 24)
		}
	} else {
		bytes << [u8(value), u8(value >> 8), u8(value >> 16), u8(value >> 24)]
	}
}
