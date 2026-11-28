// vtest build: macos
module ggshape

import stbi
import yuv

#flag darwin -L/opt/homebrew/lib -I/opt/homebrew/include -lwebpdecoder
#include <webp/decode.h>

fn C.WebPDecodeYUVInto(&u8, uint, &u8, uint, i32, &u8, uint, i32, &u8, uint, i32) &u8

fn test_odd_height_webp_planes_match_both_unchanged_brave_tile_passes() {
	bytes := $embed_file('@VMODROOT/Tests/Browser/Brave/sites/bbc/bodies/8730ee1d8ee775a9a4579a867cf924821551314a1f5a54dcdcbca7ed8c35d575').to_bytes()
	mut planes := []u8{len: 320 * 179 + 2 * 160 * 90}
	assert C.WebPDecodeYUVInto(bytes.data, uint(bytes.len), planes.data, 320 * 179, 320,
		unsafe { &planes[320 * 179] }, 160 * 90, 160,
		unsafe { &planes[320 * 179 + 160 * 90] }, 160 * 90, 160) != unsafe { nil }
	atlas := yuv.webp_420_atlas_upload(planes, 320, 179) or { panic('odd plane upload') }
	reference := $embed_file('@VMODROOT/Tests/Browser/Brave/expected/odd-height-webp-atlas.png').to_bytes()
	expected := stbi.load_from_memory(reference.data, reference.len, desired_channels: 4) or { panic(err) }
	defer { expected.free() }
	for samples in [1, 4] {
		x, y := if samples == 4 { 20 } else { 205 }, if samples == 4 { 20 } else { 77 }
		reference_y := if samples == 4 { 20 } else { 585 }
		mut pixels := []u8{len: 1024 * 256 * 4, init: 255}
		assert draw_sampled_yuv_atlas_with_mips_clipped(pixels.data, 1024, 256, 4096, 1,
			atlas, 320, 179, f32(x), f32(y), 173, 97, samples, 320, 179, [f32(x), f32(y), 173,
				97, 0, 0, 0, 0, 0, 0, 0, 0]!, false) == 1
		mut differing := 0
		for py in -1 .. 99 {
			for px in -1 .. 175 {
				i := ((y + py) * 1024 + x + px) * 4
				j := ((reference_y + py) * expected.width + x + px) * 4
				if pixels[i..i + 4] != unsafe { [expected.data[j + 2], expected.data[j + 1],
					expected.data[j], expected.data[j + 3]] } {
					differing++
				}
			}
		}
		assert differing == 0, 'samples=${samples} pixels=${differing}'
	}
}
