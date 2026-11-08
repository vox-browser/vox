module cpuraster

import math

// Paths as LibWeb Skia (google/skia ee20d565) builds and draws them:
// SkPathBuilder's verbs, SkPathData's bounds and device transform, and the
// convexity and rect queries the scan converter consults.

pub struct Point {
pub mut:
	x f32
	y f32
}

pub struct Rect {
pub mut:
	left   f32
	top    f32
	right  f32
	bottom f32
}

pub struct IRect {
pub mut:
	left   int
	top    int
	right  int
	bottom int
}

fn (r IRect) width() int {
	return r.right - r.left
}

fn (r IRect) height() int {
	return r.bottom - r.top
}

fn (r IRect) is_empty() bool {
	return r.left >= r.right || r.top >= r.bottom
}

fn (r IRect) contains(o IRect) bool {
	return !r.is_empty() && !o.is_empty() && r.left <= o.left && r.top <= o.top
		&& r.right >= o.right && r.bottom >= o.bottom
}

fn (r IRect) intersect(o IRect) ?IRect {
	left := math.max(r.left, o.left)
	top := math.max(r.top, o.top)
	right := math.min(r.right, o.right)
	bottom := math.min(r.bottom, o.bottom)
	if left >= right || top >= bottom {
		return none
	}
	return IRect{left, top, right, bottom}
}

pub enum PathFillType {
	winding
	even_odd
	inverse_winding
	inverse_even_odd
}

pub enum PathVerb {
	move
	line
	quad
	conic
	cubic
	close
}

enum PathConvexity {
	convex_cw
	convex_ccw
	convex_degenerate
	concave
}

const segment_line = 1
const segment_quad = 2
const segment_conic = 4
const segment_cubic = 8

// Path is an immutable SkPath.
pub struct Path {
	convex_hint PathConvexity = .concave
pub:
	verbs     []PathVerb
	points    []Point
	weights   []f32
	fill_type PathFillType
}

// PathBuilder mirrors SkPathBuilder's moveTo/lineTo/quadTo/conicTo/cubicTo/close.
pub struct PathBuilder {
mut:
	verbs     []PathVerb
	points    []Point
	weights   []f32
	last_move int = -1
pub mut:
	fill_type PathFillType
}

pub fn (mut b PathBuilder) move_to(x f32, y f32) {
	if b.verbs.len > 0 && b.verbs.last() == .move {
		b.points[b.points.len - 1] = Point{x, y}
		return
	}
	b.last_move = b.points.len
	b.points << Point{x, y}
	b.verbs << .move
}

// SkPathBuilder::ensureMove().
fn (mut b PathBuilder) ensure_move() {
	if b.verbs.len == 0 {
		b.move_to(0, 0)
	} else if b.verbs.last() == .close {
		p := b.points[b.last_move]
		b.move_to(p.x, p.y)
	}
}

pub fn (mut b PathBuilder) line_to(x f32, y f32) {
	b.ensure_move()
	b.points << Point{x, y}
	b.verbs << .line
}

pub fn (mut b PathBuilder) quad_to(x1 f32, y1 f32, x2 f32, y2 f32) {
	b.ensure_move()
	b.points << Point{x1, y1}
	b.points << Point{x2, y2}
	b.verbs << .quad
}

pub fn (mut b PathBuilder) conic_to(x1 f32, y1 f32, x2 f32, y2 f32, w f32) {
	b.ensure_move()
	b.points << Point{x1, y1}
	b.points << Point{x2, y2}
	if w == 1 {
		b.verbs << .quad
	} else {
		b.verbs << .conic
		b.weights << w
	}
}

pub fn (mut b PathBuilder) cubic_to(x1 f32, y1 f32, x2 f32, y2 f32, x3 f32, y3 f32) {
	b.ensure_move()
	b.points << Point{x1, y1}
	b.points << Point{x2, y2}
	b.points << Point{x3, y3}
	b.verbs << .cubic
}

pub fn (mut b PathBuilder) close() {
	if b.verbs.len > 0 && b.verbs.last() != .close {
		b.ensure_move()
		b.verbs << .close
	}
}

