module imageraster

import crypto.sha256

fn test_rounded_decode_size_selects_a_mip_from_the_actual_integer_size() {
	w, h := decode_size(500, 500, 60, 60) or { panic('size') }
	assert w == 63 && h == 63
	source := []u8{len: 500 * 500 * 4, init: 255}
	image := decode_rgba(source, 500, 500, w, h) or { panic('decode') }
	assert image.width == 63 && image.height == 63
	assert image.pixels.all(it == 255)
	sw, sh := decode_size(500, 500, 32, 32) or { panic('small size') }
	assert sw == 32 && sh == 32
	assert decode_size(500, 500, 500, 500) == none
	assert decode_rgba([], 500, 500, 63, 63) == none
}

fn test_alpha_is_premultiplied_before_neighboring_colors_are_filtered() {
	// Transparent red cannot leak into the opaque blue texel beside it.
	source := [u8(255), 0, 0, 0, 0, 0, 255, 255, 255, 0, 0, 0, 0, 0, 255, 255]
	image := decode_rgba(source, 2, 2, 1, 1) or { panic('decode') }
	assert image.pixels == [u8(0), 0, 127, 127]
}

fn test_large_odd_rgba_decode_matches_scalar_premultiplication() {
	width, height := 1027, 513
	source := []u8{len: width * height * 4, init: u8((index * 59 + index / 4) & 255)}
	input_hash := sha256.sum(source).hex()
	mut expected := source.clone()
	for offset := 0; offset < expected.len; offset += 4 {
		alpha := u32(expected[offset + 3])
		for channel in 0 .. 3 {
			expected[offset + channel] = u8((u32(expected[offset + channel]) * alpha + 127) / 255)
		}
	}
	image := decode_rgba(source, width, height, width, height) or { panic('decode') }
	assert image.width == width && image.height == height
	matches := image.pixels == expected
	assert matches
	assert sha256.sum(source).hex() == input_hash
}

fn test_odd_mip_dimensions_filter_the_final_source_row_and_column() {
	mut pixels := []u8{len: 3 * 3 * 4}
	for y in 0 .. 3 {
		for x in 0 .. 3 {
			pixels[(y * 3 + x) * 4] = u8(y * 30 + x * 10)
			pixels[(y * 3 + x) * 4 + 3] = 255
		}
	}
	image := decode_rgba(pixels, 3, 3, 1, 1) or { panic('decode') }
	assert image.pixels == [u8(40), 0, 0, 255]
	levels := mip_chain(Image{ width: 3, height: 3, pixels: pixels }) or { panic('mips') }
	assert levels.len == 2
	assert levels[1].pixels == image.pixels
	assert mip_chain(Image{ width: 3, height: 3, pixels: [] }) == none
}

fn test_rounded_rgba_decode_uses_legacy_geometric_mip_selection() {
	// Exact opaque RGBA results from independent SkPixmap scalePixels with
	// Chromium's legacy anisotropic mip configuration and nearest mip sampling.
	dimensions := [[8, 8, 2, 3]!, [8, 8, 3, 2]!, [8, 8, 8, 1]!, [10, 6, 3, 2]!, [12, 10, 3, 3]!,
		[3, 5, 2, 2]!, [16, 16, 4, 5]!, [16, 16, 5, 4]!, [32, 18, 8, 5]!, [16, 16, 4, 4]!]
	expected := [
		'fd9e2e892f4bb5166fc959944a0dcef29b5806d3e4d12cc9c924594e710b2840',
		'aa186dccc4e1ad877442d1bf64b4e403fb861de8087624847bc6a69dacb1d461',
		'2e909a73554458ef122f0e2843165a2313a11f76d10d8e90496ea6caca07da99',
		'0c0d3600457facd6505ea28c31980f6c1d54be643602f3e7e8ba33a19fb78a50',
		'6cde2988aa1d851082e423440f905c48c3ac2df76473ca29e6af0fd1c442c5a4',
		'71e2dd7311c4a568908b850cb141aec90e441d29c0c01b4b7cebd335cdadd278',
		'60be5633011bcf9c6df1e41495a4e3849c19645b361d2c19c3421806a9632ac4',
		'db109d63b231e6de863c212739e23fa6864e0831167a30357141d48218b64e19',
		'ad25b284d0d1cff1317147ca7018f0c5b5ee7bd8dbd6162c29682a2ce1830b17',
		'478817f2aef3a656abebf33c1ca2c80ebb5cfb579fe0714bf847ea46d757327c',
	]
	for n, d in dimensions {
		source := []u8{len: d[0] * d[1] * 4, init: if index % 4 == 3 {
			u8(255)
		} else {
			u8((((index / 4) % d[0]) * 17 + ((index / 4) / d[0]) * 29 + ((index / 4) % d[0]) * ((index / 4) / d[0]) * 7 + 13 + (index % 4) * 41) & 255)
		}}
		actual := decode_rgba(source, d[0], d[1], d[2], d[3]) or { panic('decode') }
		assert actual.width == d[2] && actual.height == d[3]
		assert sha256.sum(actual.pixels).hex() == expected[n], 'case ${n}'
	}
}
