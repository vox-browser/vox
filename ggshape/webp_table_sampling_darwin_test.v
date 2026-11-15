// vtest build: macos
module ggshape

import imageraster
import os
import stbi

#flag darwin -L/opt/homebrew/lib -I/opt/homebrew/include -lwebpdecoder
#include <webp/decode.h>

fn C.WebPDecodeRGBAInto(&u8, usize, &u8, usize, i32) &u8

fn test_srgb_table_webp_sampling_matches_the_unchanged_brave_control() {
	bytes := os.read_bytes(os.join_path(@VMODROOT, 'Tests/Browser/Brave/sites/cnn/bodies/1f1ea2536d7f4cb1e3d805beab53611f4c990e069f1da6181ebad55725654572'))!
	assert imageraster.webp_srgb_profile(bytes)
	mut source := []u8{len: 480 * 270 * 4}
	assert C.WebPDecodeRGBAInto(bytes.data, usize(bytes.len), source.data, usize(source.len), 480 * 4) != unsafe { nil }
	ref_bytes := os.read_bytes(os.join_path(@VMODROOT, 'Tests/Browser/Brave/diagnostic/webp-srgb-table.png'))!
	reference := stbi.load_from_memory(ref_bytes.data, ref_bytes.len, desired_channels: 4)!
	defer { reference.free() }
	assert reference.width == 1024 && reference.height == 768
	for samples in [1, 4] {
		mut pixels := []u8{len: 1024 * 768 * 4, init: 255}
		for rect in [[24, 24, 480, 270], [540, 24, 104, 59], [460, 753, 104, 59]] {

			assert draw_sampled_rgba_clipped(pixels.data, 1024, 768, 4096, 1, source,
				480, 270, f32(rect[0]), f32(rect[1]), f32(rect[2]), f32(rect[3]), samples, 480, 270, [12]f32{}, true) == 1
		}
		mut different := 0
		for i in 0 .. 1024 * 768 {
			if pixels[i * 4] != unsafe { reference.data[i * 4 + 2] }
				|| pixels[i * 4 + 1] != unsafe { reference.data[i * 4 + 1] }
				|| pixels[i * 4 + 2] != unsafe { reference.data[i * 4] }
				|| pixels[i * 4 + 3] != unsafe { reference.data[i * 4 + 3] } { different++ }
		}
		assert different == 0, 'samples=${samples}, different=${different}'
	}
}
