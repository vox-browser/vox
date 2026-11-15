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
	assert webp_minified_upload([]u8{len: 54}, 6, 6, 2, 2) == none
	assert webp_minified_upload(planes, 4098, 2, 2, 1) == none
}
