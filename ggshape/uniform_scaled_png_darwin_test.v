// vtest build: macos
module ggshape

import imageraster
import stbi

fn test_uniform_scaled_png_keeps_elliptical_image_sampling_in_both_tile_passes() {
	bytes := $embed_file('@VMODROOT/Tests/Browser/Brave/resources/shadowed-avatar.png').to_bytes()
	image := stbi.load_from_memory(bytes.data, bytes.len, desired_channels: 4) or { panic('${err}') }
	defer { image.free() }
	reference := $embed_file('@VMODROOT/Tests/Browser/Brave/expected/uniform-scaled-png.png').to_bytes()
	expected := stbi.load_from_memory(reference.data, reference.len, desired_channels: 4) or { panic('${err}') }
	defer { expected.free() }
	for samples in [1, 4] {
		for large in [false, true] {
			dw, dh := if large { f32(18) } else { f32(9) }, if large { f32(40) } else { f32(20) }
			sw, sh := imageraster.decode_size(image.width, image.height, dw, dh) or { panic('size') }
			decoded := imageraster.decode_rgba(unsafe { image.data.vbytes(image.width * image.height * 4) }, image.width, image.height, sw, sh) or { panic('decode') }
			mut pixels := []u8{len: 1024 * 256 * 4, init: if index % 4 == 3 {
				u8(255)
			} else {
				u8(254)
			}}
			x := if large { f32(100) } else { f32(20) }
			y := if samples == 4 { f32(20) } else { f32(66) }
			clip := [x, y, dw, dh, dw / 2, dh / 2, dw / 2, dh / 2, dw / 2, dh / 2, dw / 2, dh / 2]!
			assert draw_sampled_rgba_clipped(pixels.data, 1024, 256, 4096, 1, decoded.pixels, sw, sh, x, y, dw, dh, samples, image.width, image.height, clip, false) == 1
			reference_y := if samples == 4 { 20 } else { 320 }
			mut differing := 0
			for py in 0 .. int(dh) {
				for px in 0 .. int(dw) {
					i := ((int(y) + py) * 1024 + int(x) + px) * 4
					j := ((reference_y + py) * expected.width + int(x) + px) * 4
					if pixels[i..i + 4] != unsafe { [expected.data[j + 2], expected.data[j + 1],
						expected.data[j], expected.data[j + 3]] } {
						differing++
					}
				}
			}
			assert differing == 0, 'samples=${samples} large=${large} pixels=${differing}'
		}
	}
}
