module cpuraster

import crypto.sha256
import json2

struct LargeSourceBlurFixture {
	width               int
	height              int
	pitch               int
	alpha_type          int
	image_width         int
	image_height        int
	image_premultiplied bool
	image_display_p3    bool
	source              [4]f32
	destination         [4]f32
	transform           [6]f32
	smoothing           bool
	global_alpha        f32
	composite           int
	sigma               f32
	shadow              bool
	shadow_color        u32
	offset              [2]f32
	pre                 [][]f32
	post                [][]f32
	clip                bool
	supported           bool
	expected_macos      string
	expected_linux      string
}

fn large_source_blur_fixtures() []LargeSourceBlurFixture {
	return json2.decode[[]LargeSourceBlurFixture]($embed_file('@VMODROOT/cpuraster/testdata/large-source-blur-cases.json').to_string()) or { panic(err) }
}

fn large_source_blur_pixels(c LargeSourceBlurFixture, source bool) []u8 {
	w, h, pitch := if source { c.image_width } else { c.width }, if source {
		c.image_height
	} else {
		c.height
	}, if source { c.image_width * 4 + 4 } else { c.pitch }
	premul := if source { c.image_premultiplied } else { c.alpha_type == 2 }
	mut pixels := []u8{len: pitch * h, init: if source { u8(0) } else { u8(0x5a) }}
	for y in 0 .. h {
		for x in 0 .. w {
			mut a := if source { (x * 37 + y * 91) % 256 } else { (x * 17 + y * 31) % 256 }
			if source && (x + 2 * y) % 5 == 0 { a = 255 }
			if source && (x * 3 + y) % 7 == 3 { a = 0 }
			rgb := [(x * 53 + y * 17) % 256, (x * 11 + y * 67) % 256, (x * 29 + y * 41 + 100) % 256]
			o := y * pitch + x * 4
			for k in 0 .. 3 { pixels[o + k] = u8(if premul { rgb[k] * a / 255 } else { rgb[k] }) }
			pixels[o + 3] = u8(a)
		}
	}
	return pixels
}

fn large_source_blur_draw(mut pixels []u8, c LargeSourceBlurFixture) bool {
	mut steps := []CanvasFilterStep{}
	for matrix in c.pre {
		mut values := [20]f32{}
		for k, v in matrix { values[k] = v }
		steps << CanvasFilterStep{ kind: .matrix, matrix: MatrixColorFilter{values, true} }
	}
	steps << CanvasFilterStep{ kind: if c.shadow { .drop_shadow } else { .blur }, sigma: c.sigma,
		color: c.shadow_color, offset_x: c.offset[0], offset_y: c.offset[1] }
	for matrix in c.post {
		mut values := [20]f32{}
		for k, v in matrix { values[k] = v }
		steps << CanvasFilterStep{ kind: .matrix, matrix: MatrixColorFilter{values, true} }
	}
	for sigma in c.trailing_sigmas {
		steps << CanvasFilterStep{kind: .blur, sigma: sigma}
	}
	clips := if c.clip { [rect_path(Rect{5.25, 6.5, 110.75, 100.25})] } else { []Path{} }
	image := CanvasBitmap{
		pixels:        large_source_blur_pixels(c, true)
		width:         c.image_width
		height:        c.image_height
		pitch:         c.image_width * 4 + 4
		premultiplied: c.image_premultiplied
		display_p3:    c.image_display_p3
	}
	return draw_canvas_image_filtered(mut pixels, c.width, c.height, c.pitch, c.alpha_type, c.transform, image,
		c.source, c.destination, c.smoothing, c.global_alpha, canvas_blend_mode(c.composite) or { panic('bad blend') }, clips, new_canvas_filter(steps), false)
}

fn check_large_source_blur_fixture(c LargeSourceBlurFixture, index int) {
	mut pixels := large_source_blur_pixels(c, false)
	assert large_source_blur_draw(mut pixels, c), 'large source fixture ${index} declined'
	actual := sha256.sum(pixels).hex()
	expected := $if linux { c.expected_linux } $else { c.expected_macos }
	assert actual == expected, 'large source ${index}: ${actual} != ${expected}'
}

