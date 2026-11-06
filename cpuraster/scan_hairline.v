module cpuraster

import math

// Anti-aliased hairlines as LibWeb Skia (google/skia ee20d565) draws them:
// SkScan_Hairline.cpp's hair_path() flattens each segment into lines, and
// SkScan_Antihair.cpp's AntiHairLineRgn() draws every line one pixel wide,
// each segment separately (overlaps blend twice), through a rectangular
// raster clip.

pub enum StrokeCap {
	butt
	round
	square
}

const max_cubic_subdivide_level = 9
const max_quad_subdivide_level = 5
const hline_stack_buffer = 100
const fdot6_one = 64
const fdot6_half = 32

// anti_hair_path draws device-space path as an anti-aliased hairline with
// cap, clipped to clip: SkScan::AntiHairPath, AntiHairSquarePath and
// AntiHairRoundPath behind Draw::drawDevPath().
pub fn anti_hair_path(path Path, cap StrokeCap, clip IRect, mut blitter Blitter) {
	// SkPathPriv::Raw() refuses non-finite points; drawDevPath() skips paths
	// too big for math.
	bounds := path.bounds() or { return }
	limit := f32(3.4028235e38) * f32(0.25)
	if !(bounds.left >= -limit && bounds.top >= -limit && bounds.right <= limit
		&& bounds.bottom <= limit) {
		return
	}
	if path.verbs.len == 0 || clip.is_empty() {
		return
	}
	mut scratch := HairScratch{
		aa:   []u8{len: hline_stack_buffer}
		runs: []i16{len: hline_stack_buffer + 1}
	}
	cap_out := if cap == .butt { 1 } else { 2 }
	rounded := round_out(bounds)
	ibounds := IRect{saturate_i32(rounded.left - cap_out), saturate_i32(rounded.top - cap_out), saturate_i32(rounded.right +
		cap_out), saturate_i32(rounded.bottom + cap_out)}
	_ := ibounds.intersect(clip) or { return }
	mut clipped := false
	mut inset := Rect{}
	mut outset := Rect{}
	if !clip.contains(ibounds) {
		clipped = true
		inset = Rect{f32(clip.left), f32(clip.top), f32(clip.right), f32(clip.bottom)}
		outset = Rect{inset.left - 1, inset.top - 1, inset.right + 1, inset.bottom + 1}
		inset = Rect{inset.left + 1, inset.top + 1, inset.right - 1, inset.bottom - 1}
		if inset.left > inset.right || inset.top > inset.bottom {
			inset = Rect{}
		}
	}
	mut pts := [4]Point{}
	mut first_pt := Point{}
	mut last_pt := Point{}
	mut prev_verb := -1
	mut pi := 0
	mut wi := 0
	for vi, verb in path.verbs {
		next_verb := if vi + 1 < path.verbs.len { int(path.verbs[vi + 1]) } else { -1 }
		match verb {
			.move {
				first_pt = path.points[pi]
				last_pt = first_pt
				pi++
			}
			.line {
				pts[0] = path.points[pi - 1]
				pts[1] = path.points[pi]
				pi++
				if cap != .butt {
					extend_pts(cap, prev_verb, next_verb, mut pts, 2)
				}
				anti_hair_line_rgn(pts[..2], clip, clipped, mut blitter, mut scratch)
				last_pt = pts[1]
			}
			.quad {
				for k in 0 .. 3 {
					pts[k] = path.points[pi - 1 + k]
				}
				pi += 2
				if cap != .butt {
					extend_pts(cap, prev_verb, next_verb, mut pts, 3)
				}
				hairquad(pts[..3], clip, clipped, inset, outset, compute_quad_level(pts[..3]), mut
					blitter, mut scratch)
				last_pt = pts[2]
			}
			.conic {
				for k in 0 .. 3 {
					pts[k] = path.points[pi - 1 + k]
				}
				pi += 2
				w := path.weights[wi]
				wi++
				if cap != .butt {
					extend_pts(cap, prev_verb, next_verb, mut pts, 3)
				}
				quads := conic_to_quads(pts[..3], w, f32(0.25))
				for q := 0; q + 2 < quads.len; q += 2 {
					quad := quads[q..q + 3]
					hairquad(quad, clip, clipped, inset, outset, compute_quad_level(quad), mut
						blitter, mut scratch)
				}
				last_pt = pts[2]
			}
			.cubic {
				for k in 0 .. 4 {
					pts[k] = path.points[pi - 1 + k]
				}
				pi += 3
				if cap != .butt {
					extend_pts(cap, prev_verb, next_verb, mut pts, 4)
				}
				haircubic(pts[..4], clip, clipped, inset, outset, mut blitter, mut scratch)
				last_pt = pts[3]
			}
			.close {
				pts[0] = last_pt
				pts[1] = first_pt
				if cap != .butt && prev_verb == int(PathVerb.move) {
					// Cap moveTo/close to match SVG for degenerate segments.
					extend_pts(cap, prev_verb, next_verb, mut pts, 2)
				}
				anti_hair_line_rgn(pts[..2], clip, clipped, mut blitter, mut scratch)
			}
		}
		if cap != .butt {
			if prev_verb == int(PathVerb.move) && verb in [PathVerb.line, .quad, .conic, .cubic] {
				// The curve moved the initial point, so close to it instead.
				first_pt = pts[0]
			}
			prev_verb = int(verb)
		}
	}
}

