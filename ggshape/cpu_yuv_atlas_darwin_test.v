// vtest build: macos
module ggshape

import crypto.sha256
import yuv

#flag darwin -L/opt/homebrew/lib -I/opt/homebrew/include -lwebpdecoder
#include <webp/decode.h>

fn C.WebPDecodeYUVInto(&u8, uint, &u8, uint, i32, &u8, uint, i32, &u8, uint, i32) &u8

fn test_native_size_yuv_cpu_mips_match_native_pixmap_uploads() {
	bytes := $embed_file('@VMODROOT/Tests/Browser/Brave/sites/cnn/bodies/64c0bec89a02c6abf49a57bc3a3723f395d6cb2b7ef76ab0a0d429bf33b2dd8f').to_bytes()
	mut planes := []u8{len: 256 * 144 * 3 / 2}
	decoded := unsafe {
		C.WebPDecodeYUVInto(bytes.data, uint(bytes.len), planes.data, 256 * 144, 256,
			&planes[256 * 144], 128 * 72, 128, &planes[256 * 144 + 128 * 72], 128 * 72, 128)
	}
	assert decoded != unsafe { nil }
	assert sha256.sum(planes).hex() == 'dceb5bf634152414d8eb379359cb3b1a680cd5bd1b7bacb15153577f030ff4e3'
	atlas := yuv.webp_420_atlas_upload(planes, 256, 144) or { panic('native atlas') }
	for mode, height in [768, 256] {
		y := if mode == 0 { f32(629) } else { f32(121) }
		mut pixels := []u8{len: 1024 * height * 4, init: 255}
		clip := [f32(723), y, 130, 73, 4, 4, 4, 4, 4, 4, 4, 4]!
		assert draw_sampled_yuv_atlas_with_mips_clipped(pixels.data, 1024, i32(height), 4096, 1,
			atlas, 256, 144, 723, y, 130, 73, 1, 256, 144, clip, false) == 1
		// Independent Graphite/Metal TextureFromYUVAPixmaps uploads build CPU
		// byte mips before texture transfer. These are complete native frames.
		expected := ['4e7e3266040e010ab512d21555c1356ccd90160216e2b9384dd8bbd4717dc7e1',
			'40fdfe0389164a1caf140c27212d2b0c1eabcd4ce6961830aa838c3ef362494c'][mode]
		assert sha256.sum(pixels).hex() == expected, 'native CPU atlas frame ${mode}'
	}
}
