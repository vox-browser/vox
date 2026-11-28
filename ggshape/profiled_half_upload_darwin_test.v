// vtest build: macos
module ggshape

import imageraster
import os
import stbi

#flag darwin -L/opt/homebrew/lib -I/opt/homebrew/include -lwebpdecoder
#include <webp/decode.h>

fn C.WebPDecodeRGBAInto(&u8, usize, &u8, usize, i32) &u8

fn test_profiled_half_uploads_match_independent_brave_samples() {
	ref_bytes := $embed_file('@VMODROOT/Tests/Browser/Brave/diagnostic/profiled-webp-half-upload.png').to_bytes()
	reference := stbi.load_from_memory(ref_bytes.data, ref_bytes.len, desired_channels: 4)!
	defer { reference.free() }
	hashes := ['fbe3994f267a5bfabc1f8856b9adcce31ba8350b3853265605ecbeadc6a52d12',
		'1f1ea2536d7f4cb1e3d805beab53611f4c990e069f1da6181ebad55725654572']
	for samples in [1, 4] {
		mut pixels := []u8{len: 400 * 300 * 4, init: 255}
		for n, size in [[780, 438, 16, 16, 269, 151], [480, 270, 16, 190, 180, 102]] {
			bytes := os.read_bytes(os.join_path(@VMODROOT, 'Tests/Browser/Brave/sites/cnn/bodies', hashes[n]))!
			mut source := []u8{len: size[0] * size[1] * 4}
			assert C.WebPDecodeRGBAInto(bytes.data, usize(bytes.len), source.data, usize(source.len), i32(size[0] * 4)) != unsafe { nil }
			decoded := imageraster.decode_rgba(source, size[0], size[1], size[0] / 2, size[1] / 2) or { panic('half upload') }
			assert draw_sampled_rgba_clipped(pixels.data, 400, 300, 1600, 1, decoded.pixels,
				decoded.width, decoded.height, f32(size[2]), f32(size[3]), f32(size[4]), f32(size[5]),
				samples, size[0], size[1], [12]f32{}, false) == 1
		}
		for i in 0 .. 400 * 300 {
			assert pixels[i * 4..i * 4 + 4] == unsafe {
				[reference.data[i * 4 + 2], reference.data[i * 4 + 1], reference.data[i * 4],
					reference.data[i * 4 + 3]]
			}, 'samples=${samples}, pixel=${i % 400},${i / 400}'
		}
	}
}

fn test_profiled_native_first_upload_retains_gpu_mip_samples() {
	bytes := $embed_file('@VMODROOT/Tests/Browser/Brave/sites/cnn/bodies/fbe3994f267a5bfabc1f8856b9adcce31ba8350b3853265605ecbeadc6a52d12').to_bytes()
	mut source := []u8{len: 780 * 438 * 4}
	assert C.WebPDecodeRGBAInto(bytes.data, usize(bytes.len), source.data, usize(source.len), 780 * 4) != unsafe { nil }
	ref_bytes := $embed_file('@VMODROOT/Tests/Browser/Brave/diagnostic/profiled-webp-native-first.png').to_bytes()
	reference := stbi.load_from_memory(ref_bytes.data, ref_bytes.len, desired_channels: 4)!
	defer { reference.free() }
	for samples in [1, 4] {
		mut pixels := []u8{len: 1100 * 480 * 4, init: 255}
		for rect in [[16, 16, 780, 438], [816, 16, 269, 151]] {
			assert draw_sampled_rgba_clipped(pixels.data, 1100, 480, 4400, 1, source,
				780, 438, f32(rect[0]), f32(rect[1]), f32(rect[2]), f32(rect[3]), samples,
				780, 438, [12]f32{}, true) == 1
		}
		for i in 0 .. 1100 * 480 {
			assert pixels[i * 4..i * 4 + 4] == unsafe {
				[reference.data[i * 4 + 2], reference.data[i * 4 + 1], reference.data[i * 4],
					reference.data[i * 4 + 3]]
			}, 'samples=${samples}, pixel=${i % 1100},${i / 1100}'
		}
	}
}