struct HairScratch {
mut:
	aa   []u8
	runs []i16
}

@[inline]
fn saturate_i32(v int) int {
	return if v > max_i32 {
		max_i32
	} else if v < min_i32 {
		min_i32
	} else {
		v
	}
}

// SkPoint::normalize(): scaled in doubles; (0, 0) when the result is not
// finite or zero.
fn normalize_point(p Point) Point {
	xx := f64(p.x)
	yy := f64(p.y)
	x2 := xx * xx
	y2 := yy * yy
	sum := x2 + y2
	dmag := math.sqrt(sum)
	dscale := 1.0 / dmag
	x := f32(f64(p.x) * dscale)
	y := f32(f64(p.y) * dscale)
	if !is_finite_f32(x) || !is_finite_f32(y) || (x == 0 && y == 0) {
		return Point{}
	}
	return Point{x, y}
}

// extend_pts(): move the end points half a unit (square) or pi/8 (round)
// along their tangents to cover the cap, moving coincident control points
// with them.
fn extend_pts(cap StrokeCap, prev_verb int, next_verb int, mut pts [4]Point, count int) {
	cap_outset := if cap == .square { f32(0.5) } else { scalar_pi / f32(8) }
	if prev_verb == int(PathVerb.move) {
		mut ctrl := 0
		mut controls := count - 1
		mut tangent := Point{}
		for {
			ctrl++
			tangent = Point{pts[0].x - pts[ctrl].x, pts[0].y - pts[ctrl].y}
			if !(tangent.x == 0 && tangent.y == 0) {
				break
			}
			controls--
			if controls <= 0 {
				break
			}
		}
		if tangent.x == 0 && tangent.y == 0 {
			tangent = Point{1, 0}
			controls = count - 1
		} else {
			tangent = normalize_point(tangent)
		}
		mut first := 0
		for {
			dx := tangent.x * cap_outset
			dy := tangent.y * cap_outset
			pts[first].x += dx
			pts[first].y += dy
			first++
			controls++
			if controls >= count {
				break
			}
		}
	}
	if next_verb == -1 || next_verb == int(PathVerb.move) || next_verb == int(PathVerb.close) {
		last := count - 1
		mut ctrl := last
		mut controls := count - 1
		mut tangent := Point{}
		for {
			ctrl--
			tangent = Point{pts[last].x - pts[ctrl].x, pts[last].y - pts[ctrl].y}
			if !(tangent.x == 0 && tangent.y == 0) {
				break
			}
			controls--
			if controls <= 0 {
				break
			}
		}
		if tangent.x == 0 && tangent.y == 0 {
			tangent = Point{-1, 0}
			controls = count - 1
		} else {
			tangent = normalize_point(tangent)
		}
		mut index := last
		for {
			dx := tangent.x * cap_outset
			dy := tangent.y * cap_outset
			pts[index].x += dx
			pts[index].y += dy
			index--
			controls++
			if controls >= count {
				break
			}
		}
	}
}

