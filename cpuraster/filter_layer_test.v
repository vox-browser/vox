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

// An invalid blur drops the filters before it; rotations still decline.
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
		f32(0.9),
		0.4,
		-0.4,
		0.9,
		0,
		0,
	]!, 0xff000000, none, 1, .src_over, 0, [], blur_filter(2))
	assert px == before
}

fn filter_layer_test_color_pattern() CanvasPattern {
	mut pixels := []u8{len: 32 * 6}
	for y in 0 .. 6 { for x in 0 .. 7 {
		o := y * 32 + x * 4
		mut alpha := (x * 37 + y * 91) % 256
		if (x + 2 * y) % 5 == 0 { alpha = 255 }
		if (x * 3 + y) % 7 == 3 { alpha = 0 }
		pixels[o] = u8((x * 53 + y * 17) % 256)
		pixels[o + 1] = u8((x * 11 + y * 67) % 256)
		pixels[o + 2] = u8((x * 29 + y * 41 + 100) % 256)
		pixels[o + 3] = u8(alpha)
	} }
	return CanvasPattern{pixels: pixels, width: 7, height: 6, pitch: 32,
		display_p3: true, transform: [f32(1), 0, 0, 1, 0, 0]!}
}

fn test_color_matrices_before_and_after_filter_layers_match_native() {
	contrast := CanvasFilterStep{kind: .matrix, matrix: MatrixColorFilter{
		matrix: [f32(1.3), 0, 0, 0, -.15, 0, 1.3, 0, 0, -.15, 0, 0, 1.3, 0, -.15, 0, 0, 0, 1, 0]!}}
	opacity := CanvasFilterStep{kind: .matrix, matrix: MatrixColorFilter{clamp: true,
		matrix: [f32(1), 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, .65, 0]!}}
	blur := CanvasFilterStep{kind: .blur, sigma: 2.5}
	steps := [
		[contrast, blur],
		[blur, contrast],
		[contrast, CanvasFilterStep{kind: .blur, sigma: .8}, contrast],
		[contrast, CanvasFilterStep{kind: .blur}, opacity],
		[CanvasFilterStep{kind: .drop_shadow, sigma: 2.5, offset_x: 5.25,
			offset_y: -3.75, color: 0x805030e0}, contrast],
		[contrast, CanvasFilterStep{kind: .blur, sigma: .01}, opacity],
		[blur, contrast],
		[contrast, CanvasFilterStep{kind: .blur, sigma: 1.2}],
		[contrast, CanvasFilterStep{kind: .drop_shadow, sigma: 2.5, offset_x: 5.25,
			offset_y: -3.75, color: 0x805030e0}],
		[opacity, CanvasFilterStep{kind: .drop_shadow, sigma: 2.5, offset_x: 5.25,
			offset_y: -3.75, color: 0x805030e0}],
		[contrast, CanvasFilterStep{kind: .drop_shadow, offset_x: 5.25,
			offset_y: -3.75, color: 0x805030e0}, opacity],
		[opacity, CanvasFilterStep{kind: .drop_shadow, sigma: .01, offset_x: -7.25,
			offset_y: 4.5, color: 0x805030e0}, contrast],
		[opacity, CanvasFilterStep{kind: .drop_shadow, sigma: -1, offset_x: 5.25,
			offset_y: -3.75, color: 0x805030e0}],
	]
	hashes := $if linux {
		['d33ced999498998e', '4fbf747408667051', '4d8eb2b67a5444e4', 'de2bccc7da8fbd81',
		 '7ef6945c7b9398d3', 'f72a5c3abd3ce4d6', 'fe667fb7d0c8a804', 'eaee08ab4ceff5d3',
		 '6cb1cc4f7b2ba1c8', 'f0578d3f3c4cca70', '78f5b6e1d62913b4', 'aa5bfe6fe1befdcc', '1d4747ee62d26c1d']
	} $else {
		['7ec1657ab2cd72b6', '4fbf747408667051', '4d8eb2b67a5444e4', 'de2bccc7da8fbd81',
		 '7ef6945c7b9398d3', 'f72a5c3abd3ce4d6', 'fe667fb7d0c8a804', 'ef47838643df8604',
		 '5e4a0ce475763b5a', 'f98229fc7ce105d5', '78f5b6e1d62913b4', 'aa5bfe6fe1befdcc', '3cf70ee5009ca31f']
	}
	for i, filters in steps {
		mut pixels := filter_layer_test_background()
		transform := if i in [2, 7] { [f32(1.25), 0, 0, .75, 2, 4]! }
			else { [f32(1), 0, 0, 1, 0, 0]! }
		mode := match i { 2, 10 { BlendMode.multiply } 3, 4, 11 { .src_in } 5 { .plus_lighter } 6 { .overlay } else { .src_over } }
		alpha_type := if i == 7 { 1 } else { 2 }
		if i == 6 {
			assert stroke_canvas_path(mut pixels, 48, 40, 192, alpha_type, filter_layer_test_path(),
				transform, 0xc0e04010, none, .7, mode, 0, 3, .round, .round, 10, [f32(3), 2], .7,
				filter_layer_test_clip(), new_canvas_filter(filters))
		} else {
			style := if i == 2 { ?CanvasPaintStyle(filter_layer_test_color_pattern()) } else { none }
			assert fill_canvas_path(mut pixels, 48, 40, 192, alpha_type, filter_layer_test_path(),
				transform, 0xc0e04010, style, .7, mode, 0, filter_layer_test_clip(), new_canvas_filter(filters))
		}
		assert sha256.sum(pixels).hex()[..16] == hashes[i], 'mixed filter fixture ${i}'
	}
}

