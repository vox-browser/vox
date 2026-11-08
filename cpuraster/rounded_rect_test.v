module cpuraster

import math

fn test_rounded_rect_normalizes_corners_and_retains_known_convexity() {
	r := rounded_rect(Rect{10, 8, 0, 0}, [f32(100), 100, 100, 100, 100, 100, 100, 100]!)
	assert r.bounds == Rect{0, 0, 10, 8}
	assert r.radii == [f32(4), 4, 4, 4, 4, 4, 4, 4]!
	p := r.path()
	assert p.points[0] == Point{0, 4}
	assert p.weights.len == 4
	assert p.convexity() == .convex_cw
	assert p.transform(Matrix{a: -1}).convexity() == .convex_ccw
	// Zero on either axis makes that corner square before proportional scaling.
	square := rounded_rect(Rect{0, 0, 10, 8}, [f32(100), 0, 0, 100, 0, 0, 0, 0]!)
	assert square.radii == [8]f32{}
	assert square.path().weights.len == 0
	assert square.path().points[0] == Point{0, 8}
	invalid := rounded_rect(Rect{0, 0, 10, 8}, [f32(math.inf(1)), 1, 1, 1, 1, 1, 1, 1]!)
	assert invalid.radii == [8]f32{}
	// Clamped square corners can confuse inferred polygon convexity; Skia's
	// rounded-rectangle builder records its known clockwise convexity.
	complex := rounded_rect(Rect{-14.921633, 0.14568679, 40.03171, 22.173424},
		[f32(7.238985), -1.6071692, 30.661934, 45.21188, 28.219685, 30.599686, 51.04824, 1.79224]!)
	assert complex.path().convexity() == .convex_cw
}

fn test_clip_subtraction_keeps_source_outside_subtractor_and_fractional_coverage() {
	mut clip := canvas_raster_clip(10, 10, [rect_path(Rect{1.25, 1.25, 8.75, 8.75})])
	clip.subtract_path(rect_path(Rect{3.5, 0, 6.5, 10}))
	mut pixels := []u8{len: 400}
	assert fill_clipped_color(mut pixels, 10, 10, 40, 0xffffffff, clip)
	assert pixels[0..4] == [u8(0), 0, 0, 0]
	assert pixels[88..92] == [u8(255), 255, 255, 255]
	assert pixels[100..104] == [u8(0), 0, 0, 0]
	assert pixels[52..56] == [u8(95), 95, 95, 95]
	// Empty and disjoint operands leave the existing clip unchanged.
	clip.subtract_path(rect_path(Rect{20, 20, 30, 30}))
	clip.subtract_path(Path{})
	mut after := []u8{len: 400}
	assert fill_clipped_color(mut after, 10, 10, 40, 0xffffffff, clip)
	assert after == pixels
}

fn test_rotated_square_corner_clip_uses_the_rect_contour_start() {
	r := rounded_rect(Rect{19.666048, -12.060067, 24.57168, 36.56325}, [8]f32{})
	path := r.clip_path(Matrix{a: 1.3465956, b: 0.76868415, c: -0.59769595,
		d: 1.3465956, e: 19.354881, f: 14.092616})
	mut clip := canvas_raster_clip(48, 40, [])
	clip.subtract_path(path)
	mut pixels := []u8{len: 48 * 40 * 4}
	assert fill_clipped_color(mut pixels, 48, 40, 192, 0xffffffff, clip)
	// Skia's clipRRect -> clipRect path leaves this pixel fully covered.
	assert pixels[4796..4800] == [u8(255), 255, 255, 255]
}
