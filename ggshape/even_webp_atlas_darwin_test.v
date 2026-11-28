// vtest build: macos
module ggshape

import math
import stbi
import yuv

#flag darwin -L/opt/homebrew/lib -I/opt/homebrew/include -lwebpdecoder
#include <webp/decode.h>

fn C.WebPDecodeYUVInto(&u8, uint, &u8, uint, i32, &u8, uint, i32, &u8, uint, i32) &u8

struct EvenAtlasProbe {
	bytes []u8
	w int
	h int
	x int
	y int
	dw int
	dh int
}

fn test_even_webp_atlas_retains_document_coordinates_across_tiles() {
	probes := [
		EvenAtlasProbe{
			bytes: $embed_file('@VMODROOT/Tests/Browser/Brave/sites/bbc/bodies/2107054e13a88c8ea6008dc9f776316bfe7c4fa4faf873040a61d9fe5dd7dfc6').to_bytes()
			w: 640, h: 360, x: 268, y: 251, dw: 488, dh: 275
		},
		EvenAtlasProbe{
			bytes: $embed_file('@VMODROOT/Tests/Browser/Brave/sites/bbc/bodies/dedeff525f370749805456a7ac025f656f489a89aca168a5811e268d9546645c').to_bytes()
			w: 320, h: 180, x: 16, y: 585, dw: 173, dh: 97
		},
	]
	for samples in [1, 4] {
		reference := if samples == 4 {
			$embed_file('@VMODROOT/Tests/Browser/Brave/expected/even-webp-atlas.png').to_bytes()
		} else {
			$embed_file('@VMODROOT/Tests/Browser/Brave/expected/even-webp-atlas-single-sample.png').to_bytes()
		}
		expected := stbi.load_from_memory(reference.data, reference.len, desired_channels: 4) or { panic(err) }
		defer { expected.free() }
		for probe in probes {
			ys, cs := probe.w * probe.h, (probe.w / 2) * (probe.h / 2)
			mut planes := []u8{len: ys + 2 * cs}
			assert C.WebPDecodeYUVInto(probe.bytes.data, uint(probe.bytes.len), planes.data,
				uint(ys), i32(probe.w), unsafe { &planes[ys] }, uint(cs), i32(probe.w / 2),
				unsafe { &planes[ys + cs] }, uint(cs), i32(probe.w / 2)) != unsafe { nil }
			atlas := yuv.webp_420_atlas_upload(planes, probe.w, probe.h) or { panic('plane upload') }
			mut differing := 0
			for row in 0 .. 3 {
				oy := row * 254
				y := probe.y - oy
				if y >= 256 || y + probe.dh <= 0 { continue }
				mut pixels := []u8{len: 1024 * 256 * 4, init: 255}
				assert draw_sampled_yuv_atlas_at_origin(pixels.data, 1024, 256, 4096, 1, atlas,
					probe.w, probe.h, f32(probe.x), f32(y), f32(probe.dw), f32(probe.dh),
					samples, probe.w, probe.h, [f32(probe.x), f32(y), f32(probe.dw), f32(probe.dh),
					0, 0, 0, 0, 0, 0, 0, 0]!, false, [f32(0), f32(oy)]!) == 1
				first := math.max(y - 1, if row == 0 { 0 } else { 1 })
				last := math.min(y + probe.dh + 1, if row == 2 { 256 } else { 255 })
				for py in first .. last {
					for px in probe.x - 1 .. probe.x + probe.dw + 1 {
						i := (py * 1024 + px) * 4
						j := ((oy + py) * expected.width + px) * 4
						if pixels[i..i + 4] != unsafe { [expected.data[j + 2], expected.data[j + 1],
							expected.data[j], expected.data[j + 3]] } { differing++ }
					}
				}
			}
			assert differing == 0, 'samples=${samples} image=${probe.w}x${probe.h} pixels=${differing}'
		}
	}
}
