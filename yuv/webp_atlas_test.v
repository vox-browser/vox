module yuv

import math

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

fn test_webp_atlas_rejects_incomplete_or_unbounded_planes() {
	planes := []u8{len: 24}
	assert webp_420_atlas_upload(planes[..23], 4, 4) == none
	assert webp_420_atlas_upload(planes, 3, 4) == none
	assert webp_420_atlas_upload(planes, 4, 3) == none
	assert webp_420_atlas_upload(planes, 0, 4) == none
	assert webp_420_atlas_upload(planes, 4098, 2) == none
	assert webp_420_atlas_upload(planes, 4096, 4096) == none
}

fn test_webp_atlas_sampling_keeps_selected_mip_grids_aligned() {
	assert webp_atlas_sampling_supported(256, 144, 130, 73)
	assert webp_atlas_sampling_supported(6, 6, 4, 4) // Odd base chroma, no chroma mip.
	assert webp_atlas_sampling_supported(960, 540, 269, 151)
	assert webp_atlas_sampling_supported(12, 12, 4, 4) // Odd last selected chroma level.
	assert !webp_atlas_sampling_supported(960, 540, 358, 202) // No additional upload mip.
	assert !webp_atlas_sampling_supported(960, 538, 269, 151) // Chroma mip would misalign.
	assert !webp_atlas_sampling_supported(1280, 720, 245, 138) // Below the quarter bound.
	for size in [[0, 4], [-4, 4], [3, 4], [4, 3], [4098, 4], [4096, 4096]] {
		assert !webp_atlas_sampling_supported(size[0], size[1], 1, 1)
	}

	for target in [[f64(240), 135], [f64(480), 270], [f64(960), 540], [f64(0), 151], [math.nan(),
		151], [math.inf(1), 151], [f64(269), math.nan()]] {
		assert !webp_atlas_sampling_supported(960, 540, target[0], target[1])
	}
}

fn test_atlas_mip_padding_repeats_averaged_chroma_and_preserves_other_channels() {
	mut pixels := []u8{len: 4 * 4 * 4}
	for i in 0 .. 16 {
		pixels[i * 4] = u8(i)
		pixels[i * 4 + 1] = 200
		pixels[i * 4 + 2] = 210
		pixels[i * 4 + 3] = u8(255 - i)
	}
	for i, index in [0, 1, 4, 5] {
		pixels[index * 4 + 1] = u8(10 + i * 10)
		pixels[index * 4 + 2] = u8(60 + i * 10)
	}
	before := pixels.clone()
	result := webp_atlas_extend_mip_chroma(pixels, 4, 4, 2, 2) or { panic('mip edges') }
	expected := [10, 20, 20, 20, 30, 40, 40, 40, 30, 40, 40, 40, 30, 40, 40, 40]
	for i, value in expected {
		assert result[i * 4] == before[i * 4] && result[i * 4 + 3] == before[i * 4 + 3]
		assert result[i * 4 + 1] == value && result[i * 4 + 2] == value + 50
	}
	assert pixels == before
	assert webp_atlas_extend_mip_chroma(pixels[..60], 4, 4, 2, 2) == none
	assert webp_atlas_extend_mip_chroma(pixels, 4, 4, 0, 2) == none
	assert webp_atlas_extend_mip_chroma(pixels, 4, 4, 5, 2) == none
}


fn test_webp_atlas_keeps_ceiling_sized_chroma_for_odd_luma_edges() {
	// A 3x5 luma plane owns 2x3 chroma planes, not 1x2.
	mut planes := []u8{len: 27}
	for i in 0 .. 15 { planes[i] = u8(i + 16) }
	for i in 0 .. 6 {
		planes[15 + i] = u8(40 + i)
		planes[21 + i] = u8(80 + i)
	}
	packed := webp_420_atlas_upload(planes, 3, 5) or { panic('odd atlas') }
	for py in 0 .. 5 {
		for px in 0 .. 3 {
			ci := (if py < 3 { py } else { 2 }) * 2 + if px < 2 { px } else { 1 }
			i := (py * 3 + px) * 4
			assert packed[i..i + 4] == [planes[py * 3 + px], planes[15 + ci], planes[21 + ci], u8(255)]
		}
	}
	assert webp_420_atlas_upload(planes[..26], 3, 5) == none
	assert webp_atlas_sampling_supported(320, 179, 173, 97)
	assert webp_atlas_sampling_supported(319, 179, 173, 97)
	assert !webp_atlas_sampling_supported(320, 179, 150, 80)
	assert !webp_atlas_sampling_supported(319, 179, 150, 80)
}