// compute_int_quad_dist(): the cheap distance from the control point to the
// chord's midpoint, in whole pixels.
fn compute_int_quad_dist(pts []Point) u32 {
	sx := pts[0].x + pts[2].x
	hx := sx * f32(0.5)
	dx := f32(math.abs(hx - pts[1].x))
	sy := pts[0].y + pts[2].y
	hy := sy * f32(0.5)
	dy := f32(math.abs(hy - pts[1].y))
	idx := u32(saturate_to_i32(ceil_f32(dx)))
	idy := u32(saturate_to_i32(ceil_f32(dy)))
	return if idx > idy { idx + (idy >> 1) } else { idy + (idx >> 1) }
}

fn compute_quad_level(pts []Point) int {
	d := compute_int_quad_dist(pts)
	// Quadratics approach their chord 4x closer with each subdivision.
	mut level := (33 - leading_zeros_u32(d)) >> 1
	if level > max_quad_subdivide_level {
		level = max_quad_subdivide_level
	}
	return level
}

@[inline]
fn leading_zeros_u32(v u32) int {
	if v == 0 {
		return 32
	}
	mut n := 0
	mut x := v
	for x & 0x80000000 == 0 {
		x <<= 1
		n++
	}
	return n
}

fn points_bounds_nocheck(pts []Point) Rect {
	mut r := Rect{pts[0].x, pts[0].y, pts[0].x, pts[0].y}
	for p in pts[1..] {
		r.left = fmin(r.left, p.x)
		r.top = fmin(r.top, p.y)
		r.right = fmax(r.right, p.x)
		r.bottom = fmax(r.bottom, p.y)
	}
	return r
}

// geometric_overlap() and geometric_contains(): empty rects count, as a
// stroked horizontal line still draws.
fn geometric_overlap(a Rect, b Rect) bool {
	return a.left < b.right && b.left < a.right && a.top < b.bottom && b.top < a.bottom
}

fn geometric_contains(outer Rect, inner Rect) bool {
	return inner.right <= outer.right && inner.left >= outer.left && inner.bottom <= outer.bottom
		&& inner.top >= outer.top
}

// hairquad(): cull against the clip, then hair_quad() evaluates
// (A * t + B) * t + C at 1 << level uniform steps.
fn hairquad(pts []Point, clip IRect, clipped_in bool, inset Rect, outset Rect, level int, mut blitter Blitter, mut scratch HairScratch) {
	mut clipped := clipped_in
	if clipped {
		bounds := points_bounds_nocheck(pts)
		if !geometric_overlap(outset, bounds) {
			return
		}
		if geometric_contains(inset, bounds) {
			clipped = false
		}
	}
	c := pts[0]
	b := Point{(pts[1].x - c.x) + (pts[1].x - c.x), (pts[1].y - c.y) + (pts[1].y - c.y)}
	p1x2 := pts[1].x + pts[1].x
	p1y2 := pts[1].y + pts[1].y
	ax := pts[2].x - p1x2
	ay := pts[2].y - p1y2
	a := Point{ax + c.x, ay + c.y}
	lines := 1 << level
	dt := f32(1) / f32(lines)
	mut tmp := []Point{len: lines + 1}
	tmp[0] = pts[0]
	mut t := f32(0)
	for i in 1 .. lines {
		t = t + dt
		tmp[i] = Point{quad_eval(a.x, b.x, c.x, t), quad_eval(a.y, b.y, c.y, t)}
	}
	tmp[lines] = pts[2]
	anti_hair_line_rgn(tmp, clip, clipped, mut blitter, mut scratch)
}

@[inline]
fn quad_eval(a f32, b f32, c f32, t f32) f32 {
	at := a * t
	atb := at + b
	atbt := atb * t
	return atbt + c
}

@[inline]
fn cubic_eval(a f32, b f32, c f32, d f32, t f32) f32 {
	at := a * t
	atb := at + b
	atbt := atb * t
	atbtc := atbt + c
	atbtct := atbtc * t
	return atbtct + d
}