// detach mirrors SkPathBuilder::detach() with the SkPathRef path backend
// LibWeb's macOS Skia uses: verbs, points and weights are kept as built,
// including a trailing move, which still counts toward the bounds. (Linux
// defines SK_HIDE_PATH_EDIT_METHODS and uses SkPathData, which trims it.)
pub fn (mut b PathBuilder) detach() Path {
	path := Path{
		verbs:     b.verbs.clone()
		points:    b.points.clone()
		weights:   b.weights.clone()
		fill_type: b.fill_type
	}
	b.verbs.clear()
	b.points.clear()
	b.weights.clear()
	b.last_move = -1
	b.fill_type = .winding
	return path
}

@[inline]
fn is_finite_f32(v f32) bool {
	return math.f32_bits(v) & 0x7f800000 != 0x7f800000
}

fn (p Path) is_inverse_fill() bool {
	return p.fill_type == .inverse_winding || p.fill_type == .inverse_even_odd
}

fn (p Path) is_even_odd() bool {
	return p.fill_type == .even_odd || p.fill_type == .inverse_even_odd
}

fn (p Path) segment_mask() int {
	mut mask := 0
	for verb in p.verbs {
		mask |= match verb {
			.line { segment_line }
			.quad { segment_quad }
			.conic { segment_conic }
			.cubic { segment_cubic }
			else { 0 }
		}
	}
	return mask
}

// SkRect::Bounds(): fminf/fmaxf over the points; none when any is not finite.
fn (p Path) bounds() ?Rect {
	if p.points.len == 0 {
		return Rect{}
	}
	mut r := Rect{p.points[0].x, p.points[0].y, p.points[0].x, p.points[0].y}
	mut nx := f32(0)
	mut ny := f32(0)
	for point in p.points {
		r.left = f32(math.min(point.x, r.left))
		r.top = f32(math.min(point.y, r.top))
		r.right = f32(math.max(point.x, r.right))
		r.bottom = f32(math.max(point.y, r.bottom))
		nx = nx * point.x
		ny = ny * point.y
	}
	if !is_finite_f32(nx) || !is_finite_f32(ny) || nx != nx || ny != ny {
		return none
	}
	return r
}

// Matrix is an affine SkMatrix: [a c e; b d f], as Canvas2D passes it.
pub struct Matrix {
pub:
	a f32 = 1
	b f32
	c f32
	d f32 = 1
	e f32
	f f32
}

fn (m Matrix) is_identity() bool {
	return m.a == 1 && m.b == 0 && m.c == 0 && m.d == 1 && m.e == 0 && m.f == 0
}

// SkMatrix::mapPoints() with the proc its type mask selects.
fn (m Matrix) map_point(p Point) Point {
	if m.b == 0 && m.c == 0 {
		if m.a == 1 && m.d == 1 {
			return Point{p.x + m.e, p.y + m.f}
		}
		sx := p.x * m.a
		sy := p.y * m.d
		return Point{sx + m.e, sy + m.f}
	}
	xx := p.x * m.a
	xy := p.y * m.c
	x := xx + xy
	yy := p.y * m.d
	yx := p.x * m.b
	y := yy + yx
	return Point{x + m.e, y + m.f}
}

// SkPathData::MakeTransform() for an affine matrix.
pub fn (p Path) transform(m Matrix) Path {
	if m.is_identity() {
		return p
	}
	// SkPathPriv::TransformConvexity discards the hint under a rotation or
	// skew: floating point mapping can make even a convex contour concave.
	mut hint := PathConvexity.concave
	if p.convex_hint != .concave && m.b == 0 && m.c == 0 {
		determinant := m.a * m.d
		hint = if determinant == 0 { PathConvexity.convex_degenerate }
			else if determinant < 0 && p.convex_hint == .convex_cw { PathConvexity.convex_ccw }
			else if determinant < 0 && p.convex_hint == .convex_ccw { PathConvexity.convex_cw } else { p.convex_hint }
	}
	return Path{
		convex_hint: hint
		verbs:     p.verbs
		points:    p.points.map(m.map_point(it))
		weights:   p.weights
		fill_type: p.fill_type
	}
}

// Convexicator and SkPathPriv::ComputeConvexity().
const dir_unknown = 0
const dir_left = 1
const dir_right = 2
const dir_straight = 3
const dir_backwards = 4
const dir_invalid = 5

