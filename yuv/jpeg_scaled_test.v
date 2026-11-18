module yuv

import os

fn test_scaled_jpeg_upload_preserves_plane_values_before_rgb_clipping() {
	mut planes := []u8{len: 24, init: 128}
	for i, value in [0, 255, 0, 255] { planes[16 + i] = u8(value) }
	packed := jpeg_scaled_upload(planes, 4, 4, 2, 2, true) or { panic('upload') }
	assert packed == [u8(128), 0, 128, 255, 128, 255, 128, 255, 128, 0, 128, 255, 128, 255, 128,
		255]
	assert jpeg_scaled_upload(planes[..23], 4, 4, 2, 2, true) == none
	assert jpeg_scaled_upload(planes, 4, 4, 0, 2, true) == none
	assert jpeg_scaled_upload(planes, 4, 4, 5, 2, true) == none
	assert jpeg_scaled_upload(planes, 3, 4, 2, 2, true) == none
	// A 4:4:4 upload must not interpret its U and V as subsampled planes.
	single := jpeg_scaled_upload([u8(70), 90, 110], 1, 1, 1, 1, false) or { panic('4:4:4 upload') }
	assert single == [u8(70), 90, 110, 255]
}

fn test_plane_resizing_matches_normalized_gray8_store_rounding() {
	// Independent SkPixmap Gray8 scalePixels results: each source row is enlarged
	// from two texels to three, placing its middle sample exactly halfway.
	source := [u8(0), 1, 1, 2, 2, 3, 3, 4]
	// Normalization/interpolation makes the 2/3 midpoint slightly greater
	// than 2.5 on byte storage. Rounding the unnormalized bytes misses it.
	horizontal := jpeg_scale_plane(source, 2, 4, 3, 4) or { panic('horizontal scale') }
	assert horizontal == [u8(0), 0, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4]
	// Exercise the same store after vertical interpolation and clamped edges.
	vertical := jpeg_scale_plane([u8(0), 1], 1, 2, 1, 3) or { panic('vertical scale') }
	assert vertical == [u8(0), 0, 1]
	normalized := jpeg_scale_plane([u8(2), 3], 1, 2, 1, 3) or { panic('normalized scale') }
	assert normalized == [u8(2), 3, 3]
}

fn test_scaled_jpeg_planes_keep_box_mips_and_neutral_chroma() {
	mut planes := []u8{len: 24, init: 128}
	for i in 0 .. 16 { planes[i] = u8(i * 4) }
	rgba := jpeg_scaled_rgba(planes, 4, 4, 2, 2, true) or { panic('scaled') }
	for i, v in [10, 18, 42, 50] {
		assert rgba[i * 4..i * 4 + 4] == [u8(v), u8(v), u8(v), 255]
	}
	mut ramp := []u8{len: 96, init: 128}
	for y in 0 .. 8 {
		for x in 0 .. 8 { ramp[y * 8 + x] = u8(x * 24) }
	}
	scaled := jpeg_scaled_rgba(ramp, 8, 8, 3, 3, true) or { panic('fractional scale') }
	for y in 0 .. 3 {
		for x, v in [20, 84, 148] {
			i := (y * 3 + x) * 4
			assert scaled[i..i + 4] == [u8(v), u8(v), u8(v), 255]
		}
	}
	assert jpeg_scaled_rgba(planes, 4, 4, 4, 4, true) == jpeg_bilinear_rgba(planes, 4, 4, true)
}

fn test_scaled_jpeg_rejects_incomplete_planes_and_invalid_sizes() {
	for size in [-1, 0, 5] {
		assert jpeg_scaled_rgba([]u8{len: 24}, 4, 4, size, 2, true) == none
	}
	assert jpeg_scaled_rgba([]u8{len: 23}, 4, 4, 2, 2, true) == none
	assert jpeg_scaled_rgba([]u8{len: 24}, 3, 4, 2, 2, true) == none
}

fn test_plane_sampling_declines_rotated_and_malformed_exif() {
	assert jpeg_plane_orientation_supported([u8(255), 216, 255, 218])
	mut b := [u8(255), 216, 255, 225, 0, 34, 69, 120, 105, 102, 0, 0, 73, 73, 42, 0, 8, 0, 0, 0,
		1, 0, 18, 1, 3, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 255, 218]
	// APP1 spans the EXIF payload through the next-IFD pointer.
	b[5] = 34
	assert jpeg_plane_orientation_supported(b)
	b[30] = 6
	assert !jpeg_plane_orientation_supported(b)
	b[30] = 1
	b[16] = 255
	assert !jpeg_plane_orientation_supported(b)
}

fn test_plane_sampling_reads_big_endian_orientation_and_truncated_headers() {
	mut b := [u8(255), 216, 255, 225, 0, 34, 69, 120, 105, 102, 0, 0, 77, 77, 0, 42, 0, 0, 0, 8,
		0, 1, 1, 18, 0, 3, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 255, 218]
	assert jpeg_plane_orientation_supported(b)
	b[31] = 8
	assert !jpeg_plane_orientation_supported(b)
	for end in 0 .. b.len - 2 {
		assert !jpeg_plane_orientation_supported(b[..end])
	}
}

