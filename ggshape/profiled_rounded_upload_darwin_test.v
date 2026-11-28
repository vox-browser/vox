// vtest build: macos
module ggshape

import imageraster
import stbi

#flag darwin -L/opt/homebrew/lib -I/opt/homebrew/include -lwebpdecoder
#include <webp/decode.h>

fn C.WebPDecodeRGBAInto(&u8, uint, &u8, uint, i32) &u8

fn test_profiled_rounded_upload_matches_brave_with_viewport_clipping() {
	bytes := $embed_file('@VMODROOT/Tests/Browser/Brave/sites/cnn/bodies/1f1ea2536d7f4cb1e3d805beab53611f4c990e069f1da6181ebad55725654572').to_bytes()
	mut source := []u8{len: 480 * 270 * 4}
	decoded := C.WebPDecodeRGBAInto(bytes.data, uint(bytes.len), source.data, uint(source.len), 480 * 4)
	if decoded == unsafe { nil } { panic('WebP decode') }
	tw, th := imageraster.decode_size(480, 270, 103, 58) or { panic('decode size') }
	image := imageraster.decode_rgba(source, 480, 270, tw, th) or { panic('resize') }
	assert tw == 120 && th == 68
	ref_bytes := $embed_file('@VMODROOT/Tests/Browser/Brave/diagnostic/profiled-webp-rounded-upload.png').to_bytes()
	reference := stbi.load_from_memory(ref_bytes.data, ref_bytes.len, desired_channels: 4)!
	defer { reference.free() }
	assert reference.width == 400 && reference.height == 200
	// Match the isolated control's sample-count-one analytic-clip draw.
	// Forced multisampling is a separate diagnostic, not this reference.
	for samples in [1] {
		mut pixels := []u8{len: 400 * 200 * 4, init: 255}
		for rect in [[16, 16], [180, 180]] {
			clip := [f32(rect[0]), f32(rect[1]), 103, 58, 4, 4, 4, 4, 4, 4, 4, 4]!
			status := draw_sampled_rgba_clipped(pixels.data, 400, 200, 1600, 1,
				image.pixels, tw, th, f32(rect[0]), f32(rect[1]), 103, 58,
				samples, 480, 270, clip, false)
			assert status == 1
		}
		mut different := 0
		for i in 0 .. 400 * 200 {
			if pixels[i * 4] != unsafe { reference.data[i * 4 + 2] }
				|| pixels[i * 4 + 1] != unsafe { reference.data[i * 4 + 1] }
				|| pixels[i * 4 + 2] != unsafe { reference.data[i * 4] }
				|| pixels[i * 4 + 3] != unsafe { reference.data[i * 4 + 3] } {
				different++
			}
		}
		eprintln('PROFILED_ROUNDED samples=${samples} different=${different}')
		assert different == 0
	}
}
