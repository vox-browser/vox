// vtest build: macos
module ggshape

import yuv
import encoding.base64
import os
import stbi

#flag darwin -L/opt/homebrew/lib -I/opt/homebrew/include -lwebpdecoder
#include <webp/decode.h>

fn C.WebPGetInfo(&u8, usize, &i32, &i32) i32
fn C.WebPDecodeYUVInto(&u8, usize, &u8, usize, i32, &u8, usize, i32, &u8, usize, i32) &u8

fn test_lossy_webp_plane_sampling_matches_unchanged_brave_pixels() {
	for fixture in ['webp-yuv', 'webp-yuv-scaled'] {
		html := os.read_file(os.join_path(@VMODROOT, 'Tests/Browser/Brave/input', fixture + '.html'))!
		encoded := base64.decode(html.all_after('src="data:image/webp;base64,').all_before('"'))
		mut w, mut h := i32(0), i32(0)
		assert C.WebPGetInfo(encoded.data, usize(encoded.len), &w, &h) != 0
		mut planes := []u8{len: int(w) * int(h) * 3 / 2}
		ys, cs := int(w) * int(h), int(w) * int(h) / 4
		assert C.WebPDecodeYUVInto(encoded.data, usize(encoded.len), planes.data, usize(ys), w,
			unsafe { &planes[ys] }, usize(cs), w / 2, unsafe { &planes[ys + cs] }, usize(cs), w / 2) != unsafe { nil }
		dw := if fixture == 'webp-yuv' { int(w) } else { int(w) / 2 }
		dh := if fixture == 'webp-yuv' { int(h) } else { int(h) / 2 }
		reference := os.read_bytes(os.join_path(@VMODROOT, 'Tests/Browser/Brave/expected', fixture + '.png'))!
		expected := stbi.load_from_memory(reference.data, reference.len, desired_channels: 4)!
		defer { expected.free() }
		for samples in [1, 4] {
			colors := yuv.webp_sampled_colors(planes, w, h, dw, dh) or { panic('plane sampling') }
			mut pixels := []u8{len: 1024 * 768 * 4, init: 255}
			assert draw_sampled_colors_clipped(pixels.data, 1024, 768, 4096, 1, colors, dw, dh, 20, 20, dw, dh, samples, dw, dh, [12]f32{}) == 1
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