// Raw sRGB/P3 images keep alpha type until the first actual downsample.
// The near-identity downsample preserves unpremultiplied bytes through blur.
fn test_large_pixel_aligned_image_blurs_match_native() {
	for i, c in large_source_blur_fixtures()[..16] { check_large_source_blur_fixture(c, i) }
}

// Fractional subsets have the AA surface prescribed by MakeFromImage;
// clipped integer sources retain the original source-to-destination mapping.
fn test_large_fractional_and_clipped_image_blurs_match_native() {
	fixtures := large_source_blur_fixtures()
	for i in 16 .. 28 { check_large_source_blur_fixture(fixtures[i], i) }
	for i in 32 .. 39 { check_large_source_blur_fixture(fixtures[i], i) }
}

fn test_large_deferred_source_transforms_preserve_destination() {
	fixtures := large_source_blur_fixtures()
	for i in [30] {
		c := fixtures[i]
		mut pixels := large_source_blur_pixels(c, false)
		original := pixels.clone()
		assert !large_source_blur_draw(mut pixels, c)
		assert pixels == original
	}
}

// A skipped near-identity downsample reuses the original pixels and snaps
// the nearly integer transform before blur, for either source alpha type.
fn test_large_near_integer_image_blurs_keep_unscaled_pixels() {
	fixtures := large_source_blur_fixtures()
	for i in 39 .. fixtures.len { check_large_source_blur_fixture(fixtures[i], i) }
}

// Aligned raw pixels, fractional AA surfaces and skipped near-integer
// resamples retain their source alpha/color metadata through shadow merge.
fn test_large_source_image_shadows_match_native() {
	fixtures := large_source_blur_fixtures()
	indices := [0, 1, 2, 3, 6, 7, 14, 16, 17, 20, 23, 24, 25, 32, 33, 34, 35, 36, 37, 38, 39, 40]
	macos := [
		'1fb4434385b9e48a3febcc3fece3e750c034e910d5bcbbdaaf6bae7b5a98d01e',
		'73c1e06dcd7f8692ea3c5543aafd45b9dbf5d977f7cb137e7090f0748e92b185',
		'9d5e27b370ce0aa6b08d83bf8222ee68a4dfe7564a89ab08152cafe751c72b06',
		'52bf9f10b43e88fd0b128722955ed600e3dcff269f476d1f88323ab23788f5db',
		'38f7ad8282046003087f871fe1793abbc0a9ef96827ee89af15c318d9b80bf8e',
		'5535b8b868abfc2e3caf7af76ba68f16a43dc6087247a059be83d9fef1bc50b8',
		'f097f6336484b07f0917d806aa9a8d570a242051bb73cb7d4aac52d21e38347c',
		'673eccccdcfa845a3264abbc680ee3929e3581d4fb7cce7764170b8e38c50924',
		'674c217ff07be500c452905a74f0b4f0c91f1f9de4fcc304a66422bf59256732',
		'20c14c2ac340a5895bcd09772478fe8b90ef9f40c2f78460ae8cfaf1a29d96c8',
		'244faeb04e854cd69406521a675ee0344343cf097702195fd979ddef0e742667',
		'69d055525d1e9213f0b02e53fee2a0085b805b4d107cfecb8e6602909e10e659',
		'99c6a69f3658b01bc88076f5216da11430eddf7813b40c873c06067d317c5dcc',
		'13fbec8a7c99e87a7e203557a34a3b1d1db4fe9e00f140b455fd7312a650766b',
		'e8988d99bcd66778e83ef3aafa4307665e186554ef9e8bdfc80551bbe2897801',
		'ea253a5a855b5ae264260bc48f6aac51b65ebdbef6bdaf307544734dd7f6f711',
		'1736aad951c8fc7e83f7ce4cef03ffab8c0e04ec05e7d68f5b1b480b2270d539',
		'b60451a4cf0c64c6dadb4bc431df64b3b04dbd18a51718346431c2c423883542',
		'9231be161e6a428982e66ec7885f8243a94def125f26feabc3edd1a7f1c43f18',
		'ed84e5aedba36fd5768864b096c59277f61b58eaad88c286bf1b7c55f558e709',
		'be1f5494f28daa678d2f0d34cc5f5dbc9d7a7b19e5f8182be5ce5ee95e1e373b',
		'5fd1503c6d969356883261a9f7b8acbfd24250b8ddb825da845076bb06cb7cb4',
	]
	linux := [
		'e9f3ca94e31ec5c2176915f0c8ac444f87c68d291b5305e1cd0f011ee8771f66',
		'73c1e06dcd7f8692ea3c5543aafd45b9dbf5d977f7cb137e7090f0748e92b185',
		'9d5e27b370ce0aa6b08d83bf8222ee68a4dfe7564a89ab08152cafe751c72b06',
		'52bf9f10b43e88fd0b128722955ed600e3dcff269f476d1f88323ab23788f5db',
		'38f7ad8282046003087f871fe1793abbc0a9ef96827ee89af15c318d9b80bf8e',
		'5535b8b868abfc2e3caf7af76ba68f16a43dc6087247a059be83d9fef1bc50b8',
		'f097f6336484b07f0917d806aa9a8d570a242051bb73cb7d4aac52d21e38347c',
		'9f53e78139030b0945932b1edf8eae7922433fa00fe7406809bfbe4f66d0be0c',
		'674c217ff07be500c452905a74f0b4f0c91f1f9de4fcc304a66422bf59256732',
		'4c1066403e9cef914d3e8755a60ab46db190709b2a31fe65095a57ec4b78eb49',
		'244faeb04e854cd69406521a675ee0344343cf097702195fd979ddef0e742667',
		'd0d0183197e9fe7bf35dcbbe5275442f7e029f5eb36e7130573bdae1a1623bf0',
		'99c6a69f3658b01bc88076f5216da11430eddf7813b40c873c06067d317c5dcc',
		'13fbec8a7c99e87a7e203557a34a3b1d1db4fe9e00f140b455fd7312a650766b',
		'e8988d99bcd66778e83ef3aafa4307665e186554ef9e8bdfc80551bbe2897801',
		'ea253a5a855b5ae264260bc48f6aac51b65ebdbef6bdaf307544734dd7f6f711',
		'7fbc2d4fecab84078ea1eaf66e71b3304eb5a0d22581c0e0cc6ee5864e3b3a94',
		'b60451a4cf0c64c6dadb4bc431df64b3b04dbd18a51718346431c2c423883542',
		'9231be161e6a428982e66ec7885f8243a94def125f26feabc3edd1a7f1c43f18',
		'4d9af9bdc66c079943a5791a6a2b6bbd0c9814a29d12187a855d7e6aa8fa0d2b',
		'4651e7206732799e9428f6d4645bb1088b879876e70daf23e9926a7fa5cc8770',
		'5fd1503c6d969356883261a9f7b8acbfd24250b8ddb825da845076bb06cb7cb4',
	]
	for i, index in indices {
		c := LargeSourceBlurFixture{...fixtures[index], shadow: true, shadow_color: 0x9d70d020,
			offset: [f32(9.25), -13.75]!, expected_macos: macos[i], expected_linux: linux[i]}
		check_large_source_blur_fixture(c, index)
	}
}

