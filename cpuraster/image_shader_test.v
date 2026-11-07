module cpuraster

import crypto.sha256

// The gradient tests' premultiplied background and rect.
fn pattern_test_background() []u8 {
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

fn pattern_test_rect() Path {
	mut b := PathBuilder{}
	b.move_to(1.5, 2.25)
	b.line_to(46, 2.25)
	b.line_to(46, 37.5)
	b.line_to(1.5, 37.5)
	b.close()
	return b.detach()
}

// A pattern image with opaque, transparent and partial pixels, rows padded
// by one pixel.
fn pattern_test_image(width int, height int, premultiplied bool) []u8 {
	pitch := width * 4 + 4
	mut px := []u8{len: pitch * height}
	for y in 0 .. height {
		for x in 0 .. width {
			o := y * pitch + x * 4
			mut a := (x * 37 + y * 91) % 256
			if (x + 2 * y) % 5 == 0 {
				a = 255
			}
			if (x * 3 + y) % 7 == 3 {
				a = 0
			}
			c := [(x * 53 + y * 17) % 256, (x * 11 + y * 67) % 256, (x * 29 + y * 41 + 100) % 256]
			for i in 0 .. 3 {
				px[o + i] = u8(if premultiplied { c[i] * a / 255 } else { c[i] })
			}
			px[o + 3] = u8(a)
		}
	}
	return px
}

struct PatternTestCase {
	width         int
	height        int
	premultiplied bool
	display_p3    bool
	repetition    int
	transform     [6]f32
	// The canvas transform; all zeros is the identity.
	ctm        [6]f32
	alpha      f32       = 1
	mode       BlendMode = .src_over
	stroke     bool
	line_width f32
	clip       bool
}

fn pattern_test_hash(c PatternTestCase) string {
	pattern := CanvasPattern{
		pixels:        pattern_test_image(c.width, c.height, c.premultiplied)
		width:         c.width
		height:        c.height
		pitch:         c.width * 4 + 4
		premultiplied: c.premultiplied
		display_p3:    c.display_p3
		repetition:    c.repetition
		transform:     c.transform
	}
	ctm := if c.ctm == [6]f32{} { [f32(1), 0, 0, 1, 0, 0]! } else { c.ctm }
	mut px := pattern_test_background()
	mut clips := []Path{}
	if c.clip {
		mut b := PathBuilder{}
		b.move_to(2, 3)
		b.line_to(45.5, 10.25)
		b.line_to(20.5, 38)
		b.close()
		clips << b.detach()
	}
	if c.stroke {
		mut b := PathBuilder{}
		b.move_to(4, 30)
		b.quad_to(20, -6, 44, 26)
		assert stroke_canvas_path(mut px, 48, 40, 192, 2, b.detach(), ctm, 0, pattern, c.alpha,
			c.mode, 0, c.line_width, .round, .round, 10, [], 0, clips)
	} else {
		assert fill_canvas_path(mut px, 48, 40, 192, 2, pattern_test_rect(), ctm, 0, pattern,
			c.alpha, c.mode, 0, clips)
	}
	return sha256.sum(px).hex()[..16]
}

// A fractional scale and translation, which keeps bilinear sampling.
fn pattern_test_scale() [6]f32 {
	return [f32(1.7), 0, 0, 1.3, 0.4, 0.6]!
}

// Hashes of vox_skia_canvas_path()'s output with LibWeb Skia for the same
// patterns and background (test_cpu_raster.sh compares random ones).
fn test_legacy_pattern_contexts_match_skia() {
	// Premultiplied, repeated and source-over: SkBitmapProcState. Bilinear
	// filter_scale, the translate-only shader proc, the translate matrix
	// proc under global alpha, filter_affine and the one-pixel shader proc.
	assert pattern_test_hash(PatternTestCase{
		width:         5
		height:        3
		premultiplied: true
		transform:     pattern_test_scale()
	}) == '6bb0bc7d52895eef'
	assert pattern_test_hash(PatternTestCase{
		width:         5
		height:        3
		premultiplied: true
		transform:     [f32(1), 0, 0, 1, 3, -2]!
	}) == '1227ca0598e190be'
	assert pattern_test_hash(PatternTestCase{
		width:         5
		height:        3
		premultiplied: true
		transform:     [f32(1), 0, 0, 1, 3, -2]!
		alpha:         0.6
	}) == 'bf0294f026fc86d2'
	assert pattern_test_hash(PatternTestCase{
		width:         5
		height:        3
		premultiplied: true
		transform:     [f32(0.9), 0.4, -0.4, 0.9, 2, 1]!
	}) == '75ee606bebbb9856'
	assert pattern_test_hash(PatternTestCase{
		width:         1
		height:        1
		premultiplied: true
		transform:     [f32(2.5), 0, 0, 2.5, 0.3, 0]!
	}) == 'e2b375521cc1d35b'
	// A partial-coverage hairline (blit_row_s32a_blend) and an
	// anti-aliased clip.
	assert pattern_test_hash(PatternTestCase{
		width:         5
		height:        3
		premultiplied: true
		transform:     pattern_test_scale()
		stroke:        true
		line_width:    0.5
	}) == 'bacdf0a331c9f7ed'
	assert pattern_test_hash(PatternTestCase{
		width:         5
		height:        3
		premultiplied: true
		transform:     pattern_test_scale()
		clip:          true
	}) == 'b2f01d83fe2a4440'
}

fn test_pipeline_patterns_match_skia() {
	// Unpremultiplied: the highp bilinear sampler, then premul.
	assert pattern_test_hash(PatternTestCase{
		width:     5
		height:    3
		transform: pattern_test_scale()
	}) == '5163c3a3cfcc014d'
	// no-repeat at an integer offset: lowp nearest decal sampling.
	assert pattern_test_hash(PatternTestCase{
		width:         5
		height:        3
		premultiplied: true
		repetition:    3
		transform:     [f32(1), 0, 0, 1, 6, 4]!
	}) == '4e992dc0d650bf82'
	// Unequal tile modes under multiply.
	assert pattern_test_hash(PatternTestCase{
		width:         5
		height:        3
		premultiplied: true
		repetition:    1
		transform:     [f32(1.2), 0, 0, 1.2, 0, 0]!
		mode:          .multiply
	}) == '1fcd82f3cab5ab85'
	// Display P3 to sRGB after nearest repeat sampling.
	assert pattern_test_hash(PatternTestCase{
		width:      5
		height:     3
		display_p3: true
		transform:  [f32(1), 0, 0, 1, 2, 1]!
	}) == 'd06cc429d83a94d1'
	// A one-pixel image clamps both axes: bilerp_clamp_8888 in lowp, then
	// forced into highp by bounds outside the 16-bit image range.
	assert pattern_test_hash(PatternTestCase{
		width:     1
		height:    1
		transform: [f32(3), 0, 0, 3, 0.5, 0.5]!
	}) == 'a3daeb0417f2e47d'
	assert pattern_test_hash(PatternTestCase{
		width:     1
		height:    1
		transform: [f32(0.0001), 0, 0, 0.0001, 0, 0]!
		alpha:     0.8
	}) == 'd57c8f2f855bebab'
	// A wide repeat-y stroke under a skewed canvas transform and screen.
	assert pattern_test_hash(PatternTestCase{
		width:      5
		height:     3
		repetition: 2
		transform:  pattern_test_scale()
		ctm:        [f32(0.95), 0.1, -0.1, 0.95, 1, 2]!
		alpha:      0.9
		mode:       .screen
		stroke:     true
		line_width: 5
	}) == 'a749f56deb311819'
}

// apply_style() fails the draw for an image SkBitmap cannot install.
fn test_uninstallable_patterns_decline() {
	mut px := pattern_test_background()
	before := px.clone()
	assert !fill_canvas_path(mut px, 48, 40, 192, 2, pattern_test_rect(), [f32(1), 0, 0, 1, 0,
		0]!,
		0, CanvasPattern{
			width:  2
			height: 2
			pitch:  4
			pixels: []u8{len: 16}
		}, 1, .src_over, 0, [])
	assert px == before
}