// compute_cubic_segs(): how far the control points stray from the chord's
// thirds picks 1 to 512 lines.
fn compute_cubic_segs(pts []Point) int {
	one_third := f32(1) / f32(3)
	two_third := f32(2) / f32(3)
	mut diff := f32(0)
	for axis in 0 .. 2 {
		p0 := if axis == 0 { pts[0].x } else { pts[0].y }
		p1 := if axis == 0 { pts[1].x } else { pts[1].y }
		p2 := if axis == 0 { pts[2].x } else { pts[2].y }
		p3 := if axis == 0 { pts[3].x } else { pts[3].y }
		a13 := one_third * p3
		b13 := two_third * p0
		p13 := a13 + b13
		a23 := one_third * p0
		b23 := two_third * p3
		p23 := a23 + b23
		d1 := f32(math.abs(p1 - p13))
		d2 := f32(math.abs(p2 - p23))
		m := fmax(d1, d2)
		if axis == 0 || diff < m {
			diff = m
		}
	}
	mut tol := f32(1) / f32(8)
	for i in 0 .. max_cubic_subdivide_level {
		if diff < tol {
			return 1 << i
		}
		tol *= 4
	}
	return 1 << max_cubic_subdivide_level
}

fn lt_90(p0 Point, pivot Point, p2 Point) bool {
	return dot_product(Point{p0.x - pivot.x, p0.y - pivot.y}, Point{p2.x - pivot.x, p2.y - pivot.y}) >= 0
}

// quick_cubic_niceness_check(): the control points lie within the end points.
fn quick_cubic_niceness_check(pts []Point) bool {
	return lt_90(pts[1], pts[0], pts[3]) && lt_90(pts[2], pts[0], pts[3])
		&& lt_90(pts[1], pts[3], pts[0]) && lt_90(pts[2], pts[3], pts[0])
}

fn hair_cubic(pts []Point, clip IRect, clipped bool, mut blitter Blitter, mut scratch HairScratch) {
	lines := compute_cubic_segs(pts)
	if lines == 1 {
		anti_hair_line_rgn([pts[0], pts[3]], clip, clipped, mut blitter, mut scratch)
		return
	}
	// SkCubicCoeff
	mut coeff := [4][2]f32{}
	for axis in 0 .. 2 {
		p0 := if axis == 0 { pts[0].x } else { pts[0].y }
		p1 := if axis == 0 { pts[1].x } else { pts[1].y }
		p2 := if axis == 0 { pts[2].x } else { pts[2].y }
		p3 := if axis == 0 { pts[3].x } else { pts[3].y }
		d12 := p1 - p2
		d12x3 := f32(3) * d12
		a_partial := p3 + d12x3
		coeff[0][axis] = a_partial - p0
		p1x2 := p1 + p1
		b_partial := p2 - p1x2
		b_sum := b_partial + p0
		coeff[1][axis] = f32(3) * b_sum
		d10 := p1 - p0
		coeff[2][axis] = f32(3) * d10
		coeff[3][axis] = p0
	}
	dt := f32(1) / f32(lines)
	mut t := f32(0)
	mut tmp := []Point{len: lines + 1}
	tmp[0] = pts[0]
	mut finite := true
	for i in 1 .. lines {
		t = t + dt
		x := cubic_eval(coeff[0][0], coeff[1][0], coeff[2][0], coeff[3][0], t)
		y := cubic_eval(coeff[0][1], coeff[1][1], coeff[2][1], coeff[3][1], t)
		finite = finite && is_finite_f32(x) && is_finite_f32(y)
		tmp[i] = Point{x, y}
	}
	if finite {
		tmp[lines] = pts[3]
		anti_hair_line_rgn(tmp, clip, clipped, mut blitter, mut scratch)
	}
}

