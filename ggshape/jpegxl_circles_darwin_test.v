// vtest build: macos
module ggshape

import jpegxl
import stbi

fn test_opaque_jpegxl_circles_match_unchanged_brave_in_both_tile_passes() {
	files := [
		$embed_file('@VMODROOT/Tests/Browser/Brave/sites/guardian/bodies/f895a94ea328cf2548fff9d1fd2d1b1bc03d22c0ebd8012c1dc66b25774c7eae').to_bytes(),
		$embed_file('@VMODROOT/Tests/Browser/Brave/sites/guardian/bodies/ab482fcd24ecc7b107fc3c3c02cc07e4ea1fbca1bcbce1030d601aa35e26ff3d').to_bytes(),
		$embed_file('@VMODROOT/Tests/Browser/Brave/sites/guardian/bodies/156b6868aa9edeb47db16a381560d25d2cd139da78417ef6e4a5cf71a707183d').to_bytes(),
	]
	reference := $embed_file('@VMODROOT/Tests/Browser/Brave/expected/unscaled-jpegxl-circles.png').to_bytes()
	expected := stbi.load_from_memory(reference.data, reference.len, desired_channels: 4) or { panic(err) }
	defer { expected.free() }
	for samples in [1, 4] {
		y := if samples == 4 { 82 } else { 77 }
		reference_y := if samples == 4 { 82 } else { 585 }
		for index, bytes in files {
			decoded := jpegxl.decode_rgba(bytes, true) or { panic(err) }
			assert decoded.width == 98 && decoded.height == 98
			x := 234 + index * 320
			background := if index == 1 { [u8(248), 241, 254, 255] } else { [u8(242), 244, 255, 255] }
			mut pixels := []u8{len: 1024 * 256 * 4}
			for i in 0 .. 1024 * 256 {
				for c in 0 .. 4 { pixels[i * 4 + c] = background[c] }
			}
			assert draw_sampled_image_quad_rgba(pixels.data, 1024, 256, 4096, 1, decoded.pixels,
				98, 98, f32(x), f32(y), samples,
				[f32(x), f32(y), 98, 98, 49, 49, 49, 49, 49, 49, 49, 49]!) == 1
			mut differing := 0
			for py in -1 .. 99 {
				for px in -1 .. 99 {
					i := ((y + py) * 1024 + x + px) * 4
					j := ((reference_y + py) * expected.width + x + px) * 4
					if pixels[i..i + 4] != unsafe { [expected.data[j + 2], expected.data[j + 1],
						expected.data[j], expected.data[j + 3]] } { differing++ }
				}
			}
			assert differing == 0, 'samples=${samples} image=${index} pixels=${differing}'
		}
	}
}

fn test_image_quad_rejects_translucent_rows_without_changing_the_backdrop() {
	mut pixels := []u8{len: 32 * 32 * 4, init: 37}
	mut source := []u8{len: 16 * 16 * 4, init: 255}
	source[3] = 254
	assert draw_sampled_image_quad_rgba(pixels.data, 32, 32, 128, 1, source, 16, 16,
		4, 4, 4, [f32(4), 4, 16, 16, 8, 8, 8, 8, 8, 8, 8, 8]!) == 0
	assert pixels.all(it == 37)
}
