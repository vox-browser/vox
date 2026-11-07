module cpuraster

import crypto.sha256

// A premultiplied background with transparent and opaque pixels for the
// gradient tests to draw over.
fn gradient_test_background(width int, height int) []u8 {
	mut px := []u8{len: width * height * 4}
	for y in 0 .. height {
		for x in 0 .. width {
			o := (y * width + x) * 4
			a := if (x * 3 + y) % 11 == 0 { 0 } else { (x * 9 + y * 4) % 256 }
			px[o + 3] = u8(a)
			px[o] = u8(a * y / height)
			px[o + 1] = u8(a / 2)
			px[o + 2] = u8(a * x / width)
		}
	}
	return px
}

fn gradient_test_rect() Path {
	mut b := PathBuilder{}
	b.move_to(1.5, 2.25)
	b.line_to(46, 2.25)
	b.line_to(46, 37.5)
	b.line_to(1.5, 37.5)
	b.close()
	return b.detach()
}

// Three stops, one transparent and unevenly placed, plus an opaque pair.
const gradient_test_stops = [f32(0.1), 1, 0.2, 0.4, 1, 0.55, 0.3, 0.9, 0.1, 0, 0.8, 0.1, 0.5, 0.9,
	0.6]

const gradient_test_opaque_stops = [f32(0), 0.9, 0.3, 0.1, 1, 1, 0.1, 0.4, 0.95, 1]

const gradient_test_identity = [f32(1), 0, 0, 1, 0, 0]!

fn gradient_fill_hash(g CanvasGradient, transform [6]f32, alpha f32, mode BlendMode) string {
	mut px := gradient_test_background(48, 40)
	assert fill_canvas_path(mut px, 48, 40, 192, 2, gradient_test_rect(), transform, 0, g, alpha,
		mode, 0, [])
	return sha256.sum(px).hex()[..16]
}

fn gradient_stroke_hash(g CanvasGradient, line_width f32, alpha f32, mode BlendMode) string {
	mut b := PathBuilder{}
	b.move_to(4, 30)
	b.quad_to(20, -6, 44, 26)
	mut px := gradient_test_background(48, 40)
	assert stroke_canvas_path(mut px, 48, 40, 192, 2, b.detach(), gradient_test_identity, 0, g,
		alpha, mode, 0, line_width, .round, .round, 10, [], 0, [])
	return sha256.sum(px).hex()[..16]
}

fn test_gradient_stops_follow_skia() {
	// Implicit end stops, then uniform positions become evenly spaced.
	colors := [[f32(1), 0, 0, 1]!, [f32(0), 1, 0, 1]!, [f32(0), 0, 1, 1]!]
	even, even_positions := gradient_stops(colors, [f32(0), 0.5, 1])
	assert even.len == 3 && even_positions.len == 0
	// A hard stop keeps both stops of the duplicate run.
	hard, hard_positions := gradient_stops(colors, [f32(0.25), 0.5, 0.5])
	assert hard_positions == [f32(0), 0.25, 0.5, 0.5, 1]
	assert hard.len == 5 && hard[0] == colors[0] && hard[4] == colors[2]
	// Evenly spaced stops index their gap by trunc(t * (count - 1)).
	fill := gradient_fill(even, even_positions)
	assert fill.kind == .evenly && fill.index(0.6) == 1 && fill.index(1) == 2
}

