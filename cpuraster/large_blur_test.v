module cpuraster

import crypto.sha256
import json2
import math

struct LargeBlurImageFixture {
	width          int
	height         int
	subset         [4]int
	clip           [4]int
	sigma          [2]f32
	expected_macos string
	expected_linux string
}

struct LargeBlurCanvasFixture {
	width           int
	height          int
	pitch           int
	alpha_type      int
	even_odd        bool
	segments        []f32
	transform       [6]f32
	color           u32
	global_alpha    f32
	composite       int
	sigma           f32
	stroke          bool
	line_width      f32
	cap             int
	join            int
	clips           []f32
	gradient        []f32
	pre             [][]f32
	post            [][]f32
	background_file string
	expected_macos  string
	expected_linux  string
}

struct LargeBlurFixtures {
	images []LargeBlurImageFixture
	canvas []LargeBlurCanvasFixture
}

fn large_blur_fixtures() LargeBlurFixtures {
	return json2.decode[LargeBlurFixtures]($embed_file('@VMODROOT/cpuraster/testdata/large-blur-cases.json').to_string()) or { panic(err) }
}

fn large_blur_pixels(width int, height int) BlurImage {
	mut pixels := []u8{len: width * height * 4}
	for y in 0 .. height {
		for x in 0 .. width {
			mut a := (x * 37 + y * 91) % 256
			if (x + 2 * y) % 5 == 0 { a = 255 }
			if (x * 3 + y) % 7 == 3 { a = 0 }
			o := (y * width + x) * 4
			pixels[o] = u8((x * 53 + y * 17) % 256 * a / 255)
			pixels[o + 1] = u8((x * 11 + y * 67) % 256 * a / 255)
			pixels[o + 2] = u8((x * 29 + y * 41 + 100) % 256 * a / 255)
			pixels[o + 3] = u8(a)
		}
	}
	return BlurImage{pixels, width, height}
}

// Native SkImages::MakeWithFilter() fixtures include fractional threshold
// sigmas, progressive rescaling, asymmetric axes, subsets and cropped output.
fn test_large_image_blurs_match_native() {
	for i, c in large_blur_fixtures().images {
		image, x, y := image_with_blur_filter(large_blur_pixels(c.width, c.height),
			IRect{c.subset[0], c.subset[1], c.subset[2], c.subset[3]}, IRect{c.clip[0], c.clip[1], c.clip[2], c.clip[3]}, c.sigma[0], c.sigma[1]) or { panic('empty large blur ${i}') }
		result := '${image.width}x${image.height} at ${x},${y} ${sha256.sum(image.pixels).hex()}'
		expected := $if linux { c.expected_linux } $else { c.expected_macos }
		assert result == expected, 'large image ${i}: ${result} != ${expected}'
	}
}

fn large_blur_background(c LargeBlurCanvasFixture) []u8 {
	match c.background_file {
		'large-blur-gradient-padding-background.rgba' {
			return $embed_file('@VMODROOT/cpuraster/testdata/large-blur-gradient-padding-background.rgba').to_bytes()
		}
		'large-blur-legacy-restore-background.rgba' {
			return $embed_file('@VMODROOT/cpuraster/testdata/large-blur-legacy-restore-background.rgba').to_bytes()
		}
		'large-blur-subset-restore-background.rgba' {
			return $embed_file('@VMODROOT/cpuraster/testdata/large-blur-subset-restore-background.rgba').to_bytes()
		}
		'large-blur-stroke-gradient-background.rgba' {
			return $embed_file('@VMODROOT/cpuraster/testdata/large-blur-stroke-gradient-background.rgba').to_bytes()
		}
		else {
			assert c.background_file == ''
		}
	}
	mut pixels := []u8{len: c.pitch * c.height, init: 0x5a}
	for y in 0 .. c.height {
		for x in 0 .. c.width {
			a := (x * 17 + y * 31) % 256
			rgb := [(x * 53 + y * 17) % 256, (x * 11 + y * 67) % 256, (x * 29 + y * 41 + 100) % 256]
			o := y * c.pitch + x * 4
			for k in 0 .. 3 {
				pixels[o + k] = u8(if c.alpha_type == 2 { rgb[k] * a / 255 } else { rgb[k] })
			}
			pixels[o + 3] = u8(a)
		}
	}
	return pixels
}

