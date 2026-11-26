// vtest build: macos
module ggshape

import stbi
import yuv

#flag darwin -L/opt/homebrew/lib -I/opt/homebrew/include -lwebpdecoder
#include <webp/decode.h>

fn C.WebPDecodeYUVInto(&u8, uint, &u8, uint, i32, &u8, uint, i32, &u8, uint, i32) &u8

fn test_cropped_webp_planes_match_both_unchanged_brave_tile_passes() {
	bytes := $embed_file('@VMODROOT/Tests/Browser/Brave/sites/bbc/bodies/7bf2e08ddd47ad437fb837aededdc667fcfa86c0b4dee430d23d85d28ffe9559').to_bytes()
	mut planes := []u8{len: 320 * 179 + 2 * 160 * 90}
	assert C.WebPDecodeYUVInto(bytes.data, uint(bytes.len), planes.data, 320 * 179, 320,
		unsafe { &planes[320 * 179] }, 160 * 90, 160,
		unsafe { &planes[320 * 179 + 160 * 90] }, 160 * 90, 160) != unsafe { nil }
	atlas := yuv.webp_420_atlas_upload(planes, 320, 179) or { panic('cropped plane upload') }
	reference := $embed_file('@VMODROOT/Tests/Browser/Brave/expected/cropped-webp-atlas.png').to_bytes()
	expected := stbi.load_from_memory(reference.data, reference.len, desired_channels: 4) or { panic(err) }
	defer { expected.free() }
	for samples in [1, 4] {
		y := if samples == 4 { 20 } else { 77 }
		reference_y := if samples == 4 { 20 } else { 585 }
		mut pixels := []u8{len: 1024 * 256 * 4, init: 255}
		assert draw_sampled_yuv_atlas_at_origin(pixels.data, 1024, 256, 4096, 1,
			atlas, 320, 179, 771, f32(y), 238, 133, samples, 320, 179,
			[f32(772), f32(y), 236, 133, 0, 0, 0, 0, 0, 0, 0, 0]!, false, [f32(0), f32(reference_y - y)]!) == 1
		mut differing := 0
		for py in -1 .. 135 {
			for px in -2 .. 239 {
				i := ((y + py) * 1024 + 772 + px) * 4
				j := ((reference_y + py) * expected.width + 772 + px) * 4
				if pixels[i..i + 4] != unsafe { [expected.data[j + 2], expected.data[j + 1],
					expected.data[j], expected.data[j + 3]] } {
					differing++
				}
			}
		}
		assert differing == 0, 'samples=${samples} pixels=${differing}'
	}
}
