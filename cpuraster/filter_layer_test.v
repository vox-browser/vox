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
	assert filter_layer_test_hash(px, 2) == '7263a58806bf8436'
	// A scaled stroke: the layer matrix carries the scale, and the sigma is
	// mapped into layer space per axis (the Gaussian pass).
	px = filter_layer_test_background()
	assert stroke_canvas_path(mut px, 48, 40, 192, 1, filter_layer_test_path(), [f32(1.25), 0, 0,
		0.75, 2, 4]!, 0xff3070c0, none, 1, .src_over, 0, 3, .round, .round, 10, [], 0, [], blur_filter(0.8))
	assert filter_layer_test_hash(px, 1) == '11314abdec52c202'
	// Multiply through an anti-aliased clip, which cuts the sprite: the
	// result is drawn with an image shader.
	px = filter_layer_test_background()
	assert fill_canvas_path(mut px, 48, 40, 192, 2, filter_layer_test_path(), identity, 0xff10a040,
		none, 1, .multiply, 0, filter_layer_test_clip(), blur_filter(4))
	assert filter_layer_test_hash(px, 2) == '698232341bfd269c'
	// A large translucent blur: the three-box pass.
	px = filter_layer_test_background()
	assert fill_canvas_path(mut px, 48, 40, 192, 2, filter_layer_test_path(), identity, 0x80ff8000,
		none, 0.7, .src_over, 0, [], blur_filter(12))
	assert filter_layer_test_hash(px, 2) == '9715f8489f927c77'
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
		assert filter_layer_test_hash(px, 2) == '5dc0e6b8a4ddf089'
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
	assert !fill_canvas_path(mut px, 48, 40, 192, 2, filter_layer_test_path(), [f32(1), 0, 0, 1,
		0, 0]!, 0xff000000, none, 1, .src_in, 0, [], blur_filter(2))
	assert !fill_canvas_path(mut px, 48, 40, 192, 2, filter_layer_test_path(), [f32(0.9), 0.4, -0.4,
		0.9, 0, 0]!, 0xff000000, none, 1, .src_over, 0, [], blur_filter(2))
	assert px == before
}