fn haircubic(pts []Point, clip IRect, clipped_in bool, inset Rect, outset Rect, mut blitter Blitter, mut scratch HairScratch) {
	mut clipped := clipped_in
	if clipped {
		bounds := points_bounds_nocheck(pts)
		if !geometric_overlap(outset, bounds) {
			return
		}
		if geometric_contains(inset, bounds) {
			clipped = false
		}
	}
	if quick_cubic_niceness_check(pts) {
		hair_cubic(pts, clip, clipped, mut blitter, mut scratch)
		return
	}
	chopped := chop_cubic_at_max_curvature(pts)
	for i := 0; i + 3 < chopped.len; i += 3 {
		hair_cubic(chopped[i..i + 4], clip, clipped, mut blitter, mut scratch)
	}
}

// SkLineClipper::IntersectLine(): the part of the line inside clip; a line
// along a clip edge only survives when it is colinear with it.
fn intersect_line(src []Point, clip Rect) ?[2]Point {
	bounds := Rect{fmin(src[0].x, src[1].x), fmin(src[0].y, src[1].y), fmax(src[0].x, src[1].x), fmax(src[0].y, src[1].y)}
	if clip.left <= bounds.left && clip.top <= bounds.top && clip.right >= bounds.right
		&& clip.bottom >= bounds.bottom {
		return [src[0], src[1]]!
	}
	width := bounds.right - bounds.left
	height := bounds.bottom - bounds.top
	if nested_lt(bounds.right, clip.left, width) || nested_lt(clip.right, bounds.left, width)
		|| nested_lt(bounds.bottom, clip.top, height) || nested_lt(clip.bottom, bounds.top, height) {
		return none
	}
	mut index0 := 0
	mut index1 := 1
	if !(src[0].y < src[1].y) {
		index0 = 1
		index1 = 0
	}
	mut tmp := [src[0], src[1]]
	if tmp[index0].y < clip.top {
		tmp[index0] = Point{sect_with_horizontal(src, clip.top), clip.top}
	}
	if tmp[index1].y > clip.bottom {
		tmp[index1] = Point{sect_with_horizontal(src, clip.bottom), clip.bottom}
	}
	if tmp[0].x < tmp[1].x {
		index0 = 0
		index1 = 1
	} else {
		index0 = 1
		index1 = 0
	}
	if tmp[index1].x <= clip.left || tmp[index0].x >= clip.right {
		if tmp[0].x != tmp[1].x || tmp[0].x < clip.left || tmp[0].x > clip.right {
			return none
		}
	}
	if tmp[index0].x < clip.left {
		tmp[index0] = Point{clip.left, sect_with_vertical(tmp, clip.left)}
	}
	if tmp[index1].x > clip.right {
		tmp[index1] = Point{clip.right, sect_with_vertical(tmp, clip.right)}
	}
	return [tmp[0], tmp[1]]!
}

@[inline]
fn nested_lt(a f32, b f32, dim f32) bool {
	return a <= b && (a < b || dim > 0)
}

// SkScan::AntiHairLineRgn(): each line of the polyline, chopped to the
// SkFixed range and to the clip outset by a pixel, in 26.6 fixed point.
fn anti_hair_line_rgn(src []Point, clip IRect, clipped bool, mut blitter Blitter, mut scratch HairScratch) {
	if src.len == 0 || (clipped && clip.is_empty()) {
		return
	}
	limit := f32(32767)
	fixed_bounds := Rect{-limit, -limit, limit, limit}
	mut clip_bounds := Rect{}
	if clipped {
		clip_bounds = Rect{f32(clip.left) - 1, f32(clip.top) - 1, f32(clip.right) + 1, f32(clip.bottom) + 1}
	}
	for i in 0 .. src.len - 1 {
		mut pts := intersect_line(src[i..i + 2], fixed_bounds) or { continue }
		if clipped {
			pts = intersect_line(pts[..], clip_bounds) or { continue }
		}
		x0 := saturate_to_i32(pts[0].x * f32(fdot6_one))
		y0 := saturate_to_i32(pts[0].y * f32(fdot6_one))
		x1 := saturate_to_i32(pts[1].x * f32(fdot6_one))
		y1 := saturate_to_i32(pts[1].y * f32(fdot6_one))
		if clipped {
			ir := IRect{int(min_i32_value(x0, x1) >> 6) - 1, int(min_i32_value(y0, y1) >> 6) - 1, int((max_i32_value(x0, x1) +
				63) >> 6) + 1, int((max_i32_value(y0, y1) + 63) >> 6) + 1}
			r := ir.intersect(clip) or { continue }
			if !clip.contains(ir) {
				do_anti_hairline(x0, y0, x1, y1, r, true, mut blitter, mut scratch)
				continue
			}
		}
		do_anti_hairline(x0, y0, x1, y1, IRect{}, false, mut blitter, mut scratch)
	}
}

