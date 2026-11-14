// vtest build: macos
module ggshape

import crypto.sha256
import imageraster
import stbi

fn test_legacy_png_upload_matches_the_independent_color_conversion_and_preserves_alpha() {
	bytes := $embed_file('@VMODROOT/Tests/Browser/Brave/resources/vlang-mastodon.png').to_bytes()
	profile := imageraster.png_sampling_profile(bytes) or { panic('profile') }
	assert profile.gamma == f32(2.2)
	image := stbi.load_from_memory(bytes.data, bytes.len, desired_channels: 4) or { panic(err) }
	defer { image.free() }
	decoded := imageraster.decode_rgba(unsafe { image.data.vbytes(image.width * image.height * 4) },
		image.width, image.height, 33, 33) or { panic('decode') }
	before := decoded.pixels.clone()
	converted := convert_image_color(decoded, profile) or { panic('conversion') }
	// Independent old-renderer GPU readback, with its executable hash retained
	// in the site report's local evidence. This is a conversion gold, not a
	// replacement for the unchanged Brave full-page reference.
	assert sha256.hexhash(converted.bytestr()) == '209d3dc79e56a9ffe9be9e9559c5b1e43621b284c979893723f00aee7b0c2e4b'
	assert decoded.pixels == before
	for i in 0 .. 33 * 33 {
		assert converted[i * 4 + 3] == decoded.pixels[i * 4 + 3]
	}
	assert convert_image_color(imageraster.Image{}, profile) == none
}

fn test_color_converted_png_uses_gpu_mips_when_the_final_draw_is_smaller() {
	bytes := $embed_file('@VMODROOT/Tests/Browser/Brave/resources/vlang-mastodon.png').to_bytes()
	profile := imageraster.png_sampling_profile(bytes) or { panic('profile') }
	image := stbi.load_from_memory(bytes.data, bytes.len, desired_channels: 4) or { panic(err) }
	defer { image.free() }
	decoded := imageraster.decode_rgba(unsafe { image.data.vbytes(image.width * image.height * 4) },
		image.width, image.height, 33, 33) or { panic('decode') }
	converted := convert_image_color(decoded, profile) or { panic('conversion') }
	ref := $embed_file('@VMODROOT/Tests/Browser/Brave/diagnostic/legacy-gamma-scaled-png.png').to_bytes()
	expected := stbi.load_from_memory(ref.data, ref.len, desired_channels: 4) or { panic(err) }
	defer { expected.free() }
	for size in [24, 20] {
		mut pixels := []u8{len: 44 * 44 * 4}
		for i in 0 .. 44 * 44 {
			pixels[i * 4], pixels[i * 4 + 1], pixels[i * 4 + 2], pixels[i * 4 + 3] = 15, 11, 9, 255
		}
		assert draw_sampled_rgba_clipped(pixels.data, 44, 44, 176, 1, converted, 33, 33,
			10, 10, f32(size), f32(size), 1, 130, 130,
			[f32(10), 10, f32(size), f32(size), 0, 0, 0, 0, 0, 0, 0, 0]!, true) == 1
		mut differing := 0
		left := if size == 24 { 42 } else { 100 }
		for y in 0 .. size {
			for x in 0 .. size {
				i, j := ((y + 10) * 44 + x + 10) * 4, ((y + 202) * expected.width + x + left) * 4
				if pixels[i..i + 4] != unsafe { [expected.data[j + 2], expected.data[j + 1],
					expected.data[j], expected.data[j + 3]] } {
					differing++
				}
			}
		}
		assert differing == 0, 'size=${size} pixels=${differing}'
	}
}
