module cpuraster

import crypto.sha256
import os

fn filter_layer_test_background() []u8 {
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

fn filter_layer_test_path() Path {
	mut b := PathBuilder{}
	b.move_to(10, 8)
	b.quad_to(40, 30, 38, 12)
	b.line_to(12, 34)
	b.close()
	return b.detach()
}

fn filter_layer_test_clip() []Path {
	mut b := PathBuilder{}
	b.move_to(2, 3)
	b.line_to(45.5, 10.25)
	b.line_to(20.5, 38)
	b.close()
	return [b.detach()]
}

fn blur_filter(sigma f32) ?CanvasFilter {
	return new_canvas_filter([CanvasFilterStep{
		kind:  .blur
		sigma: sigma
	}])
}

// The hash of the pixels, which must have changed.
fn filter_layer_test_hash(px []u8, alpha_type int) string {
	mut untouched := filter_layer_test_background()
	if alpha_type != 2 {
		premultiply_rows(mut untouched, 48, 40, 192)
	}
	assert px != untouched
	return sha256.sum(px).hex()[..16]
}

// Hashes of vox_skia_canvas_path() and vox_skia_canvas_glyphs() with a
// canvas blur() filter in LibWeb Skia (test_cpu_raster.sh compares random
// ones): the content is drawn into a padded layer, blurred by the raster
// blur engine and drawn back as a sprite with the composite operation.
fn test_blur_filtered_draws_match_skia() {
	identity := [f32(1), 0, 0, 1, 0, 0]!
	mut px := filter_layer_test_background()
	assert fill_canvas_path(mut px, 48, 40, 192, 2, filter_layer_test_path(), identity, 0xc0e04010,
		none, 1, .src_over, 0, [], blur_filter(2.5))
	assert filter_layer_test_hash(px, 2) == fixture_hash('7263a58806bf8436')
	// A scaled stroke: the layer matrix carries the scale, and the sigma is
	// mapped into layer space per axis (the Gaussian pass).
	px = filter_layer_test_background()
	assert stroke_canvas_path(mut px, 48, 40, 192, 1, filter_layer_test_path(), [
		f32(1.25),
		0,
		0,
		0.75,
		2,
		4,
	]!, 0xff3070c0, none, 1, .src_over, 0, 3, .round, .round, 10, [], 0, [], blur_filter(0.8))
	assert filter_layer_test_hash(px, 1) == fixture_hash('11314abdec52c202')
	// Multiply through an anti-aliased clip, which cuts the sprite: the
	// result is drawn with an image shader.
	px = filter_layer_test_background()
	assert fill_canvas_path(mut px, 48, 40, 192, 2, filter_layer_test_path(), identity, 0xff10a040,
		none, 1, .multiply, 0, filter_layer_test_clip(), blur_filter(4))
	assert filter_layer_test_hash(px, 2) == fixture_hash('698232341bfd269c')
	// A large translucent blur: the three-box pass.
	px = filter_layer_test_background()
	assert fill_canvas_path(mut px, 48, 40, 192, 2, filter_layer_test_path(), identity, 0x80ff8000,
		none, 0.7, .src_over, 0, [], blur_filter(12))
	assert filter_layer_test_hash(px, 2) == fixture_hash('9715f8489f927c77')
	$if macos {
		px = filter_layer_test_background()
		run := CanvasGlyphRun{
			font_path:   os.join_path(@VMODROOT, 'pixel_tests/sites/tarsnap/www.tarsnap.com/font/NotoSans-Regular-subset.ttf')
			font_size:   17
			glyphs:      [u16(5), 9, 12, 7]
			positions:   [f32(0), 0, 9.3, 0, 18.55, 0, 27.8, 0]
			translation: [f32(3.25), 26.6]!
		}
		assert fill_canvas_glyphs(mut px, 48, 40, 192, 2, run, identity, 0xff203040, none, 1,
			.src_over, [], blur_filter(1.5))
		assert filter_layer_test_hash(px, 2) == fixture_hash('5dc0e6b8a4ddf089')
	}
}

// An invalid blur drops the filters before it; blenders that change
// transparent black and rotations still decline.
fn test_blur_filter_lists() {
	f := new_canvas_filter([CanvasFilterStep{
		kind:   .matrix
		matrix: MatrixColorFilter{
			matrix: [f32(1), 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0]!
		}
	}, CanvasFilterStep{
		kind:  .blur
		sigma: -1
	}])
	assert f == none
	mut px := filter_layer_test_background()
	before := px.clone()
	assert !fill_canvas_path(mut px, 48, 40, 192, 2, filter_layer_test_path(), [
		f32(1),
		0,
		0,
		1,
		0,
		0,
	]!, 0xff000000, none, 1, .src_in, 0, [], blur_filter(2))
	assert !fill_canvas_path(mut px, 48, 40, 192, 2, filter_layer_test_path(), [
		f32(0.9),
		0.4,
		-0.4,
		0.9,
		0,
		0,
	]!, 0xff000000, none, 1, .src_over, 0, [], blur_filter(2))
	assert px == before
}

// Byte hashes captured from vox_skia_canvas_path() in the pinned LibWeb
// Skia, on the same path/background as the blur-layer regression tests.
fn test_drop_shadow_filter_layers_match_skia() {
	steps := [
		CanvasFilterStep{ kind: .drop_shadow, sigma: -1, color: 0xff000000 },
		CanvasFilterStep{ kind: .drop_shadow, offset_x: 7, offset_y: -5, color: 0x805030e0 },
		CanvasFilterStep{ kind: .drop_shadow, sigma: 2.5, offset_x: 5.25, offset_y: -3.75, color: 0x805030e0 },
		CanvasFilterStep{ kind: .drop_shadow, sigma: 0.8, offset_x: -7.25, offset_y: 4.5, color: 0xff3070c0 },
		CanvasFilterStep{ kind: .drop_shadow, sigma: 12, offset_x: 2, offset_y: 3, color: 0x80ff8000 },
		CanvasFilterStep{ kind: .drop_shadow, offset_x: 90, offset_y: 80, color: 0xff000000 },
	]
	modes := [BlendMode.src_over, .src_over, .src_over, .multiply, .screen, .xor]
	hashes := ['e285128862b4c6f0', 'ab22cb5dca7fc310', 'a62f8ada40e53b93', '05e318754d94c77f',
		'4cb7f8b02151c3f6', '4394924f9676093c']
	for i, step in steps {
		mut px := filter_layer_test_background()
		clips := if i == 3 { filter_layer_test_clip() } else { []Path{} }
		assert fill_canvas_path(mut px, 48, 40, 192, 2, filter_layer_test_path(),
			[f32(1), 0, 0, 1, 0, 0]!, 0xc0e04010, none, 1, modes[i], 0, clips,
			new_canvas_filter([step]))
		assert filter_layer_test_hash(px, 2) == fixture_hash(hashes[i]), 'drop-shadow fixture ${i}'
	}
}

// A native comparison reduced from seed 20261106, draw 5714. The mapped
// X sigma produces a blur while Y is an identity. Sampling the initialized
// bottom edge as a transparent border loses one alpha value at (55, 50).
fn test_scaled_drop_shadow_keeps_initialized_blur_boundary() {
	mut b := PathBuilder{}
	b.move_to(36.080982, 64.31974)
	b.cubic_to(33.5, 62.165848, 49.5, -3.6732166, 5.4647284, 53.63945)
	b.line_to(34, 16.909954)
	b.cubic_to(52.80074, 59.36197, 63.24132, 18.59892, 17.961535, 28.317299)
	b.quad_to(60.485752, 17, 41.736267, 58.978004)
	b.close()
	style := CanvasPaintStyle(CanvasPattern{
		pixels: $embed_file('testdata/drop-shadow-pattern.rgba').to_bytes()
		width: 10
		height: 14
		pitch: 48
		transform: [f32(1), 0, 0, 1, 0, 0]!
	})
	filter := new_canvas_filter([CanvasFilterStep{
		kind: .drop_shadow
		sigma: .023268236
		offset_x: 7
		offset_y: -13.374848
		color: 0xff000000
	}])
	mut pixels := []u8{len: 61 * 59 * 4}
	assert fill_canvas_path(mut pixels, 61, 59, 244, 2, b.detach(),
		[f32(1.4418191), 0, 0, 1.0050474, -6.6226745, -1.0314453]!, 0xff000000,
		style, 1, .src_over, 0, [], filter)
	offset := (50 * 61 + 55) * 4
	assert pixels[offset..offset + 4] == [u8(54), 110, 80, 184]
	assert sha256.sum(pixels).hex() == '2bc0e0020dae8a2c6b45581b13f07fd8c9357a810d291d7115d1975030a57fb0'
}

fn test_unsupported_drop_shadow_layers_preserve_destination() {
	step := CanvasFilterStep{ kind: .drop_shadow, sigma: 2, offset_x: 3.5, offset_y: -1.25, color: 0x80000000 }
	mut px := filter_layer_test_background()
	before := px.clone()
	assert !fill_canvas_path(mut px, 48, 40, 192, 1, filter_layer_test_path(),
		[f32(1), 0, 0, 1, 0, 0]!, 0xff000000, none, 1, .src_in, 0, [], new_canvas_filter([step]))
	assert px == before
	assert !fill_canvas_path(mut px, 48, 40, 192, 1, filter_layer_test_path(),
		[f32(0.9), 0.4, -0.4, 0.9, 0, 0]!, 0xff000000, none, 1, .src_over, 0, [], new_canvas_filter([step]))
	assert px == before
	assert !fill_canvas_path(mut px, 48, 40, 192, 1, filter_layer_test_path(),
		[f32(1), 0, 0, 1, 0, 0]!, 0xff000000, none, 1, .src_over, 0, [], new_canvas_filter([
			step,
			step,
		]))
	assert px == before
}
