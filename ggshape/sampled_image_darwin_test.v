// vtest build: macos
module ggshape

import imageraster
import os
import stbi

fn test_downsampled_png_matches_the_unchanged_brave_logo_pixels() {
	bytes := $embed_file('@VMODROOT/Tests/Browser/Brave/resources/image-decode-cold.png').to_bytes()
	image := stbi.load_from_memory(bytes.data, bytes.len, desired_channels: 4) or { panic('${err}') }
	defer { image.free() }
	decoded := imageraster.decode_rgba(unsafe { image.data.vbytes(image.width * image.height * 4) },
		image.width, image.height, 63, 63) or { panic('decode') }
	if path := os.getenv_opt('VOX_SAMPLED_PNG_OUTPUT') {
		os.write_file_array(path, decoded.pixels) or { panic('${err}') }
	}
	ref := $embed_file('@VMODROOT/Tests/Browser/Brave/expected/image-decode-resource-reuse.png').to_bytes()
	expected := stbi.load_from_memory(ref.data, ref.len, desired_channels: 4) or { panic('${err}') }
	defer { expected.free() }
	for samples in [1, 4] {
		mut pixels := []u8{len: 80 * 80 * 4}
		for i in 0 .. 80 * 80 {
			pixels[i * 4], pixels[i * 4 + 1], pixels[i * 4 + 2], pixels[i * 4 + 3] = 15, 11, 9, 255
		}
		assert draw_sampled_rgba(pixels.data, 80, 80, 320, 1, decoded.pixels, 63, 63, 10, 10, 60, 60, samples, 500, 500) == 1
		mut differing := 0
		for y in 0 .. 60 {
			for x in 0 .. 60 {
				i, j := ((y + 10) * 80 + x + 10) * 4, ((y + 20) * expected.width + x + 198) * 4
				for c in 0 .. 4 {
					channel := if c == 0 {
						2
					} else if c == 2 {
						0
					} else {
						c
					}
					if pixels[i + channel] != unsafe { expected.data[j + c] } {
						differing++
					}
				}
			}
		}
		assert differing == 0, 'samples=${samples} channels=${differing}'
	}
}