struct Convexicator {
mut:
	first_pt        Point
	first_vec       Point
	last_pt         Point
	last_vec        Point
	expected_dir    int = dir_invalid
	first_direction int // 0 unknown, 1 cw, 2 ccw
	reversals       int
	is_finite       bool = true
}

fn (mut c Convexicator) set_move_pt(p Point) {
	c.first_pt = p
	c.last_pt = p
	c.expected_dir = dir_invalid
}

fn (mut c Convexicator) add_pt(p Point) bool {
	if c.last_pt == p {
		return true
	}
	if c.first_pt == c.last_pt && c.expected_dir == dir_invalid && c.last_vec.x == 0
		&& c.last_vec.y == 0 {
		c.last_vec = Point{p.x - c.last_pt.x, p.y - c.last_pt.y}
		c.first_vec = c.last_vec
	} else if !c.add_vec(Point{p.x - c.last_pt.x, p.y - c.last_pt.y}) {
		return false
	}
	c.last_pt = p
	return true
}

fn cross_product(a Point, b Point) f32 {
	ab := a.x * b.y
	ba := a.y * b.x
	return ab - ba
}

fn dot_product(a Point, b Point) f32 {
	xx := a.x * b.x
	yy := a.y * b.y
	return xx + yy
}

fn (c Convexicator) direction_change(v Point) int {
	cross := cross_product(c.last_vec, v)
	if !is_finite_f32(cross) {
		return dir_unknown
	}
	if cross == 0 {
		return if dot_product(c.last_vec, v) < 0 { dir_backwards } else { dir_straight }
	}
	return if cross > 0 { dir_right } else { dir_left }
}

fn (mut c Convexicator) add_vec(v Point) bool {
	dir := c.direction_change(v)
	match dir {
		dir_left, dir_right {
			if c.expected_dir == dir_invalid {
				c.expected_dir = dir
				c.first_direction = if dir == dir_right { 1 } else { 2 }
			} else if dir != c.expected_dir {
				c.first_direction = 0
				return false
			}
			c.last_vec = v
		}
		dir_straight {}
		dir_backwards {
			c.last_vec = v
			c.reversals++
			return c.reversals < 3
		}
		else {
			c.is_finite = false
			return false
		}
	}
	return true
}

fn (mut c Convexicator) close() bool {
	return c.add_pt(c.first_pt) && c.add_vec(c.first_vec)
}

fn is_concave_by_sign(points []Point) bool {
	if points.len <= 3 {
		return false
	}
	mut index := 0
	mut curr := points[index]
	index++
	first := curr
	mut dxes := 0
	mut dyes := 0
	mut last_sx := 2
	mut last_sy := 2
	for outer in 0 .. 2 {
		for index <= points.len {
			// The second pass visits only the closing vector back to firstPt.
			next := if index == points.len { first } else { points[index] }
			if outer == 0 && index == points.len {
				break
			}
			vec := Point{next.x - curr.x, next.y - curr.y}
			if vec.x != 0 || vec.y != 0 {
				if !is_finite_f32(vec.x) || !is_finite_f32(vec.y) {
					return true
				}
				sx := if vec.x < 0 { 1 } else { 0 }
				sy := if vec.y < 0 { 1 } else { 0 }
				if sx != last_sx {
					dxes++
				}
				if sy != last_sy {
					dyes++
				}
				if dxes > 3 || dyes > 3 {
					return true
				}
				last_sx = sx
				last_sy = sy
			}
			curr = next
			index++
			if outer == 1 {
				break
			}
		}
		index = points.len
	}
	return false
}

fn verb_point_count(v PathVerb) int {
	return match v {
		.move, .line { 1 }
		.quad, .conic { 2 }
		.cubic { 3 }
		.close { 0 }
	}
}

