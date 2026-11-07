module cpuraster

import crypto.sha256

// The premultiplied gradient the clip tests draw over.
fn clip_test_background(width int, height int) []u8 {
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

fn clip_test_segment(kind int, values []f32) []f32 {
	mut segment := [f32(kind)]
	segment << values
	for segment.len < 12 {
		segment << 0
	}
	return segment
}

fn clip_test_circle(cx f32, cy f32, r f32) Path {
	mut s := []f32{}
	s << clip_test_segment(0, [cx + r, cy])
	s << [f32(4), cx - r, cy, 0, 0, 0, 0, r, r, 0, 0, 1]
	s << [f32(4), cx + r, cy, 0, 0, 0, 0, r, r, 0, 0, 1]
	s << clip_test_segment(5, [])
	return canvas_path(s, false)
}

fn clip_test_rect_segments(l f32, t f32, r f32, b f32) []f32 {
	mut s := []f32{}
	s << clip_test_segment(0, [l, t])
	s << clip_test_segment(1, [r, t])
	s << clip_test_segment(1, [r, b])
	s << clip_test_segment(1, [l, b])
	s << clip_test_segment(5, [])
	return s
}

fn clip_test_star() []f32 {
	mut s := []f32{}
	s << clip_test_segment(0, [f32(32), 2])
	s << clip_test_segment(1, [f32(50), 58])
	s << clip_test_segment(1, [f32(4), 22])
	s << clip_test_segment(1, [f32(60), 22])
	s << clip_test_segment(1, [f32(14), 58])
	s << clip_test_segment(5, [])
	return s
}

// Hashes of vox_skia_canvas_path()'s output with LibWeb Skia for the same
// clipped draws and backgrounds (test_cpu_raster.sh compares random ones).
fn test_fill_inside_a_circle_and_a_fractional_rect() {
	mut path := []f32{}
	path << clip_test_segment(0, [f32(4), 6])
	path << clip_test_segment(2, [f32(60), 10, 40, 4])
	path << clip_test_segment(3, [f32(10), 56, 62, 40, 30, 70])
	path << clip_test_segment(5, [])
	mut pixels := clip_test_background(64, 60)
	assert fill_canvas_path(mut pixels, 64, 60, 256, 2, canvas_path(path, false), [f32(1), 0, 0,
		1, 0, 0]!, 0xff3070c0, 0.9, .src_over, [
		clip_test_circle(30, 28, 24.5),
		canvas_path(clip_test_rect_segments(8.25, 10.5, 55.75, 49.25), false),
	])
	assert sha256.sum(pixels).hex()[..16] == 'e6089ba3774fa01a'
}

fn clipped_stroke_hash(path []f32, transform [6]f32, line_width f32, cap StrokeCap, join StrokeJoin, dashes []f32, dash_offset f32, clips []Path) string {
	mut pixels := clip_test_background(64, 60)
	assert stroke_canvas_path(mut pixels, 64, 60, 256, 2, canvas_path(path, false), transform,
		0xe0c04020, 0.85, .src_over, line_width, cap, join, 10, dashes, dash_offset, clips)
	return sha256.sum(pixels).hex()[..16]
}

fn test_wide_stroke_inside_a_rect_and_an_even_odd_star() {
	assert clipped_stroke_hash(clip_test_star(), [f32(0.95), 0.2, -0.2, 0.95, 4, 2]!, 6, .round,
		.miter, [], 0, [canvas_path(clip_test_rect_segments(6, 4, 58, 54), false),
		canvas_path(clip_test_star(), true)]) == '21da18757af66944'
}

fn test_hairline_inside_a_circle() {
	assert clipped_stroke_hash(clip_test_star(), [f32(1), 0, 0, 1, 0, 0]!, 1, .square, .round,
		[], 0, [clip_test_circle(32, 30, 22.5)]) == 'ca71651a5cc21f65'
}

fn test_dashed_stroke_inside_a_fractional_rect() {
	mut circle := []f32{}
	circle << clip_test_segment(0, [f32(50), 30])
	circle << [f32(4), 10, 30, 0, 0, 0, 0, 20, 20, 0, 0, 1]
	circle << [f32(4), 50, 30, 0, 0, 0, 0, 20, 20, 0, 0, 1]
	circle << clip_test_segment(5, [])
	assert clipped_stroke_hash(circle, [f32(1), 0, 0, 1, 0, 0]!, 4, .butt, .bevel, [f32(7), 3],
		1.5, [canvas_path(clip_test_rect_segments(10.5, 12.25, 60.75, 47.5), false)]) == '6eb1430a4af2c8b9'
}

fn test_raster_clip_keeps_rects_hard_edged() {
	// An integral rect intersects the device as a rect.
	rect := canvas_raster_clip(40, 30, [canvas_path(clip_test_rect_segments(-5, 4, 12, 50),
		false)])
	assert rect.is_bw && rect.rect == IRect{0, 4, 12, 30}
	// A fractional rect becomes an AAClip covering its rounded-out bounds.
	soft := canvas_raster_clip(40, 30, [canvas_path(clip_test_rect_segments(2.5, 3.25, 9.5, 8),
		false)])
	assert !soft.is_bw
	assert soft.aa.bounds == IRect{2, 3, 10, 8}
	// Disjoint clips leave nothing.
	empty := canvas_raster_clip(40, 30, [canvas_path(clip_test_rect_segments(0, 0, 5, 5), false),
		clip_test_circle(30, 20, 4)])
	assert empty.is_empty
}

fn test_aaclip_rows_and_skia_is_rect() {
	mut clip := AAClip{}
	clip.set_rect(IRect{0, 0, 300, 2})
	// Runs hold at most 255 pixels.
	assert clip.rows[0].data == [u8(255), 0xff, 45, 0xff]
	assert clip.is_rect()
	// SkAAClip::isRect() compares the row's relative y with the absolute
	// bottom, so an offset rect clip is not reported as a rect.
	mut offset := AAClip{}
	offset.set_rect(IRect{2, 3, 6, 7})
	assert !offset.is_rect()
	assert offset.quick_contains(2, 3, 6, 6)
	assert !offset.quick_contains(2, 3, 6, 7)
}
