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
	steps << CanvasFilterStep{ kind: .blur, sigma: c.sigma }
	for matrix in c.post {
		mut values := [20]f32{}
		for k, v in matrix { values[k] = v }
		steps << CanvasFilterStep{ kind: .matrix, matrix: MatrixColorFilter{values, true} }
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
	for i in 28 .. 32 {
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
