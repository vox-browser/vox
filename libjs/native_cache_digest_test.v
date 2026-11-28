module libjs

import crypto.sha256

fn test_native_cache_digest_preserves_known_sha256_values_and_binary_inputs() {
	defer { set_native_cache_digests_for_testing(true) }
	for enabled in [false, true] {
		set_native_cache_digests_for_testing(enabled)
		assert native_cache_digest_string('') == 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
		assert native_cache_digest_string('abc') == 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'
		for count in [1, 31, 55, 56, 63, 64, 65, 127, 128, 129, 4096, 65537] {
			mut bytes := []u8{len: count}
			for index in 0 .. count { bytes[index] = u8(index % 256) }
			expected := sha256.sum(bytes).hex()
			assert native_cache_digest_bytes(bytes) == expected
			assert native_cache_digest_string(bytes.bytestr()) == expected
		}
		text := ('cached native code: 😀' + u8(0).ascii_str()).repeat(10000)
		assert native_cache_digest_string(text) == sha256.hexhash(text)
	}
}