fn test_repeated_blurs_retain_native_intermediate_images() {
	sigmas := [[f32(.8), 2.5], [f32(0), 2.5], [f32(2.5), 0],
		[f32(12), .8], [f32(2.5), .01, .8], [f32(0), 0]]
	hashes := $if linux {
		['2889dc346af37304', '7e03b4439a49e901', '748ca7b57f80635f',
		 '60d1b6760d6fb439', '2d6eec02b544f6ed', '115c6c84bcab9406']
	} $else {
		['65eb7d8f1b75d1cd', '7e03b4439a49e901', '748ca7b57f80635f',
		 'f2193c7ef46611fb', '2d6eec02b544f6ed', '115c6c84bcab9406']
	}
	for i, sequence in sigmas {
		mut pixels := filter_layer_test_background()
		transform := if i == 3 { [f32(1.25), 0, 0, .75, 2, 4]! }
			else { [f32(1), 0, 0, 1, 0, 0]! }
		mode := match i { 1 { BlendMode.multiply } 2, 5 { .src_in } 4 { .plus_lighter } else { .src_over } }
		steps := sequence.map(CanvasFilterStep{kind: .blur, sigma: it})
		assert fill_canvas_path(mut pixels, 48, 40, 192, if i == 3 { 1 } else { 2 },
			filter_layer_test_path(), transform, 0xc0e04010, none, .7, mode, 0,
			filter_layer_test_clip(), new_canvas_filter(steps))
		assert sha256.sum(pixels).hex()[..16] == hashes[i], 'blur chain fixture ${i}'
	}
}

fn test_color_filters_between_blur_passes_match_native() {
	contrast := CanvasFilterStep{kind: .matrix, matrix: MatrixColorFilter{
		matrix: [f32(1.3), 0, 0, 0, -.15, 0, 1.3, 0, 0, -.15, 0, 0, 1.3, 0, -.15, 0, 0, 0, 1, 0]!}}
	opacity := CanvasFilterStep{kind: .matrix, matrix: MatrixColorFilter{clamp: true,
		matrix: [f32(1), 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, .65, 0]!}}
	zero := CanvasFilterStep{kind: .blur}
	tiny := CanvasFilterStep{kind: .blur, sigma: .01}
	gaussian := CanvasFilterStep{kind: .blur, sigma: .8}
	box := CanvasFilterStep{kind: .blur, sigma: 2.5}
	large := CanvasFilterStep{kind: .blur, sigma: 12}
	sequences := [
		[contrast, gaussian, opacity, box, contrast],
		[zero, contrast, box],
		[box, contrast, zero, opacity],
		[contrast, zero, opacity, tiny, contrast],
		[large, contrast, gaussian],
		[contrast, gaussian, opacity, box, contrast, gaussian],
		[gaussian, opacity, zero, contrast, box],
		[contrast, box, opacity, large, contrast],
	]
	hashes := $if linux {
		['7607d02c17545ce9', 'e6fc7d183d6f508a', '853d995ca42ed6ae', 'd44f4631ee09188a',
		 'bc75c784f5dc7c47', '2e2efd552912f6ff', '9094cff4114223f5', 'de48da03ed37df5c']
	} $else {
		['7607d02c17545ce9', 'e6fc7d183d6f508a', '853d995ca42ed6ae', 'd44f4631ee09188a',
		 'db5ae4482ca62300', '2e2efd552912f6ff', '9094cff4114223f5', 'de48da03ed37df5c']
	}
	for i, steps in sequences {
		mut pixels := filter_layer_test_background()
		transform := if i in [4, 7] { [f32(1.25), 0, 0, .75, 2, 4]! }
			else { [f32(1), 0, 0, 1, 0, 0]! }
		mode := match i { 1 { BlendMode.multiply } 2, 6 { .src_in } 3 { .plus_lighter }
			5 { .overlay } 7 { .plus_darker } else { .src_over } }
		style := if i == 4 { ?CanvasPaintStyle(filter_layer_test_color_pattern()) } else { none }
		filter := new_canvas_filter(steps)
		if i == 5 {
			assert stroke_canvas_path(mut pixels, 48, 40, 192, 2, filter_layer_test_path(),
				transform, 0xc0e04010, style, .7, mode, 0, 3, .round, .round, 10,
				[f32(3), 2], .7, filter_layer_test_clip(), filter)
		} else {
			assert fill_canvas_path(mut pixels, 48, 40, 192, if i in [4, 7] { 1 } else { 2 },
				filter_layer_test_path(), transform, 0xc0e04010, style, .7, mode, 0,
				filter_layer_test_clip(), filter)
		}
		assert sha256.sum(pixels).hex()[..16] == hashes[i], 'color blur chain fixture ${i}'
	}
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
		[f32(0.9), 0.4, -0.4, 0.9, 0, 0]!, 0xff000000, none, 1, .src_over, 0, [], new_canvas_filter([step]))
	assert px == before
	assert !fill_canvas_path(mut px, 48, 40, 192, 1, filter_layer_test_path(),
		[f32(1), 0, 0, 1, 0, 0]!, 0xff000000, none, 1, .src_over, 0, [], new_canvas_filter([
			step,
			step,
		]))
	assert px == before
}

