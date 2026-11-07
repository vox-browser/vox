module cpuraster

import crypto.sha256

// The premultiplied gradient scan_hairline_test.v strokes over.
fn stroke_test_background(width int, height int) []u8 {
	mut px := []u8{len: width * height * 4}
	for y in 0 .. height {
		for x in 0 .. width {
			o := (y * width + x) * 4
			a := u8((x * 7 + y * 3) % 256)
			px[o + 3] = a
			px[o] = u8(int(a) * x / width)
			px[o + 1] = u8(int(a) * y / height)
			px[o + 2] = a / 2
		}
	}
	return px
}

fn stroke_test_segment(kind int, values []f32) []f32 {
	mut segment := [f32(kind)]
	segment << values
	for segment.len < 12 {
		segment << 0
	}
	return segment
}

fn wide_stroke_hash(segments []f32, width int, height int, transform [6]f32, color u32, global_alpha f32, line_width f32, cap StrokeCap, join StrokeJoin, miter f32) string {
	return dashed_stroke_hash(segments, width, height, transform, color, global_alpha, line_width,
		cap, join, miter, [], 0)
}

fn dashed_stroke_hash(segments []f32, width int, height int, transform [6]f32, color u32, global_alpha f32, line_width f32, cap StrokeCap, join StrokeJoin, miter f32, dashes []f32, dash_offset f32) string {
	mut pixels := stroke_test_background(width, height)
	assert stroke_canvas_path(mut pixels, width, height, width * 4, 2, canvas_path(segments,
		false), transform, color, none, global_alpha, .src_over, 0, line_width, cap, join, miter, dashes, dash_offset, [])
	assert pixels != stroke_test_background(width, height)
	return sha256.sum(pixels).hex()[..16]
}

// Hashes of vox_skia_canvas_path()'s output with LibWeb Skia for the same
// strokes and backgrounds (test_cpu_raster.sh compares random strokes).
fn test_wide_polyline_with_square_caps_and_beveled_miters() {
	mut s := []f32{}
	s << stroke_test_segment(0, [f32(6), 8.5])
	s << stroke_test_segment(1, [f32(52), 10])
	s << stroke_test_segment(1, [f32(30), 42.25])
	s << stroke_test_segment(1, [f32(58), 40])
	// A zero-length contour, which square caps draw as a square.
	s << stroke_test_segment(0, [f32(10), 30])
	s << stroke_test_segment(1, [f32(10), 30])
	assert wide_stroke_hash(s, 64, 48, [f32(1), 0, 0, 1, 0, 0]!, 0xff2a60d0, 1, 6, .square,
		.miter, 4) == '0dd8702f735886e1'
}

fn test_wide_curves_with_round_caps_and_joins_under_a_transform() {
	mut s := []f32{}
	s << stroke_test_segment(0, [f32(8), 40])
	s << stroke_test_segment(2, [f32(60), 44, 30, 2])
	s << stroke_test_segment(3, [f32(70), 50, 10, 5, 50, -10])
	s << stroke_test_segment(4, [f32(20), 30, 0, 0, 0, 0, 25, 14, 0.4, 1, 0])
	assert wide_stroke_hash(s, 80, 60, [f32(0.9), 0.3, -0.25, 1.05, 6, -2]!, 0xc8e05020,
		0.85, 7.5, .round, .round, 10) == '48cad6dfb1e598d2'
}

// SkStroke::strokeRect() outlines closed rects directly; a quarter turn keeps
// them axis aligned.
fn test_wide_rect_with_bevel_joins_under_a_quarter_turn() {
	mut s := []f32{}
	s << stroke_test_segment(0, [f32(12.5), 9.25])
	s << stroke_test_segment(1, [f32(47), 9.25])
	s << stroke_test_segment(1, [f32(47), 33.75])
	s << stroke_test_segment(1, [f32(12.5), 33.75])
	s << stroke_test_segment(5, [])
	assert wide_stroke_hash(s, 60, 44, [f32(0), 1, -1, 0, 50, -6]!, 0xff107040, 1, 9, .butt,
		.bevel, 10) == '56bf60736e47897d'
}

// A cubic whose control polygon crosses itself has a cusp, which the stroker
// covers with a circle.
fn test_wide_cubic_cusp_and_square_capped_move_close() {
	mut s := []f32{}
	s << stroke_test_segment(0, [f32(10), 50])
	s << stroke_test_segment(3, [f32(60), 50, 60, 10, 10, 10])
	s << stroke_test_segment(0, [f32(40), 30])
	s << stroke_test_segment(5, [])
	assert wide_stroke_hash(s, 72, 64, [f32(1), 0, 0, 1, 0, 0]!, 0xe0303090, 1, 10, .square,
		.round, 10) == '2b8fc31a519a1424'
}

fn test_stroke_path_builds_skia_outlines() {
	// A closed rect strokes as one outer rect when the width covers it.
	mut b := PathBuilder{}
	b.move_to(0, 0)
	b.line_to(4, 0)
	b.line_to(4, 2)
	b.line_to(0, 2)
	b.close()
	outline := stroke_path(b.detach(), 6, .butt, .miter, 4, 1)
	assert outline.known_convex
	assert outline.builder.points == [Point{-3, -3}, Point{7, -3}, Point{7, 5}, Point{-3, 5}]
	assert outline.builder.verbs == [PathVerb.move, .line, .line, .line, .close]
	// A butt-capped segment: the outer side, the end cap to the inner side,
	// the inner side reversed, and the start cap back to the first point.
	mut l := PathBuilder{}
	l.move_to(0, 0)
	l.line_to(10, 0)
	line := stroke_path(l.detach(), 2, .butt, .miter, 4, 1)
	assert !line.known_convex
	assert line.builder.points == [Point{0, -1}, Point{10, -1}, Point{10, 1}, Point{0, 1},
		Point{0, -1}]
	assert line.builder.verbs == [PathVerb.move, .line, .line, .line, .line, .close]
	// Butt caps draw nothing for a zero-length contour.
	mut z := PathBuilder{}
	z.move_to(3, 3)
	z.line_to(3, 3)
	assert stroke_path(z.detach(), 4, .butt, .round, 4, 1).builder.verbs.len == 0
}
