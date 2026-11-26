// vtest build: macos
module ggshape

import imageraster
import encoding.base64
import os
import stbi

#flag darwin -L/opt/homebrew/lib -I/opt/homebrew/include -lwebpdecoder
#include <webp/decode.h>

fn C.WebPGetInfo(&u8, usize, &i32, &i32) i32
fn C.WebPDecodeRGBAInto(&u8, usize, &u8, usize, i32) &u8

fn test_lossless_webp_downsampling_matches_unchanged_brave_pixels() {
	for fixture in ['webp-rgba-mip', 'webp-rgba-mip-blend'] {
		html := os.read_file(os.join_path(@VMODROOT, 'Tests/Browser/Brave/input', fixture + '.html'))!
		encoded := base64.decode(html.all_after('src="data:image/webp;base64,').all_before('"'))
		mut w, mut h := i32(0), i32(0)
		assert C.WebPGetInfo(encoded.data, usize(encoded.len), &w, &h) != 0
		mut decoded := []u8{len: int(w) * int(h) * 4}
		assert C.WebPDecodeRGBAInto(encoded.data, usize(encoded.len), decoded.data, usize(decoded.len), w * 4) != unsafe { nil }
		dw := if fixture == 'webp-rgba-mip' { 240 } else { 320 }
		dh := if fixture == 'webp-rgba-mip' { 135 } else { 180 }
		reference := os.read_bytes(os.join_path(@VMODROOT, 'Tests/Browser/Brave/expected', fixture + '.png'))!
		expected := stbi.load_from_memory(reference.data, reference.len, desired_channels: 4)!
		defer { expected.free() }
		for samples in [1, 4] {
			sw, sh := imageraster.decode_size(w, h, dw, dh) or { panic('decode size') }
			reduced := imageraster.decode_rgba(decoded, w, h, sw, sh) or { panic('resize') }
			source := reduced.pixels
			mut pixels := []u8{len: 1024 * 768 * 4, init: 255}
			assert draw_sampled_rgba_clipped(pixels.data, 1024, 768, 4096, 1, source, sw, sh, 20, 20, dw, dh, samples, w, h, [12]f32{}, false) == 1
			mut different := 0
			for y in 20 .. 20 + dh {
				for x in 20 .. 20 + dw {
					i := (y * 1024 + x) * 4
					if pixels[i] != unsafe { expected.data[i + 2] } || pixels[i + 1] != unsafe { expected.data[i + 1] } || pixels[i + 2] != unsafe { expected.data[i] } || pixels[i + 3] != unsafe { expected.data[i + 3] } {
						different++
					}
				}
			}
			assert different == 0, '${fixture}, samples=${samples}, differing=${different}'
		}
	}
}