@[inline]
fn min_i32_value(a i32, b i32) i32 {
	return if a < b { a } else { b }
}

@[inline]
fn max_i32_value(a i32, b i32) i32 {
	return if a > b { a } else { b }
}

enum HairKind {
	hline
	horish
	vline
	vertish
}

@[inline]
fn scale_alpha_by_coverage(value int, coverage int) u8 {
	return u8((value * coverage) >> 6)
}

@[inline]
fn hair_fixed_to_alpha(f i32) int {
	return int((f >> 8) & 0xff)
}

@[inline]
fn fd6_frac(x i32) i32 {
	return x & (fdot6_one - 1)
}

// partial_pixel_coverage(): the fractional part, with whole pixels as 64.
@[inline]
fn partial_pixel_coverage(pos i32) i32 {
	return fd6_frac(pos - 1) + 1
}

// call_hline_blitter(): runs of at most HLINE_STACK_BUFFER pixels.
fn call_hline_blitter(mut blitter Blitter, x_in int, y int, count_in int, alpha u8, mut scratch HairScratch) {
	mut x := x_in
	mut count := count_in
	for {
		scratch.aa[0] = alpha
		n := if count > hline_stack_buffer { hline_stack_buffer } else { count }
		scratch.runs[0] = i16(n)
		scratch.runs[n] = 0
		blitter.blit_anti_h(x, y, mut scratch.aa, mut scratch.runs)
		x += n
		count -= n
		if count <= 0 {
			break
		}
	}
}

// SkAntiHairBlitter::drawCap() for the four line orientations.
// major is x for the horizontal kinds and y for the vertical ones.
fn hair_draw_cap(kind HairKind, major int, f i32, slope i32, coverage int, mut blitter Blitter, mut scratch HairScratch) i32 {
	match kind {
		.hline {
			fy := f + fixed_half
			y := fixed_floor_to_int(fy)
			a := hair_fixed_to_alpha(fy)
			mut ma := scale_alpha_by_coverage(a, coverage)
			if ma != 0 {
				call_hline_blitter(mut blitter, major, y, 1, ma, mut scratch)
			}
			ma = scale_alpha_by_coverage(255 - a, coverage)
			if ma != 0 {
				call_hline_blitter(mut blitter, major, y - 1, 1, ma, mut scratch)
			}
			return fy - fixed_half
		}
		.horish {
			fy := f + fixed_half
			lower_y := fixed_floor_to_int(fy)
			a := hair_fixed_to_alpha(fy)
			blitter.blit_anti_v2(major, lower_y - 1, scale_alpha_by_coverage(255 - a, coverage),
				scale_alpha_by_coverage(a, coverage))
			return fy + slope - fixed_half
		}
		.vline {
			fx := f + fixed_half
			x := fixed_floor_to_int(fx)
			a := hair_fixed_to_alpha(fx)
			mut ma := scale_alpha_by_coverage(a, coverage)
			if ma != 0 {
				blitter.blit_v(x, major, 1, ma)
			}
			ma = scale_alpha_by_coverage(255 - a, coverage)
			if ma != 0 {
				blitter.blit_v(x - 1, major, 1, ma)
			}
			return fx - fixed_half
		}
		.vertish {
			fx := f + fixed_half
			x := fixed_floor_to_int(fx)
			a := hair_fixed_to_alpha(fx)
			blitter.blit_anti_h2(x - 1, major, scale_alpha_by_coverage(255 - a, coverage),
				scale_alpha_by_coverage(a, coverage))
			return fx + slope - fixed_half
		}
	}
}

