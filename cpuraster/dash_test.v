module cpuraster

import crypto.sha256
import math

// The premultiplied gradient the stroke tests draw over.
fn dash_test_background(width int, height int) []u8 {
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

fn dash_test_segment(kind int, values []f32) []f32 {
	mut segment := [f32(kind)]
	segment << values
	for segment.len < 12 {
		segment << 0
	}
	return segment
}

fn dashed_hash(segments []f32, width int, height int, transform [6]f32, color u32, global_alpha f32, line_width f32, cap StrokeCap, join StrokeJoin, miter f32, dashes []f32, dash_offset f32) string {
	mut pixels := dash_test_background(width, height)
	assert stroke_canvas_path(mut pixels, width, height, width * 4, 2, canvas_path(segments,
		false), transform, color, global_alpha, .src_over, line_width, cap, join, miter, dashes, dash_offset, [])
	mut undashed := dash_test_background(width, height)
	assert stroke_canvas_path(mut undashed, width, height, width * 4, 2, canvas_path(segments,
		false), transform, color, global_alpha, .src_over, line_width, cap, join, miter, [], 0, [])
	assert pixels != undashed
	return sha256.sum(pixels).hex()[..16]
}

// Hashes of vox_skia_canvas_path()'s output with LibWeb Skia for the same
// dashed strokes and backgrounds (test_cpu_raster.sh compares random ones).
fn test_dashed_curves_with_round_caps_under_a_transform() {
	mut s := []f32{}
	s << dash_test_segment(0, [f32(8), 40])
	s << dash_test_segment(2, [f32(60), 44, 30, 2])
	s << dash_test_segment(3, [f32(70), 50, 10, 5, 50, -10])
	s << dash_test_segment(4, [f32(20), 30, 0, 0, 0, 0, 25, 14, 0.4, 1, 0])
	assert dashed_hash(s, 80, 60, [f32(0.9), 0.3, -0.25, 1.05, 6, -2]!, 0xc8e05020, 0.85, 4,
		.round, .miter, 10, [f32(9), 4, 2, 4], 3.5) == '2472657d501d84e9'
}

// A butt-capped line far wider than the device is trimmed to the cull rect,
// in phase, and dashed directly into quads (SpecialLineRec).
fn test_dashed_line_trimmed_to_the_device() {
	mut s := []f32{}
	s << dash_test_segment(0, [f32(-500), 12.5])
	s << dash_test_segment(1, [f32(900), 12.5])
	assert dashed_hash(s, 64, 40, [f32(1), 0, 0, 1, 0, 0]!, 0xff2a60d0, 1, 3, .butt, .bevel,
		4, [f32(6), 3], -2) == '327282a95a0d0aee'
}

// A closed rect that starts and ends in a dash gets a tiny corner so the
// first dash joins the last; at width 1 the dashes are hairlines.
fn test_dashed_closed_rect_hairline() {
	mut s := []f32{}
	s << dash_test_segment(0, [f32(10), 8])
	s << dash_test_segment(1, [f32(50), 8])
	s << dash_test_segment(1, [f32(50), 36])
	s << dash_test_segment(1, [f32(10), 36])
	s << dash_test_segment(5, [])
	assert dashed_hash(s, 60, 44, [f32(1), 0, 0, 1, 0, 0]!, 0xff107040, 1, 1, .square,
		.bevel, 10, [f32(7), 5], 1) == '5e3331fed1e90d5e'
}

// A zero-length dash still draws nothing with butt caps; the rotated line
// is not trimmed.
fn test_dashed_rotated_butt_line_with_a_zero_dash() {
	mut s := []f32{}
	s << dash_test_segment(0, [f32(6), 30])
	s << dash_test_segment(1, [f32(60), 12])
	assert dashed_hash(s, 64, 40, [f32(0.94), 0.34, -0.34, 0.94, 4, -6]!, 0xe0303090, 1, 5,
		.butt, .round, 10, [f32(5), 2.5, 0, 2.5], 0) == '8cf60fb249145508'
}

fn test_dash_parameters_follow_skia() {
	// Odd, negative, all-zero and non-finite intervals leave the stroke
	// undashed.
	assert new_dash_effect([f32(4)], 0) == none
	assert new_dash_effect([f32(4), 2, 1], 0) == none
	assert new_dash_effect([f32(4), -1], 0) == none
	assert new_dash_effect([f32(0), 0], 0) == none
	assert new_dash_effect([f32(4), 2], f32(math.inf(1))) == none
	// A negative phase counts back from the interval length.
	dash := new_dash_effect([f32(4), 2], -1) or { panic('valid dash') }
	assert dash.phase == 5
	assert dash.initial_dash_index == 1
	assert dash.initial_dash_length == 1
	assert dash.interval_length == 6
	wrapped := new_dash_effect([f32(4), 2], 13) or { panic('valid dash') }
	assert wrapped.phase == 1
	assert wrapped.initial_dash_index == 0
	assert wrapped.initial_dash_length == 3
}

fn test_contour_measure_lengths_and_segments() {
	mut b := PathBuilder{}
	b.move_to(0, 0)
	b.line_to(30, 0)
	b.line_to(30, 40)
	b.close()
	mut iter := new_contour_measure_iter(b.detach(), 1)
	cm := iter.next() or { panic('one contour') }
	assert cm.closed
	assert cm.length == 120
	assert iter.next() == none
	mut dst := PathBuilder{}
	assert cm.get_segment(20, 50, mut dst, true)
	assert dst.points == [Point{20, 0}, Point{30, 0}, Point{30, 20}]
	assert dst.verbs == [PathVerb.move, .line, .line]
}
