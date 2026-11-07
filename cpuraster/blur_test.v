module cpuraster

import crypto.sha256

// A premultiplied gradient with transparent and opaque pixels for the
// shadow tests to draw over.
fn blur_test_background(width int, height int) []u8 {
	mut px := []u8{len: width * height * 4}
	for y in 0 .. height {
		for x in 0 .. width {
			o := (y * width + x) * 4
			a := if (x + 2 * y) % 9 == 0 { 0 } else { (x * 5 + y * 7) % 256 }
			px[o + 3] = u8(a)
			px[o] = u8(a * x / width)
			px[o + 1] = u8(a * y / height)
			px[o + 2] = u8(a / 3)
		}
	}
	return px
}

fn blur_test_segment(kind int, values []f32) []f32 {
	mut segment := [f32(kind)]
	segment << values
	for segment.len < 12 {
		segment << 0
	}
	return segment
}

fn blur_test_rect(l f32, t f32, r f32, b f32) []f32 {
	mut s := []f32{}
	s << blur_test_segment(0, [l, t])
	s << blur_test_segment(1, [r, t])
	s << blur_test_segment(1, [r, b])
	s << blur_test_segment(1, [l, b])
	s << blur_test_segment(5, [])
	return s
}

fn blur_test_curve() []f32 {
	mut s := []f32{}
	s << blur_test_segment(0, [f32(12), 10])
	s << blur_test_segment(2, [f32(60), 14, 52, 6])
	s << blur_test_segment(3, [f32(40), 50, 6, 30, 58, 44])
	s << blur_test_segment(5, [])
	return s
}

const blur_test_identity = [f32(1), 0, 0, 1, 0, 0]!

fn blur_fill_hash(segments []f32, transform [6]f32, color u32, mode BlendMode, blur f32, clips []Path) string {
	mut px := blur_test_background(64, 56)
	assert fill_canvas_path(mut px, 64, 56, 256, 2, canvas_path(segments, false), transform, color, none,
		1, mode, blur, clips)
	return sha256.sum(px).hex()[..16]
}

fn blur_stroke_hash(segments []f32, transform [6]f32, line_width f32, cap StrokeCap, blur f32) string {
	mut px := blur_test_background(64, 56)
	assert stroke_canvas_path(mut px, 64, 56, 256, 2, canvas_path(segments, false), transform,
		0xc0306090, none, 1, .src_over, blur, line_width, cap, .miter, 10, [], 0, [])
	return sha256.sum(px).hex()[..16]
}

// Hashes of vox_skia_canvas_path()'s output with LibWeb Skia for the same
// shadows and background (test_cpu_raster.sh compares random ones).
fn test_blurred_masks_match_skia() {
	// sigma 1.5: SkMaskBlurFilter's direct Gaussian kernel.
	assert blur_fill_hash(blur_test_curve(), blur_test_identity, 0xff204080, .src_over, 3, []) == '31420421a7850a76'
	// sigma 6 under a scale of 1.5: three box passes.
	assert blur_fill_hash(blur_test_curve(), [f32(1.5), 0, 0, 1.5, -10, -6]!, 0xa0e05010,
		.src_over, 12, []) == 'dea51d8b129f7d39'
	// sigma 0.25 has no blur: Skia draws the shape unfiltered.
	assert blur_fill_hash(blur_test_curve(), blur_test_identity, 0xff204080, .src_over, 0.5,
		[]) == 'edcd6b85fed92936'
	// A hairline shadow is drawn into the mask with butt caps.
	assert blur_stroke_hash(blur_test_curve(), blur_test_identity, 1, .square, 5) == '49259369cfea127b'
	// Inside an anti-aliased clip, with a composite operation.
	assert blur_fill_hash(blur_test_curve(), blur_test_identity, 0xff40c060, .multiply, 7, [
		canvas_path(blur_test_rect(8.5, 6.25, 50.75, 41.5), false),
	]) == '802858540a0d2a24'
}

fn test_blurred_rects_match_skia() {
	// One rect: SkBlurMask::BlurRect()'s analytic nine-patch.
	assert blur_fill_hash(blur_test_rect(10.25, 8.5, 52.75, 44), blur_test_identity, 0xff802040,
		.src_over, 8, []) == '727f7a3691bdb1cf'
	// A stroked rect is a ring of nested rects: the blurred ring nine-patch.
	assert blur_stroke_hash(blur_test_rect(6, 6, 58, 50), blur_test_identity, 4, .butt, 6) == '627f3ce6ef3d3aec'
	// Too small for a nine-patch, so blurred as a mask.
	assert blur_fill_hash(blur_test_rect(30, 26, 36, 31), blur_test_identity, 0xff802040,
		.src_over, 9, []) == 'f9911f428908818f'
}

// A ring whose mask is more than 8191 pixels across would need Skia's
// non-anti-aliased SkScan::FillPath(): the draw declines and leaves the
// pixels, even unpremultiplied ones, untouched.
fn test_oversized_ring_declines_untouched() {
	mut s := blur_test_rect(-9000, -9000, 9000, 9000)
	s << blur_test_rect(-100, -100, 100, 100)
	before := blur_test_background(64, 56)
	mut px := before.clone()
	assert !fill_canvas_path(mut px, 64, 56, 256, 1, canvas_path(s, false), blur_test_identity,
		0xff000000, none, 1, .src_over, 20, [])
	assert px == before
}

fn test_nested_rect_contours() {
	// SkStroke outlines a closed rect as an outer and an inner rect.
	mut outline := stroke_path(canvas_path(blur_test_rect(10, 10, 40, 30), false), 4, .butt,
		.miter, 4, 1)
	rects := nested_fill_rects(outline.builder.detach())
	assert rects == [Rect{8, 8, 42, 32}, Rect{12, 12, 38, 28}]
	// An open first rect is closed by the next move: the first contour
	// consumes its four points and four verbs.
	mut pair := blur_test_rect(0, 0, 20, 20)
	pair << blur_test_rect(4, 4, 16, 16)
	points := canvas_path(pair, false).points
	first := rect_contour_in(points, [PathVerb.move, .line, .line, .line, .move, .line, .line,
		.line, .close], true) or { panic('no rect') }
	assert first.rect == Rect{0, 0, 20, 20}
	assert first.points_consumed == 4 && first.verbs_consumed == 4
	// A ring whose inner rect pokes out is not nested.
	mut crossing := blur_test_rect(0, 0, 20, 20)
	crossing << blur_test_rect(5, 5, 25, 15)
	assert nested_fill_rects(canvas_path(crossing, false)).len == 0
}
