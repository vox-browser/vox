// vtest build: macos
module ggshape

import math
import stbi
import yuv

#flag darwin -L/opt/homebrew/lib -I/opt/homebrew/include -lwebpdecoder
#include <webp/decode.h>

fn C.WebPDecodeYUVInto(&u8, uint, &u8, uint, i32, &u8, uint, i32, &u8, uint, i32) &u8

fn enlarged_webp_planes() []u8 {
	bytes := $embed_file('@VMODROOT/Tests/Browser/Brave/sites/theverge/bodies/dfffe5e6ef2ca7d69e140c3d35089fbd7e66f83fd27e3d9be70742843abd28a1').to_bytes()
	ys, cs := 540 * 360, 270 * 180
	mut planes := []u8{len: ys + 2 * cs}
	decoded := C.WebPDecodeYUVInto(bytes.data, uint(bytes.len), planes.data, uint(ys), 540,
		unsafe { &planes[ys] }, uint(cs), 270, unsafe { &planes[ys + cs] }, uint(cs), 270)
	assert decoded != unsafe { nil }
	return yuv.webp_420_atlas_upload(planes, 540, 360) or { panic('plane upload') }
}

fn assert_enlarged_webp_pixels(reference []u8, samples int, full [4]f32, clip [12]f32) {
	expected := stbi.load_from_memory(reference.data, reference.len, desired_channels: 4) or { panic(err) }
	defer { expected.free() }
	atlas := enlarged_webp_planes()
	mut different := 0
	for row in 0 .. 3 {
		oy := row * 254
		y := int(full[1]) - oy
		mut pixels := []u8{len: 1024 * 256 * 4, init: 255}
		mut local_clip := clip
		local_clip[1] -= f32(oy)
		r := draw_sampled_yuv_atlas_at_origin(pixels.data, 1024, 256, 4096, 1, atlas, 540, 360,
			full[0], f32(y), full[2], full[3], samples, 540, 360, local_clip, false, [
				f32(0),
				f32(oy),
			]!)
		assert r == 1
		first := math.max(y - 1, if row == 0 { 0 } else { 1 })
		last := math.min(y + int(full[3]) + 1, if row == 2 { 256 } else { 255 })
		for py in first .. last {
			for px in int(clip[0]) - 1 .. int(clip[0] + clip[2]) + 1 {
				i := (py * 1024 + px) * 4
				j := ((oy + py) * expected.width + px) * 4
				if pixels[i..i + 4] != unsafe { [expected.data[j + 2], expected.data[j + 1],
					expected.data[j], expected.data[j + 3]] } {
					different++
				}
			}
		}
	}
	assert different == 0, 'samples=${samples} pixels=${different}'
}

fn test_upscaled_webp_crop_clamps_luma_and_chroma_in_both_sample_modes() {
	full := yuv.webp_atlas_subset_destination(540, 360, [f32(45), 0, 450.00003, 360]!,
		[f32(222), 204, 580, 464]!) or { panic('crop transform') }
	assert full == [f32(164), 204, 696, 464]!
	for samples in [1, 4] {
		reference := if samples == 4 {
			$embed_file('@VMODROOT/Tests/Browser/Brave/expected/upscaled-webp-atlas.png').to_bytes()
		} else {
			$embed_file('@VMODROOT/Tests/Browser/Brave/expected/upscaled-webp-atlas-single-sample.png').to_bytes()
		}
		assert_enlarged_webp_pixels(reference, samples, full, [f32(222), 204, 580, 464, 0, 0, 0,
			0, 0, 0, 0, 0]!)
	}
}

fn test_upscaled_full_webp_keeps_its_original_plane_edges() {
	reference := $embed_file('@VMODROOT/Tests/Browser/Brave/expected/upscaled-webp-atlas-full.png').to_bytes()
	for samples in [1, 4] {
		assert_enlarged_webp_pixels(reference, samples, [f32(164), 204, 696, 464]!, [
			f32(164),
			204,
			696,
			464,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
		]!)
	}
}
