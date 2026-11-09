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

// An identity rescale still samples the source shader and resolves paint
// effects before the blur.
fn test_large_identity_rescale_image_filters_match_native() {
	fixtures := large_source_blur_fixtures()
	indices := [0, 1, 2, 3, 4, 5, 6, 7, 16, 17, 24, 25, 0, 1, 2, 3]
	sigmas := [f32(135.01), 135.01, 135.01, 135.01, 135.01, 135.01, 135.01, 135.01, 135.01, 135.01, 135.01, 135.01, 135.001, 135.1, 135.13, 135.135]
	macos := [
		'7d80be1fece0a4168cc94cbebfa06d09205a3413096bfb2ccc80fbc81076bb4d',
		'2de7278a1b4828f1aacf707f7ce7a58916bf2d144042ccad849bf557f1b87ed8',
		'b2f3078667063cefd2d44605955cec2f1d5b6889f2c0897368c096f1c5e5d935',
		'4d1ef2e9dc50b03052c94e9d152f661118d7db54e7a88ad602e73925811c3bc6',
		'0ff7c68391c1742131fc445dc1f2774ea4cdad322967c8ec42e65164c9102485',
		'b2343f97ab8e72daac163f565c27acfaad853f8e4fa17fd19ba8c24bb52e7d81',
		'77ee7552da56317c7db9ab605de9e1eafa7da8c395e0ab8755b686387a8e6054',
		'03f286f8a213e86caf95b0ea3330c4a9ca7f1cb4e15c73b89717a0d6cf13affd',
		'4a492d8de1a7537f6c5c55581aca980345012aed5c3c063ec199cb6b13b379db',
		'f509b823d9ded0f6a20b55ae72265b859cd5ce4d3b67cb3a2d69d92a0f8350b8',
		'ceed5bac7106b947bdf03edadffadd7d19f1377db80dc22c0055d7dfad8c0c7d',
		'edf67d81bc04d9db580d52cc001f1a48dcbab66c16e2a0d7ce2a6a49efa88189',
		'7d80be1fece0a4168cc94cbebfa06d09205a3413096bfb2ccc80fbc81076bb4d',
		'2de7278a1b4828f1aacf707f7ce7a58916bf2d144042ccad849bf557f1b87ed8',
		'b2f3078667063cefd2d44605955cec2f1d5b6889f2c0897368c096f1c5e5d935',
		'4d1ef2e9dc50b03052c94e9d152f661118d7db54e7a88ad602e73925811c3bc6',
	]
	linux := [
		'0738951d7d84126af0692d76cf09052e99342d0a40e8b2423941c0d98a4085dc',
		'2de7278a1b4828f1aacf707f7ce7a58916bf2d144042ccad849bf557f1b87ed8',
		'b2f3078667063cefd2d44605955cec2f1d5b6889f2c0897368c096f1c5e5d935',
		'4d1ef2e9dc50b03052c94e9d152f661118d7db54e7a88ad602e73925811c3bc6',
		'0ff7c68391c1742131fc445dc1f2774ea4cdad322967c8ec42e65164c9102485',
		'b2343f97ab8e72daac163f565c27acfaad853f8e4fa17fd19ba8c24bb52e7d81',
		'77ee7552da56317c7db9ab605de9e1eafa7da8c395e0ab8755b686387a8e6054',
		'03f286f8a213e86caf95b0ea3330c4a9ca7f1cb4e15c73b89717a0d6cf13affd',
		'1e15ac1fc014b62badfd076c32c298e75046972567edd48a61f0b8252c52a1ff',
		'f509b823d9ded0f6a20b55ae72265b859cd5ce4d3b67cb3a2d69d92a0f8350b8',
		'ed92451fda2d31fb241fb957f637468b0ade5fbdd5fc527d10088dc0fed2763f',
		'edf67d81bc04d9db580d52cc001f1a48dcbab66c16e2a0d7ce2a6a49efa88189',
		'0738951d7d84126af0692d76cf09052e99342d0a40e8b2423941c0d98a4085dc',
		'2de7278a1b4828f1aacf707f7ce7a58916bf2d144042ccad849bf557f1b87ed8',
		'b2f3078667063cefd2d44605955cec2f1d5b6889f2c0897368c096f1c5e5d935',
		'4d1ef2e9dc50b03052c94e9d152f661118d7db54e7a88ad602e73925811c3bc6',
	]
	for i, index in indices {
		base := fixtures[index]
		c := LargeSourceBlurFixture{...base,
			destination: [f32(5.25), 7.75, base.source[2] * f32(.5), base.source[3] * f32(.75)]!,
			sigma: sigmas[i], shadow: i % 2 != 0, shadow_color: 0x9d70d020, offset: [f32(9.25), -13.75]!,
			expected_macos: macos[i], expected_linux: linux[i]}
		check_large_source_blur_fixture(c, i)
	}
}