fn large_blur_matrices(matrices [][]f32) []CanvasFilterStep {
	mut steps := []CanvasFilterStep{}
	for matrix in matrices {
		assert matrix.len == 20
		mut values := [20]f32{}
		for k, value in matrix { values[k] = value }
		steps << CanvasFilterStep{ kind: .matrix, matrix: MatrixColorFilter{values, true} }
	}
	return steps
}

// Saved layer fills and strokes retain the blur's initialized padding and
// defer incoming color filters until after the first downsample. Four random
// regressions cover final restore rounding, a linear gradient, and color math.
fn test_large_canvas_blurs_match_native() {
	for i, c in large_blur_fixtures().canvas {
		mut pixels := large_blur_background(c)
		mut steps := large_blur_matrices(c.pre)
		steps << CanvasFilterStep{ kind: .blur, sigma: c.sigma }
		steps << large_blur_matrices(c.post)
		clips := if c.clips.len == 0 { []Path{} } else { [canvas_path(c.clips, false)] }
		g := c.gradient
		style := if g.len == 0 {
			?CanvasPaintStyle(none)
		} else {
			?CanvasPaintStyle(CanvasGradient{
				kind:  1
				x0:    g[0]
				y0:    g[1]
				r0:    g[2]
				x1:    g[3]
				y1:    g[4]
				r1:    g[5]
				angle: g[6]
				stops: g[7..]
			})
		}
		mode := canvas_blend_mode(c.composite) or { panic('bad blend') }
		if c.stroke {
			assert stroke_canvas_path(mut pixels, c.width, c.height, c.pitch, c.alpha_type, canvas_path(c.segments, false), c.transform, c.color, style, c.global_alpha, mode, 0, c.line_width,
				match c.cap {
					0 { StrokeCap.butt }
					1 { .round }
					else { .square }
				},
				match c.join {
					0 { StrokeJoin.round }
					1 { .bevel }
					else { .miter }
				}, 10, [], 0, clips, new_canvas_filter(steps))
		} else {
			assert fill_canvas_path(mut pixels, c.width, c.height, c.pitch, c.alpha_type, canvas_path(c.segments, c.even_odd), c.transform, c.color, style, c.global_alpha, mode, 0, clips, new_canvas_filter(steps))
		}
		expected := $if linux { c.expected_linux } $else { c.expected_macos }
		actual := sha256.sum(pixels).hex()
		assert actual == expected, 'large canvas ${i}: ${actual} != ${expected}'
	}
}

fn test_large_blur_unsupported_layers_preserve_destination() {
	mut b := PathBuilder{}
	b.move_to(2, 3)
	b.line_to(25, 3)
	b.line_to(25, 23)
	b.close()
	path := b.detach()
	identity := [f32(1), 0, 0, 1, 0, 0]!
	for filters in [
		[CanvasFilterStep{ kind: .drop_shadow, sigma: 300, color: 0xff203040 }],
		[CanvasFilterStep{ kind: .blur, sigma: 300 }, CanvasFilterStep{ kind: .blur, sigma: 2 }],
	] {
		mut pixels := large_blur_pixels(32, 28).pixels
		original := pixels.clone()
		assert !fill_canvas_path(mut pixels, 32, 28, 128, 2, path, identity, 0xff203040, none, 1, .src_over, 0, [], new_canvas_filter(filters))
		assert pixels == original
	}
	mut pixels := large_blur_pixels(32, 28).pixels
	original := pixels.clone()
	assert !fill_canvas_path(mut pixels, 32, 28, 128, 2, path, [f32(1), .1, 0, 1, 0, 0]!, 0xff203040, none, 1, .src_over, 0, [], new_canvas_filter([CanvasFilterStep{ kind: .blur, sigma: 300 }]))
	assert pixels == original
}

fn test_image_blur_rejects_invalid_sigmas() {
	image := large_blur_pixels(8, 7)
	for sigma in [f32(-1), math.f32_from_bits(0x7fc00000), math.f32_from_bits(0x7f800000)] {
		assert image_with_blur_filter(image, IRect{0, 0, 8, 7}, IRect{-2, -2, 10, 9}, sigma, 1) == none
		assert image_with_blur_filter(image, IRect{0, 0, 8, 7}, IRect{-2, -2, 10, 9}, 1, sigma) == none
	}
}