fn test_scaled_jpeg_promotes_chroma_before_clipping_rgb() {
	mut planes := []u8{len: 24, init: 128}
	planes[16] = 0
	planes[17] = 255
	planes[18] = 0
	planes[19] = 255
	actual := jpeg_scaled_rgba(planes, 4, 4, 2, 2, true) or { panic('chroma promotion') }
	assert actual == [u8(128), 172, 0, 255, 128, 84, 255, 255, 128, 172, 0, 255, 128, 84, 255,
		255]
}

fn test_scaled_jpeg_keeps_fractional_rgb_before_texture_sampling() {
	mut planes := []u8{len: 24, init: 128}
	for i in 20 .. 24 { planes[i] = 129 }
	colors := jpeg_scaled_colors(planes, 4, 4, 2, 2, true) or { panic('colors') }
	assert colors[0] == f32(129.402 / 255)
	assert colors[1] == f32((128 - .714136) / 255)
	assert colors[2] == f32(128.0 / 255)
	assert colors[3] == 1
	assert jpeg_scaled_colors(planes[..23], 4, 4, 2, 2, true) == none
}

fn test_plane_resizing_uses_geometric_mean_for_rounded_mips() {
	// Independent SkPixmap Gray8 results with Chromium's legacy anisotropic
	// mip selection. Rounded decode extents must not select a deeper mip.
	dimensions := [[8, 8, 2, 3]!, [8, 8, 3, 2]!, [8, 8, 8, 1]!, [10, 6, 3, 2]!, [12, 10, 3, 3]!,
		[3, 5, 2, 2]!, [16, 16, 4, 5]!, [16, 16, 5, 4]!, [32, 18, 8, 5]!, [16, 16, 4, 4]!]
	expected := [
		[u8(71), 135, 128, 118, 132, 127],
		[u8(79), 136, 113, 154, 110, 119],
		[u8(135), 131, 125, 126, 136, 129, 107, 96],
		[u8(69), 133, 133, 133, 123, 113],
		[u8(84), 131, 125, 120, 122, 124, 123, 133, 122],
		[u8(40), 74, 117, 177],
		[u8(81), 132, 125, 141, 121, 121, 124, 126, 126, 132, 122, 144, 105, 140, 152, 130, 136,
			122, 128, 138],
		[u8(86), 145, 118, 123, 137, 143, 129, 124, 116, 140, 108, 119, 146, 138, 143, 139, 138,
			120, 131, 146],
		[u8(89), 130, 125, 140, 123, 112, 140, 161, 122, 123, 123, 130, 131, 99, 131, 157, 118,
			136, 122, 140, 94, 144, 130, 148, 138, 122, 152, 123, 127, 124, 121, 131, 140, 129,
			137, 158, 128, 137, 145, 141],
		[u8(97), 127, 125, 139, 127, 125, 123, 137, 109, 139, 137, 135, 139, 121, 135, 133],
	]
	for n, d in dimensions {
		source := []u8{len: d[0] * d[1], init: u8(((index % d[0]) * 17 + (index / d[0]) * 29 + (index % d[0]) * (index / d[0]) * 7 + 13) & 255)}
		actual := jpeg_scale_plane(source, d[0], d[1], d[2], d[3]) or { panic('plane scale') }
		assert actual == expected[n], 'case ${n}'
	}
}

fn test_plane_identity_result_owns_its_pixels() {
	source := [u8(10), 20, 30, 40]
	mut scaled := jpeg_scale_plane(source, 2, 2, 2, 2) or { panic('identity resize') }
	scaled[0] = 99
	assert source == [u8(10), 20, 30, 40]
}

fn test_large_jpeg_and_webp_yuv_uploads_match_serial_mips() {
	serial_setting := 'VOX_SERIAL_CPU_RASTER'
	previous := os.getenv_opt(serial_setting)
	defer {
		if value := previous {
			os.setenv(serial_setting, value, true)
		} else {
			os.unsetenv(serial_setting)
		}
	}

	for subsampled in [false, true] {
		// 4:4:4 exercises odd dimensions on all three planes. For the
		// 4:2:0 WebP half-size upload the chroma is already the target size.
		width := if subsampled { 2048 } else { 2047 }
		height := if subsampled { 1840 } else { 1795 }
		size := width * height
		length := if subsampled { size + size / 2 } else { size * 3 }
		source := []u8{len: length, init: u8((index * 53 + index / 127) & 255)}
		original := source.clone()
		assert os.setenv(serial_setting, '1', true) == 0
		serial := if subsampled {
			webp_minified_upload(source, width, height, width / 2, height / 2)
		} else {
			jpeg_scaled_upload(source, width, height, 1003, 857, false)
		} or { panic('serial upload') }
		assert os.unsetenv(serial_setting) == 0
		parallel := if subsampled {
			webp_minified_upload(source, width, height, width / 2, height / 2)
		} else {
			jpeg_scaled_upload(source, width, height, 1003, 857, false)
		} or { panic('parallel upload') }
		pixels_match := parallel == serial
		source_unchanged := source == original
		assert pixels_match, 'YUV upload bytes differ for subsampled=${subsampled}'
		assert source_unchanged, 'source plane bytes changed'
	}
}
