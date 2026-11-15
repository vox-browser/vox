// vtest build: macos
module ggshape

import encoding.base64
import os
import stbi

#flag darwin -L/opt/homebrew/lib -I/opt/homebrew/include -lwebpdecoder
#include <webp/decode.h>

fn C.WebPGetInfo(&u8, usize, &i32, &i32) i32
fn C.WebPDecodeRGBAInto(&u8, usize, &u8, usize, i32) &u8

fn test_untagged_alpha_webp_sampling_matches_unchanged_brave_pixels() {
	html := os.read_file(os.join_path(@VMODROOT, 'Tests/Browser/Brave/input/webp-alpha-premultiplication.html'))!
	bytes := os.read_bytes(os.join_path(@VMODROOT, 'Tests/Browser/Brave/expected/webp-alpha-premultiplication.png'))!
	reference := stbi.load_from_memory(bytes.data, bytes.len, desired_channels: 4)!
	defer { reference.free() }
	for samples in [1, 4] {
		mut pixels := []u8{len: reference.width * reference.height * 4}
		for i in 0 .. reference.width * reference.height {
			pixels[i * 4], pixels[i * 4 + 1], pixels[i * 4 + 2], pixels[i * 4 + 3] = 245, 250, 251, 255
		}
		for index, body in html.split('src="data:image/webp;base64,')[1..4] {
			encoded := base64.decode(body.all_before('"'))
			mut w, mut h := i32(0), i32(0)
			assert C.WebPGetInfo(encoded.data, usize(encoded.len), &w, &h) != 0
			mut rgba := []u8{len: int(w) * int(h) * 4}
			assert C.WebPDecodeRGBAInto(encoded.data, usize(encoded.len), rgba.data, usize(rgba.len), w * 4) != unsafe { nil }
			// These untagged WebP paint rows retain libwebp's truncated multiplication.
			for i := 0; i < rgba.len; i += 4 {
				for c in 0 .. 3 { rgba[i + c] = u8(u32(rgba[i + c]) * rgba[i + 3] / 255) }
			}
			x := 20 + 100 * index
			dw, dh := if index == 0 { 80 } else { 76 }, if index == 0 { 40 } else { 38 }
			assert draw_sampled_rgba_clipped(pixels.data, reference.width, reference.height, reference.width * 4, 1, rgba, w, h, x, 20, dw, dh, samples, w, h, [12]f32{}, false) == 1
			mut differences := 0
			for y in 20 .. 20 + dh {
				for xx in x .. x + dw {
					i := (y * reference.width + xx) * 4
					if pixels[i] != unsafe { reference.data[i + 2] } || pixels[i + 1] != unsafe { reference.data[i + 1] } || pixels[i + 2] != unsafe { reference.data[i] } || pixels[i + 3] != unsafe { reference.data[i + 3] } {
						differences++
					}
				}
			}
			assert differences == 0, 'index=${index}, samples=${samples}, differences=${differences}'
		}
	}
}