// SkAntiHairBlitter::drawLine(): full-coverage pixels from start to stop.
fn hair_draw_line(kind HairKind, start int, stop int, f i32, slope i32, mut blitter Blitter, mut scratch HairScratch) i32 {
	match kind {
		.hline {
			fy := f + fixed_half
			y := fixed_floor_to_int(fy)
			mut a := hair_fixed_to_alpha(fy)
			if a != 0 {
				call_hline_blitter(mut blitter, start, y, stop - start, u8(a), mut scratch)
			}
			a = 255 - a
			if a != 0 {
				call_hline_blitter(mut blitter, start, y - 1, stop - start, u8(a), mut
					scratch)
			}
			return fy - fixed_half
		}
		.horish {
			mut fy := f + fixed_half
			for x in start .. stop {
				lower_y := fixed_floor_to_int(fy)
				a := hair_fixed_to_alpha(fy)
				blitter.blit_anti_v2(x, lower_y - 1, u8(255 - a), u8(a))
				fy += slope
			}
			return fy - fixed_half
		}
		.vline {
			fx := f + fixed_half
			x := fixed_floor_to_int(fx)
			mut a := hair_fixed_to_alpha(fx)
			if a != 0 {
				blitter.blit_v(x, start, stop - start, u8(a))
			}
			a = 255 - a
			if a != 0 {
				blitter.blit_v(x - 1, start, stop - start, u8(a))
			}
			return fx - fixed_half
		}
		.vertish {
			mut fx := f + fixed_half
			for y in start .. stop {
				x := fixed_floor_to_int(fx)
				a := hair_fixed_to_alpha(fx)
				blitter.blit_anti_h2(x - 1, y, u8(255 - a), u8(a))
				fx += slope
			}
			return fx - fixed_half
		}
	}
}

