// vtest build: macos
module ggshape

import crypto.sha256
import yuv

#flag darwin -L/opt/homebrew/lib -I/opt/homebrew/include -lwebpdecoder
#include <webp/decode.h>

fn C.WebPDecodeYUVInto(&u8, uint, &u8, uint, i32, &u8, uint, i32, &u8, uint, i32) &u8

// Separate native Graphite/Metal R8 textures, device-space rounded clipping,
// and the recorded natural-image canvas transform supply these full frames.
// This pins fragment normalization without changing a browser PNG reference.
fn test_planar_image_fragment_coordinates_match_native_rounded_draws() {
	bytes := $embed_file('@VMODROOT/Tests/Browser/Brave/sites/cnn/bodies/781d2b9c3ec6b401a4b2e9dbdce964f4ba3f6ecdb9880466d85dc30df6227139').to_bytes()
	assert sha256.sum(bytes).hex() == '781d2b9c3ec6b401a4b2e9dbdce964f4ba3f6ecdb9880466d85dc30df6227139'
	mut planes := []u8{len: 960 * 540 * 3 / 2}
	decoded := unsafe {
		C.WebPDecodeYUVInto(bytes.data, uint(bytes.len), planes.data, 960 * 540, 960,
			&planes[960 * 540], 480 * 270, 480, &planes[960 * 540 + 480 * 270], 480 * 270, 480)
	}
	assert decoded != unsafe { nil }
	assert sha256.sum(planes[..960 * 540]).hex() == '25f79bfccaded1fefd2f5e284bdbfa25450e81130aa34d9f7a0b6a25561253b0'
	atlas := yuv.webp_420_atlas_upload(planes, 960, 540) or { panic('native atlas') }
	for mode, height in [768, 256] {
		mut pixels := []u8{len: 1024 * height * 4, init: 255}
		clip := [f32(32), 127, 269, 151, 4, 4, 4, 4, 4, 4, 4, 4]!
		assert draw_sampled_yuv_atlas_clipped(pixels.data, 1024, i32(height), 4096, 1,
			atlas, 960, 540, 32, 127, 269, 151, 1, 960, 540, clip) == 1
		expected := ['7f28b70276ba342b68d3a914b6c588a474e968dcedb223e628e0b43c0cfc04bb',
			'10ce2be37045e9278e4d6c0e2cb692f8be97862dc9f59344fa634f9fd3c88ed7'][mode]
		assert sha256.sum(pixels).hex() == expected, 'native image frame ${mode}'
	}
}
