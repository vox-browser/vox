module cpuraster

import crypto.sha256
import math
import os

fn color_filter_test_background() []u8 {
	mut px := []u8{len: 48 * 40 * 4}
	for y in 0 .. 40 {
		for x in 0 .. 48 {
			o := (y * 48 + x) * 4
			a := if (x * 3 + y) % 11 == 0 { 0 } else { (x * 9 + y * 4) % 256 }
			px[o + 3] = u8(a)
			px[o] = u8(a * y / 40)
			px[o + 1] = u8(a / 2)
			px[o + 2] = u8(a * x / 48)
		}
	}
	return px
}

fn color_filter_test_path() Path {
	mut b := PathBuilder{}
	b.move_to(4, 5)
	b.quad_to(44, 30, 40, 2)
	b.line_to(10, 36)
	b.close()
	return b.detach()
}

// The test harness's matrices as clang folded them.
const cf_grayscale = MatrixColorFilter{
	matrix: [f32(0.448819995), 0.500639975, 0.0505400002, 0, 0, 0.148819983, 0.800639987, 0.0505400002,
		0, 0, 0.148819983, 0.500639975, 0.350540012, 0, 0, 0, 0, 0, 1, 0]!
	clamp:  true
}

const cf_contrast = MatrixColorFilter{
	matrix: [f32(2.2278025), 0, 0, 0, -0.61390126, 0, 2.2278025, 0, 0, -0.61390126, 0, 0, 2.2278025,
		0, -0.61390126, 0, 0, 0, 1, 0]!
}

const cf_opacity = MatrixColorFilter{
	matrix: [f32(1), 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 2.8894753, 0]!
	clamp:  true
}

const cf_invert = MatrixColorFilter{
	matrix: [f32(-0.600000024), 0, 0, 0, 0.800000012, 0, -0.600000024, 0, 0, 0.800000012, 0, 0,
		-0.600000024, 0, 0.800000012, 0, 0, 0, 1, 0]!
	clamp:  true
}

const cf_brightness = MatrixColorFilter{
	matrix: [f32(1.7), 0, 0, 0, 0, 0, 1.7, 0, 0, 0, 0, 0, 1.7, 0, 0, 0, 0, 0, 1, 0]!
}

fn color_filter_test_hash(mut px []u8) string {
	return sha256.sum(px).hex()[..16]
}

// filterColor4f()'s one-pixel pipeline, bit for bit with LibWeb Skia: the
// unclamped contrast pushes red below 0 and blue above 1, and the opacity
// matrix lifts alpha.
fn test_filter_color_matches_skia() {
	f := new_color_filter([cf_contrast, cf_opacity, MatrixColorFilter{
		matrix: [f32(2.5450857), 0, 0, 0, -0.77254283, 0, 2.5450857, 0, 0, -0.77254283, 0, 0,
			2.5450857, 0, -0.77254283, 0, 0, 0, 1, 0]!
	}]) or { panic('no filter') }
	c := filtered_paint_color(2234942615, f32(58) * inv_255, f)
	assert c.map(math.f32_bits(it)) == [u32(0xbf45c55e), 0x3f199d6b, 0x3f82e21c, 0x3f283f2e]
	// Non-finite matrices are dropped; an alpha offset moves transparent
	// black, which keeps the filter out of the paint.
	mut inf_matrix := cf_brightness.matrix
	inf_matrix[3] = f32(math.inf(1))
	assert new_color_filter([MatrixColorFilter{
		matrix: inf_matrix
	}]) == none
	mut offset := cf_brightness.matrix
	offset[19] = 0.25
	g := new_color_filter([MatrixColorFilter{
		matrix: offset
	}]) or { panic('no filter') }
	assert g.affects_transparent_black()
	assert !f.affects_transparent_black()
}