// Native rescale resolves whole-image minification before decimation when
// the combined step count would otherwise omit source pixels.
fn test_large_minified_whole_source_blurs_match_native() {
	fixtures := large_source_blur_fixtures()
	macos := [
		'c55db4f651180f604cb69e49c9f231bab877c87a7dce7004b826ae6da44ad38c',
		'f023909591bbd5590cea9710ba690c0d2c1235760060a30ba506fc76f88be9bf',
		'f023909591bbd5590cea9710ba690c0d2c1235760060a30ba506fc76f88be9bf',
		'210107c689fe1839876780397e0931dfa73483d992145cb13d41c6f07bf2f9ed',
		'd5f376e71629cb91dabfde32b1bd2c59731dfac489616e05ab5d9b7f6633db1d',
		'e1ea97290f53f652fe24f914b7561299dfb212b4ec9d83a81e3f8abee6848df0',
		'0ab9764c231131015f7b7a697083e118214214e4db1d70c12250af1ebc74f499',
		'df7c41a9da2b27cc56160f3d4194f3c2b0a64a05a44aadc667e6cf36921bbe6b',
	]
	linux := [
		'e231bc84276b8e4770dbf3e4a5fffbdc08e676bff590398298cc62d9a63003cc',
		'f023909591bbd5590cea9710ba690c0d2c1235760060a30ba506fc76f88be9bf',
		'f023909591bbd5590cea9710ba690c0d2c1235760060a30ba506fc76f88be9bf',
		'210107c689fe1839876780397e0931dfa73483d992145cb13d41c6f07bf2f9ed',
		'd5f376e71629cb91dabfde32b1bd2c59731dfac489616e05ab5d9b7f6633db1d',
		'e1ea97290f53f652fe24f914b7561299dfb212b4ec9d83a81e3f8abee6848df0',
		'0ab9764c231131015f7b7a697083e118214214e4db1d70c12250af1ebc74f499',
		'df7c41a9da2b27cc56160f3d4194f3c2b0a64a05a44aadc667e6cf36921bbe6b',
	]
	for i in 0 .. 8 {
		base := fixtures[i]
		w, h := f32(base.image_width), f32(base.image_height)
		c := LargeSourceBlurFixture{...base, source: [f32(0), 0, w, h]!,
			destination: [f32(5.25), 7.75, w * f32(.5), h * f32(.75)]!, sigma: 300,
			expected_macos: macos[i], expected_linux: linux[i]}
		check_large_source_blur_fixture(c, i)
	}
}

