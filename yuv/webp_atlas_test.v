module yuv

fn test_webp_atlas_keeps_plane_bytes_and_extends_chroma_edges() {
	mut planes := []u8{len: 24}
	for i in 0 .. 16 { planes[i] = u8(i + 16) }
	for i, value in [u8(3), 7, 11, 19] { planes[16 + i] = value }
	for i, value in [u8(101), 103, 107, 109] { planes[20 + i] = value }
	packed := webp_420_atlas_upload(planes, 4, 4) or { panic('atlas upload') }
	for y in 0 .. 4 {
		for x in 0 .. 4 {
			i := (y * 4 + x) * 4
			// The right/bottom extension repeats the final chroma texel.
			ci := (if y == 0 { 0 } else { 2 }) + if x == 0 { 0 } else { 1 }
			assert packed[i..i + 4] == [planes[y * 4 + x], planes[16 + ci], planes[20 + ci], u8(255)]
		}
	}
}

fn test_webp_atlas_rejects_incomplete_odd_or_unbounded_planes() {
	planes := []u8{len: 24}
	assert webp_420_atlas_upload(planes[..23], 4, 4) == none
	assert webp_420_atlas_upload(planes, 3, 4) == none
	assert webp_420_atlas_upload(planes, 4, 3) == none
	assert webp_420_atlas_upload(planes, 0, 4) == none
	assert webp_420_atlas_upload(planes, 4098, 2) == none
	assert webp_420_atlas_upload(planes, 4096, 4096) == none
}
