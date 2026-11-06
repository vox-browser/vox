module cpuraster

import math

// SkLineClipper and SkEdgeClipper (google/skia ee20d565): clip path segments
// to the device bounds before building edges, turning parts left of the clip
// (and right of it for convex paths) into vertical lines along its sides.

fn pin_unsorted_f64(value f64, limit0_in f64, limit1_in f64) f64 {
	mut limit0 := limit0_in
	mut limit1 := limit1_in
	if limit1 < limit0 {
		limit0, limit1 = limit1, limit0
	}
	if value < limit0 {
		return limit0
	}
	if value > limit1 {
		return limit1
	}
	return value
}

fn pin_unsorted_f32(value f32, limit0_in f32, limit1_in f32) f32 {
	mut limit0 := limit0_in
	mut limit1 := limit1_in
	if limit1 < limit0 {
		limit0, limit1 = limit1, limit0
	}
	if value < limit0 {
		return limit0
	}
	if value > limit1 {
		return limit1
	}
	return value
}

// sk_float_midpoint().
fn float_midpoint(a f32, b f32) f32 {
	sum := f64(a) + f64(b)
	return f32(sum * 0.5)
}

fn sect_with_horizontal(src []Point, y f32) f32 {
	dy := src[1].y - src[0].y
	if f32(math.abs(dy)) <= scalar_nearly_zero {
		return float_midpoint(src[0].x, src[1].x)
	}
	x0 := f64(src[0].x)
	y0 := f64(src[0].y)
	x1 := f64(src[1].x)
	y1 := f64(src[1].y)
	num := f64(y) - y0
	dx := x1 - x0
	prod := num * dx
	den := y1 - y0
	q := prod / den
	result := x0 + q
	return f32(pin_unsorted_f64(result, x0, x1))
}

fn sect_with_vertical(src []Point, x f32) f32 {
	dx := src[1].x - src[0].x
	if f32(math.abs(dx)) <= scalar_nearly_zero {
		return float_midpoint(src[0].y, src[1].y)
	}
	x0 := f64(src[0].x)
	y0 := f64(src[0].y)
	x1 := f64(src[1].x)
	y1 := f64(src[1].y)
	num := f64(x) - x0
	dy := y1 - y0
	prod := num * dy
	den := x1 - x0
	q := prod / den
	return f32(y0 + q)
}

fn sect_clamp_with_vertical(src []Point, x f32) f32 {
	y := sect_with_vertical(src, x)
	return pin_unsorted_f32(y, src[0].y, src[1].y)
}

// SkLineClipper::ClipLine(): the clipped polyline, empty when culled.
fn clip_line(pts []Point, clip Rect, can_cull_to_the_right bool) []Point {
	mut index0 := 0
	mut index1 := 1
	if !(pts[0].y < pts[1].y) {
		index0 = 1
		index1 = 0
	}
	if pts[index1].y <= clip.top || pts[index0].y >= clip.bottom {
		return []
	}
	mut tmp := [pts[0], pts[1]]
	if pts[index0].y < clip.top {
		tmp[index0] = Point{sect_with_horizontal(pts, clip.top), clip.top}
	}
	if tmp[index1].y > clip.bottom {
		tmp[index1] = Point{sect_with_horizontal(pts, clip.bottom), clip.bottom}
	}
	mut reverse := false
	if pts[0].x < pts[1].x {
		index0 = 0
		index1 = 1
	} else {
		index0 = 1
		index1 = 0
		reverse = true
	}
	mut result := []Point{}
	if tmp[index1].x <= clip.left {
		tmp[0].x = clip.left
		tmp[1].x = clip.left
		result = tmp.clone()
		reverse = false
	} else if tmp[index0].x >= clip.right {
		if can_cull_to_the_right {
			return []
		}
		tmp[0].x = clip.right
		tmp[1].x = clip.right
		result = tmp.clone()
		reverse = false
	} else {
		if tmp[index0].x < clip.left {
			result << Point{clip.left, tmp[index0].y}
			result << Point{clip.left, sect_clamp_with_vertical(tmp, clip.left)}
		} else {
			result << tmp[index0]
		}
		if tmp[index1].x > clip.right {
			result << Point{clip.right, sect_clamp_with_vertical(tmp, clip.right)}
			result << Point{clip.right, tmp[index1].y}
		} else {
			result << tmp[index1]
		}
	}
	if reverse {
		result.reverse_in_place()
	}
	return result
}

// One clipped segment: 2 points for a line, 3 for a quad, 4 for a cubic.
struct ClippedSegment {
	verb PathVerb
	pts  []Point
}

struct EdgeClipper {
	can_cull_to_the_right bool
mut:
	segments []ClippedSegment
}

fn (mut c EdgeClipper) clip_line(p0 Point, p1 Point, clip Rect) {
	lines := clip_line([p0, p1], clip, c.can_cull_to_the_right)
	for i in 0 .. lines.len - 1 {
		c.segments << ClippedSegment{.line, [lines[i], lines[i + 1]]}
	}
}