// Native sampling, source conversion and incoming effects share the first
// downsample. Include former declines, flipped/clipped sources, and an invalid
// blur node whose shadow must still sample SourceGraphic.
fn test_large_direct_source_rescale_filters_match_native() {
	fixtures := large_source_blur_fixtures()
	indices := [0, 1, 2, 3, 4, 5, 6, 7, 0, 1, 2, 3, 4, 5, 6, 7, 24, 25, 28, 31, 0, 1, 1]
	macos := [
		'7d80be1fece0a4168cc94cbebfa06d09205a3413096bfb2ccc80fbc81076bb4d',
		'76eb08acbb83f2525d2c7c1b4e6332cd1bf1d652d3cf206fd258a7e7748cc98c',
		'682cf4123cfd144c64feaebf7ac6748205d629ea7c46526597e05c31e48b21c0',
		'5af31dab7380ebf9704dded28423aa7325e8c8929539a10a205ad2b7b249062d',
		'8045f4d2eec0e03618c081236d11b9447083a8451bea98b10db61608cef1c293',
		'6a3f24a4db26dd70cfee029cdbc5ec072ae5184f5251aa9783ad58a92ad78eb5',
		'519279c1a2eb6e6d79af835a1533e856cafd6e5bd27722160b004cfc2847535f',
		'9493a3db3ccc6d25ab55cdc695542a333140875095584a36253741f3627491e6',
		'7d80be1fece0a4168cc94cbebfa06d09205a3413096bfb2ccc80fbc81076bb4d',
		'f0c89868f7c31ccaa374c24a0e7708731eeb1f2e0d84983b294f435d8371789a',
		'682cf4123cfd144c64feaebf7ac6748205d629ea7c46526597e05c31e48b21c0',
		'6a1a82a627d72ca834b353b50dbf2e8120273a097a703ac867b335c4a9a8484c',
		'8045f4d2eec0e03618c081236d11b9447083a8451bea98b10db61608cef1c293',
		'be5a9066b6b9a8226b4f8405e77d7e283ba44fb7e021e5cc6eaf81a9876977eb',
		'519279c1a2eb6e6d79af835a1533e856cafd6e5bd27722160b004cfc2847535f',
		'0dc89417500e36089ac1c8015a895f7b23e49164dff1f4d458a8d0599006cdbe',
		'957e547449a8b4f3db0377d4191a1f1942151530d9f78243ff388f93979e7ffa',
		'af2fbf6e3a4982d577826747bd772b238e5025d8fe78dc2088fdb8c864e3412d',
		'78f7a93c681ea21a3c00a851b8607043de3adcf8009ebc43c4a9b9da379526b8',
		'2010356bfa03ec5b99d8e161f971196f29969e7cef54308782bf3e59ad6e0542',
		'03743ea674376c1ebbbdce486c63beaf13daf7ed6d2e43154ffe98d1c32dcb0d',
		'b8d9c734aba8c5e2a504a43e91f371fb7e511665b2bd920b8999e7dda2e78c67',
		'69628f453a4875ca8cc77647e6a0952cb17b677f75aa3aa3e0e93ae86454642d',
	]
	linux := [
		'0738951d7d84126af0692d76cf09052e99342d0a40e8b2423941c0d98a4085dc',
		'76eb08acbb83f2525d2c7c1b4e6332cd1bf1d652d3cf206fd258a7e7748cc98c',
		'682cf4123cfd144c64feaebf7ac6748205d629ea7c46526597e05c31e48b21c0',
		'5af31dab7380ebf9704dded28423aa7325e8c8929539a10a205ad2b7b249062d',
		'8045f4d2eec0e03618c081236d11b9447083a8451bea98b10db61608cef1c293',
		'6a3f24a4db26dd70cfee029cdbc5ec072ae5184f5251aa9783ad58a92ad78eb5',
		'519279c1a2eb6e6d79af835a1533e856cafd6e5bd27722160b004cfc2847535f',
		'9493a3db3ccc6d25ab55cdc695542a333140875095584a36253741f3627491e6',
		'0738951d7d84126af0692d76cf09052e99342d0a40e8b2423941c0d98a4085dc',
		'f0c89868f7c31ccaa374c24a0e7708731eeb1f2e0d84983b294f435d8371789a',
		'682cf4123cfd144c64feaebf7ac6748205d629ea7c46526597e05c31e48b21c0',
		'6a1a82a627d72ca834b353b50dbf2e8120273a097a703ac867b335c4a9a8484c',
		'8045f4d2eec0e03618c081236d11b9447083a8451bea98b10db61608cef1c293',
		'be5a9066b6b9a8226b4f8405e77d7e283ba44fb7e021e5cc6eaf81a9876977eb',
		'519279c1a2eb6e6d79af835a1533e856cafd6e5bd27722160b004cfc2847535f',
		'0dc89417500e36089ac1c8015a895f7b23e49164dff1f4d458a8d0599006cdbe',
		'ad146ab2e6946f86ec4e30cb61286c1f1419240b517f46f39405b580911fef85',
		'af2fbf6e3a4982d577826747bd772b238e5025d8fe78dc2088fdb8c864e3412d',
		'78f7a93c681ea21a3c00a851b8607043de3adcf8009ebc43c4a9b9da379526b8',
		'2010356bfa03ec5b99d8e161f971196f29969e7cef54308782bf3e59ad6e0542',
		'a62e52dffb37d90a01f59ffb07b0300a31eefe11520183ddc864ed46c533d675',
		'b8d9c734aba8c5e2a504a43e91f371fb7e511665b2bd920b8999e7dda2e78c67',
		'26da05733f5dab5516a830e81afa54ef07c9eb6dfe3f1faeac52399678f69d65',
	]
	for i, index in indices {
		base := fixtures[index]
		sx, sy := if i == 20 { f32(.5) } else { f32(1.25) }, if i == 20 { f32(.75) } else { f32(1.4) }
		c := LargeSourceBlurFixture{...base,
			destination: if i < 18 || i >= 20 {
				[f32(5.25), 7.75, base.source[2] * sx, base.source[3] * sy]!
			} else { base.destination },
			transform: if i >= 8 && i < 16 { [f32(-1.25), 0, 0, .75, 137, 2]! } else { base.transform },
			sigma: if i < 18 || i == 21 { f32(300) } else if i == 20 { f32(135.14) }
				else if i == 22 { f32(-300) } else { base.sigma },
			shadow: (i < 18 && i % 2 != 0) || i >= 21, shadow_color: 0x9d70d020,
			offset: if i == 21 { [f32(4096), -4096]! } else { [f32(9.25), -13.75]! },
			expected_macos: macos[i], expected_linux: linux[i]}
		check_large_source_blur_fixture(c, i)
	}
}

