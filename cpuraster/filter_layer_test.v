module cpuraster

import crypto.sha256
import json2
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
}

fn test_rejected_drop_shadow_branch_matches_native_layers() {
	step := CanvasFilterStep{kind: .drop_shadow, sigma: 2, offset_x: 3.5,
		offset_y: -1.25, color: 0x80000000}
	hashes := ['d15d6f0deb8e3adc', '92397e22e3517d7e']
	for i, alpha_type in [1, 2] {
		mut pixels := filter_layer_test_background()
		assert fill_canvas_path(mut pixels, 48, 40, 192, alpha_type, filter_layer_test_path(),
			[f32(1), 0, 0, 1, 0, 0]!, 0xff000000, none, 1, .src_over, 0, [],
			new_canvas_filter([step, CanvasFilterStep{...step, sigma: -1}]))
		assert sha256.sum(pixels).hex()[..16] == hashes[i]
	}
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

// Native fixtures captured by native_mixed_filter_hashes.py. A shadow forks
// the preceding graph; its foreground and blur request different bounds.
fn test_mixed_spatial_filter_chains_match_native() {
 contrast := CanvasFilterStep{kind: .matrix, matrix: MatrixColorFilter{
  matrix: [f32(1.3), 0, 0, 0, -.15, 0, 1.3, 0, 0, -.15, 0, 0, 1.3, 0, -.15, 0, 0, 0, 1, 0]!}}
 opacity := CanvasFilterStep{kind: .matrix, matrix: MatrixColorFilter{clamp: true,
  matrix: [f32(1), 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, .65, 0]!}}
 shadow := CanvasFilterStep{kind: .drop_shadow, sigma: 2.5, offset_x: 5.25,
  offset_y: -3.75, color: 0x805030e0}
 shadow2 := CanvasFilterStep{kind: .drop_shadow, sigma: .8, offset_x: -7.25,
  offset_y: 4.5, color: 0xc0ff6040}
 shadow3 := CanvasFilterStep{kind: .drop_shadow, sigma: .01, color: 0x80000000}
 identity := CanvasFilterStep{...shadow, sigma: 0}
 gaussian := CanvasFilterStep{kind: .blur, sigma: .8}
 blur := CanvasFilterStep{kind: .blur, sigma: 2.5}
 tiny := CanvasFilterStep{kind: .blur, sigma: .01}
 steps := [
  [gaussian, shadow], [shadow, blur], [shadow, shadow], [shadow, shadow2, shadow3],
  [contrast, gaussian, shadow, opacity], [shadow, contrast, blur, opacity],
  [contrast, identity, opacity, tiny, shadow],
  [shadow, contrast, gaussian, opacity, shadow2], [blur, shadow],
  [shadow, gaussian, shadow2], [opacity, identity, contrast, identity],
  [gaussian, shadow], [gaussian, shadow], [gaussian, shadow], [gaussian, shadow],
  [gaussian, shadow], [gaussian, shadow], [gaussian, shadow],
 ]
 hashes := $if linux { ['85ded641bc1c40b8', 'ec15a885c51f0d6b', '9d2ac3778a55b8b4', 'a64b950cb4d0a36d', '97c5d861829696bd', '14d76c98d987d016', '0c1f73de745d740c', '40ba2d1c527ff712', '5bd229939f881f9e', '1f0a2c78c8e886b1', '93e68261d8d229b5', '94c142ea8bddbd93', 'db5c83122c79221e', 'cda50e26e2123dda', '6dd757e2dc19830b', 'f314c3b09b8271eb', '2c7e8f53b7715761', 'f96cd103d1fd3b1b'] } $else { ['adebac55b9b00c3e', 'bb249b0417fd19d0', '08ac9e68c0cc079e', 'a4b05ca5ecaffedc', '97c5d861829696bd', '14d76c98d987d016', '3f7c1039156f9d86', '40ba2d1c527ff712', '5bd229939f881f9e', '08e9e2e170ce3ec7', 'e0c801a90a68a272', '94c142ea8bddbd93', 'db5c83122c79221e', 'cda50e26e2123dda', '6dd757e2dc19830b', 'f314c3b09b8271eb', '2c7e8f53b7715761', 'f96cd103d1fd3b1b'] }
 clearing := [BlendMode.src, .src_in, .dst_in, .src_out, .dst_atop, .plus_darker, .plus_lighter]
 for i, filters in steps {
  mut pixels := filter_layer_test_background()
  transform := if i in [7, 8] { [f32(1.25), 0, 0, .75, 2, 4]! }
   else { [f32(1), 0, 0, 1, 0, 0]! }
  mode := if i >= 11 { clearing[i - 11] } else if i == 7 { BlendMode.overlay }
   else if i == 8 { BlendMode.multiply } else { BlendMode.src_over }
  alpha_type := if i in [7, 9] { 1 } else { 2 }
  if i == 7 {
   assert stroke_canvas_path(mut pixels, 48, 40, 192, alpha_type, filter_layer_test_path(),
    transform, 0xc0e04010, none, .7, mode, 0, 3, .round, .round, 10, [f32(3), 2], .7,
    filter_layer_test_clip(), new_canvas_filter(filters))
  } else {
   style := if i == 8 { ?CanvasPaintStyle(filter_layer_test_color_pattern()) } else { none }
   assert fill_canvas_path(mut pixels, 48, 40, 192, alpha_type, filter_layer_test_path(),
    transform, 0xc0e04010, style, .7, mode, 0, filter_layer_test_clip(), new_canvas_filter(filters))
  }
  assert sha256.sum(pixels).hex()[..16] == hashes[i], 'spatial chain fixture ${i}'
 }
}

struct SpatialChainClipFixture {
 segments []f32
 even_odd bool
}

struct SpatialChainStepFixture {
 kind int
 matrix [20]f32
 clamp bool
 sigma f32
 offset_x f32
 offset_y f32
 color u32
}

struct SpatialChainFixture {
 width int
 height int
 alpha_type int
 segments []f32
 even_odd bool
 transform [6]f32
 color u32
 global_alpha f32
 clips []SpatialChainClipFixture
 composite int
 filters []SpatialChainStepFixture
}

fn test_spatial_chain_branch_requests_and_source_leaf_bounds() {
 inputs := [
  $embed_file('@VMODROOT/cpuraster/testdata/spatial-branch.json').to_string(),
  $embed_file('@VMODROOT/cpuraster/testdata/spatial-leaf-bounds.json').to_string(),
 ]
 hashes := ['79d4e37074d97045', '18911ffab2702601', '5fd9c806c2246dd6']
 for i, input in inputs {
  c := json2.decode[SpatialChainFixture](input) or { panic(err) }
  steps := c.filters.map(CanvasFilterStep{
   kind: match it.kind { 0 { CanvasFilterKind.blur } 1 { .drop_shadow } else { .matrix } }
   matrix: MatrixColorFilter{it.matrix, it.clamp}
   sigma: it.sigma, offset_x: it.offset_x, offset_y: it.offset_y, color: it.color
  })
  clips := c.clips.map(canvas_path(it.segments, it.even_odd))
  counts := if i == 0 { [steps.len] } else { [5, steps.len] }
  for j, count in counts {
   mut pixels := if i == 0 {
    $embed_file('@VMODROOT/cpuraster/testdata/spatial-branch-background.rgba').to_bytes()
   } else { []u8{len: c.width * c.height * 4} }
   assert fill_canvas_path(mut pixels, c.width, c.height, c.width * 4, c.alpha_type,
    canvas_path(c.segments, c.even_odd), c.transform, c.color, none, c.global_alpha,
    if c.composite == 7 { BlendMode.dst_atop } else { .src_over }, 0, clips,
    new_canvas_filter(steps[..count]))
   assert sha256.sum(pixels).hex()[..16] == hashes[if i == 0 { 0 } else { j + 1 }]
  }
 }
}

fn test_spatial_chain_work_limit_preserves_unpremultiplied_destination() {
 step := CanvasFilterStep{kind: .drop_shadow, sigma: .8, offset_x: 5.25,
  offset_y: -3.75, color: 0x805030e0}
 steps := []CanvasFilterStep{len: 8, init: step}
 mut pixels := filter_layer_test_background()
 before := pixels.clone()
 assert !fill_canvas_path(mut pixels, 48, 40, 192, 1, filter_layer_test_path(),
  [f32(1), 0, 0, 1, 0, 0]!, 0xc0e04010, none, .7, .src_over, 0,
  filter_layer_test_clip(), new_canvas_filter(steps))
 assert pixels == before
}

// Frozen inputs for native chains; color matrices on either side of identity
// blurs must stay pending until the next real sampling pass.
fn terminal_blur_chain_test_filters(index int) []CanvasFilterStep {
	base := if index >= 24 { index - 24 } else { index }
	contrast := CanvasFilterStep{kind: .matrix, matrix: MatrixColorFilter{
		matrix: [f32(1.3), 0, 0, 0, -.15, 0, 1.3, 0, 0, -.15, 0, 0, 1.3, 0, -.15, 0, 0, 0, 1, 0]!}}
	opacity := CanvasFilterStep{kind: .matrix, matrix: MatrixColorFilter{clamp: true,
		matrix: [f32(1), 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, .65, 0]!}}
	sequences := [[f32(.8), 135.01], [f32(2.5), 135.2], [f32(0), .01, 300],
		[f32(12), 0, 532], [f32(.8), 2.5, 270], [f32(0), 0, 700],
		[f32(6), .01, 200], [f32(12), .8, 135.2]]
	mut steps := []CanvasFilterStep{}
	for j, sigma in sequences[base % 8] {
		if (base + j) % 3 == 0 { steps << contrast }
		if (base + j) % 4 == 1 { steps << opacity }
		steps << CanvasFilterStep{kind: .blur, sigma: sigma}
	}
	steps << if base % 2 == 0 { opacity } else { contrast }
	if index >= 24 {
		matrices := steps.filter(it.kind == .matrix)
		steps = [CanvasFilterStep{kind: .blur, sigma: .8}]
		steps << matrices[..matrices.len - 1]
		steps << CanvasFilterStep{kind: .blur, sigma: [f32(135.2), 200, 270, 300][index - 24]}
		steps << matrices.last()
	}
	return steps
}

fn test_large_terminal_blur_chains_match_native() {
	macos := [
		'f00be8e39ec6bc7f43235343e37285116618eb45a806d76d7afaecea98bdb6a2',
		'c88f74bf3bd0396aca8beb6360464e01096a8fe5c383e61a0561453f191f7654',
		'f00be8e39ec6bc7f43235343e37285116618eb45a806d76d7afaecea98bdb6a2',
		'f6e28ad1753237d42be72be187a88f09a269097eeda24bcf12908db6bd361246',
		'62cea4a16ecb51ad1c809526f32a969f1255b2d003004aaf87895a6eaa4fbeb8',
		'f00be8e39ec6bc7f43235343e37285116618eb45a806d76d7afaecea98bdb6a2',
		'f00be8e39ec6bc7f43235343e37285116618eb45a806d76d7afaecea98bdb6a2',
		'c88f74bf3bd0396aca8beb6360464e01096a8fe5c383e61a0561453f191f7654',
		'f00be8e39ec6bc7f43235343e37285116618eb45a806d76d7afaecea98bdb6a2',
		'f6e28ad1753237d42be72be187a88f09a269097eeda24bcf12908db6bd361246',
		'62cea4a16ecb51ad1c809526f32a969f1255b2d003004aaf87895a6eaa4fbeb8',
		'f00be8e39ec6bc7f43235343e37285116618eb45a806d76d7afaecea98bdb6a2',
		'a136bd1493ddaa627bd62a99628c03441de5bee6482e75bb9d4b1d83f6761bfe',
		'c88f74bf3bd0396aca8beb6360464e01096a8fe5c383e61a0561453f191f7654',
		'b827517e205d6914ba40a284edef363714d54b6a0043a7dde40e57b5d1ecb495',
		'54ac08e557d084447e66d971b7a6154703dc17d628acf128ac1e40b2972983a9',
		'89eab1219d5f708c1bfbced60997b70ee082b48369b13241eaad6613e4a5cc9a',
		'd075ce7a4e5e47fdfa0ce90c1f3c23a62554f818bd066912e77679b1efcceca9',
		'888cc7e483fa30db295d60f5abe38eeaa023dbff51b752d5948748c206323fdb',
		'c88f74bf3bd0396aca8beb6360464e01096a8fe5c383e61a0561453f191f7654',
		'2d69d84d736288c7f1b1a44fa1317ee4f0a5a62d24bf79a634ebf762bf0139e7',
		'f6e28ad1753237d42be72be187a88f09a269097eeda24bcf12908db6bd361246',
		'260346c2414aaa19221eeecd3c641c9e8fe3a363c91ea9a0310440e180129468',
		'f00be8e39ec6bc7f43235343e37285116618eb45a806d76d7afaecea98bdb6a2',
		'052e579749bb28870d5a6486a363d24c54f2763468afb632393b12bbae5565f4',
		'7532dd2f320942fbdc28a25b8ec58bee3416af2ef244d4f345b913ade90e4deb',
		'f563dfbdadea8586e8fe40d06c55bdff54f07dc3fd8fd314994c1c5d39eb3c34',
		'6b24599580daacc5f4b09e3ad37810c0d12c4099f7026545d150f5ce55fa2838',
	]
	linux := [
		'f00be8e39ec6bc7f43235343e37285116618eb45a806d76d7afaecea98bdb6a2',
		'c88f74bf3bd0396aca8beb6360464e01096a8fe5c383e61a0561453f191f7654',
		'f00be8e39ec6bc7f43235343e37285116618eb45a806d76d7afaecea98bdb6a2',
		'f6e28ad1753237d42be72be187a88f09a269097eeda24bcf12908db6bd361246',
		'62cea4a16ecb51ad1c809526f32a969f1255b2d003004aaf87895a6eaa4fbeb8',
		'f00be8e39ec6bc7f43235343e37285116618eb45a806d76d7afaecea98bdb6a2',
		'f00be8e39ec6bc7f43235343e37285116618eb45a806d76d7afaecea98bdb6a2',
		'c88f74bf3bd0396aca8beb6360464e01096a8fe5c383e61a0561453f191f7654',
		'f00be8e39ec6bc7f43235343e37285116618eb45a806d76d7afaecea98bdb6a2',
		'f6e28ad1753237d42be72be187a88f09a269097eeda24bcf12908db6bd361246',
		'62cea4a16ecb51ad1c809526f32a969f1255b2d003004aaf87895a6eaa4fbeb8',
		'f00be8e39ec6bc7f43235343e37285116618eb45a806d76d7afaecea98bdb6a2',
		'a136bd1493ddaa627bd62a99628c03441de5bee6482e75bb9d4b1d83f6761bfe',
		'c88f74bf3bd0396aca8beb6360464e01096a8fe5c383e61a0561453f191f7654',
		'b827517e205d6914ba40a284edef363714d54b6a0043a7dde40e57b5d1ecb495',
		'54ac08e557d084447e66d971b7a6154703dc17d628acf128ac1e40b2972983a9',
		'89eab1219d5f708c1bfbced60997b70ee082b48369b13241eaad6613e4a5cc9a',
		'd075ce7a4e5e47fdfa0ce90c1f3c23a62554f818bd066912e77679b1efcceca9',
		'888cc7e483fa30db295d60f5abe38eeaa023dbff51b752d5948748c206323fdb',
		'c88f74bf3bd0396aca8beb6360464e01096a8fe5c383e61a0561453f191f7654',
		'2d69d84d736288c7f1b1a44fa1317ee4f0a5a62d24bf79a634ebf762bf0139e7',
		'f6e28ad1753237d42be72be187a88f09a269097eeda24bcf12908db6bd361246',
		'260346c2414aaa19221eeecd3c641c9e8fe3a363c91ea9a0310440e180129468',
		'f00be8e39ec6bc7f43235343e37285116618eb45a806d76d7afaecea98bdb6a2',
		'052e579749bb28870d5a6486a363d24c54f2763468afb632393b12bbae5565f4',
		'7532dd2f320942fbdc28a25b8ec58bee3416af2ef244d4f345b913ade90e4deb',
		'f563dfbdadea8586e8fe40d06c55bdff54f07dc3fd8fd314994c1c5d39eb3c34',
		'6b24599580daacc5f4b09e3ad37810c0d12c4099f7026545d150f5ce55fa2838',
	]
	for i in 0 .. macos.len {
		base := if i >= 24 { i - 24 } else { i }
		mut pixels := filter_layer_test_background()
		shape := if i >= 24 { rect_path(Rect{-1024, -1024, 1024, 1024}) } else {
			scale := if i >= 12 { f32(8) } else { f32(1) }
			filter_layer_test_path().transform(Matrix{a: scale, d: scale})
		}
		transform := if i >= 24 || base % 4 !in [1, 2] { [f32(1), 0, 0, 1, 0, 0]! }
			else if base % 4 == 1 { [f32(1.25), 0, 0, .75, 2, 4]! }
			else { [f32(-.75), 0, 0, 1.25, 42, 3]! }
		alpha_type := if base % 3 == 1 { 1 } else { 2 }
		mode := [BlendMode.src_over, .src_in, .multiply, .src, .plus_lighter, .plus_darker][base % 6]
		style := if base % 5 == 3 { ?CanvasPaintStyle(filter_layer_test_color_pattern()) } else { none }
		clips := if base % 3 != 0 { filter_layer_test_clip() } else { []Path{} }
		filter := new_canvas_filter(terminal_blur_chain_test_filters(i))
		if i < 24 && base % 2 != 0 {
			assert stroke_canvas_path(mut pixels, 48, 40, 192, alpha_type, shape, transform,
				0xc0e04010, style, .7, mode, 0, 3, .round, .round, 10, [f32(3), 2], .7, clips, filter)
		} else {
			assert fill_canvas_path(mut pixels, 48, 40, 192, alpha_type, shape, transform,
				0xc0e04010, style, .7, mode, 0, clips, filter)
		}
		expected := $if linux { linux[i] } $else { macos[i] }
		assert sha256.sum(pixels).hex() == expected, 'terminal blur fixture ${i}'
	}
}

fn test_unsupported_large_chain_positions_preserve_destination() {
	for sigmas in [[f32(300), .8], [f32(.8), 300, 2.5]] {
		mut pixels := filter_layer_test_background()
		original := pixels.clone()
		assert !fill_canvas_path(mut pixels, 48, 40, 192, 1, filter_layer_test_path(),
			[f32(1), 0, 0, 1, 0, 0]!, 0xc0e04010, none, .7, .src_over, 0, [],
			new_canvas_filter(sigmas.map(CanvasFilterStep{kind: .blur, sigma: it})))
		assert pixels == original
	}
	mut pixels := filter_layer_test_background()
	original := pixels.clone()
	image := CanvasBitmap{pixels: []u8{len: 24, init: 255}, width: 3, height: 2, pitch: 12, premultiplied: true}
	assert !draw_canvas_image_filtered(mut pixels, 48, 40, 192, 1, [f32(1), 0, 0, 1, 0, 0]!,
		image, [f32(0), 0, 3, 2]!, [f32(10), 8, 3, 2]!, true, 1, .src_over, [],
		new_canvas_filter([CanvasFilterStep{kind: .blur, sigma: .01}, CanvasFilterStep{kind: .blur, sigma: 300}]), false)
	assert pixels == original
}


fn identity_tail_blur_chain_test_filters(index int) []CanvasFilterStep {
	contrast := CanvasFilterStep{kind: .matrix, matrix: MatrixColorFilter{
		matrix: [f32(1.3), 0, 0, 0, -.15, 0, 1.3, 0, 0, -.15, 0, 0, 1.3, 0, -.15, 0, 0, 0, 1, 0]!}}
	opacity := CanvasFilterStep{kind: .matrix, matrix: MatrixColorFilter{clamp: true,
		matrix: [f32(1), 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, .65, 0]!}}
	tiny := CanvasFilterStep{kind: .blur, sigma: .01}
	tinier := CanvasFilterStep{kind: .blur, sigma: .001}
	mut steps := terminal_blur_chain_test_filters(index)
	steps << match index % 3 {
		0 { [contrast, tiny, opacity] }
		1 { [opacity, tinier, contrast, tiny, opacity] }
		else { [tiny, contrast, tinier] }
	}
	return steps
}

// Identity kernels preserve the large blur's deferred image and pending
// color effects, without another sampled or quantized surface.
fn test_large_blur_identity_tails_match_native() {
	macos := [
		'f00be8e39ec6bc7f43235343e37285116618eb45a806d76d7afaecea98bdb6a2',
		'c88f74bf3bd0396aca8beb6360464e01096a8fe5c383e61a0561453f191f7654',
		'f00be8e39ec6bc7f43235343e37285116618eb45a806d76d7afaecea98bdb6a2',
		'f6e28ad1753237d42be72be187a88f09a269097eeda24bcf12908db6bd361246',
		'62cea4a16ecb51ad1c809526f32a969f1255b2d003004aaf87895a6eaa4fbeb8',
		'f00be8e39ec6bc7f43235343e37285116618eb45a806d76d7afaecea98bdb6a2',
		'f00be8e39ec6bc7f43235343e37285116618eb45a806d76d7afaecea98bdb6a2',
		'c88f74bf3bd0396aca8beb6360464e01096a8fe5c383e61a0561453f191f7654',
		'f00be8e39ec6bc7f43235343e37285116618eb45a806d76d7afaecea98bdb6a2',
		'f6e28ad1753237d42be72be187a88f09a269097eeda24bcf12908db6bd361246',
		'62cea4a16ecb51ad1c809526f32a969f1255b2d003004aaf87895a6eaa4fbeb8',
		'f00be8e39ec6bc7f43235343e37285116618eb45a806d76d7afaecea98bdb6a2',
		'e40e81a4ae066320f6bbe1d762c5165667957a3addd780d7bf90bb82a6d0be3d',
		'c88f74bf3bd0396aca8beb6360464e01096a8fe5c383e61a0561453f191f7654',
		'1516aedad9b79dc403c1959f338b0076432c164cdaad1eacedbb435a4d6bd630',
		'f1c007ec3f14a3b3aa4a740b68d6a227bec68edd177aac709407bdd8dd0c4756',
		'516bcce4886a9b075dd9791b9464ced019e22ee8d1f5a84deb50885a80915ba0',
		'd075ce7a4e5e47fdfa0ce90c1f3c23a62554f818bd066912e77679b1efcceca9',
		'e0c4e542907c903a1a1d4f2589c68bdb646ac6a160ec2947bacc5f3856c5c207',
		'c88f74bf3bd0396aca8beb6360464e01096a8fe5c383e61a0561453f191f7654',
		'af095bbe6112552d43f7b6d344fe739b123d25cf1fe72a5d360a052ad5c9dcc3',
		'f6e28ad1753237d42be72be187a88f09a269097eeda24bcf12908db6bd361246',
		'0afee1cdc5de52520d0432d503c00a9675c2a3b2957c3c7a37ca0d4db9612ac9',
		'f00be8e39ec6bc7f43235343e37285116618eb45a806d76d7afaecea98bdb6a2',
		'f5fe0cdf7a65578e5c61245456d9bf6c5335d310f6c8491af0a7a7cb38a08b42',
		'c171f6d5a6987fab811b16cd54c9ed9a9b6d3c2cf3df679cf3485b42a4bae97e',
		'7fd0e4ab10200b0565c6177f4464e4a17e54d0e6dceb694e1c7eed190a87f680',
		'78de0d64470b92d98a06d08c79ce815d476fbd1e3273cf71e61b2f0aafcdd3c4',
	]
	linux := [
		'f00be8e39ec6bc7f43235343e37285116618eb45a806d76d7afaecea98bdb6a2',
		'c88f74bf3bd0396aca8beb6360464e01096a8fe5c383e61a0561453f191f7654',
		'f00be8e39ec6bc7f43235343e37285116618eb45a806d76d7afaecea98bdb6a2',
		'f6e28ad1753237d42be72be187a88f09a269097eeda24bcf12908db6bd361246',
		'62cea4a16ecb51ad1c809526f32a969f1255b2d003004aaf87895a6eaa4fbeb8',
		'f00be8e39ec6bc7f43235343e37285116618eb45a806d76d7afaecea98bdb6a2',
		'f00be8e39ec6bc7f43235343e37285116618eb45a806d76d7afaecea98bdb6a2',
		'c88f74bf3bd0396aca8beb6360464e01096a8fe5c383e61a0561453f191f7654',
		'f00be8e39ec6bc7f43235343e37285116618eb45a806d76d7afaecea98bdb6a2',
		'f6e28ad1753237d42be72be187a88f09a269097eeda24bcf12908db6bd361246',
		'62cea4a16ecb51ad1c809526f32a969f1255b2d003004aaf87895a6eaa4fbeb8',
		'f00be8e39ec6bc7f43235343e37285116618eb45a806d76d7afaecea98bdb6a2',
		'e40e81a4ae066320f6bbe1d762c5165667957a3addd780d7bf90bb82a6d0be3d',
		'c88f74bf3bd0396aca8beb6360464e01096a8fe5c383e61a0561453f191f7654',
		'1516aedad9b79dc403c1959f338b0076432c164cdaad1eacedbb435a4d6bd630',
		'f1c007ec3f14a3b3aa4a740b68d6a227bec68edd177aac709407bdd8dd0c4756',
		'516bcce4886a9b075dd9791b9464ced019e22ee8d1f5a84deb50885a80915ba0',
		'd075ce7a4e5e47fdfa0ce90c1f3c23a62554f818bd066912e77679b1efcceca9',
		'e0c4e542907c903a1a1d4f2589c68bdb646ac6a160ec2947bacc5f3856c5c207',
		'c88f74bf3bd0396aca8beb6360464e01096a8fe5c383e61a0561453f191f7654',
		'af095bbe6112552d43f7b6d344fe739b123d25cf1fe72a5d360a052ad5c9dcc3',
		'f6e28ad1753237d42be72be187a88f09a269097eeda24bcf12908db6bd361246',
		'0afee1cdc5de52520d0432d503c00a9675c2a3b2957c3c7a37ca0d4db9612ac9',
		'f00be8e39ec6bc7f43235343e37285116618eb45a806d76d7afaecea98bdb6a2',
		'f5fe0cdf7a65578e5c61245456d9bf6c5335d310f6c8491af0a7a7cb38a08b42',
		'c171f6d5a6987fab811b16cd54c9ed9a9b6d3c2cf3df679cf3485b42a4bae97e',
		'7fd0e4ab10200b0565c6177f4464e4a17e54d0e6dceb694e1c7eed190a87f680',
		'78de0d64470b92d98a06d08c79ce815d476fbd1e3273cf71e61b2f0aafcdd3c4',
	]
	for i in 0 .. macos.len {
		base := if i >= 24 { i - 24 } else { i }
		mut pixels := filter_layer_test_background()
		shape := if i >= 24 { rect_path(Rect{-1024, -1024, 1024, 1024}) } else {
			scale := if i >= 12 { f32(8) } else { f32(1) }
			filter_layer_test_path().transform(Matrix{a: scale, d: scale})
		}
		transform := if i >= 24 || base % 4 !in [1, 2] { [f32(1), 0, 0, 1, 0, 0]! }
			else if base % 4 == 1 { [f32(1.25), 0, 0, .75, 2, 4]! }
			else { [f32(-.75), 0, 0, 1.25, 42, 3]! }
		alpha_type := if base % 3 == 1 { 1 } else { 2 }
		mode := [BlendMode.src_over, .src_in, .multiply, .src, .plus_lighter, .plus_darker][base % 6]
		style := if base % 5 == 3 { ?CanvasPaintStyle(filter_layer_test_color_pattern()) } else { none }
		clips := if base % 3 != 0 { filter_layer_test_clip() } else { []Path{} }
		filter := new_canvas_filter(identity_tail_blur_chain_test_filters(i))
		if i < 24 && base % 2 != 0 {
			assert stroke_canvas_path(mut pixels, 48, 40, 192, alpha_type, shape, transform,
				0xc0e04010, style, .7, mode, 0, 3, .round, .round, 10, [f32(3), 2], .7, clips, filter)
		} else {
			assert fill_canvas_path(mut pixels, 48, 40, 192, alpha_type, shape, transform,
				0xc0e04010, style, .7, mode, 0, clips, filter)
		}
		expected := $if linux { linux[i] } $else { macos[i] }
		assert sha256.sum(pixels).hex() == expected, 'terminal blur fixture ${i}'
	}
}


fn test_nonidentity_blur_tails_preserve_destination() {
	steps := [CanvasFilterStep{kind: .blur, sigma: .8},
		CanvasFilterStep{kind: .blur, sigma: 300}, CanvasFilterStep{kind: .blur, sigma: .02}]
	image := CanvasBitmap{pixels: []u8{len: 24, init: 255}, width: 3, height: 2, pitch: 12, premultiplied: true}
	for transform in [[f32(2), 0, 0, 1, 0, 0]!, [f32(1), 0, 0, 2, 0, 0]!] {
		mut pixels := filter_layer_test_background()
		original := pixels.clone()
		assert !fill_canvas_path(mut pixels, 48, 40, 192, 1, filter_layer_test_path(),
			transform, 0xc0e04010, none, .7, .src_over, 0, [], new_canvas_filter(steps))
		assert pixels == original
		assert !draw_canvas_image_filtered(mut pixels, 48, 40, 192, 1, transform, image,
			[f32(0), 0, 3, 2]!, [f32(10), 8, 3, 2]!, true, 1, .src_over, [], new_canvas_filter(steps), false)
		assert pixels == original
	}
}