fn (mut c EdgeClipper) append_vline(x f32, y0_in f32, y1_in f32, reverse bool) {
	mut y0 := y0_in
	mut y1 := y1_in
	if reverse {
		y0, y1 = y1, y0
	}
	c.segments << ClippedSegment{.line, [Point{x, y0}, Point{x, y1}]}
}

fn (mut c EdgeClipper) append_quad(pts []Point, reverse bool) {
	if reverse {
		c.segments << ClippedSegment{.quad, [pts[2], pts[1], pts[0]]}
	} else {
		c.segments << ClippedSegment{.quad, [pts[0], pts[1], pts[2]]}
	}
}

fn sort_increasing_y(src []Point) ([]Point, bool) {
	if src[0].y > src[src.len - 1].y {
		mut dst := src.clone()
		dst.reverse_in_place()
		return dst, true
	}
	return src.clone(), false
}

fn chop_mono_quad_at(c0 f32, c1 f32, c2 f32, target f32) ?f32 {
	d01 := c0 - c1
	d011 := d01 - c1
	a := d011 + c2
	d10 := c1 - c0
	b := 2 * d10
	c := c0 - target
	roots := find_unit_quad_roots(a, b, c)
	if roots.len > 0 {
		return roots[0]
	}
	return none
}

fn chop_quad_in_y(mut pts []Point, clip Rect) {
	if pts[0].y < clip.top {
		if t := chop_mono_quad_at(pts[0].y, pts[1].y, pts[2].y, clip.top) {
			mut tmp := chop_quad_at(pts, t)
			tmp[2].y = clip.top
			if tmp[3].y < clip.top {
				tmp[3].y = clip.top
			}
			pts[0] = tmp[2]
			pts[1] = tmp[3]
		} else {
			for i in 0 .. 3 {
				if pts[i].y < clip.top {
					pts[i].y = clip.top
				}
			}
		}
	}
	if pts[2].y > clip.bottom {
		if t := chop_mono_quad_at(pts[0].y, pts[1].y, pts[2].y, clip.bottom) {
			mut tmp := chop_quad_at(pts, t)
			if tmp[1].y > clip.bottom {
				tmp[1].y = clip.bottom
			}
			tmp[2].y = clip.bottom
			pts[1] = tmp[1]
			pts[2] = tmp[2]
		} else {
			for i in 0 .. 3 {
				if pts[i].y > clip.bottom {
					pts[i].y = clip.bottom
				}
			}
		}
	}
}

fn (mut c EdgeClipper) clip_mono_quad(src []Point, clip Rect) {
	mut pts, mut reverse := sort_increasing_y(src)
	if pts[2].y <= clip.top || pts[0].y >= clip.bottom {
		return
	}
	chop_quad_in_y(mut pts, clip)
	if pts[0].x > pts[2].x {
		pts[0], pts[2] = pts[2], pts[0]
		reverse = !reverse
	}
	if pts[2].x <= clip.left {
		c.append_vline(clip.left, pts[0].y, pts[2].y, reverse)
		return
	}
	if pts[0].x >= clip.right {
		if !c.can_cull_to_the_right {
			c.append_vline(clip.right, pts[0].y, pts[2].y, reverse)
		}
		return
	}
	if pts[0].x < clip.left {
		if t := chop_mono_quad_at(pts[0].x, pts[1].x, pts[2].x, clip.left) {
			mut tmp := chop_quad_at(pts, t)
			c.append_vline(clip.left, tmp[0].y, tmp[2].y, reverse)
			tmp[2].x = clip.left
			if tmp[3].x < clip.left {
				tmp[3].x = clip.left
			}
			pts[0] = tmp[2]
			pts[1] = tmp[3]
		} else {
			c.append_vline(clip.left, pts[0].y, pts[2].y, reverse)
			return
		}
	}
	if pts[2].x > clip.right {
		if t := chop_mono_quad_at(pts[0].x, pts[1].x, pts[2].x, clip.right) {
			mut tmp := chop_quad_at(pts, t)
			if tmp[1].x > clip.right {
				tmp[1].x = clip.right
			}
			tmp[2].x = clip.right
			c.append_quad(tmp[..3], reverse)
			c.append_vline(clip.right, tmp[2].y, tmp[4].y, reverse)
		} else {
			pts[1].x = f32(math.min(pts[1].x, clip.right))
			pts[2].x = f32(math.min(pts[2].x, clip.right))
			c.append_quad(pts, reverse)
		}
	} else {
		c.append_quad(pts, reverse)
	}
}

