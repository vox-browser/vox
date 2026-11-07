module main

import os

fn test_historical_webp_policy_only_retains_rgb_for_matching_incremental_lossy_responses() {
	bytes := os.read_bytes(os.join_path(@VMODROOT, 'Tests/Browser/Brave/input/decode-texture.webp'))!
	address := 'https://webp.test/paint.webp'
	mut app := BrowserApp{}
	assert app.webp_complete_yuv_allowed(address, bytes)
	for prefix in [u64(0), 29, 30, u64(bytes.len / 2)] {
		app.retain_navigation_resource(address, PreloadedResource{
			url: address
			body: bytes.bytestr()
			bytes_available_before_completion: prefix
		})
		assert app.webp_complete_yuv_allowed(address, bytes) == (!retain_incremental_webp_paint_policy || prefix < 30)
	}
	assert app.webp_complete_yuv_allowed(address, bytes[..29])
	mut different := bytes.clone()
	different[different.len - 1] ^= 1
	assert app.webp_complete_yuv_allowed(address, different)
}