// Hashes of vox_skia_canvas_path() and vox_skia_canvas_glyphs() with LibWeb
// Skia and the same canvas filter lists (test_cpu_raster.sh compares random
// ones).
fn test_color_filtered_draws_match_skia() {
	identity := [f32(1), 0, 0, 1, 0, 0]!
	// A filtered solid color through the legacy blitter.
	mut px := color_filter_test_background()
	assert fill_canvas_path(mut px, 48, 40, 192, 2, color_filter_test_path(), identity, 0xc0e04010,
		none, 1, .src_over, 0, [], canvas_matrix_filter([cf_grayscale]))
	assert color_filter_test_hash(mut px) == fixture_hash('b9e3807216264fee')
	// A thin stroke's coverage alpha, then a color outside premultiplied
	// range: the unbounded uniform color keeps the pipeline in highp.
	px = color_filter_test_background()
	assert stroke_canvas_path(mut px, 48, 40, 192, 1, color_filter_test_path(), identity, 2234942615,
		none, 0.54357654, .src_over, 0, 0.81891125, .square, .miter, 10, [], 0, [], canvas_matrix_filter([
		cf_contrast, cf_opacity]))
	assert color_filter_test_hash(mut px) == fixture_hash('981723a1df76bd4e')
	// A gradient's SkColorFilterShader: the shader, its alpha, then the
	// filter stages, under multiply.
	px = color_filter_test_background()
	gradient := CanvasGradient{
		kind:  1
		x0:    2
		x1:    44
		y1:    30
		stops: [f32(0), 1, 0, 0, 1, 0.6, 0, 0.5, 1, 0.8, 1, 0.2, 0.9, 0.1, 1]
	}
	assert fill_canvas_path(mut px, 48, 40, 192, 2, color_filter_test_path(), identity, 0, gradient,
		0.8, .multiply, 0, [], canvas_matrix_filter([cf_grayscale, cf_invert]))
	assert color_filter_test_hash(mut px) == fixture_hash('a3298d3c5d402d2a')
	// A wide stroke whose brightened color leaves byte range.
	px = color_filter_test_background()
	assert stroke_canvas_path(mut px, 48, 40, 192, 1, color_filter_test_path(), identity, 0xff3070c0,
		none, 1, .src_over, 0, 5, .round, .round, 10, [], 0, [], canvas_matrix_filter([cf_brightness,
		cf_contrast]))
	assert color_filter_test_hash(mut px) == fixture_hash('d2c92fb8066b9c06')
	// Destination-in is not skipped for a filtered paint.
	px = color_filter_test_background()
	assert fill_canvas_path(mut px, 48, 40, 192, 2, color_filter_test_path(), identity, 0x80ff8000,
		none, 1, .dst_in, 0, [], canvas_matrix_filter([cf_invert, MatrixColorFilter{
		matrix: [f32(1), 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0.4, 0]!
		clamp:  true
	}]))
	assert color_filter_test_hash(mut px) == fixture_hash('2a187525bf21fe92')
	$if macos {
		// Glyph masks with the filtered color; the mask gamma follows the
		// filtered luminance color.
		px = color_filter_test_background()
		run := CanvasGlyphRun{
			font_path:   os.join_path(@VMODROOT, 'pixel_tests/sites/tarsnap/www.tarsnap.com/font/NotoSans-Regular-subset.ttf')
			font_size:   17
			glyphs:      [u16(5), 9, 12, 7]
			positions:   [f32(0), 0, 9.3, 0, 18.55, 0, 27.8, 0]
			translation: [f32(3.25), 26.6]!
		}
		assert fill_canvas_glyphs(mut px, 48, 40, 192, 2, run, identity, 0xff203040, none, 1,
			.src_over, [], canvas_matrix_filter([cf_brightness, cf_grayscale]))
		assert color_filter_test_hash(mut px) == fixture_hash('ef23d717aba8bafd')
	}
}

// A filter that moves transparent black needs an image filter layer, which
// is not ported: the draw declines without touching the pixels.
fn test_layer_color_filters_decline() {
	mut offset := cf_brightness.matrix
	offset[19] = 0.25
	mut px := color_filter_test_background()
	before := px.clone()
	assert !fill_canvas_path(mut px, 48, 40, 192, 1, color_filter_test_path(), [f32(1), 0, 0, 1,
		0, 0]!, 0xff000000, none, 1, .src_over, 0, [], canvas_matrix_filter([MatrixColorFilter{
		matrix: offset
	}]))
	assert px == before
}
