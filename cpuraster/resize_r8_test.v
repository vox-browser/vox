module cpuraster

import crypto.sha256

fn test_r8_resize_preserves_constant_planes_and_byte_roundtrips() {
	mut bytes := []u8{len: 256}
	for i in 0 .. 256 { bytes[i] = u8(i) }
	identity := resize_r8(bytes, 16, 16, 16, 16) or { panic('identity') }
	assert identity == bytes
	for value in [u8(0), 1, 2, 127, 128, 254, 255] {
		constant := resize_r8([value], 1, 1, 7, 5) or { panic('constant') }
		assert constant == []u8{len: 35, init: value}
	}
}

fn test_r8_resize_rejects_invalid_plane_buffers_and_extents() {
	for dims in [[0, 1, 1, 1], [-1, 1, 1, 1], [1, 1, 0, 1], [1, 1, 1, -1], [4097, 1, 1, 1],
		[1, 1, 4097, 1], [4096, 4096, 1, 1], [1, 1, 4096, 4096]] {
		assert resize_r8([u8(128)], dims[0], dims[1], dims[2], dims[3]) == none
	}
	assert resize_r8([u8(0), 1, 2], 2, 2, 1, 1) == none
}

fn test_r8_resize_matches_independent_skia_reference_dimensions() {
	references := ['0e543cf34c7d4497e157a0109dfc909a8e81312b6d02756fd8d1bd3514aa1939',
		'e2ec834d0f7c74ce9cc101bd6262f52978f0d65539a728c3019d870d32ef1c16',
		'5ef11c570b2bf2bfaad589a3fce0d4ee34b6b9f3c0275f8d54115d9ad4781f0f',
		'aab53cbacb632a62cd172cf8fa3b284121bde6c5d45243073dfd44f640f92711',
		'7570d1ab410b1cbe9b25567ab060327d2782bf8a93d6128626ebcd09fa855710',
		'04c0cc9ceebb8946ea9f5e849f7d5ef1fac1bd9c4554b75636affc0abb229415',
		'6268217887d951bfc362da6cfc478cca8c412cf117140d0f7677e09994efd4c6',
		'08cbe3ec7880aeba12dff2b8098e44fcdb3e6c2b3a857e83887ff2878cba72c5',
		'a7c5089f24e75397e39728330b43635bdaf6eee3efe4fae66aaea3996517b001',
		'af7db0e8fbd621b8be49daa59b03e77284a99c65eca2c255ea0b2d45655f7b17']
	for n, d in [[2, 4, 3, 4], [1, 2, 1, 3], [7, 5, 11, 9], [13, 9, 4, 3], [8, 8, 3, 3],
		[120, 67, 120, 68], [19, 17, 33, 29], [1, 7, 9, 3], [7, 1, 3, 9], [64, 32, 17, 11]] {
		mut source := []u8{len: d[0] * d[1]}
		for y in 0 .. d[1] {
			for x in 0 .. d[0] {
				source[y * d[0] + x] = u8((x * 17 + y * 29 + x * y * 7 + 13) & 255)
			}
		}
		pixels := resize_r8(source, d[0], d[1], d[2], d[3]) or { panic('reference resize') }
		assert sha256.sum(pixels).hex() == references[n], 'dimensions=${d}'
	}
}