fn (p Path) convexity() PathConvexity {
	if p.convex_hint != .concave { return p.convex_hint }
	mut verb_count := p.verbs.len
	mut point_count := p.points.len
	for verb_count > 0 && p.verbs[verb_count - 1] == .move {
		verb_count--
		point_count--
	}
	if verb_count == 0 {
		return .convex_degenerate
	}
	if is_concave_by_sign(p.points[..point_count]) {
		return .concave
	}
	mut contour_count := 0
	mut needs_close := false
	mut state := Convexicator{}
	mut pi := 0
	for vi in 0 .. verb_count {
		verb := p.verbs[vi]
		if contour_count == 0 {
			if verb == .move {
				state.set_move_pt(p.points[pi])
			} else {
				contour_count++
				needs_close = true
			}
		}
		if contour_count == 1 {
			if verb == .close || verb == .move {
				if !state.close() {
					return .concave
				}
				needs_close = false
				contour_count++
			} else {
				for i in 0 .. verb_point_count(verb) {
					if !state.add_pt(p.points[pi + i]) {
						return .concave
					}
				}
			}
		} else if verb != .move {
			return .concave
		}
		pi += verb_point_count(verb)
	}
	if needs_close && !state.close() {
		return .concave
	}
	if state.first_direction == 0 && state.reversals >= 3 {
		return .concave
	}
	return match state.first_direction {
		1 { PathConvexity.convex_cw }
		2 { PathConvexity.convex_ccw }
		else { PathConvexity.convex_degenerate }
	}
}

// SkPathPriv::IsRectContour(..., allowPartial = false) for SkPathRaw::isRect().
fn rect_make_dir(dx f32, dy f32) int {
	return int(dx != 0) | (int(dx > 0 || dy > 0) << 1)
}

fn trivial_rect(pts []Point, verbs []PathVerb) ?Rect {
	if pts.len != 4 || verbs.len != 5 || verbs[0] != .move || verbs[1] != .line
		|| verbs[2] != .line || verbs[3] != .line || verbs[4] != .close {
		return none
	}
	v0 := Point{pts[1].x - pts[0].x, pts[1].y - pts[0].y}
	v1 := Point{pts[2].x - pts[1].x, pts[2].y - pts[1].y}
	v2 := Point{pts[3].x - pts[2].x, pts[3].y - pts[2].y}
	v3 := Point{pts[0].x - pts[3].x, pts[0].y - pts[3].y}
	if !(((v0.x == 0) != (v0.y == 0)) && axis_aligned_orthogonal(v0, v1)
		&& axis_aligned_orthogonal(v1, v2) && axis_aligned_orthogonal(v2, v3)) {
		return none
	}
	return sorted_rect(pts[0], pts[2])
}

fn axis_aligned_orthogonal(a Point, b Point) bool {
	return ((a.x == 0) != (b.x == 0)) && ((a.y == 0) != (b.y == 0))
}

fn sorted_rect(a Point, b Point) Rect {
	return Rect{f32(math.min(a.x, b.x)), f32(math.min(a.y, b.y)), f32(math.max(a.x, b.x)), f32(math.max(a.y,
		b.y))}
}

fn (p Path) is_rect() ?Rect {
	rc := p.rect_contour() or { return none }
	return rc.rect
}

// SkPathPriv::RectContour: the rect, whether its contour was closed and
// whether it runs clockwise.
struct RectContour {
	rect   Rect
	closed bool
	cw     bool
}

