module main

import os

fn test_lossy_webp_retains_complete_yuv420_planes_for_native_sampling() {
	$if macos {
		if C.native_webp_yuv_decoder_available() == 0 {
			eprintln('SKIP: optional libwebp YUV decoder unavailable')
			return
		}
		bytes := os.read_bytes(os.join_path(@DIR, 'Tests/Browser/Brave/input/decode-texture.webp'))!
		mut width := 0
		mut height := 0
		mut size := 0
		decoded := C.native_decode_webp_yuv(bytes.data, uint(bytes.len), &width, &height, &size)
		assert decoded != unsafe { nil }
		defer { C.native_free_webp_pixels(decoded) }
		assert width == 140 && height == 94
		assert size == 140 * 94 + 2 * 70 * 47
		planes := unsafe { decoded.vbytes(size) }
		assert planes[0] >= 16 && planes[0] < 40
		assert planes[140 * 94] != planes[140 * 94 + 70 * 47]
		lossless := os.read_bytes(os.join_path(@DIR, 'Tests/Browser/Brave/input/decode-colors.webp'))!
		rejected := C.native_decode_webp_yuv(lossless.data, uint(lossless.len), &width, &height, &size)
		assert rejected == unsafe { nil }
		assert width == 0 && height == 0 && size == 0
		invalid := 'RIFFxxxxWEBPVP8 invalid'.bytes()
		assert C.native_decode_webp_yuv(invalid.data, uint(invalid.len), &width, &height, &size) == unsafe { nil }
	}
}
