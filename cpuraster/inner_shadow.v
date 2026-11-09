module cpuraster

import math

// A nested rounded hole needs no curve intersections. Its two contours share
// the even-odd winding rule of the boolean difference.
pub fn rasterize_inner_shadow(width int, height int, outer RoundedRect, inner RoundedRect, content RoundedRect, transform [6]f32, color u32, blur f32, clips []Path) ?[]u8 {
	if width <= 0 || height <= 0 || width > max_untiled_dimension || height > max_untiled_dimension { return none }
	if !rect_contains(outer.bounds, inner.bounds) { return none }
	if !outer.radii[..].all(it == 0) && !shadow_rounded_rect_contains_inner(outer, inner) { return none }
	a, b := shadow_boolean_contour(outer), shadow_boolean_contour(inner)
	mut verbs := a.verbs.clone()
	mut points := a.points.clone()
	mut weights := a.weights.clone()
	verbs << b.verbs
	points << b.points
	weights << b.weights
	local := Path{verbs: verbs, points: points, weights: weights, fill_type: .even_odd}
	matrix := Matrix{transform[0], transform[1], transform[2], transform[3], transform[4], transform[5]}
	device := local.transform(matrix)
	mut all_clips := clips.clone()
	all_clips << content.clip_path(matrix)
	rc := canvas_raster_clip(width, height, all_clips)
	mut pixels := []u8{len: width * height * 4}
	mut fast_bounds := outer.bounds
	if sigma := canvas_shadow_sigma(blur) {
		pad := f32(3) * sigma
		fast_bounds = Rect{fast_bounds.left - pad, fast_bounds.top - pad, fast_bounds.right + pad, fast_bounds.bottom + pad}
	}
	if canvas_quick_reject(fast_bounds, matrix, &rc) { return pixels }
	if !rc.is_empty && color >> 24 != 0 {
		mut blitter := choose_color_blitter(mut pixels, width * 4, color, f32(color >> 24) * inv_255,
			.src_over, canvas_rgba_uses_legacy()) or { return none }
		if sigma := canvas_shadow_sigma(blur) {
			plan := plan_blur(device, false, sigma, matrix, &rc, false)
			if plan.kind == .declined { return none }
			if plan.kind == .unfiltered { anti_fill_path_clip(device, false, &rc, mut blitter) }
			else { plan.draw(&rc, blitter) }
		} else { anti_fill_path_clip(device, false, &rc, mut blitter) }
	}
	mut straight := []u8{len: pixels.len}
	if !read_pixels(pixels, width, height, width * 4, 2, mut straight, width, height, width * 4, 0, 0) { return none }
	return straight
}

// Containment follows from the inner bounding-box corners or concentric
// smaller corner ellipses. Keep a margin at curved edges so this route only
// handles disjoint contours; intersections and shared edges need PathOps.
fn shadow_rounded_rect_contains_inner(outer RoundedRect, hole RoundedRect) bool {
	inner := hole.bounds
	b := outer.bounds
	if rect_is_empty(inner) || inner.left <= b.left || inner.top <= b.top
		|| inner.right >= b.right || inner.bottom >= b.bottom { return false }
	for point_index, point in [Point{inner.left, inner.top}, Point{inner.right, inner.top},
		Point{inner.right, inner.bottom}, Point{inner.left, inner.bottom}] {
		for corner in 0 .. 4 {
			rx, ry := outer.radii[corner * 2], outer.radii[corner * 2 + 1]
			if rx == 0 || ry == 0 { continue }
			left := corner in [0, 3]
			top := corner in [0, 1]
			cx := if left { b.left + rx } else { b.right - rx }
			cy := if top { b.top + ry } else { b.bottom - ry }
			in_x := if left { point.x < cx } else { point.x > cx }
			in_y := if top { point.y < cy } else { point.y > cy }
			if in_x && in_y {
				dx, dy := (f64(point.x) - cx) / rx, (f64(point.y) - cy) / ry
				xx, yy := dx * dx, dy * dy
				magnitude := math.max(math.abs(cx), math.abs(cy))
				margin := f64(1e-5) * (1 + magnitude / math.min(rx, ry))
				if xx + yy >= 1 - margin {
					// A concentric smaller corner ellipse is contained even
					// when its missing bounding-box corner lies outside.
					irx, iry := hole.radii[corner * 2], hole.radii[corner * 2 + 1]
					icx := if left { inner.left + irx } else { inner.right - irx }
					icy := if top { inner.top + iry } else { inner.bottom - iry }
					if point_index != corner || irx <= 0 || iry <= 0 || icx != cx || icy != cy
						|| f64(irx) / rx >= 1 - margin || f64(iry) / ry >= 1 - margin { return false }
				}
			}
		}
	}
	return true
}