// The blur resolves a minified source per shadow request, while merge keeps
// the original foreground view, including when the shadow is offscreen.
fn test_large_minified_whole_source_shadows_match_native() {
	fixtures := large_source_blur_fixtures()
	indices := [0, 1, 2, 3, 4, 5, 6, 7, 2, 1]
	macos := [
		'ac90861d3cdd537e9f6e6fc6068b6b48e207dd96a7e040666c2eb9ef646f8c3c',
		'dc87f96b84e2d04bc947af14fd42eff3f46ab7bbcf8ad25b9a16e3d93f19e831',
		'1d0a643c1131ca50477ea6fbd633079190621fafb20a18d9018094495cecc87b',
		'3ef6eebac7b3ed64eefe6df2bc7404a6931c2ea0f2fda3e0efcafc6b530c1130',
		'72bd5d4149364f4e7f9c92b569d61601d7b16d6db0b60328fb6e4502c3eb9cb1',
		'114a74b5e4150d7b0b2947f23fb5b7d29766409c9c07c606043c84c6e821a9b6',
		'fc7373294e6b292a8eee37068bb5baa1f48f50737514c92cf97a50c6f2bd6437',
		'61d939acd1709dd5028ba9a59e608214a48ee5333ebd2e185475914c97f273d2',
		'1d0a643c1131ca50477ea6fbd633079190621fafb20a18d9018094495cecc87b',
		'dcf5803a334a54610445c02f042975fffd6502696ae2f3df361842ba1e90df61',
	]
	linux := [
		'c3c14a4ddab99cc6b850feb8d3871754784ae663cd10e39d7311a02cfc500bcc',
		'dc87f96b84e2d04bc947af14fd42eff3f46ab7bbcf8ad25b9a16e3d93f19e831',
		'1d0a643c1131ca50477ea6fbd633079190621fafb20a18d9018094495cecc87b',
		'3ef6eebac7b3ed64eefe6df2bc7404a6931c2ea0f2fda3e0efcafc6b530c1130',
		'72bd5d4149364f4e7f9c92b569d61601d7b16d6db0b60328fb6e4502c3eb9cb1',
		'114a74b5e4150d7b0b2947f23fb5b7d29766409c9c07c606043c84c6e821a9b6',
		'fc7373294e6b292a8eee37068bb5baa1f48f50737514c92cf97a50c6f2bd6437',
		'61d939acd1709dd5028ba9a59e608214a48ee5333ebd2e185475914c97f273d2',
		'1d0a643c1131ca50477ea6fbd633079190621fafb20a18d9018094495cecc87b',
		'dcf5803a334a54610445c02f042975fffd6502696ae2f3df361842ba1e90df61',
	]
	for i, index in indices {
		base := fixtures[index]
		w, h := f32(base.image_width), f32(base.image_height)
		c := LargeSourceBlurFixture{...base, source: [f32(0), 0, w, h]!,
			destination: [f32(5.25), 7.75, w * f32(.5), h * f32(.75)]!, sigma: 300,
			shadow: true, shadow_color: 0x9d70d020,
			offset: if i < 8 { [f32(9.25), -13.75]! } else { [f32(4096), -4096]! },
			expected_macos: macos[i], expected_linux: linux[i]}
		check_large_source_blur_fixture(c, i)
	}
}