// SkRect::BoundsOrEmpty() of a few points.
fn points_bounds(pts []Point) Rect {
	mut r := Rect{pts[0].x, pts[0].y, pts[0].x, pts[0].y}
	for p in pts {
		r.left = f32(math.min(p.x, r.left))
		r.top = f32(math.min(p.y, r.top))
		r.right = f32(math.max(p.x, r.right))
		r.bottom = f32(math.max(p.y, r.bottom))
	}
	return r
}

fn (mut c EdgeClipper) clip_quad(src []Point, clip Rect) {
	bounds := points_bounds(src)
	if bounds.top >= clip.bottom || bounds.bottom <= clip.top {
		return
	}
	mono_y := chop_quad_at_extrema(src, true)
	for y := 0; y * 2 + 2 < mono_y.len; y++ {
		mono_x := chop_quad_at_extrema(mono_y[y * 2..y * 2 + 3], false)
		for x := 0; x * 2 + 2 < mono_x.len; x++ {
			c.clip_mono_quad(mono_x[x * 2..x * 2 + 3], clip)
		}
	}
}

fn (mut c EdgeClipper) clip_cubic(src []Point, clip Rect) {
	bounds := points_bounds(src)
	if bounds.bottom > clip.top && bounds.top < clip.bottom {
		limit := f32(1 << 22)
		if bounds.left < -limit || bounds.top < -limit || bounds.right > limit
			|| bounds.bottom > limit {
			c.clip_line(src[0], src[3], clip)
			return
		}
		mono_y := chop_cubic_at_extrema(src, true)
		for y := 0; y * 3 + 3 < mono_y.len; y++ {
			mono_x := chop_cubic_at_extrema(mono_y[y * 3..y * 3 + 4], false)
			for x := 0; x * 3 + 3 < mono_x.len; x++ {
				c.clip_mono_cubic(mono_x[x * 3..x * 3 + 4], clip)
			}
		}
	}
}

fn chop_cubic_in_y(mut pts []Point, clip Rect) {
	if pts[0].y < clip.top {
		mut tmp := chop_mono_cubic_at_clip(pts, clip.top, true)
		if tmp[3].y < clip.top && tmp[4].y < clip.top && tmp[5].y < clip.top {
			tmp = chop_mono_cubic_at_clip(tmp[3..7], clip.top, true)
		}
		tmp[3].y = clip.top
		if tmp[4].y < clip.top {
			tmp[4].y = clip.top
		}
		pts[0] = tmp[3]
		pts[1] = tmp[4]
		pts[2] = tmp[5]
	}
	if pts[3].y > clip.bottom {
		mut tmp := chop_mono_cubic_at_clip(pts, clip.bottom, true)
		tmp[3].y = clip.bottom
		if tmp[2].y > clip.bottom {
			tmp[2].y = clip.bottom
		}
		pts[1] = tmp[1]
		pts[2] = tmp[2]
		pts[3] = tmp[3]
	}
}

fn (mut c EdgeClipper) append_cubic(pts []Point, reverse bool) {
	if reverse {
		c.segments << ClippedSegment{.cubic, [pts[3], pts[2], pts[1], pts[0]]}
	} else {
		c.segments << ClippedSegment{.cubic, [pts[0], pts[1], pts[2], pts[3]]}
	}
}

// SkEdgeClipper::clipMonoCubic(): src is monotonic in X and Y.
fn (mut c EdgeClipper) clip_mono_cubic(src []Point, clip Rect) {
	mut pts, mut reverse := sort_increasing_y(src)
	if pts[3].y <= clip.top || pts[0].y >= clip.bottom {
		return
	}
	chop_cubic_in_y(mut pts, clip)
	if pts[0].x > pts[3].x {
		pts[0], pts[3] = pts[3], pts[0]
		pts[1], pts[2] = pts[2], pts[1]
		reverse = !reverse
	}
	if pts[3].x <= clip.left {
		c.append_vline(clip.left, pts[0].y, pts[3].y, reverse)
		return
	}
	if pts[0].x >= clip.right {
		if !c.can_cull_to_the_right {
			c.append_vline(clip.right, pts[0].y, pts[3].y, reverse)
		}
		return
	}
	if pts[0].x < clip.left {
		mut tmp := chop_mono_cubic_at_clip(pts, clip.left, false)
		c.append_vline(clip.left, tmp[0].y, tmp[3].y, reverse)
		tmp[3].x = clip.left
		if tmp[4].x < clip.left {
			tmp[4].x = clip.left
		}
		pts[0] = tmp[3]
		pts[1] = tmp[4]
		pts[2] = tmp[5]
	}
	if pts[3].x > clip.right {
		mut tmp := chop_mono_cubic_at_clip(pts, clip.right, false)
		tmp[3].x = clip.right
		if tmp[2].x > clip.right {
			tmp[2].x = clip.right
		}
		c.append_cubic(tmp[..4], reverse)
		c.append_vline(clip.right, tmp[3].y, tmp[6].y, reverse)
	} else {
		c.append_cubic(pts, reverse)
	}
}