// Near-integer mappings retain their unsnapped transform in real rescale
// passes. Exact raw mappings keep their copy path; color effects still resolve.
fn test_large_near_source_rescale_filters_match_native() {
	fixtures := large_source_blur_fixtures()
	indices := [0, 1, 2, 3, 4, 5, 6, 7, 0, 1, 2, 3, 4, 5, 6, 7, 39, 40, 29, 1, 0, 36, 37]
	macos := [
		'f147529c899244e453fa430b18894b4345613bf08b96c203603eeaedc39944ae',
		'e0641f3b38b847d119fea1bc15dc36cbc6db88ee5171d802af1fa7e693fa24cf',
		'2836cb2fd108e4a2fc8cf26e6517de77ddc0094d848022664836fef899458698',
		'5737531974dd72708a11287fc865451f97ea417018e95ae3d334ab7394b95d40',
		'30a1c27354085bbd3fa8cb9e051164edacd8a59c4ca46d15f546bc1522e1ff5b',
		'4f0ac21e1cf486dc0b5c6fffcd8c0d00cc80e219537fc3de1ceca21ab5aded26',
		'06c316f59f4c0920c4dc0ba86e3a2e97cea099181e1b142fbc3e59da07015829',
		'27447f76b4a7ca120c64f0dc6f389073b30e383a5ed02d8aed9a2eaef6f68d0d',
		'04e93c6f459adb8d27eeb621440efc593b54971a26332bd5aa5f4850a1abc74a',
		'a809c08e701fd918f445572d26ec532a4410f9f6af5ef967dc6b1d91d3a35a50',
		'3f98a3b0998776923ae010085a487c56ca60a9bf5af5bbdd03caecdd6eeeb63d',
		'10c3d6aaa49390cac9d1ffad8da2ab983dc92f7eb994e99bdb9e4062a88035c1',
		'3107e2e603375124e7c73883cdaa80d806c9091d7578996bb1fb1c6ef971c191',
		'f95fe1d4a5572288e444bee70975189bce2d5dc4370ed8d4ad6bc823dddb9ea3',
		'0c2e438b745192c1bbc7fcc1b15fa4bdfbbc2e74eb826aece4a4f332e65ee2e5',
		'69ed1c581293a06d0fb5b9a7d4dab732650bf20af284f7dd0353fab18134e233',
		'78f7a93c681ea21a3c00a851b8607043de3adcf8009ebc43c4a9b9da379526b8',
		'a810462d0ea1dc68f84ca35bc7680b51d613f5986b7460f20987820407fac730',
		'e1ea97290f53f652fe24f914b7561299dfb212b4ec9d83a81e3f8abee6848df0',
		'17d297d37adc501396c1a34166cb00f40cf2ce0094ebdfbca2852f112577a808',
		'fa540d8f8f6f916307a5531b41d09cd8fedbf214b779a9711d688ff76dfb9f2c',
		'bc41bf0144f89d92988ee528f41084b5f9031cfe0e5e0fbfbbecc0c9aa483a8d',
		'bd7773dd4297eb3e4e060bc9310bbdea6950c09603ec5baf69261c8fc24ffe69',
	]
	linux := [
		'23a448c27062ceef7436fba177c9da09a39cb97e68fda702189e4724e51629c5',
		'e0641f3b38b847d119fea1bc15dc36cbc6db88ee5171d802af1fa7e693fa24cf',
		'2836cb2fd108e4a2fc8cf26e6517de77ddc0094d848022664836fef899458698',
		'5737531974dd72708a11287fc865451f97ea417018e95ae3d334ab7394b95d40',
		'30a1c27354085bbd3fa8cb9e051164edacd8a59c4ca46d15f546bc1522e1ff5b',
		'4f0ac21e1cf486dc0b5c6fffcd8c0d00cc80e219537fc3de1ceca21ab5aded26',
		'06c316f59f4c0920c4dc0ba86e3a2e97cea099181e1b142fbc3e59da07015829',
		'27447f76b4a7ca120c64f0dc6f389073b30e383a5ed02d8aed9a2eaef6f68d0d',
		'b174c7b08a8c6c0f4ba827bef8a108884aac1d41d04956b3f1c5d70046c64b31',
		'a809c08e701fd918f445572d26ec532a4410f9f6af5ef967dc6b1d91d3a35a50',
		'3f98a3b0998776923ae010085a487c56ca60a9bf5af5bbdd03caecdd6eeeb63d',
		'10c3d6aaa49390cac9d1ffad8da2ab983dc92f7eb994e99bdb9e4062a88035c1',
		'3107e2e603375124e7c73883cdaa80d806c9091d7578996bb1fb1c6ef971c191',
		'f95fe1d4a5572288e444bee70975189bce2d5dc4370ed8d4ad6bc823dddb9ea3',
		'0c2e438b745192c1bbc7fcc1b15fa4bdfbbc2e74eb826aece4a4f332e65ee2e5',
		'69ed1c581293a06d0fb5b9a7d4dab732650bf20af284f7dd0353fab18134e233',
		'78f7a93c681ea21a3c00a851b8607043de3adcf8009ebc43c4a9b9da379526b8',
		'a810462d0ea1dc68f84ca35bc7680b51d613f5986b7460f20987820407fac730',
		'e1ea97290f53f652fe24f914b7561299dfb212b4ec9d83a81e3f8abee6848df0',
		'93960ba8cb71ff46152816adc6da65d04892c481f93ddfd4ec62867b902e032d',
		'61f89369033a113cbd4cdc04178f09648786738d10514673dd74137330196031',
		'bc41bf0144f89d92988ee528f41084b5f9031cfe0e5e0fbfbbecc0c9aa483a8d',
		'bd7773dd4297eb3e4e060bc9310bbdea6950c09603ec5baf69261c8fc24ffe69',
	]
	for i, index in indices {
		base := fixtures[index]
		sx, sy := if i < 8 || i >= 19 { f32(1.0005) } else { f32(.9997) },
			if i < 8 || i >= 19 { f32(.9996) } else { f32(1.0004) }
		near := i < 16 || i == 19 || i == 20
		c := LargeSourceBlurFixture{...base,
			destination: if near { [f32(5.0002), 7.0003, base.source[2] * sx, base.source[3] * sy]! }
				else { base.destination },
			transform: if near { [f32(1), 0, 0, 1, 0, 0]! } else { base.transform },
			sigma: if i >= 8 && i < 16 { f32(135.2) } else if i == 19 { f32(-300) }
				else if i == 18 { base.sigma } else { f32(300) },
			shadow: (i < 18 && i % 2 != 0) || i in [19, 20, 21], shadow_color: 0x9d70d020,
			offset: if i == 20 { [f32(4096), -4096]! } else { [f32(9.25), -13.75]! },
			global_alpha: if i == 21 { f32(.7) } else { base.global_alpha },
			image_display_p3: i == 21 || base.image_display_p3,
			pre: if i == 21 { fixtures[1].pre } else { base.pre },
			expected_macos: macos[i], expected_linux: linux[i]}
		check_large_source_blur_fixture(c, i)
	}
}