// The nonintersecting PathOps contours are emitted counterclockwise from
// their top-left extremum, with an explicit final edge before close().
fn shadow_boolean_contour(r RoundedRect) Path {
	mut b := PathBuilder{}
	rect := r.bounds
	rad := r.radii
	if rad[..].all(it == 0) {
		b.move_to(rect.left, rect.top)
		b.line_to(rect.left, rect.bottom)
		b.line_to(rect.right, rect.bottom)
		b.line_to(rect.right, rect.top)
		b.line_to(rect.left, rect.top)
		b.close()
		return b.detach()
	}
	mut p := [Point{rect.left + rad[0], rect.top}, Point{rect.right - rad[2], rect.top},
		Point{rect.right, rect.top + rad[3]}, Point{rect.right, rect.bottom - rad[5]},
		Point{rect.right - rad[4], rect.bottom}, Point{rect.left + rad[6], rect.bottom},
		Point{rect.left, rect.bottom - rad[7]}, Point{rect.left, rect.top + rad[1]}]!
	// preFetch drops nearly degenerate lines and joins each preceding
	// conic's endpoint to the line's endpoint. The first line follows moveTo.
	if shadow_points_equal(p[6], p[7]) { p[7] = p[6] }
	for i in [0, 2, 4] { if shadow_points_equal(p[i], p[i+1]) { p[i] = p[i+1] } }
	if p[6] != p[7] {
		b.move_to_pt(p[7])
		b.line_to_pt(p[6])
		mut last := p[6]
		for i in 0 .. 4 {
			corner := 3 - i
			end := (5 - i*2 + 8) % 8
			if p[end] != last { b.conic_to_pts(rect_corner(rect, corner), p[end], scalar_root2_over2) }
			if i < 3 {
				line := (end + 7) % 8
				if p[line] != p[end] { b.line_to_pt(p[line]) }
				last = p[line]
			}
		}
		b.close()
		return b.detach()
	}
	b.move_to_pt(p[0])
	mut last := p[0]
	for i in 0 .. 4 {
		corner := (4 - i) % 4
		end := (7 - i*2) % 8
		if p[end] != last { b.conic_to_pts(rect_corner(rect, corner), p[end], scalar_root2_over2) }
		line := (end + 7) % 8
		if p[line] != p[end] { b.line_to_pt(p[line]) }
		last = p[line]
	}
	b.close()
	return b.detach()
}

fn shadow_float_ordered(x f32) i64 {
	bits := i32(math.f32_bits(x))
	return if bits < 0 { -i64(u32(bits) & 0x7fffffff) } else { i64(bits) }
}

fn shadow_ulps_equal(a f32, b f32, epsilon int) bool {
	x, y := shadow_float_ordered(a), shadow_float_ordered(b)
	return x < y + epsilon && y < x + epsilon
}

// SkDPoint::ApproximatelyEqual (the general-coordinate, float overload).
fn shadow_points_equal(a Point, b Point) bool {
	dx, dy := f64(a.x) - f64(b.x), f64(a.y) - f64(b.y)
	if math.abs(dx) < 1.1920928955078125e-7 && math.abs(dy) < 1.1920928955078125e-7 { return true }
	if !shadow_ulps_equal(a.x, b.x, 256) || !shadow_ulps_equal(a.y, b.y, 256) { return false }
	xx, yy := dx*dx, dy*dy
	distance := math.sqrt(xx + yy)
	largest := math.max(math.max(math.abs(a.x), math.abs(a.y)), math.max(math.abs(b.x), math.abs(b.y)))
	return shadow_ulps_equal(largest, f32(f64(largest) + distance), 16)
}