// SkPathPriv::IsRectContour(..., allowPartial = false), as SkPath::isRect()
// and SkPathRaw::isRect() call it.
fn (p Path) rect_contour() ?RectContour {
	if p.segment_mask() != segment_line || p.points.len < 4 || p.verbs.len < 4 {
		return none
	}
	if r := trivial_rect(p.points, p.verbs) {
		v0 := Point{p.points[1].x - p.points[0].x, p.points[1].y - p.points[0].y}
		v1 := Point{p.points[2].x - p.points[1].x, p.points[2].y - p.points[1].y}
		return RectContour{r, true, cross_product(v0, v1) > 0}
	}
	pts := p.points
	mut pi := 0
	mut corners := 0
	mut line_start := Point{}
	mut first_pt := -1
	mut last_pt := -1
	mut first_corner := Point{}
	mut third_corner := Point{}
	mut directions := [-1, -1, -1, -1, -1]
	mut closed_or_moved := false
	mut auto_close := false
	for verb in p.verbs {
		match verb {
			.close, .line {
				if verb != .close {
					last_pt = pi
				}
				line_end := if verb == .close { pts[first_pt] } else { pts[pi] }
				if verb != .close {
					pi++
				}
				if verb == .close {
					auto_close = true
				}
				delta := Point{line_end.x - line_start.x, line_end.y - line_start.y}
				if delta.x != 0 && delta.y != 0 {
					return none
				}
				if !is_finite_f32(delta.x) || !is_finite_f32(delta.y) {
					return none
				}
				if line_start == line_end {
					continue
				}
				next_direction := rect_make_dir(delta.x, delta.y)
				if corners == 0 {
					directions[0] = next_direction
					corners = 1
					closed_or_moved = false
					line_start = line_end
					continue
				}
				if closed_or_moved {
					return none
				}
				if auto_close && next_direction == directions[0] {
					continue
				}
				closed_or_moved = auto_close
				if directions[corners - 1] == next_direction {
					if corners == 3 && verb == .line {
						third_corner = line_end
					}
					line_start = line_end
					continue
				}
				directions[corners] = next_direction
				corners++
				match corners {
					2 {
						first_corner = line_start
					}
					3 {
						if directions[0] ^ directions[2] != 2 {
							return none
						}
						third_corner = line_end
					}
					4 {
						if directions[1] ^ directions[3] != 2 {
							return none
						}
					}
					else {
						return none
					}
				}
				line_start = line_end
			}
			.quad, .conic, .cubic {
				return none
			}
			.move {
				if corners == 0 {
					first_pt = pi
				} else {
					close_x := pts[first_pt].x - pts[last_pt].x
					close_y := pts[first_pt].y - pts[last_pt].y
					if close_x != 0 && close_y != 0 {
						return none
					}
				}
				line_start = pts[pi]
				pi++
				closed_or_moved = true
			}
		}
	}
	if corners < 3 || corners > 4 {
		return none
	}
	close_x := pts[first_pt].x - pts[last_pt].x
	close_y := pts[first_pt].y - pts[last_pt].y
	if close_x != 0 && close_y != 0 {
		return none
	}
	return RectContour{sorted_rect(first_corner, third_corner), auto_close, directions[0] == ((directions[1] +
		1) & 3)}
}

// glibc exposes the combined sin/cos entry point under GNU extensions.
#flag linux -D_GNU_SOURCE=1
#include "@DIR/path_math.h"

fn C.cpuraster_sincosf(x f32, s &f32, c &f32)
fn C.cosf(x f32) f32
fn C.tanf(x f32) f32
fn C.atan2f(y f32, x f32) f32
fn C.sqrtf(x f32) f32

// SK_ScalarPI.
const scalar_pi = f32(3.14159265)

@[inline]
fn abs_f32(v f32) f32 {
	return if v < 0 { -v } else { v }
}

// SkScalarSinSnapToZero() and SkScalarCosSnapToZero() of one angle.
fn sin_cos_snap_to_zero(radians f32) (f32, f32) {
	mut s := f32(0)
	mut c := f32(0)
	C.cpuraster_sincosf(radians, &s, &c)
	tolerance := f32(1) / f32(1 << 16)
	return if abs_f32(s) <= tolerance { f32(0) } else { s }, if abs_f32(c) <= tolerance {
		f32(0)
	} else {
		c
	}
}

// The 2x2 of an affine SkMatrix: (x * sx + y * kx, x * ky + y * sy).
struct Linear2 {
	sx f32
	kx f32
	ky f32
	sy f32
}

fn (m Linear2) map(p Point) Point {
	a := p.x * m.sx
	b := p.y * m.kx
	c := p.x * m.ky
	d := p.y * m.sy
	return Point{a + b, c + d}
}

