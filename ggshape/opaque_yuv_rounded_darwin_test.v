// vtest build: macos
module ggshape

import crypto.sha256
import yuv

// Independent Graphite/Metal R8-plane image: clip in device space, then
// translate/scale and draw at natural size. The native image is opaque.
fn test_opaque_planar_image_preserves_native_rounded_coverage() {
	planes := []u8{len: 32 * 32 * 3 / 2, init: 128}
	atlas := yuv.webp_420_atlas_upload(planes, 32, 32) or { panic('opaque atlas') }
	mut pixels := []u8{len: 64 * 64 * 4, init: 255}
	clip := [f32(8), 8, 24, 24, 4, 4, 4, 4, 4, 4, 4, 4]!
	assert draw_sampled_yuv_atlas_clipped(pixels.data, 64, 64, 256, 1,
		atlas, 32, 32, 8, 8, 24, 24, 1, 32, 32, clip) == 1
	assert sha256.sum(pixels).hex() == '77a8d85e85d3c547e206571c84040fcbb3bad3873992d595419084da6d8f5199'
}