fn test_filter_restore_composites_fill_outside_the_image() {
	modes := [BlendMode.src, .src_in, .dst_in, .src_out, .dst_atop, .plus_darker, .plus_lighter]
	// Native captures on both macOS and Linux, using the existing path,
	// background and AA clip. Each row is blur, then drop-shadow.
	hashes := ['13bb3b584aee40e2', '748ca7b57f80635f', '4f0ee529c81e4fd3', '45a5a637b91461d2',
		'0c46b8e6b9a52d2d', 'ca3d395770f5b586', 'c88197ff69a30d4e',
		'170e032dd570db45', '6d8fdab2a4ac85e6', 'c7ad9747a1106525', '6a55f13257d139e2',
		'393c80694ec2d278', '48fd6085c641f383', '94e6409b2bc10137']
	for row in 0 .. 2 {
		filter := new_canvas_filter([CanvasFilterStep{
			kind: if row == 0 { CanvasFilterKind.blur } else { .drop_shadow }
			sigma: 2.5
			offset_x: 5.25
			offset_y: -3.75
			color: 0x805030e0
		}])
		for i, mode in modes {
			mut pixels := filter_layer_test_background()
			assert fill_canvas_path(mut pixels, 48, 40, 192, 2, filter_layer_test_path(),
				[f32(1), 0, 0, 1, 0, 0]!, 0xc0e04010, none, .7, mode, 0,
				filter_layer_test_clip(), filter)
			assert sha256.sum(pixels).hex()[..16] == hashes[row * modes.len + i]
		}
	}
}

fn test_empty_filter_input_restores_only_after_the_draw_quick_reject() {
	mut pixels := []u8{cap: 8 * 8 * 4}
	for _ in 0 .. 64 { pixels << [u8(40), 80, 120, 160] }
	before := pixels.clone()
	filter := blur_filter(.0014)
	identity := [f32(1), 0, 0, 1, 0, 0]!
	// Within the quick-reject margin, but no layer input intersects the
	// viewport: the null-source restore still clears the clip.
	assert fill_canvas_path(mut pixels, 8, 8, 32, 2, rect_path(Rect{3, 8.25, 6, 8.75}),
		identity, 0xff000000, none, 1, .src, 0, [], filter)
	assert pixels.all(it == 0)
	// Further away, quick reject avoids creating/restoring any layer.
	pixels = before.clone()
	assert fill_canvas_path(mut pixels, 8, 8, 32, 2, rect_path(Rect{3, 10.25, 6, 10.75}),
		identity, 0xff000000, none, 1, .src, 0, [], filter)
	assert pixels == before
}

fn test_drop_shadow_fast_bounds_ignore_empty_original_bounds() {
	mut pixels := []u8{cap: 36 * 10 * 4}
	for _ in 0 .. 360 { pixels << [u8(40), 80, 120, 160] }
	before := pixels.clone()
	mut path := PathBuilder{}
	path.move_to(20.652514, 2.3456857)
	path.close()
	filter := new_canvas_filter([CanvasFilterStep{
		kind: .drop_shadow
		sigma: .573897
		offset_x: 7.4242115
		offset_y: -12
		color: 0xfff56b7f
	}])
	// The shadow's fast bounds are outside the clip. Joining the empty
	// source point would incorrectly prevent quick reject and clear it.
	assert fill_canvas_path(mut pixels, 36, 10, 144, 2, path.detach(),
		[f32(1), 0, 0, 1, -8, 5]!, 0xff000000, none, 1, .src_out, 0, [], filter)
	assert pixels == before
}
