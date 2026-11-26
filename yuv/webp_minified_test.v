module yuv

fn test_minified_webp_upload_preserves_independent_planes() {
	mut planes := []u8{len: 24}
	for i in 0 .. 16 { planes[i] = u8(16 + i) }
	planes[16], planes[17], planes[18], planes[19] = 0, 64, 128, 255
	planes[20], planes[21], planes[22], planes[23] = 255, 128, 64, 0
	packed := webp_minified_upload(planes, 4, 4, 2, 2) or { panic('half upload') }
	assert packed == [u8(18), 0, 255, 255, 20, 64, 128, 255, 26, 128, 64, 255, 28, 255, 0, 255]
	quarter := webp_minified_upload(planes, 4, 4, 1, 1) or { panic('quarter upload') }
	assert quarter == [u8(23), 111, 111, 255]
}

fn test_minified_webp_upload_rejects_invalid_or_unsupported_planes() {
	planes := []u8{len: 24, init: 128}
	assert webp_minified_upload(planes[..23], 4, 4, 2, 2) == none
	assert webp_minified_upload(planes, 4, 4, 4, 4) == none
	assert webp_minified_upload(planes, 4, 4, 3, 2) == none
	assert webp_minified_upload(planes, 3, 4, 1, 2) == none
	assert webp_minified_upload(planes, 4, 4, 0, 2) == none
	assert webp_minified_upload(planes, 4, 4, 2, 1) == none
	assert webp_minified_upload(planes, 4098, 2, 2, 1) == none
}

fn test_minified_webp_accepts_only_shared_rounded_decode_levels() {
	assert webp_minified_upload_supported(480, 270, 120, 68)
	assert webp_minified_upload_supported(480, 270, 60, 34)
	assert webp_minified_upload_supported(6, 6, 2, 2)
	assert !webp_minified_upload_supported(480, 270, 120, 67)
	assert !webp_minified_upload_supported(480, 270, 121, 68)
	assert !webp_minified_upload_supported(480, 270, 240, 68)
	assert !webp_minified_upload_supported(480, 270, 0, 68)
	assert !webp_minified_upload_supported(480, 270, 480, 270)
	assert !webp_minified_upload_supported(481, 270, 121, 68)
	assert !webp_minified_upload_supported(4098, 2, 2049, 1)
	planes := []u8{len: 54, init: 128}
	packed := webp_minified_upload(planes, 6, 6, 2, 2) or { panic('rounded upload') }
	assert packed.len == 16
	for i in 0 .. 4 {
		assert packed[i * 4..i * 4 + 4] == [u8(128), 128, 128, 255]
	}
	assert webp_minified_upload(planes[..53], 6, 6, 2, 2) == none
}
