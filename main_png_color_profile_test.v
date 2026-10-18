module main

@[typedef]
struct C.VoxPngColorProfile {
	values [10]f32
}

fn C.native_png_color_profile(bytes &u8, length usize, profile &C.VoxPngColorProfile) int
fn C.native_image_color_profile(pixels voidptr, width int, height int, profile &C.VoxPngColorProfile) int

fn png_color_test_chunk(kind string, values []u32) []u8 {
	mut chunk := []u8{}
	length := u32(values.len * 4)
	chunk << [u8(length >> 24), u8(length >> 16), u8(length >> 8), u8(length)]
	chunk << kind.bytes()
	for value in values {
		chunk << [u8(value >> 24), u8(value >> 16), u8(value >> 8), u8(value)]
	}
	// The parser ignores CRCs.
	chunk << [u8(0), 0, 0, 0]
	return chunk
}

fn png_color_test_stream(chunks [][]u8) []u8 {
	mut bytes := [u8(0x89), `P`, `N`, `G`, `\r`, `\n`, 0x1A, `\n`]
	// A 13-byte 2x2 RGBA header: depth 8, color type 6, no interlacing.
	bytes << [u8(0), 0, 0, 13]
	bytes << 'IHDR'.bytes()
	bytes << [u8(0), 0, 0, 2, 0, 0, 0, 2, 8, 6, 0, 0, 0, 0, 0, 0, 0]
	for chunk in chunks {
		bytes << chunk
	}
	bytes << png_color_test_chunk('IDAT', [])
	bytes << png_color_test_chunk('IEND', [])
	return bytes
}

const png_color_test_srgb_primaries = [u32(31270), 32900, 64000, 33000, 30000, 60000, 15000, 6000]

fn png_color_test_profile(bytes []u8) ?[]f32 {
	$if macos {
		profile := C.VoxPngColorProfile{}
		if C.native_png_color_profile(bytes.data, usize(bytes.len), &profile) == 0 {
			return none
		}
		return profile.values[..]
	}
	return none
}

fn png_color_test_close(value f32, expected f64) bool {
	return f64(value) - expected < 1e-5 && expected - f64(value) < 1e-5
}

// Skia's PNG codec, used by Chromium, tags gAMA and cHRM chunks as an RGB
// color space; the profile carries the red, green, blue and white points.
fn test_png_gamma_and_chromaticities_form_a_color_profile() {
	$if macos {
		values := png_color_test_profile(png_color_test_stream([
			png_color_test_chunk('gAMA', [u32(45455)]),
			png_color_test_chunk('cHRM', png_color_test_srgb_primaries),
		])) or { panic('gAMA and cHRM must tag the image') }
		assert png_color_test_close(values[0], 1.0 / 0.45455)
		assert values[1] == 1
		for index, expected in [0.64, 0.33, 0.30, 0.60, 0.15, 0.06, 0.3127, 0.329] {
			assert png_color_test_close(values[2 + index], expected)
		}
		// Gamma alone keeps the sRGB gamut unless it is neutral.
		linear := png_color_test_profile(png_color_test_stream([
			png_color_test_chunk('gAMA', [u32(100000)]),
		])) or { panic('a linear gamma must tag the image') }
		assert linear[0] == 1 && linear[1] == 0
	}
}

fn test_png_color_profile_follows_skia_precedence_and_neutral_gamma() {
	$if macos {
		gamma := png_color_test_chunk('gAMA', [u32(45455)])
		chromaticities := png_color_test_chunk('cHRM', png_color_test_srgb_primaries)
		// A gamma within 5% of 1/2.2 without cHRM is treated as untagged.
		assert png_color_test_profile(png_color_test_stream([gamma])) == none
		assert png_color_test_profile(png_color_test_stream([
			png_color_test_chunk('gAMA', [u32(43500)]),
		])) == none
		// sRGB, iCCP and cICP chunks take precedence over gAMA and cHRM.
		for kind in ['sRGB', 'iCCP', 'cICP'] {
			assert png_color_test_profile(png_color_test_stream([gamma, chromaticities,
				png_color_test_chunk(kind, [u32(0)])])) == none
		}
		// cHRM needs a valid gamma, and chunks after the image data are ignored.
		assert png_color_test_profile(png_color_test_stream([chromaticities])) == none
		assert png_color_test_profile(png_color_test_stream([
			png_color_test_chunk('gAMA', [u32(0)]),
			chromaticities,
		])) == none
		mut late := png_color_test_stream([])
		late.insert(late.len - 12, png_color_test_chunk('gAMA', [u32(100000)]))
		assert png_color_test_profile(late) == none
	}
}

fn test_png_color_profile_is_associated_with_its_decoded_pixels() {
	$if macos {
		pixels := []u8{len: 16}
		tagged := png_color_test_stream([png_color_test_chunk('gAMA', [u32(100000)])])
		profile := C.VoxPngColorProfile{}
		C.native_tag_image_color_profile(pixels.data, 2, 2, tagged.data, usize(tagged.len), 1)
		assert C.native_image_color_profile(pixels.data, 2, 2, &profile) == 1
		assert profile.values[0] == 1
		// A reused buffer of another size is not converted.
		assert C.native_image_color_profile(pixels.data, 4, 1, &profile) == 0
		// Retagging with the policy disabled, or with an untagged stream, clears it.
		C.native_tag_image_color_profile(pixels.data, 2, 2, tagged.data, usize(tagged.len), 0)
		assert C.native_image_color_profile(pixels.data, 2, 2, &profile) == 0
		C.native_tag_image_color_profile(pixels.data, 2, 2, tagged.data, usize(tagged.len), 1)
		untagged := png_color_test_stream([])
		C.native_tag_image_color_profile(pixels.data, 2, 2, untagged.data, usize(untagged.len), 1)
		assert C.native_image_color_profile(pixels.data, 2, 2, &profile) == 0
	}
}
