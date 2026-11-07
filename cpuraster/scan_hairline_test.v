module cpuraster

import crypto.sha256

// The premultiplied gradient scan_test.v fills over.
fn hairline_background(width int, height int) []u8 {
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

fn hairline_segment(kind int, values []f32) []f32 {
	mut segment := [f32(kind)]
	segment << values
	for segment.len < 12 {
		segment << 0
	}
	return segment
}

fn stroke_hash(segments []f32, width int, height int, transform [6]f32, color u32, global_alpha f32, line_width f32, cap StrokeCap, join StrokeJoin) string {
	mut pixels := hairline_background(width, height)
	assert stroke_canvas_path(mut pixels, width, height, width * 4, 2, canvas_path(segments,
		false), transform, color, global_alpha, .src_over, 0, line_width, cap, join, 10, [], 0, [])
	return sha256.sum(pixels).hex()[..16]
}

// Hashes of vox_skia_canvas_path()'s output with LibWeb Skia for the same
// strokes and backgrounds (test_cpu_raster.sh compares random strokes).
fn test_stroke_one_pixel_polyline_with_butt_caps() {
	mut s := []f32{}
	s << hairline_segment(0, [f32(4), 6.5])
	s << hairline_segment(1, [f32(58), 6.5])
	s << hairline_segment(1, [f32(58), 40])
	s << hairline_segment(1, [f32(9.25), 30.75])
	s << hairline_segment(5, [])
	s << hairline_segment(0, [f32(20), 12])
	s << hairline_segment(1, [f32(44.5), 25.25])
	assert stroke_hash(s, 64, 48, [f32(1), 0, 0, 1, 0, 0]!, 0xff2a60d0, 1, 1, .butt, .miter) == '3955e568dc7e51e9'
}

fn test_stroke_thin_curves_scale_alpha_by_coverage() {
	mut s := []f32{}
	s << hairline_segment(0, [f32(8), 40])
	s << hairline_segment(2, [f32(60), 44, 30, 2])
	s << hairline_segment(3, [f32(70), 50, 10, 5, 50, -10])
	s << hairline_segment(4, [f32(20), 30, 0, 0, 0, 0, 25, 14, 0.4, 1, 0])
	assert stroke_hash(s, 80, 60, [f32(0.9), 0.3, -0.25, 1.05, 6, -2]!, 0xc8e05020, 0.85,
		0.5, .round, .round) == '0fa8edf3e8f321c6'
}

fn test_stroke_square_caps_clip_at_the_device_edges() {
	mut s := []f32{}
	s << hairline_segment(0, [f32(-15), 20])
	s << hairline_segment(1, [f32(30), -12])
	s << hairline_segment(1, [f32(75), 33])
	s << hairline_segment(0, [f32(40), 25])
	s << hairline_segment(1, [f32(40), 25])
	s << hairline_segment(0, [f32(5), 35])
	s << hairline_segment(1, [f32(5), 35.5])
	assert stroke_hash(s, 60, 40, [f32(1), 0, 0, 1, 0, 0]!, 0xff000000, 1, 0.75, .square,
		.bevel) == '39a45c3f5a2c4ec5'
}

fn test_stroke_declines_devices_skia_tiles() {
	mut pixels := hairline_background(8192, 1)
	before := pixels.clone()
	path := canvas_path(hairline_segment(0, [f32(2), 0.5]), false)
	assert !stroke_canvas_path(mut pixels, 8192, 1, 8192 * 4, 2, path, [f32(1), 0, 0, 1, 0, 0]!,
		0xff000000, 1, .src_over, 0, 1, .butt, .miter, 10, [], 0, [])
	assert !stroke_canvas_path(mut pixels, 8192, 1, 8192 * 4, 2, path, [f32(1), 0, 0, 1, 0, 0]!,
		0xff000000, 1, .src_over, 0, 6, .butt, .miter, 10, [f32(3), 2], 0, [])
	assert pixels == before
}