// Resolve cropped and clipped sources before large-filter decimation, including
// fractional AA subsets and negative source-to-layer scales.
fn test_large_minified_source_subset_filters_match_native() {
	fixtures := large_source_blur_fixtures()
	indices := [0, 1, 2, 3, 4, 5, 6, 7, 16, 17, 24, 25, 0, 1]
	macos := [
		'9c19fb0d7af7e1c2560cbe1115c3472a81491a351fe88654c64c8320b07c1a27',
		'2cebbea57095bdd0c40fc555eb67f728cd978008d0ae545459d7f286317326d2',
		'f023909591bbd5590cea9710ba690c0d2c1235760060a30ba506fc76f88be9bf',
		'71de0d0b3ec1fd93197e696316832e37a5e99e9c9204a74532029d5ac60df3cc',
		'78f7a93c681ea21a3c00a851b8607043de3adcf8009ebc43c4a9b9da379526b8',
		'653ac93bf13745fc254a7da440b494e2453673d0761d471431a60ebea2075620',
		'0ab9764c231131015f7b7a697083e118214214e4db1d70c12250af1ebc74f499',
		'd855ed553b7fa1b8171fade00eee17a3689d0fe48e1f775c18e38ad6490fe5df',
		'78f7a93c681ea21a3c00a851b8607043de3adcf8009ebc43c4a9b9da379526b8',
		'83e919fea7f88a23d6bb99dacc2acd54d5f02571f252fa1dd669678fde3ba21a',
		'9c19fb0d7af7e1c2560cbe1115c3472a81491a351fe88654c64c8320b07c1a27',
		'7904d81a9b9a33a33cfbb53f70cbeefa98a24d74f1d8a27eb6cc3cd16bdb6d53',
		'9c19fb0d7af7e1c2560cbe1115c3472a81491a351fe88654c64c8320b07c1a27',
		'4f0755a955cc6c81625e020fc095e9c516316f4a17dd4dd9ec1cfd0214139bed',
	]
	linux := [
		'0382e0abf59b1bc6660ad064a871ac5a45a157340a72ff0de63bba1e36acf70a',
		'2cebbea57095bdd0c40fc555eb67f728cd978008d0ae545459d7f286317326d2',
		'f023909591bbd5590cea9710ba690c0d2c1235760060a30ba506fc76f88be9bf',
		'71de0d0b3ec1fd93197e696316832e37a5e99e9c9204a74532029d5ac60df3cc',
		'78f7a93c681ea21a3c00a851b8607043de3adcf8009ebc43c4a9b9da379526b8',
		'653ac93bf13745fc254a7da440b494e2453673d0761d471431a60ebea2075620',
		'0ab9764c231131015f7b7a697083e118214214e4db1d70c12250af1ebc74f499',
		'd855ed553b7fa1b8171fade00eee17a3689d0fe48e1f775c18e38ad6490fe5df',
		'78f7a93c681ea21a3c00a851b8607043de3adcf8009ebc43c4a9b9da379526b8',
		'83e919fea7f88a23d6bb99dacc2acd54d5f02571f252fa1dd669678fde3ba21a',
		'0382e0abf59b1bc6660ad064a871ac5a45a157340a72ff0de63bba1e36acf70a',
		'7904d81a9b9a33a33cfbb53f70cbeefa98a24d74f1d8a27eb6cc3cd16bdb6d53',
		'0382e0abf59b1bc6660ad064a871ac5a45a157340a72ff0de63bba1e36acf70a',
		'4f0755a955cc6c81625e020fc095e9c516316f4a17dd4dd9ec1cfd0214139bed',
	]
	for i, index in indices {
		base := fixtures[index]
		c := LargeSourceBlurFixture{...base,
			destination: [f32(5.25), 7.75, base.source[2] * f32(.5), base.source[3] * f32(.75)]!,
			transform: if i >= 12 { [f32(-1.25), 0, 0, .75, 137, 2]! } else { base.transform },
			sigma: 300, shadow: i % 2 != 0, shadow_color: 0x9d70d020, offset: [f32(9.25), -13.75]!,
			expected_macos: macos[i], expected_linux: linux[i]}
		check_large_source_blur_fixture(c, i)
	}
}