// do_anti_hairline(): one 26.6 fixed-point line, split until it spans at
// most 511 pixels, then walked along its major axis with partial-coverage
// end caps.
fn do_anti_hairline(x0_in i32, y0_in i32, x1_in i32, y1_in i32, clip_in IRect, clipped_in bool, mut blitter Blitter, mut scratch HairScratch) {
	mut x0 := x0_in
	mut y0 := y0_in
	mut x1 := x1_in
	mut y1 := y1_in
	// any_bad_ints(): 0x80000000 comes from huge or NaN floats.
	if x0 == min_i32 || y0 == min_i32 || x1 == min_i32 || y1 == min_i32 {
		return
	}
	if abs32(x1 - x0) > 511 * fdot6_one || abs32(y1 - y0) > 511 * fdot6_one {
		hx := (x0 >> 1) + (x1 >> 1)
		hy := (y0 >> 1) + (y1 >> 1)
		do_anti_hairline(x0, y0, hx, hy, clip_in, clipped_in, mut blitter, mut scratch)
		do_anti_hairline(hx, hy, x1, y1, clip_in, clipped_in, mut blitter, mut scratch)
		return
	}
	mut clip := clip_in
	mut clipped := clipped_in
	mut start_coverage := i32(0)
	mut stop_coverage := i32(0)
	mut istart := 0
	mut istop := 0
	mut fstart := i32(0)
	mut slope := i32(0)
	mut kind := HairKind.hline
	if abs32(x1 - x0) > abs32(y1 - y0) {
		if x0 > x1 {
			x0, x1 = x1, x0
			y0, y1 = y1, y0
		}
		istart = int(x0 >> 6)
		istop = int((x1 + 63) >> 6)
		if y0 == y1 {
			slope = 0
			kind = .hline
			fstart = fdot6_to_fixed(y0)
		} else {
			slope = left_shift(y1 - y0, 16) / (x1 - x0)
			dx_to_center := fdot6_half - fd6_frac(x0)
			fstart = fdot6_to_fixed(y0) + ((slope * dx_to_center + fdot6_half) >> 6)
			kind = .horish
		}
		if istop - istart == 1 {
			start_coverage = x1 - x0
			stop_coverage = 0
		} else {
			start_coverage = fdot6_one - fd6_frac(x0)
			stop_coverage = fd6_frac(x1)
		}
		if clipped {
			if istart >= clip.right || istop <= clip.left {
				return
			}
			if istart < clip.left {
				fstart += slope * i32(clip.left - istart)
				istart = clip.left
				start_coverage = fdot6_one
				if istop - istart == 1 {
					start_coverage = partial_pixel_coverage(x1)
					stop_coverage = 0
				}
			}
			if istop > clip.right {
				istop = clip.right
				stop_coverage = 0
			}
			if istart == istop {
				return
			}
			mut top := 0
			mut bottom := 0
			span := i32(istop - istart - 1) * slope
			if slope >= 0 {
				top = fixed_floor_to_int(fstart - fixed_half)
				bottom = fixed_ceil_to_int(fstart + span + fixed_half)
			} else {
				bottom = fixed_ceil_to_int(fstart + fixed_half)
				top = fixed_floor_to_int(fstart + span - fixed_half)
			}
			top -= 1
			bottom += 1
			if top >= clip.bottom || bottom <= clip.top {
				return
			}
			if clip.top <= top && clip.bottom >= bottom {
				clipped = false
			}
		}
	} else {
		if y0 > y1 {
			x0, x1 = x1, x0
			y0, y1 = y1, y0
		}
		istart = int(y0 >> 6)
		istop = int((y1 + 63) >> 6)
		if x0 == x1 {
			if y0 == y1 {
				return
			}
			slope = 0
			kind = .vline
			fstart = fdot6_to_fixed(x0)
		} else {
			slope = left_shift(x1 - x0, 16) / (y1 - y0)
			dy_to_center := fdot6_half - fd6_frac(y0)
			fstart = fdot6_to_fixed(x0) + ((slope * dy_to_center + fdot6_half) >> 6)
			kind = .vertish
		}
		if istop - istart == 1 {
			start_coverage = y1 - y0
			stop_coverage = 0
		} else {
			start_coverage = fdot6_one - fd6_frac(y0)
			stop_coverage = fd6_frac(y1)
		}
		if clipped {
			if istart >= clip.bottom || istop <= clip.top {
				return
			}
			if istart < clip.top {
				fstart += slope * i32(clip.top - istart)
				istart = clip.top
				start_coverage = fdot6_one
				if istop - istart == 1 {
					start_coverage = partial_pixel_coverage(y1)
					stop_coverage = 0
				}
			}
			if istop > clip.bottom {
				istop = clip.bottom
				stop_coverage = 0
			}
			if istart == istop {
				return
			}
			mut left := 0
			mut right := 0
			span := i32(istop - istart - 1) * slope
			if slope >= 0 {
				left = fixed_floor_to_int(fstart - fixed_half)
				right = fixed_ceil_to_int(fstart + span + fixed_half)
			} else {
				right = fixed_ceil_to_int(fstart + fixed_half)
				left = fixed_floor_to_int(fstart + span - fixed_half)
			}
			left -= 1
			right += 1
			if left >= clip.right || right <= clip.left {
				return
			}
			if clip.left <= left && clip.right >= right {
				clipped = false
			}
		}
	}
	if clipped {
		mut wrapper := RectClipBlitter{
			clip:  clip
			inner: blitter
		}
		hair_walk(kind, istart, istop, fstart, slope, start_coverage, stop_coverage, mut
			wrapper, mut scratch)
		return
	}
	hair_walk(kind, istart, istop, fstart, slope, start_coverage, stop_coverage, mut blitter, mut
		scratch)
}

fn hair_walk(kind HairKind, istart_in int, istop int, fstart_in i32, slope i32, start_coverage i32, stop_coverage i32, mut blitter Blitter, mut scratch HairScratch) {
	mut istart := istart_in
	mut fstart := hair_draw_cap(kind, istart, fstart_in, slope, int(start_coverage), mut
		blitter, mut scratch)
	istart++
	full_spans := istop - istart - (if stop_coverage > 0 { 1 } else { 0 })
	if full_spans > 0 {
		fstart = hair_draw_line(kind, istart, istart + full_spans, fstart, slope, mut blitter, mut
			scratch)
	}
	if stop_coverage > 0 {
		hair_draw_cap(kind, istop - 1, fstart, slope, int(stop_coverage), mut blitter, mut
			scratch)
	}
}