// Hashes of vox_skia_canvas_path()'s output with LibWeb Skia for the same
// gradients and background (test_cpu_raster.sh compares random ones).
fn test_linear_and_conic_gradients_match_skia() {
	linear := CanvasGradient{
		kind:  1
		x0:    4
		y0:    6
		x1:    40
		y1:    30
		stops: gradient_test_stops
	}
	assert gradient_fill_hash(linear, gradient_test_identity, 1, .src_over) == '6aa6e6ef1a127891'
	// Two opaque stops at 0 and 1 under a rotation: the two-stop stage, and
	// source-over drawn as Src.
	assert gradient_fill_hash(CanvasGradient{ ...linear, stops: gradient_test_opaque_stops },
		[f32(0.9), 0.3, -0.3, 0.9, 6, -4]!, 1, .src_over) == '672a21cef990ac82'
	conic := CanvasGradient{
		kind:  3
		x0:    22
		y0:    18
		angle: 0.7
		stops: gradient_test_stops
	}
	assert gradient_fill_hash(conic, gradient_test_identity, 0.8, .src_over) == '05723ebe132e976a'
	// Equal points: the degenerate gradient's last color.
	assert gradient_fill_hash(CanvasGradient{ ...linear, x1: 4, y1: 6 }, gradient_test_identity,
		1, .src_over) == 'eb17c98b2cdfad4d'
}

fn test_radial_gradients_match_skia() {
	radial := CanvasGradient{
		kind:  2
		x0:    20
		y0:    18
		x1:    20
		y1:    18
		r1:    22
		stops: gradient_test_stops
	}
	assert gradient_fill_hash(radial, gradient_test_identity, 1, .src_over) == '940205b8c5cbcb62'
	// Concentric circles with a start radius.
	assert gradient_fill_hash(CanvasGradient{ ...radial, r0: 6 }, gradient_test_identity, 1,
		.src_over) == 'ed5a2c2bf9441c36'
	// Equal radii apart: the strip stage.
	assert gradient_fill_hash(CanvasGradient{ ...radial, x0: 10, r0: 9, r1: 9 }, gradient_test_identity,
		1, .src_over) == 'df2440d8a20676c5'
	// Focal gradients: well behaved, the end circle smaller, swapped (a zero
	// end radius) and the focal point on the end circle.
	assert gradient_fill_hash(CanvasGradient{ ...radial, x0: 14, y0: 14, r0: 2 }, gradient_test_identity,
		1, .src_over) == '561efbed8d922733'
	assert gradient_fill_hash(CanvasGradient{ ...radial, x0: 2, y0: 30, r0: 4, r1: 10 },
		gradient_test_identity, 1, .src_over) == 'd9f97573284eeffb'
	assert gradient_fill_hash(CanvasGradient{ ...radial, x0: 30, r0: 12, r1: 0 }, gradient_test_identity,
		1, .src_over) == '554dd657f9df3b23'
	assert gradient_fill_hash(CanvasGradient{ ...radial, x0: 42, r0: 0 }, gradient_test_identity,
		1, .src_over) == '4e33d3c2ad3f65f2'
}

fn test_gradient_blends_and_strokes_match_skia() {
	linear := CanvasGradient{
		kind:  1
		x0:    4
		y0:    6
		x1:    40
		y1:    30
		stops: gradient_test_stops
	}
	// lowp multiply and highp color-dodge.
	assert gradient_fill_hash(linear, gradient_test_identity, 0.7, .multiply) == '59d3ebc98406a3e0'
	assert gradient_fill_hash(linear, gradient_test_identity, 1, .color_dodge) == '6b5d4ccefc9c00c7'
	// A focal gradient forces highp for source-over too.
	focal := CanvasGradient{
		kind:  2
		x0:    14
		y0:    14
		r0:    2
		x1:    20
		y1:    18
		r1:    22
		stops: gradient_test_stops
	}
	assert gradient_fill_hash(focal, gradient_test_identity, 0.6, .src_atop) == '4d09454332d2633c'
	// A partial-coverage hairline and a wide stroke.
	assert gradient_stroke_hash(linear, 0.5, 1, .src_over) == '6c959fa940ccf6fd'
	assert gradient_stroke_hash(focal, 5, 0.9, .screen) == '6626037d1e8a110b'
	// No stops: the shader is null and Skia paints the default black color.
	assert gradient_fill_hash(CanvasGradient{ ...linear, stops: [] }, gradient_test_identity, 0.5,
		.src_in) == '1547562089ca3340'
}