// arc_to mirrors SkPathBuilder::arcTo(SkPoint rad, angle, arcLarge,
// arcSweep, endPt): an SVG elliptical arc from the last point, as conics.
// angle is in degrees; sweep_cw selects SkPathDirection::kCW.
pub fn (mut b PathBuilder) arc_to(rad_x f32, rad_y f32, angle f32, large bool, sweep_cw bool, x f32, y f32) {
	b.ensure_move()
	src0 := b.points.last()
	src1 := Point{x, y}
	if rad_x == 0 || rad_y == 0 {
		b.line_to(x, y)
		return
	}
	if src0 == src1 {
		b.line_to(x, y)
		return
	}
	mut rx := abs_f32(rad_x)
	mut ry := abs_f32(rad_y)
	mid_dx := src0.x - src1.x
	mid_dy := src0.y - src1.y
	mid := Point{mid_dx * f32(0.5), mid_dy * f32(0.5)}
	deg_to_rad := scalar_pi / f32(180)
	neg_rad := -angle * deg_to_rad
	s0, c0 := sin_cos_snap_to_zero(neg_rad)
	tm := Linear2{c0, -s0, s0, c0}.map(mid)
	square_rx := rx * rx
	square_ry := ry * ry
	square_x := tm.x * tm.x
	square_y := tm.y * tm.y
	qx := square_x / square_rx
	qy := square_y / square_ry
	mut radii_scale := qx + qy
	if radii_scale > 1 {
		radii_scale = C.sqrtf(radii_scale)
		rx *= radii_scale
		ry *= radii_scale
	}
	isx := f32(1) / rx
	isy := f32(1) / ry
	unit := Linear2{isx * c0, isx * -s0, isy * s0, isy * c0}
	mut u0 := unit.map(src0)
	mut u1 := unit.map(src1)
	mut delta := Point{u1.x - u0.x, u1.y - u0.y}
	dxx := delta.x * delta.x
	dyy := delta.y * delta.y
	d := dxx + dyy
	inv_d := f32(1) / d
	reduced := inv_d - f32(0.25)
	scale_factor_squared := if reduced > 0 { reduced } else { f32(0) }
	mut scale_factor := C.sqrtf(scale_factor_squared)
	if !sweep_cw != large {
		scale_factor = -scale_factor
	}
	delta = Point{delta.x * scale_factor, delta.y * scale_factor}
	sum := Point{u0.x + u1.x, u0.y + u1.y}
	mut center := Point{sum.x * f32(0.5), sum.y * f32(0.5)}
	center = Point{center.x + -delta.y, center.y + delta.x}
	u0 = Point{u0.x - center.x, u0.y - center.y}
	u1 = Point{u1.x - center.x, u1.y - center.y}
	theta1 := C.atan2f(u0.y, u0.x)
	theta2 := C.atan2f(u1.y, u1.x)
	mut theta_arc := theta2 - theta1
	two_pi := scalar_pi * f32(2)
	if theta_arc < 0 && sweep_cw {
		theta_arc += two_pi
	} else if theta_arc > 0 && !sweep_cw {
		theta_arc -= two_pi
	}
	if abs_f32(theta_arc) < scalar_pi / f32(1000 * 1000) {
		b.line_to(x, y)
		return
	}
	rad := angle * deg_to_rad
	s1, c1 := sin_cos_snap_to_zero(rad)
	xform := Linear2{c1 * rx, -s1 * ry, s1 * rx, c1 * ry}
	third := (f32(2) * scalar_pi) / f32(3)
	segments := int(saturate_to_i32(ceil_f32(abs_f32(theta_arc / third))))
	theta_width := theta_arc / f32(segments)
	t := C.tanf(f32(0.5) * theta_width)
	if !is_finite_f32(t) {
		return
	}
	mut start_theta := theta1
	half_cos := C.cosf(theta_width) * f32(0.5)
	w := C.sqrtf(f32(0.5) + half_cos)
	half_pi := scalar_pi / f32(2)
	expect_integers := abs_f32(half_pi - abs_f32(theta_width)) <= scalar_nearly_zero
		&& rx == floor_f32(rx) && ry == floor_f32(ry) && x == floor_f32(x) && y == floor_f32(y)
	for _ in 0 .. segments {
		end_theta := start_theta + theta_width
		sin_end, cos_end := sin_cos_snap_to_zero(end_theta)
		p1 := Point{cos_end + center.x, sin_end + center.y}
		ts := t * sin_end
		tc := -t * cos_end
		p0 := Point{p1.x + ts, p1.y + tc}
		mut m0 := xform.map(p0)
		mut m1 := xform.map(p1)
		if expect_integers {
			m0 = Point{floor_f32(m0.x + f32(0.5)), floor_f32(m0.y + f32(0.5))}
			m1 = Point{floor_f32(m1.x + f32(0.5)), floor_f32(m1.y + f32(0.5))}
		}
		b.conic_to(m0.x, m0.y, m1.x, m1.y, w)
		start_theta = end_theta
	}
	b.points[b.points.len - 1] = Point{x, y}
}
