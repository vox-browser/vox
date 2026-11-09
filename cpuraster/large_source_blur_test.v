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
