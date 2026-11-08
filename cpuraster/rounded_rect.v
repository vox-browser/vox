module cpuraster

import math

// SkRRect::setRectRadii(), represented by its normalized bounds and four
// elliptical corner radii in TL, TR, BR, BL order.
pub struct RoundedRect {
pub:
	bounds Rect
	radii [8]f32
}

pub fn rounded_rect(bounds_in Rect, radii_in [8]f32) RoundedRect {
	if !rect_is_finite(bounds_in) { return RoundedRect{} }
	bounds := rect_sorted(bounds_in)
	if rect_is_empty(bounds) { return RoundedRect{bounds: bounds} }
	if !radii_in[..].all(is_finite_f32(it)) { return RoundedRect{bounds: bounds} }
	mut radii := radii_in
	for i in 0 .. 4 {
		if radii[i * 2] <= 0 || radii[i * 2 + 1] <= 0 {
			radii[i * 2], radii[i * 2 + 1] = 0, 0
		}
	}
	width := f64(bounds.right) - f64(bounds.left)
	height := f64(bounds.bottom) - f64(bounds.top)
	pairs := [[0, 2]!, [3, 5]!, [4, 6]!, [7, 1]!]
	mut scale := f64(1)
	for i, pair in pairs {
		limit := if i % 2 == 0 { width } else { height }
		sum := f64(radii[pair[0]]) + f64(radii[pair[1]])
		if sum > limit { scale = math.min(scale, limit / sum) }
	}
	for i, pair in pairs {
		mut a := radii[pair[0]]
		mut b := radii[pair[1]]
		if a + b == a { b = 0 } else if a + b == b { a = 0 }
		if scale < 1 {
			limit := if i % 2 == 0 { width } else { height }
			a = f32(f64(a) * scale)
			b = f32(f64(b) * scale)
			if f64(a + b) > limit {
				if a > b {
					a = f32(limit - f64(b))
					for f64(a + b) > limit { a = math.nextafter32(a, 0) }
				} else {
					b = f32(limit - f64(a))
					for f64(a + b) > limit { b = math.nextafter32(b, 0) }
				}
			}
		}
		radii[pair[0]], radii[pair[1]] = a, b
	}
	for i in 0 .. 4 {
		if radii[i * 2] <= 0 || radii[i * 2 + 1] <= 0 { radii[i * 2], radii[i * 2 + 1] = 0, 0 }
	}
	return RoundedRect{bounds, radii}
}

// SkPathBuilder::addRRect()'s default clockwise contour begins at index 6.
pub fn (r RoundedRect) path() Path {
	mut b := PathBuilder{}
	rect := r.bounds
	if r.radii[..].all(it == 0) {
		b.add_rect_dir(rect, true, 3)
		return Path{...b.detach(), convex_hint: .convex_cw}
	}
	rad := r.radii
	p := [Point{rect.left + rad[0], rect.top}, Point{rect.right - rad[2], rect.top},
		Point{rect.right, rect.top + rad[3]}, Point{rect.right, rect.bottom - rad[5]},
		Point{rect.right - rad[4], rect.bottom}, Point{rect.left + rad[6], rect.bottom},
		Point{rect.left, rect.bottom - rad[7]}, Point{rect.left, rect.top + rad[1]}]!
	// An oval takes the dedicated four-conic path with start index 3.
	if rad[0] == rad[2] && rad[0] == rad[4] && rad[0] == rad[6]
		&& rad[1] == rad[3] && rad[1] == rad[5] && rad[1] == rad[7]
		&& rad[0] >= (rect.right - rect.left) * f32(0.5)
		&& rad[1] >= (rect.bottom - rect.top) * f32(0.5) {
		b.add_oval_dir(rect, true, 3)
		return Path{...b.detach(), convex_hint: .convex_cw}
	}
	b.move_to_pt(p[6])
	for i in 0 .. 4 {
		line := (6 + i * 2 + 1) % 8
		end := (line + 1) % 8
		b.line_to_pt(p[line])
		b.conic_to_pts(rect_corner(rect, (i + 0) % 4), p[end], scalar_root2_over2)
	}
	b.close()
	return Path{...b.detach(), convex_hint: .convex_cw}
}

// SkCanvas::clipRRect() routes a square-corner rectangle through clipRect,
// whose rotated contour starts at TL rather than addRRect's legacy BL.
pub fn (r RoundedRect) clip_path(matrix Matrix) Path {
	if r.radii[..].all(it == 0) && !rect_is_empty(r.bounds) {
		p := rect_path(r.bounds)
		return Path{...p, convex_hint: .convex_cw}.transform(matrix)
	}
	return r.path().transform(matrix)
}
