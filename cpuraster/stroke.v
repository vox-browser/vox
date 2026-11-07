module cpuraster

import math

// Strokes as LibWeb Skia (google/skia ee20d565) builds them for SkDraw:
// skpathutils::FillPathWithPaint() hands the source path to
// SkStrokeRec::applyToPath(), whose SkStroke::strokePath() (SkStroke.cpp's
// SkPathStroker with SkStrokerPriv.cpp's caps and joins) returns the outline
// as a path to fill. The outline is built in source space; the canvas matrix
// only supplies its resolution scale. Every operation is a separate float
// operation, as Skia is compiled with -ffp-contract=off.

const scalar_root2_over2 = f32(0.707106781)
const scalar_sqrt2 = f32(1.41421356)

// kRecursiveLimits: tangent (cubic before its tangents meet), cubic, conic
// and quad.
const recursive_limit_tangent = 15
const recursive_limit_cubic = 24
const recursive_limit_conic = 33
const recursive_limit_quad = 33

// Point arithmetic, one float operation per component.
@[inline]
fn vadd(a Point, b Point) Point {
	return Point{a.x + b.x, a.y + b.y}
}

@[inline]
fn vsub(a Point, b Point) Point {
	return Point{a.x - b.x, a.y - b.y}
}

@[inline]
fn vmul(a Point, s f32) Point {
	return Point{a.x * s, a.y * s}
}

@[inline]
fn vneg(a Point) Point {
	return Point{-a.x, -a.y}
}

// SkPoint::isZero().
@[inline]
fn vzero(a Point) bool {
	return a.x == 0 && a.y == 0
}

@[inline]
fn point_is_finite(p Point) bool {
	return is_finite_f32(p.x) && is_finite_f32(p.y)
}

// SkPointPriv::CanNormalize().
@[inline]
fn can_normalize(dx f32, dy f32) bool {
	return is_finite_f32(dx) && is_finite_f32(dy) && (dx != 0 || dy != 0)
}

@[inline]
fn degenerate_vector(v Point) bool {
	return !can_normalize(v.x, v.y)
}

// SkPointPriv::DistanceToSqd().
fn distance_to_sqd(a Point, b Point) f32 {
	dx := a.x - b.x
	dy := a.y - b.y
	xx := dx * dx
	yy := dy * dy
	return xx + yy
}

// set_point_length<false>(): scales (x, y) to length in double precision.
// Returns none (SkPoint::setLength()'s (0, 0) and false) when the result is
// not finite or zero.
fn set_point_length(x f32, y f32, length f32) ?Point {
	xx := f64(x) * f64(x)
	yy := f64(y) * f64(y)
	dmag := math.sqrt(xx + yy)
	dscale := f64(length) / dmag
	rx := f32(f64(x) * dscale)
	ry := f32(f64(y) * dscale)
	if !is_finite_f32(rx) || !is_finite_f32(ry) || (rx == 0 && ry == 0) {
		return none
	}
	return Point{rx, ry}
}

// SkPoint::Length().
fn point_length(dx f32, dy f32) f32 {
	xx := dx * dx
	yy := dy * dy
	mag2 := xx + yy
	if is_finite_f32(mag2) {
		return C.sqrtf(mag2)
	}
	dxx := f64(dx) * f64(dx)
	dyy := f64(dy) * f64(dy)
	return f32(math.sqrt(dxx + dyy))
}

// SkMatrixPriv::ComputeResScaleForStroking() for an affine matrix.
fn res_scale_for_stroking(m Matrix) f32 {
	sx := point_length(m.a, m.b)
	sy := point_length(m.c, m.d)
	if is_finite_f32(sx) && is_finite_f32(sy) {
		scale := if sx < sy { sy } else { sx }
		if scale > 0 {
			return scale
		}
	}
	return 1
}

// SkPathBuilder operations the stroker uses, beyond the verbs in path.v.

fn (mut b PathBuilder) reset() {
	b.verbs.clear()
	b.points.clear()
	b.weights.clear()
	b.last_move = -1
	b.fill_type = .winding
}

fn (b &PathBuilder) last_point() ?Point {
	if b.points.len > 0 {
		return b.points.last()
	}
	return none
}

// SkPathBuilder::setLastPt().
fn (mut b PathBuilder) set_last_point(p Point) {
	if b.points.len == 0 {
		b.move_to(p.x, p.y)
	} else {
		b.points[b.points.len - 1] = p
	}
}

@[inline]
fn (mut b PathBuilder) move_to_pt(p Point) {
	b.move_to(p.x, p.y)
}

@[inline]
fn (mut b PathBuilder) line_to_pt(p Point) {
	b.line_to(p.x, p.y)
}

@[inline]
fn (mut b PathBuilder) quad_to_pts(p1 Point, p2 Point) {
	b.quad_to(p1.x, p1.y, p2.x, p2.y)
}

@[inline]
fn (mut b PathBuilder) conic_to_pts(p1 Point, p2 Point, w f32) {
	b.conic_to(p1.x, p1.y, p2.x, p2.y, w)
}

@[inline]
fn (mut b PathBuilder) cubic_to_pts(p1 Point, p2 Point, p3 Point) {
	b.cubic_to(p1.x, p1.y, p2.x, p2.y, p3.x, p3.y)
}

// SkPathBuilder::privateReversePathTo(): src's last contour in reverse,
// ignoring the last point of src's first contour.
fn (mut b PathBuilder) reverse_path_to(src &PathBuilder) {
	if src.verbs.len == 0 {
		return
	}
	mut pi := src.points.len - 1
	mut wi := src.weights.len
	for vi := src.verbs.len - 1; vi >= 0; vi-- {
		v := src.verbs[vi]
		pi -= verb_point_count(v)
		match v {
			.move {
				return
			}
			.line {
				b.line_to_pt(src.points[pi])
			}
			.quad {
				b.quad_to_pts(src.points[pi + 1], src.points[pi])
			}
			.conic {
				wi--
				b.conic_to_pts(src.points[pi + 1], src.points[pi], src.weights[wi])
			}
			.cubic {
				b.cubic_to_pts(src.points[pi + 2], src.points[pi + 1], src.points[pi])
			}
			.close {}
		}
	}
}

// SkPathBuilder::addPath(src) with kAppend_AddPathMode and no matrix.
fn (mut b PathBuilder) add_path(src &PathBuilder) {
	if src.verbs.len == 0 {
		return
	}
	if b.verbs.len <= 1 {
		fill := b.fill_type
		b.verbs = src.verbs.clone()
		b.points = src.points.clone()
		b.weights = src.weights.clone()
		b.last_move = src.last_move
		b.fill_type = fill
		return
	}
	// SkPathPriv::FindLastMoveToIndex().
	mut last_move := src.points.len - 1
	for vi := src.verbs.len - 1; vi >= 0; vi-- {
		if src.verbs[vi] == .move {
			break
		}
		last_move -= verb_point_count(src.verbs[vi])
	}
	b.last_move = last_move + b.points.len
	b.verbs << src.verbs
	b.points << src.points
	b.weights << src.weights
}

fn rect_corner(r Rect, index int) Point {
	return match index {
		0 { Point{r.left, r.top} }
		1 { Point{r.right, r.top} }
		2 { Point{r.right, r.bottom} }
		else { Point{r.left, r.bottom} }
	}
}

// SkPath_PointIterator<N>: the start index modulo N, advancing by 1 (CW) or
// N - 1 (CCW).
struct ShapePointIterator {
	n       int
	advance int
mut:
	current int
}

fn new_shape_iterator(n int, cw bool, start int) ShapePointIterator {
	return ShapePointIterator{
		n:       n
		advance: if cw { 1 } else { n - 1 }
		current: start % n
	}
}

fn (mut it ShapePointIterator) next() int {
	it.current = (it.current + it.advance) % it.n
	return it.current
}

// SkPathBuilder::addRect(rect, dir, startIndex) through SkPathRawShapes::Rect.
fn (mut b PathBuilder) add_rect_dir(r Rect, cw bool, start int) {
	mut it := new_shape_iterator(4, cw, start)
	b.move_to_pt(rect_corner(r, it.current))
	for _ in 0 .. 3 {
		b.line_to_pt(rect_corner(r, it.next()))
	}
	b.close()
}

// SkPathBuilder::addOval(oval, dir, startIndex) through SkPathRawShapes::Oval.
fn (mut b PathBuilder) add_oval_dir(r Rect, cw bool, start int) {
	cx := float_midpoint(r.left, r.right)
	cy := float_midpoint(r.top, r.bottom)
	oval := [Point{cx, r.top}, Point{r.right, cy}, Point{cx, r.bottom}, Point{r.left, cy}]!
	mut oval_it := new_shape_iterator(4, cw, start)
	mut rect_it := new_shape_iterator(4, cw, start + if cw { 0 } else { 1 })
	b.move_to_pt(oval[oval_it.current])
	for _ in 0 .. 4 {
		p1 := rect_corner(r, rect_it.next())
		p2 := oval[oval_it.next()]
		b.conic_to_pts(p1, p2, scalar_root2_over2)
	}
	b.close()
}

// SkPathBuilder::addCircle(x, y, r) with the default kCW direction.
fn (mut b PathBuilder) add_circle(center Point, radius f32) {
	if radius >= 0 {
		left := center.x - radius
		top := center.y - radius
		right := center.x + radius
		bottom := center.y + radius
		b.add_oval_dir(Rect{left, top, right, bottom}, true, 1)
	}
}

// SkPathBuilder::addPolygon(pts, true).
fn (mut b PathBuilder) add_closed_polygon(pts []Point) {
	if pts.len == 0 {
		return
	}
	b.move_to_pt(pts[0])
	for p in pts[1..] {
		b.line_to_pt(p)
	}
	b.close()
}

// SkRect::isEmpty(): !(left < right && top < bottom).
@[inline]
fn rect_is_empty(r Rect) bool {
	return !(r.left < r.right && r.top < r.bottom)
}

// SkRect::makeSorted().
fn rect_sorted(r Rect) Rect {
	return Rect{fmin_std(r.left, r.right), fmin_std(r.top, r.bottom), fmax_std(r.left,
		r.right), fmax_std(r.top, r.bottom)}
}

// std::min() and std::max(): the first argument unless the second compares
// strictly smaller (larger).
@[inline]
fn fmin_std(a f32, b f32) f32 {
	return if b < a { b } else { a }
}

@[inline]
fn fmax_std(a f32, b f32) f32 {
	return if a < b { b } else { a }
}

// SkPathBuilder::addRRect(SkRRect::MakeRectXY(rect, rad, rad), dir) with its
// default start index. Returns false when the rounded rect simplified to a
// rect or oval, as SkPathPriv::SimplifyRRect() selects.
fn (mut b PathBuilder) add_round_rect(rect Rect, rad_in f32, cw bool) {
	index := if cw { 6 } else { 7 }
	// SkRRect::setRectXY() and initializeRect().
	if !is_finite_f32(rect.left) || !is_finite_f32(rect.top) || !is_finite_f32(rect.right)
		|| !is_finite_f32(rect.bottom) {
		b.add_rect_dir(Rect{}, cw, (index + 1) / 2)
		return
	}
	bounds := rect_sorted(rect)
	if rect_is_empty(bounds) {
		b.add_rect_dir(bounds, cw, (index + 1) / 2)
		return
	}
	mut x_rad := rad_in
	mut y_rad := rad_in
	if !is_finite_f32(x_rad) || !is_finite_f32(y_rad) {
		x_rad = 0
		y_rad = 0
	}
	width := bounds.right - bounds.left
	height := bounds.bottom - bounds.top
	x_twice := x_rad + x_rad
	y_twice := y_rad + y_rad
	if width < x_twice || height < y_twice {
		sx := width / x_twice
		sy := height / y_twice
		scale := fmin_std(sx, sy)
		x_rad *= scale
		y_rad *= scale
	}
	if x_rad <= 0 || y_rad <= 0 {
		b.add_rect_dir(bounds, cw, (index + 1) / 2)
		return
	}
	half_width := width * f32(0.5)
	half_height := height * f32(0.5)
	if x_rad >= half_width && y_rad >= half_height {
		b.add_oval_dir(bounds, cw, index / 2)
		return
	}
	// set_as_rrect() starting with a line (index 6 for CW, 7 for CCW).
	l := bounds.left
	t := bounds.top
	r := bounds.right
	bt := bounds.bottom
	lx := l + x_rad
	rx := r - x_rad
	ty := t + y_rad
	by := bt - y_rad
	rrect := [Point{lx, t}, Point{rx, t}, Point{r, ty}, Point{r, by}, Point{rx, bt},
		Point{lx, bt}, Point{l, by}, Point{l, ty}]!
	mut rrect_it := new_shape_iterator(8, cw, index)
	mut rect_it := new_shape_iterator(4, cw, index / 2 + if cw { 0 } else { 1 })
	b.move_to_pt(rrect[rrect_it.current])
	for _ in 0 .. 4 {
		b.line_to_pt(rrect[rrect_it.next()])
		p1 := rect_corner(bounds, rect_it.next())
		p2 := rrect[rrect_it.next()]
		b.conic_to_pts(p1, p2, scalar_root2_over2)
	}
	b.close()
}

// An affine SkMatrix with the map proc its computed type mask selects.
struct SkAffine {
	sx f32 = 1
	kx f32
	tx f32
	ky f32
	sy f32 = 1
	ty f32
}

const affine_translate_mask = 1
const affine_scale_mask = 2
const affine_affine_mask = 4

// SkMatrix::computeTypeMask() without perspective.
fn (m SkAffine) type_mask() int {
	mut mask := 0
	if m.tx != 0 || m.ty != 0 {
		mask |= affine_translate_mask
	}
	if m.kx != 0 || m.ky != 0 {
		mask |= affine_affine_mask | affine_scale_mask
	} else if m.sx != 1 || m.sy != 1 {
		mask |= affine_scale_mask
	}
	return mask
}

// Identity_pts, Trans_pts, Scale_pts and Affine_vpts.
fn (m SkAffine) map(p Point) Point {
	mask := m.type_mask()
	if mask == 0 {
		return p
	}
	if mask == affine_translate_mask {
		return Point{p.x + m.tx, p.y + m.ty}
	}
	if mask & affine_affine_mask == 0 {
		x := p.x * m.sx
		y := p.y * m.sy
		return Point{x + m.tx, y + m.ty}
	}
	xx := p.x * m.sx
	xy := p.y * m.kx
	x := xx + xy
	yy := p.y * m.sy
	yx := p.x * m.ky
	y := yy + yx
	return Point{x + m.tx, y + m.ty}
}

// muladdmul(): a * b + c * d in double precision.
fn muladdmul(a f32, b f32, c f32, d f32) f32 {
	ab := f64(a) * f64(b)
	cd := f64(c) * f64(d)
	return f32(ab + cd)
}

// SkMatrix::setConcat(a, b) when neither matrix is trivially the identity.
fn affine_concat(a SkAffine, b SkAffine) SkAffine {
	if (a.type_mask() | b.type_mask()) & affine_affine_mask == 0 {
		sx := a.sx * b.sx
		sy := a.sy * b.sy
		ax := a.sx * b.tx
		ay := a.sy * b.ty
		return SkAffine{
			sx: sx
			sy: sy
			tx: ax + a.tx
			ty: ay + a.ty
		}
	}
	tx := muladdmul(a.sx, b.tx, a.kx, b.ty)
	ty := muladdmul(a.ky, b.tx, a.sy, b.ty)
	return SkAffine{
		sx: muladdmul(a.sx, b.sx, a.kx, b.ky)
		kx: muladdmul(a.sx, b.kx, a.kx, b.sy)
		tx: tx + a.tx
		ky: muladdmul(a.ky, b.sx, a.sy, b.ky)
		sy: muladdmul(a.ky, b.kx, a.sy, b.sy)
		ty: ty + a.ty
	}
}

// SkGeometry.cpp evaluation.

// SkQuadCoeff(src).eval(t) on one axis: ((A t + B) t + C).
fn quad_coeff_eval_axis(p0 f32, p1 f32, p2 f32, t f32) f32 {
	d := p1 - p0
	b := d + d
	p1x2 := p1 + p1
	a0 := p2 - p1x2
	a := a0 + p0
	at := a * t
	atb := at + b
	atbt := atb * t
	return atbt + p0
}

// SkEvalQuadAt(src, t).
fn eval_quad_at(src [3]Point, t f32) Point {
	return Point{quad_coeff_eval_axis(src[0].x, src[1].x, src[2].x, t), quad_coeff_eval_axis(src[0].y,
		src[1].y, src[2].y, t)}
}

// SkEvalQuadTangentAt().
fn eval_quad_tangent_at(src [3]Point, t f32) Point {
	if (t == 0 && src[0] == src[1]) || (t == 1 && src[1] == src[2]) {
		return vsub(src[2], src[0])
	}
	b := vsub(src[1], src[0])
	a0 := vsub(src[2], src[1])
	a := vsub(a0, b)
	at := vmul(a, t)
	tt := vadd(at, b)
	return vadd(tt, tt)
}

// SkFindQuadMaxCurvature().
fn find_quad_max_curvature(src [3]Point) f32 {
	ax := src[1].x - src[0].x
	ay := src[1].y - src[0].y
	bx0 := src[0].x - src[1].x
	bx1 := bx0 - src[1].x
	bx := bx1 + src[2].x
	by0 := src[0].y - src[1].y
	by1 := by0 - src[1].y
	by := by1 + src[2].y
	axbx := ax * bx
	ayby := ay * by
	numer_sum := axbx + ayby
	mut numer := -numer_sum
	bxbx := bx * bx
	byby := by * by
	mut denom := bxbx + byby
	if denom < 0 {
		numer = -numer
		denom = -denom
	}
	if numer <= 0 {
		return 0
	}
	if numer >= denom {
		return 1
	}
	return numer / denom
}

// SkCubicCoeff(src).eval(t) on one axis.
fn cubic_coeff_eval_axis(p0 f32, p1 f32, p2 f32, p3 f32, t f32) f32 {
	d12 := p1 - p2
	d12x3 := f32(3) * d12
	a0 := p3 + d12x3
	a := a0 - p0
	p1x2 := p1 + p1
	b0 := p2 - p1x2
	b1 := b0 + p0
	b := f32(3) * b1
	c0 := p1 - p0
	c := f32(3) * c0
	r0 := a * t
	r1 := r0 + b
	r2 := r1 * t
	r3 := r2 + c
	r4 := r3 * t
	return r4 + p0
}

fn eval_cubic_at(src []Point, t f32) Point {
	return Point{cubic_coeff_eval_axis(src[0].x, src[1].x, src[2].x, src[3].x, t), cubic_coeff_eval_axis(src[0].y,
		src[1].y, src[2].y, src[3].y, t)}
}

// eval_cubic_derivative() on one axis.
fn cubic_derivative_axis(p0 f32, p1 f32, p2 f32, p3 f32, t f32) f32 {
	d12 := p1 - p2
	d12x3 := f32(3) * d12
	a0 := p3 + d12x3
	a := a0 - p0
	p1x2 := p1 + p1
	b0 := p2 - p1x2
	b1 := b0 + p0
	b := b1 + b1
	c := p1 - p0
	r0 := a * t
	r1 := r0 + b
	r2 := r1 * t
	return r2 + c
}

fn eval_cubic_derivative(src []Point, t f32) Point {
	return Point{cubic_derivative_axis(src[0].x, src[1].x, src[2].x, src[3].x, t), cubic_derivative_axis(src[0].y,
		src[1].y, src[2].y, src[3].y, t)}
}

// SkEvalCubicAt()'s tangent.
fn eval_cubic_tangent_at(src []Point, t f32) Point {
	if (t == 0 && src[0] == src[1]) || (t == 1 && src[2] == src[3]) {
		mut tangent := if t == 0 { vsub(src[2], src[0]) } else { vsub(src[3], src[1]) }
		if tangent.x == 0 && tangent.y == 0 {
			tangent = vsub(src[3], src[0])
		}
		return tangent
	}
	return eval_cubic_derivative(src, t)
}

// SkFindCubicMaxCurvature(): solve_cubic_poly()'s roots, pinned to [0, 1].
fn find_cubic_max_curvature(src []Point) []f32 {
	x := f1_dot_f2(src[0].x, src[1].x, src[2].x, src[3].x)
	y := f1_dot_f2(src[0].y, src[1].y, src[2].y, src[3].y)
	mut coeff := [4]f32{}
	for i in 0 .. 4 {
		coeff[i] = x[i] + y[i]
	}
	return solve_cubic_poly(coeff)
}

// SkFindCubicInflections().
fn find_cubic_inflections(src []Point) []f32 {
	ax := src[1].x - src[0].x
	ay := src[1].y - src[0].y
	bx0 := f32(2) * src[1].x
	bx1 := src[2].x - bx0
	bx := bx1 + src[0].x
	by0 := f32(2) * src[1].y
	by1 := src[2].y - by0
	by := by1 + src[0].y
	cx0 := src[1].x - src[2].x
	cx1 := f32(3) * cx0
	cx2 := src[3].x + cx1
	cx := cx2 - src[0].x
	cy0 := src[1].y - src[2].y
	cy1 := f32(3) * cy0
	cy2 := src[3].y + cy1
	cy := cy2 - src[0].y
	bxcy := bx * cy
	bycx := by * cx
	axcy := ax * cy
	aycx := ay * cx
	axby := ax * by
	aybx := ay * bx
	return find_unit_quad_roots(bxcy - bycx, axcy - aycx, axby - aybx)
}

// on_same_side(): src[test], src[test + 1] in one half plane of the line
// src[line], src[line + 1].
fn on_same_side(src []Point, test int, line int) bool {
	origin := src[line]
	l := vsub(src[line + 1], origin)
	mut crosses := [2]f32{}
	for index in 0 .. 2 {
		test_line := vsub(src[test + index], origin)
		crosses[index] = cross_product(l, test_line)
	}
	return crosses[0] * crosses[1] >= 0
}

// SkFindCubicCusp(): the cusp's t, or -1.
fn find_cubic_cusp(src []Point) f32 {
	if src[0] == src[1] || src[2] == src[3] {
		return -1
	}
	if on_same_side(src, 0, 2) || on_same_side(src, 2, 0) {
		return -1
	}
	for test_t in find_cubic_max_curvature(src) {
		if 0 >= test_t || test_t >= 1 {
			continue
		}
		d_pt := eval_cubic_derivative(src, test_t)
		magnitude := dot_product(d_pt, d_pt)
		// calc_cubic_precision()
		d10 := distance_to_sqd(src[1], src[0])
		d21 := distance_to_sqd(src[2], src[1])
		d32 := distance_to_sqd(src[3], src[2])
		sum0 := d10 + d21
		sum := sum0 + d32
		precision := sum * f32(1e-8)
		if magnitude < precision {
			return test_t
		}
	}
	return -1
}

// SkConicCoeff(conic).eval(t) on one axis.
fn conic_eval_axis(p0 f32, p1 f32, p2 f32, w f32, t f32) f32 {
	p1w := p1 * w
	p1w2 := p1w + p1w
	na0 := p2 - p1w2
	na := na0 + p0
	nb0 := p1w - p0
	nb := nb0 + nb0
	n0 := na * t
	n1 := n0 + nb
	n2 := n1 * t
	numer := n2 + p0
	wm1 := w - 1
	db := wm1 + wm1
	da := 0 - db
	d0 := da * t
	d1 := d0 + db
	d2 := d1 * t
	denom := d2 + 1
	return numer / denom
}

// SkConic::evalAt(t).
fn conic_eval_at(c Conic, t f32) Point {
	return Point{conic_eval_axis(c.pts[0].x, c.pts[1].x, c.pts[2].x, c.w, t), conic_eval_axis(c.pts[0].y,
		c.pts[1].y, c.pts[2].y, c.w, t)}
}

// SkConic::evalTangentAt(t).
fn conic_eval_tangent_at(c Conic, t f32) Point {
	if (t == 0 && c.pts[0] == c.pts[1]) || (t == 1 && c.pts[1] == c.pts[2]) {
		return vsub(c.pts[2], c.pts[0])
	}
	p20 := vsub(c.pts[2], c.pts[0])
	p10 := vsub(c.pts[1], c.pts[0])
	cc := vmul(p10, c.w)
	wp20 := vmul(p20, c.w)
	a := vsub(wp20, p20)
	b0 := vsub(p20, cc)
	b := vsub(b0, cc)
	r0 := vmul(a, t)
	r1 := vadd(r0, b)
	r2 := vmul(r1, t)
	return vadd(r2, cc)
}

const unit_arc_quadrant_points = [Point{1, 0}, Point{1, 1}, Point{0, 1}, Point{-1, 1}, Point{-1, 0},
	Point{-1, -1}, Point{0, -1}, Point{1, -1}]

// SkConic::BuildUnitArc() with a scale-and-translate user matrix.
fn build_unit_arc(u_start Point, u_stop Point, cw bool, user SkAffine, user_is_identity bool) []Conic {
	x := dot_product(u_start, u_stop)
	mut y := cross_product(u_start, u_stop)
	abs_y := abs_f32(y)
	if abs_y <= scalar_nearly_zero && x > 0 && ((y >= 0 && cw) || (y <= 0 && !cw)) {
		return []
	}
	if !cw {
		y = -y
	}
	mut quadrant := 0
	if y == 0 {
		quadrant = 2
	} else if x == 0 {
		quadrant = if y > 0 { 1 } else { 3 }
	} else {
		if y < 0 {
			quadrant += 2
		}
		if (x < 0) != (y < 0) {
			quadrant += 1
		}
	}
	mut conics := []Conic{cap: 5}
	for i in 0 .. quadrant {
		conics << Conic{[unit_arc_quadrant_points[i * 2], unit_arc_quadrant_points[i * 2 + 1],
			unit_arc_quadrant_points[i * 2 + 2]]!, scalar_root2_over2}
	}
	final_p := Point{x, y}
	last_q := unit_arc_quadrant_points[quadrant * 2]
	dot := dot_product(last_q, final_p)
	if dot != dot {
		return []
	}
	if dot < 1 {
		off_curve := Point{last_q.x + x, last_q.y + y}
		half_sum := (1 + dot) / 2
		cos_theta_over2 := C.sqrtf(half_sum)
		length := f32(1) / cos_theta_over2
		scaled := set_point_length(off_curve.x, off_curve.y, length) or { Point{} }
		diff := vsub(last_q, scaled)
		if can_normalize(diff.x, diff.y) {
			conics << Conic{[last_q, scaled, final_p]!, cos_theta_over2}
		}
	}
	// setSinCos(uStart.fY, uStart.fX), preScale(1, -1) for CCW, then
	// postConcat(userMatrix).
	mut matrix := SkAffine{
		sx: u_start.x
		kx: -u_start.y
		ky: u_start.y
		sy: u_start.x
	}
	if !cw {
		matrix = SkAffine{
			sx: matrix.sx * f32(1)
			kx: matrix.kx * f32(-1)
			ky: matrix.ky * f32(1)
			sy: matrix.sy * f32(-1)
		}
	}
	if !user_is_identity {
		matrix = affine_concat(user, matrix)
	}
	for mut conic in conics {
		for i in 0 .. 3 {
			conic.pts[i] = matrix.map(conic.pts[i])
		}
	}
	return conics
}

// SkStrokerPriv.cpp caps.

// ButtCapper, RoundCapper and SquareCapper.
fn stroke_cap(cap StrokeCap, mut sink PathBuilder, pivot Point, normal Point, stop Point, extend_last_pt bool) {
	match cap {
		.butt {
			sink.line_to_pt(stop)
		}
		.round {
			parallel := Point{-normal.y, normal.x}
			projected_center := vadd(pivot, parallel)
			sink.conic_to_pts(vadd(projected_center, normal), projected_center, scalar_root2_over2)
			sink.conic_to_pts(vsub(projected_center, normal), stop, scalar_root2_over2)
		}
		.square {
			parallel := Point{-normal.y, normal.x}
			out0 := vadd(pivot, normal)
			out := vadd(out0, parallel)
			in0 := vsub(pivot, normal)
			inn := vadd(in0, parallel)
			if extend_last_pt {
				sink.set_last_point(out)
				sink.line_to_pt(inn)
			} else {
				sink.line_to_pt(out)
				sink.line_to_pt(inn)
				sink.line_to_pt(stop)
			}
		}
	}
}

// SkStrokerPriv.cpp joins.

enum AngleType {
	nearly_180
	sharp
	shallow
	nearly_line
}

fn is_clockwise(before Point, after Point) bool {
	a := before.x * after.y
	b := before.y * after.x
	return a > b
}

// Dot2AngleType().
fn dot_to_angle_type(dot f32) AngleType {
	if dot >= 0 {
		return if abs_f32(1 - dot) <= scalar_nearly_zero { .nearly_line } else { .shallow }
	}
	return if abs_f32(1 + dot) <= scalar_nearly_zero { .nearly_180 } else { .sharp }
}

fn handle_inner_join(mut inner PathBuilder, pivot Point, after Point) {
	inner.line_to_pt(pivot)
	inner.line_to_pt(vsub(pivot, after))
}

// The joiner a stroker calls with its outer and inner contours.
fn stroke_join(join StrokeJoin, mut outer PathBuilder, mut inner PathBuilder, before_unit_normal Point, pivot Point, after_unit_normal Point, radius f32, inv_miter_limit f32, prev_is_line bool, curr_is_line bool) {
	match join {
		.bevel {
			blunt_joiner(mut outer, mut inner, before_unit_normal, pivot, after_unit_normal,
				radius)
		}
		.round {
			round_joiner(mut outer, mut inner, before_unit_normal, pivot, after_unit_normal,
				radius)
		}
		.miter {
			miter_joiner(mut outer, mut inner, before_unit_normal, pivot, after_unit_normal,
				radius, inv_miter_limit, prev_is_line, curr_is_line)
		}
	}
}

// BluntJoiner.
fn blunt_joiner(mut outer PathBuilder, mut inner PathBuilder, before_unit_normal Point, pivot Point, after_unit_normal Point, radius f32) {
	after := vmul(after_unit_normal, radius)
	if !is_clockwise(before_unit_normal, after_unit_normal) {
		negated := vneg(after)
		inner.line_to_pt(vadd(pivot, negated))
		handle_inner_join(mut outer, pivot, negated)
		return
	}
	outer.line_to_pt(vadd(pivot, after))
	handle_inner_join(mut inner, pivot, after)
}

// RoundJoiner.
fn round_joiner(mut outer PathBuilder, mut inner PathBuilder, before_unit_normal Point, pivot Point, after_unit_normal Point, radius f32) {
	dot := dot_product(before_unit_normal, after_unit_normal)
	if dot_to_angle_type(dot) == .nearly_line {
		return
	}
	if !is_clockwise(before_unit_normal, after_unit_normal) {
		round_join_arc(mut inner, mut outer, vneg(before_unit_normal), pivot, vneg(after_unit_normal),
			radius, false)
	} else {
		round_join_arc(mut outer, mut inner, before_unit_normal, pivot, after_unit_normal,
			radius, true)
	}
}

fn round_join_arc(mut outer PathBuilder, mut inner PathBuilder, before Point, pivot Point, after Point, radius f32, cw bool) {
	// matrix.setScale(radius, radius); matrix.postTranslate(pivot).
	tx := f32(0) + pivot.x
	ty := f32(0) + pivot.y
	user := SkAffine{
		sx: radius
		sy: radius
		tx: tx
		ty: ty
	}
	user_is_identity := radius == 1 && tx == 0 && ty == 0
	conics := build_unit_arc(before, after, cw, user, user_is_identity)
	if conics.len > 0 {
		for conic in conics {
			outer.conic_to_pts(conic.pts[1], conic.pts[2], conic.w)
		}
		handle_inner_join(mut inner, pivot, vmul(after, radius))
	}
}

// MiterJoiner.
fn miter_joiner(mut outer PathBuilder, mut inner PathBuilder, before_unit_normal Point, pivot Point, after_unit_normal Point, radius f32, inv_miter_limit f32, prev_is_line bool, curr_is_line bool) {
	dot := dot_product(before_unit_normal, after_unit_normal)
	angle := dot_to_angle_type(dot)
	if angle == .nearly_line {
		return
	}
	if angle == .nearly_180 {
		miter_blunt(mut outer, mut inner, pivot, after_unit_normal, radius, false)
		return
	}
	if !is_clockwise(before_unit_normal, after_unit_normal) {
		miter_join_turn(mut inner, mut outer, vneg(before_unit_normal), pivot, vneg(after_unit_normal),
			dot, angle, true, radius, inv_miter_limit, prev_is_line, curr_is_line)
	} else {
		miter_join_turn(mut outer, mut inner, before_unit_normal, pivot, after_unit_normal,
			dot, angle, false, radius, inv_miter_limit, prev_is_line, curr_is_line)
	}
}

fn miter_join_turn(mut outer PathBuilder, mut inner PathBuilder, before Point, pivot Point, after Point, dot f32, angle AngleType, ccw bool, radius f32, inv_miter_limit f32, prev_is_line bool, curr_is_line bool) {
	mut mid := Point{}
	if dot == 0 && inv_miter_limit <= one_over_sqrt2_join {
		sum := vadd(before, after)
		mid = vmul(sum, radius)
	} else {
		half := (1 + dot) * f32(0.5)
		sin_half_angle := C.sqrtf(half)
		if sin_half_angle < inv_miter_limit {
			miter_blunt(mut outer, mut inner, pivot, after, radius, false)
			return
		}
		if angle == .sharp {
			mid = Point{after.y - before.y, before.x - after.x}
			if ccw {
				mid = vneg(mid)
			}
		} else {
			mid = Point{before.x + after.x, before.y + after.y}
		}
		mid = set_point_length(mid.x, mid.y, radius / sin_half_angle) or { Point{} }
	}
	if prev_is_line {
		outer.set_last_point(vadd(pivot, mid))
	} else {
		outer.line_to_pt(vadd(pivot, mid))
	}
	miter_blunt(mut outer, mut inner, pivot, after, radius, curr_is_line)
}

// MiterJoiner's DO_BLUNT.
fn miter_blunt(mut outer PathBuilder, mut inner PathBuilder, pivot Point, after_unit Point, radius f32, curr_is_line bool) {
	after := vmul(after_unit, radius)
	if !curr_is_line {
		outer.line_to_pt(vadd(pivot, after))
	}
	handle_inner_join(mut inner, pivot, after)
}

const one_over_sqrt2_join = f32(0.707106781)

// SkPath::Iter(path, false): a line closes each contour whose last point is
// not its start, and trailing moves end the iteration.
struct StrokeIter {
	verbs   []PathVerb
	points  []Point
	weights []f32
mut:
	verb_index   int
	point_index  int
	weight_index int
	move_to      Point
	last_pt      Point
}

struct IterRec {
	verb   PathVerb
	pts    [4]Point
	weight f32 = 1
}

fn (mut it StrokeIter) next() ?IterRec {
	if it.verb_index == it.verbs.len {
		return none
	}
	verb := it.verbs[it.verb_index]
	it.verb_index++
	pi := it.point_index
	match verb {
		.move {
			if it.verb_index == it.verbs.len {
				return none
			}
			it.move_to = it.points[pi]
			it.point_index++
			it.last_pt = it.move_to
			return IterRec{
				verb: .move
				pts:  [it.move_to, Point{}, Point{}, Point{}]!
			}
		}
		.line {
			rec := IterRec{
				verb: .line
				pts:  [it.last_pt, it.points[pi], Point{}, Point{}]!
			}
			it.last_pt = it.points[pi]
			it.point_index++
			return rec
		}
		.quad, .conic {
			mut weight := f32(1)
			if verb == .conic {
				weight = it.weights[it.weight_index]
				it.weight_index++
			}
			rec := IterRec{
				verb:   verb
				pts:    [it.last_pt, it.points[pi], it.points[pi + 1], Point{}]!
				weight: weight
			}
			it.last_pt = it.points[pi + 1]
			it.point_index += 2
			return rec
		}
		.cubic {
			rec := IterRec{
				verb: .cubic
				pts:  [it.last_pt, it.points[pi], it.points[pi + 1], it.points[pi + 2]]!
			}
			it.last_pt = it.points[pi + 2]
			it.point_index += 3
			return rec
		}
		.close {
			// autoClose()
			if it.last_pt != it.move_to {
				nan := it.last_pt.x != it.last_pt.x || it.last_pt.y != it.last_pt.y
					|| it.move_to.x != it.move_to.x || it.move_to.y != it.move_to.y
				if !nan {
					rec := IterRec{
						verb: .line
						pts:  [it.last_pt, it.move_to, Point{}, Point{}]!
					}
					it.last_pt = it.move_to
					it.verb_index--
					return rec
				}
			}
			it.last_pt = it.move_to
			return IterRec{
				verb: .close
			}
		}
	}
}

// has_valid_tangent(): whether the rest of the contour has a segment of
// nonzero length.
fn has_valid_tangent(iter StrokeIter) bool {
	mut ahead := iter
	for {
		rec := ahead.next() or { return false }
		p := rec.pts
		match rec.verb {
			.move {
				return false
			}
			.line {
				if p[0] == p[1] {
					continue
				}
				return true
			}
			.quad, .conic {
				if p[0] == p[1] && p[0] == p[2] {
					continue
				}
				return true
			}
			.cubic {
				if p[0] == p[1] && p[0] == p[2] && p[0] == p[3] {
					continue
				}
				return true
			}
			.close {
				return false
			}
		}
	}
	return false
}

// SkQuadConstruct: the state of a quad stroke under construction.
struct QuadConstruct {
mut:
	quad              [3]Point
	tangent_start     Point
	tangent_end       Point
	start_t           f32
	mid_t             f32
	end_t             f32
	start_set         bool
	end_set           bool
	opposite_tangents bool
}

fn (mut q QuadConstruct) init(start f32, end f32) bool {
	q.start_t = start
	sum := start + end
	q.mid_t = sum * f32(0.5)
	q.end_t = end
	q.start_set = false
	q.end_set = false
	return q.start_t < q.mid_t && q.mid_t < q.end_t
}

fn (mut q QuadConstruct) init_with_start(parent &QuadConstruct) bool {
	if !q.init(parent.start_t, parent.mid_t) {
		return false
	}
	q.quad[0] = parent.quad[0]
	q.tangent_start = parent.tangent_start
	q.start_set = true
	return true
}

fn (mut q QuadConstruct) init_with_end(parent &QuadConstruct) bool {
	if !q.init(parent.mid_t, parent.end_t) {
		return false
	}
	q.quad[2] = parent.quad[2]
	q.tangent_end = parent.tangent_end
	q.end_set = true
	return true
}

enum StrokeResult {
	split
	degenerate
	quad
}

enum ReductionType {
	point
	line
	quad
	degenerate
	degenerate2
	degenerate3
}

// isZeroLengthSincePoint().
fn zero_length_since_point(points []Point, start int) bool {
	count := points.len - start
	if count < 2 {
		return true
	}
	first := points[start]
	for index in 1 .. count {
		if first != points[start + index] {
			return false
		}
	}
	return true
}

// SkPathStroker.
struct PathStroker {
mut:
	radius                          f32
	inv_miter_limit                 f32
	res_scale                       f32
	inv_res_scale                   f32
	inv_res_scale_squared           f32
	first_normal                    Point
	prev_normal                     Point
	first_unit_normal               Point
	prev_unit_normal                Point
	first_pt                        Point
	prev_pt                         Point
	first_outer_pt                  Point
	first_outer_pt_index_in_contour int
	segment_count                   int = -1
	prev_is_line                    bool
	cap                             StrokeCap
	join                            StrokeJoin
	inner                           PathBuilder
	outer                           PathBuilder
	cusper                          PathBuilder
	// 1 for the outer stroke, -1 for the inner.
	stroke_type     int = 1
	recursion_depth int
	found_tangents  bool
	join_completed  bool
}

fn new_path_stroker(radius f32, miter_limit f32, cap StrokeCap, join_in StrokeJoin, res_scale f32) PathStroker {
	mut join := join_in
	mut inv_miter_limit := f32(0)
	if join == .miter {
		if miter_limit <= 1 {
			join = .bevel
		} else {
			inv_miter_limit = f32(1) / miter_limit
		}
	}
	res4 := res_scale * f32(4)
	inv_res_scale := f32(1) / res4
	return PathStroker{
		radius:                radius
		inv_miter_limit:       inv_miter_limit
		res_scale:             res_scale
		inv_res_scale:         inv_res_scale
		inv_res_scale_squared: inv_res_scale * inv_res_scale
		cap:                   cap
		join:                  join
	}
}

// A normal scaled to the stroke radius and the unit normal.
struct StrokeNormal {
	normal Point
	unit   Point
}

// set_normal_unitnormal(before, after, scale, radius).
fn (s &PathStroker) normal_between(before Point, after Point) ?StrokeNormal {
	dx := after.x - before.x
	dy := after.y - before.y
	sdx := dx * s.res_scale
	sdy := dy * s.res_scale
	unit := set_point_length(sdx, sdy, 1) or { return none }
	rotated := Point{unit.y, -unit.x}
	return StrokeNormal{vmul(rotated, s.radius), rotated}
}

// set_normal_unitnormal(vec, radius).
fn (s &PathStroker) normal_of(vec Point) ?StrokeNormal {
	unit := set_point_length(vec.x, vec.y, 1) or { return none }
	rotated := Point{unit.y, -unit.x}
	return StrokeNormal{vmul(rotated, s.radius), rotated}
}

fn (mut s PathStroker) pre_join_to(curr_pt Point, curr_is_line bool) ?(Point, Point) {
	mut normal := Point{}
	mut unit_normal := Point{}
	if n := s.normal_between(s.prev_pt, curr_pt) {
		normal = n.normal
		unit_normal = n.unit
	} else {
		if s.cap == .butt {
			return none
		}
		normal = Point{s.radius, 0}
		unit_normal = Point{1, 0}
	}
	if s.segment_count == 0 {
		s.first_normal = normal
		s.first_unit_normal = unit_normal
		s.first_outer_pt = vadd(s.prev_pt, normal)
		s.outer.move_to_pt(s.first_outer_pt)
		s.inner.move_to_pt(vsub(s.prev_pt, normal))
	} else {
		stroke_join(s.join, mut s.outer, mut s.inner, s.prev_unit_normal, s.prev_pt, unit_normal,
			s.radius, s.inv_miter_limit, s.prev_is_line, curr_is_line)
	}
	s.prev_is_line = curr_is_line
	return normal, unit_normal
}

fn (mut s PathStroker) post_join_to(curr_pt Point, normal Point, unit_normal Point) {
	s.join_completed = true
	s.prev_pt = curr_pt
	s.prev_unit_normal = unit_normal
	s.prev_normal = normal
	s.segment_count += 1
}

fn (mut s PathStroker) finish_contour(close bool, curr_is_line bool) {
	if s.segment_count > 0 {
		if close {
			stroke_join(s.join, mut s.outer, mut s.inner, s.prev_unit_normal, s.prev_pt,
				s.first_unit_normal, s.radius, s.inv_miter_limit, s.prev_is_line, curr_is_line)
			s.outer.close()
			// fCanIgnoreCenter only applies to stroke-and-fill.
			if pt := s.inner.last_point() {
				s.outer.move_to_pt(pt)
				s.outer.reverse_path_to(&s.inner)
				s.outer.close()
			}
		} else {
			if pt := s.inner.last_point() {
				stroke_cap(s.cap, mut s.outer, s.prev_pt, s.prev_normal, pt, curr_is_line)
				s.outer.reverse_path_to(&s.inner)
				stroke_cap(s.cap, mut s.outer, s.first_pt, vneg(s.first_normal), s.first_outer_pt,
					s.prev_is_line)
				s.outer.close()
			}
		}
		if s.cusper.verbs.len > 0 {
			s.outer.add_path(&s.cusper)
			s.cusper.reset()
		}
	}
	s.inner.reset()
	s.segment_count = -1
	s.first_outer_pt_index_in_contour = s.outer.points.len
}

fn (mut s PathStroker) move_to(pt Point) {
	if s.segment_count > 0 {
		s.finish_contour(false, false)
	}
	s.segment_count = 0
	s.first_pt = pt
	s.prev_pt = pt
	s.join_completed = false
}

fn (mut s PathStroker) line_to(curr_pt Point, iter ?StrokeIter) {
	tolerance := scalar_nearly_zero * s.inv_res_scale
	dx := s.prev_pt.x - curr_pt.x
	dy := s.prev_pt.y - curr_pt.y
	teeny_line := abs_f32(dx) <= tolerance && abs_f32(dy) <= tolerance
	if s.cap == .butt && teeny_line {
		return
	}
	if teeny_line {
		if s.join_completed {
			return
		}
		if it := iter {
			if has_valid_tangent(it) {
				return
			}
		}
	}
	normal, unit_normal := s.pre_join_to(curr_pt, true) or { return }
	s.outer.line_to_pt(vadd(curr_pt, normal))
	s.inner.line_to_pt(vsub(curr_pt, normal))
	s.post_join_to(curr_pt, normal, unit_normal)
}

fn (s &PathStroker) set_quad_end_normal(quad [3]Point, normal_ab Point, unit_normal_ab Point) (Point, Point) {
	if n := s.normal_between(quad[1], quad[2]) {
		return n.normal, n.unit
	}
	return normal_ab, unit_normal_ab
}

fn (s &PathStroker) set_cubic_end_normal(cubic []Point, normal_ab Point, unit_normal_ab Point) (Point, Point) {
	mut ab := vsub(cubic[1], cubic[0])
	mut cd := vsub(cubic[3], cubic[2])
	mut degenerate_ab := degenerate_vector(ab)
	mut degenerate_cd := degenerate_vector(cd)
	if degenerate_ab && degenerate_cd {
		return normal_ab, unit_normal_ab
	}
	if degenerate_ab {
		ab = vsub(cubic[2], cubic[0])
		degenerate_ab = degenerate_vector(ab)
	}
	if degenerate_cd {
		cd = vsub(cubic[3], cubic[1])
		degenerate_cd = degenerate_vector(cd)
	}
	if degenerate_ab || degenerate_cd {
		return normal_ab, unit_normal_ab
	}
	if n := s.normal_of(cd) {
		return n.normal, n.unit
	}
	return Point{}, Point{}
}

fn (mut s PathStroker) init_stroke(stroke_type int, mut quad_pts QuadConstruct, t_start f32, t_end f32) {
	s.stroke_type = stroke_type
	s.found_tangents = false
	quad_pts.init(t_start, t_end)
}

// pt_to_line(): the squared distance from pt to the segment.
fn pt_to_line(pt Point, line_start Point, line_end Point) f32 {
	dxy := vsub(line_end, line_start)
	ab0 := vsub(pt, line_start)
	numer := dot_product(dxy, ab0)
	denom := dot_product(dxy, dxy)
	t := numer / denom
	if t >= 0 && t <= 1 {
		one_minus_t := 1 - t
		a := vmul(line_start, one_minus_t)
		b := vmul(line_end, t)
		hit := vadd(a, b)
		return distance_to_sqd(hit, pt)
	}
	return distance_to_sqd(pt, line_start)
}

// pt_to_tangent_line().
fn pt_to_tangent_line(pt Point, line_start Point, tangent Point) f32 {
	ab0 := vsub(pt, line_start)
	numer := dot_product(tangent, ab0)
	denom := dot_product(tangent, tangent)
	t := numer / denom
	if t >= 0 && t <= 1 {
		scaled := vmul(tangent, t)
		hit := vadd(line_start, scaled)
		return distance_to_sqd(hit, pt)
	}
	return distance_to_sqd(pt, line_start)
}

// The largest coordinate difference between any two points and its pair.
fn outermost_points(pts []Point) (f32, int, int) {
	mut pt_max := f32(-1)
	mut outer1 := 0
	mut outer2 := 0
	for index in 0 .. pts.len - 1 {
		for inner in index + 1 .. pts.len {
			test_diff := vsub(pts[inner], pts[index])
			test_max := fmax_std(abs_f32(test_diff.x), abs_f32(test_diff.y))
			if pt_max < test_max {
				outer1 = index
				outer2 = inner
				pt_max = test_max
			}
		}
	}
	return pt_max, outer1, outer2
}

// cubic_in_line().
fn cubic_in_line(cubic []Point) bool {
	pt_max, outer1, outer2 := outermost_points(cubic)
	mid1 := (1 + (2 >> outer2)) >> outer1
	mid2 := outer1 ^ outer2 ^ mid1
	square := pt_max * pt_max
	line_slop := square * f32(0.00001)
	return pt_to_line(cubic[mid1], cubic[outer1], cubic[outer2]) <= line_slop
		&& pt_to_line(cubic[mid2], cubic[outer1], cubic[outer2]) <= line_slop
}

// quad_in_line() (and conic_in_line()).
fn quad_in_line(quad [3]Point) bool {
	pt_max, outer1, outer2 := outermost_points([quad[0], quad[1], quad[2]])
	mid := outer1 ^ outer2 ^ 3
	square := pt_max * pt_max
	line_slop := square * f32(0.000005)
	return pt_to_line(quad[mid], quad[outer1], quad[outer2]) <= line_slop
}

// CheckCubicLinear(): the reduction, its points and the tangent point.
fn check_cubic_linear(cubic []Point) (ReductionType, []Point, Point) {
	degenerate_ab := degenerate_vector(vsub(cubic[1], cubic[0]))
	degenerate_bc := degenerate_vector(vsub(cubic[2], cubic[1]))
	degenerate_cd := degenerate_vector(vsub(cubic[3], cubic[2]))
	if degenerate_ab && degenerate_bc && degenerate_cd {
		return .point, []Point{}, Point{}
	}
	if int(degenerate_ab) + int(degenerate_bc) + int(degenerate_cd) == 2 {
		return .line, []Point{}, Point{}
	}
	if !cubic_in_line(cubic) {
		tangent_pt := if degenerate_ab { cubic[2] } else { cubic[1] }
		return .quad, []Point{}, tangent_pt
	}
	mut reduction := []Point{cap: 3}
	for t in find_cubic_max_curvature(cubic) {
		if 0 >= t || t >= 1 {
			continue
		}
		p := eval_cubic_at(cubic, t)
		if p != cubic[0] && p != cubic[3] {
			reduction << p
		}
	}
	mut reduction_type := ReductionType.degenerate3
	if reduction.len == 0 {
		reduction_type = .line
	} else if reduction.len == 1 {
		reduction_type = .degenerate
	} else if reduction.len == 2 {
		reduction_type = .degenerate2
	}
	return reduction_type, reduction, Point{}
}

// CheckConicLinear().
fn check_conic_linear(conic Conic) (ReductionType, Point) {
	degenerate_ab := degenerate_vector(vsub(conic.pts[1], conic.pts[0]))
	degenerate_bc := degenerate_vector(vsub(conic.pts[2], conic.pts[1]))
	if degenerate_ab && degenerate_bc {
		return .point, Point{}
	}
	if degenerate_ab || degenerate_bc {
		return .line, Point{}
	}
	if !quad_in_line(conic.pts) {
		return .quad, Point{}
	}
	t := find_quad_max_curvature(conic.pts)
	if t == 0 || t != t {
		return .line, Point{}
	}
	return .degenerate, conic_eval_at(conic, t)
}

// CheckQuadLinear().
fn check_quad_linear(quad [3]Point) (ReductionType, Point) {
	degenerate_ab := degenerate_vector(vsub(quad[1], quad[0]))
	degenerate_bc := degenerate_vector(vsub(quad[2], quad[1]))
	if degenerate_ab && degenerate_bc {
		return .point, Point{}
	}
	if degenerate_ab || degenerate_bc {
		return .line, Point{}
	}
	if !quad_in_line(quad) {
		return .quad, Point{}
	}
	t := find_quad_max_curvature(quad)
	if t == 0 || t == 1 {
		return .line, Point{}
	}
	return .degenerate, eval_quad_at(quad, t)
}

// Lines to the reduction points with round joins, then to the end point.
fn (mut s PathStroker) line_to_reductions(reduction []Point, end Point) {
	saved := s.join
	s.line_to(reduction[0], none)
	s.join = .round
	for p in reduction[1..] {
		s.line_to(p, none)
	}
	s.line_to(end, none)
	s.join = saved
}

fn (mut s PathStroker) conic_to(pt1 Point, pt2 Point, weight f32) {
	conic := Conic{[s.prev_pt, pt1, pt2]!, weight}
	reduction_type, reduction := check_conic_linear(conic)
	if reduction_type == .point || reduction_type == .line {
		s.line_to(pt2, none)
		return
	}
	if reduction_type == .degenerate {
		s.line_to_reductions([reduction], pt2)
		return
	}
	normal_ab, unit_ab := s.pre_join_to(pt1, false) or {
		s.line_to(pt2, none)
		return
	}
	mut quad_pts := QuadConstruct{}
	s.init_stroke(1, mut quad_pts, 0, 1)
	s.conic_stroke(conic, mut quad_pts)
	s.init_stroke(-1, mut quad_pts, 0, 1)
	s.conic_stroke(conic, mut quad_pts)
	normal_bc, unit_bc := s.set_quad_end_normal(conic.pts, normal_ab, unit_ab)
	s.post_join_to(pt2, normal_bc, unit_bc)
}

fn (mut s PathStroker) quad_to(pt1 Point, pt2 Point) {
	quad := [s.prev_pt, pt1, pt2]!
	reduction_type, reduction := check_quad_linear(quad)
	if reduction_type == .point || reduction_type == .line {
		s.line_to(pt2, none)
		return
	}
	if reduction_type == .degenerate {
		s.line_to_reductions([reduction], pt2)
		return
	}
	normal_ab, unit_ab := s.pre_join_to(pt1, false) or {
		s.line_to(pt2, none)
		return
	}
	mut quad_pts := QuadConstruct{}
	s.init_stroke(1, mut quad_pts, 0, 1)
	s.quad_stroke(quad, mut quad_pts)
	s.init_stroke(-1, mut quad_pts, 0, 1)
	s.quad_stroke(quad, mut quad_pts)
	normal_bc, unit_bc := s.set_quad_end_normal(quad, normal_ab, unit_ab)
	s.post_join_to(pt2, normal_bc, unit_bc)
}

// setRayPts(): the point perpendicular to the curve at tPt, and the tangent.
fn (s &PathStroker) ray_pts(t_pt Point, dxy_in Point) (Point, Point) {
	dxy := set_point_length(dxy_in.x, dxy_in.y, s.radius) or { Point{s.radius, 0} }
	axis_flip := f32(s.stroke_type)
	fy := axis_flip * dxy.y
	fx := axis_flip * dxy.x
	return Point{t_pt.x + fy, t_pt.y - fx}, dxy
}

// conicPerpRay(): the curve point, its perpendicular point and tangent.
fn (s &PathStroker) conic_perp_ray(conic Conic, t f32) (Point, Point, Point) {
	t_pt := conic_eval_at(conic, t)
	mut dxy := conic_eval_tangent_at(conic, t)
	if vzero(dxy) {
		dxy = vsub(conic.pts[2], conic.pts[0])
	}
	on_pt, tangent := s.ray_pts(t_pt, dxy)
	return t_pt, on_pt, tangent
}

fn (s &PathStroker) conic_quad_ends(conic Conic, mut quad_pts QuadConstruct) {
	if !quad_pts.start_set {
		_, on_pt, tangent := s.conic_perp_ray(conic, quad_pts.start_t)
		quad_pts.quad[0] = on_pt
		quad_pts.tangent_start = tangent
		quad_pts.start_set = true
	}
	if !quad_pts.end_set {
		_, on_pt, tangent := s.conic_perp_ray(conic, quad_pts.end_t)
		quad_pts.quad[2] = on_pt
		quad_pts.tangent_end = tangent
		quad_pts.end_set = true
	}
}

// cubicPerpRay().
fn (s &PathStroker) cubic_perp_ray(cubic []Point, t f32) (Point, Point, Point) {
	t_pt := eval_cubic_at(cubic, t)
	mut dxy := eval_cubic_tangent_at(cubic, t)
	if vzero(dxy) {
		mut c_start := cubic[0]
		mut c_end := cubic[3]
		if abs_f32(t) <= scalar_nearly_zero {
			dxy = vsub(cubic[2], cubic[0])
		} else if abs_f32(1 - t) <= scalar_nearly_zero {
			dxy = vsub(cubic[3], cubic[1])
		} else {
			chopped := chop_cubic_at(cubic, t)
			dxy = vsub(chopped[3], chopped[2])
			if vzero(dxy) {
				dxy = vsub(chopped[3], chopped[1])
				c_start = chopped[0]
				c_end = chopped[3]
			}
		}
		if vzero(dxy) {
			dxy = vsub(c_end, c_start)
		}
	}
	on_pt, tangent := s.ray_pts(t_pt, dxy)
	return t_pt, on_pt, tangent
}

fn (s &PathStroker) cubic_quad_ends(cubic []Point, mut quad_pts QuadConstruct) {
	if !quad_pts.start_set {
		_, on_pt, tangent := s.cubic_perp_ray(cubic, quad_pts.start_t)
		quad_pts.quad[0] = on_pt
		quad_pts.tangent_start = tangent
		quad_pts.start_set = true
	}
	if !quad_pts.end_set {
		_, on_pt, tangent := s.cubic_perp_ray(cubic, quad_pts.end_t)
		quad_pts.quad[2] = on_pt
		quad_pts.tangent_end = tangent
		quad_pts.end_set = true
	}
}

// quadPerpRay().
fn (s &PathStroker) quad_perp_ray(quad [3]Point, t f32) (Point, Point, Point) {
	t_pt := eval_quad_at(quad, t)
	mut dxy := eval_quad_tangent_at(quad, t)
	if vzero(dxy) {
		dxy = vsub(quad[2], quad[0])
	}
	on_pt, tangent := s.ray_pts(t_pt, dxy)
	return t_pt, on_pt, tangent
}

// intersectRay(): whether the stroke between the quad's ends is degenerate
// (a line), a quad (with its control point when ctrl_pt is set), or must be
// split.
fn (s &PathStroker) intersect_ray(mut quad_pts QuadConstruct, ctrl_pt bool) StrokeResult {
	start := quad_pts.quad[0]
	end := quad_pts.quad[2]
	a_len := quad_pts.tangent_start
	b_len := quad_pts.tangent_end
	denom := cross_product(a_len, b_len)
	if denom == 0 || !is_finite_f32(denom) {
		quad_pts.opposite_tangents = dot_product(a_len, b_len) < 0
		return .degenerate
	}
	quad_pts.opposite_tangents = false
	ab0 := vsub(start, end)
	mut numer_a := cross_product(b_len, ab0)
	numer_b := cross_product(a_len, ab0)
	if (numer_a >= 0) == (numer_b >= 0) {
		dist1 := pt_to_tangent_line(start, end, quad_pts.tangent_end)
		dist2 := pt_to_tangent_line(end, start, quad_pts.tangent_start)
		if fmax_std(dist1, dist2) <= s.inv_res_scale_squared {
			return .degenerate
		}
		return .split
	}
	numer_a /= denom
	valid_divide := numer_a > numer_a - 1
	if valid_divide {
		if ctrl_pt {
			scaled := vmul(quad_pts.tangent_start, numer_a)
			quad_pts.quad[1] = vadd(start, scaled)
		}
		return .quad
	}
	quad_pts.opposite_tangents = dot_product(a_len, b_len) < 0
	return .degenerate
}

// tangentsMeet().
fn (s &PathStroker) tangents_meet(cubic []Point, mut quad_pts QuadConstruct) StrokeResult {
	s.cubic_quad_ends(cubic, mut quad_pts)
	return s.intersect_ray(mut quad_pts, false)
}

// intersect_quad_ray(): the t values where the line crosses the quad.
fn intersect_quad_ray(line [2]Point, quad [3]Point) []f32 {
	vec := vsub(line[1], line[0])
	mut r := [3]f32{}
	for n in 0 .. 3 {
		r[n] = cross_product(vec, vsub(quad[n], line[0]))
	}
	mut a := r[2]
	mut b := r[1]
	c := r[0]
	b2 := f32(2) * b
	cb := c - b2
	a += cb
	b -= c
	return find_unit_quad_roots(a, f32(2) * b, c)
}

// std::min({a, b, c}) and std::max({a, b, c}).
fn min3_std(a f32, b f32, c f32) f32 {
	mut m := a
	if b < m {
		m = b
	}
	if c < m {
		m = c
	}
	return m
}

fn max3_std(a f32, b f32, c f32) f32 {
	mut m := a
	if m < b {
		m = b
	}
	if m < c {
		m = c
	}
	return m
}

// ptInQuadBounds().
fn (s &PathStroker) pt_in_quad_bounds(quad [3]Point, pt Point) bool {
	x_min := min3_std(quad[0].x, quad[1].x, quad[2].x)
	if pt.x + s.inv_res_scale < x_min {
		return false
	}
	x_max := max3_std(quad[0].x, quad[1].x, quad[2].x)
	if pt.x - s.inv_res_scale > x_max {
		return false
	}
	y_min := min3_std(quad[0].y, quad[1].y, quad[2].y)
	if pt.y + s.inv_res_scale < y_min {
		return false
	}
	y_max := max3_std(quad[0].y, quad[1].y, quad[2].y)
	if pt.y - s.inv_res_scale > y_max {
		return false
	}
	return true
}

fn points_within_dist(near_pt Point, far_pt Point, limit f32) bool {
	limit2 := limit * limit
	return distance_to_sqd(near_pt, far_pt) <= limit2
}

// sharp_angle().
fn sharp_angle(quad [3]Point) bool {
	mut smaller := vsub(quad[1], quad[0])
	mut larger := vsub(quad[1], quad[2])
	smaller_len := dot_product(smaller, smaller)
	mut larger_len := dot_product(larger, larger)
	if smaller_len > larger_len {
		smaller, larger = larger, smaller
		larger_len = smaller_len
	}
	scaled := set_point_length(smaller.x, smaller.y, larger_len) or { return false }
	return dot_product(scaled, larger) > 0
}

// strokeCloseEnough().
fn (s &PathStroker) stroke_close_enough(stroke [3]Point, ray [2]Point, quad_pts &QuadConstruct) StrokeResult {
	stroke_mid := eval_quad_at(stroke, f32(0.5))
	if points_within_dist(ray[0], stroke_mid, s.inv_res_scale) {
		if sharp_angle(quad_pts.quad) {
			return .split
		}
		return .quad
	}
	if !s.pt_in_quad_bounds(stroke, ray[0]) {
		return .split
	}
	roots := intersect_quad_ray(ray, stroke)
	if roots.len != 1 {
		return .split
	}
	quad_pt := eval_quad_at(stroke, roots[0])
	offset := roots[0] - f32(0.5)
	doubled := abs_f32(offset) * f32(2)
	remaining := 1 - doubled
	tolerance := s.inv_res_scale * remaining
	if points_within_dist(ray[0], quad_pt, tolerance) {
		if sharp_angle(quad_pts.quad) {
			return .split
		}
		return .quad
	}
	return .split
}

// compareQuadCubic().
fn (s &PathStroker) compare_quad_cubic(cubic []Point, mut quad_pts QuadConstruct) StrokeResult {
	s.cubic_quad_ends(cubic, mut quad_pts)
	result := s.intersect_ray(mut quad_pts, true)
	if result != .quad {
		return result
	}
	t_pt, on_pt, _ := s.cubic_perp_ray(cubic, quad_pts.mid_t)
	return s.stroke_close_enough(quad_pts.quad, [on_pt, t_pt]!, quad_pts)
}

// compareQuadConic().
fn (s &PathStroker) compare_quad_conic(conic Conic, mut quad_pts QuadConstruct) StrokeResult {
	s.conic_quad_ends(conic, mut quad_pts)
	result := s.intersect_ray(mut quad_pts, true)
	if result != .quad {
		return result
	}
	t_pt, on_pt, _ := s.conic_perp_ray(conic, quad_pts.mid_t)
	return s.stroke_close_enough(quad_pts.quad, [on_pt, t_pt]!, quad_pts)
}

// compareQuadQuad().
fn (s &PathStroker) compare_quad_quad(quad [3]Point, mut quad_pts QuadConstruct) StrokeResult {
	if !quad_pts.start_set {
		_, on_pt, tangent := s.quad_perp_ray(quad, quad_pts.start_t)
		quad_pts.quad[0] = on_pt
		quad_pts.tangent_start = tangent
		quad_pts.start_set = true
	}
	if !quad_pts.end_set {
		_, on_pt, tangent := s.quad_perp_ray(quad, quad_pts.end_t)
		quad_pts.quad[2] = on_pt
		quad_pts.tangent_end = tangent
		quad_pts.end_set = true
	}
	result := s.intersect_ray(mut quad_pts, true)
	if result != .quad {
		return result
	}
	t_pt, on_pt, _ := s.quad_perp_ray(quad, quad_pts.mid_t)
	return s.stroke_close_enough(quad_pts.quad, [on_pt, t_pt]!, quad_pts)
}

fn (mut s PathStroker) sink_line_to(p Point) {
	if s.stroke_type == 1 {
		s.outer.line_to_pt(p)
	} else {
		s.inner.line_to_pt(p)
	}
}

fn (mut s PathStroker) sink_quad_to(p1 Point, p2 Point) {
	if s.stroke_type == 1 {
		s.outer.quad_to_pts(p1, p2)
	} else {
		s.inner.quad_to_pts(p1, p2)
	}
}

// addDegenerateLine().
fn (mut s PathStroker) add_degenerate_line(quad_pts &QuadConstruct) {
	s.sink_line_to(quad_pts.quad[2])
}

// cubicMidOnLine().
fn (s &PathStroker) cubic_mid_on_line(cubic []Point, quad_pts &QuadConstruct) bool {
	_, stroke_mid, _ := s.cubic_perp_ray(cubic, quad_pts.mid_t)
	dist := pt_to_line(stroke_mid, quad_pts.quad[0], quad_pts.quad[2])
	return dist < s.inv_res_scale_squared
}

// cubicStroke().
fn (mut s PathStroker) cubic_stroke(cubic []Point, mut quad_pts QuadConstruct) bool {
	if !s.found_tangents {
		result := s.tangents_meet(cubic, mut quad_pts)
		if result != .quad {
			if (result == .degenerate || points_within_dist(quad_pts.quad[0], quad_pts.quad[2],
				s.inv_res_scale)) && s.cubic_mid_on_line(cubic, quad_pts) {
				s.add_degenerate_line(quad_pts)
				return true
			}
		} else {
			s.found_tangents = true
		}
	}
	if s.found_tangents {
		result := s.compare_quad_cubic(cubic, mut quad_pts)
		if result == .quad {
			s.sink_quad_to(quad_pts.quad[1], quad_pts.quad[2])
			return true
		}
		if result == .degenerate {
			if !quad_pts.opposite_tangents {
				s.add_degenerate_line(quad_pts)
				return true
			}
		}
	}
	if !point_is_finite(quad_pts.quad[2]) {
		return false
	}
	s.recursion_depth++
	limit := if s.found_tangents { recursive_limit_cubic } else { recursive_limit_tangent }
	if s.recursion_depth > limit {
		s.add_degenerate_line(quad_pts)
		return true
	}
	mut half := QuadConstruct{}
	if !half.init_with_start(quad_pts) {
		s.add_degenerate_line(quad_pts)
		s.recursion_depth--
		return true
	}
	if !s.cubic_stroke(cubic, mut half) {
		return false
	}
	if !half.init_with_end(quad_pts) {
		s.add_degenerate_line(quad_pts)
		s.recursion_depth--
		return true
	}
	if !s.cubic_stroke(cubic, mut half) {
		return false
	}
	s.recursion_depth--
	return true
}

// conicStroke().
fn (mut s PathStroker) conic_stroke(conic Conic, mut quad_pts QuadConstruct) bool {
	result := s.compare_quad_conic(conic, mut quad_pts)
	if result == .quad {
		s.sink_quad_to(quad_pts.quad[1], quad_pts.quad[2])
		return true
	}
	if result == .degenerate {
		s.add_degenerate_line(quad_pts)
		return true
	}
	s.recursion_depth++
	if s.recursion_depth > recursive_limit_conic {
		s.add_degenerate_line(quad_pts)
		return true
	}
	mut half := QuadConstruct{}
	half.init_with_start(quad_pts)
	if !s.conic_stroke(conic, mut half) {
		return false
	}
	half.init_with_end(quad_pts)
	if !s.conic_stroke(conic, mut half) {
		return false
	}
	s.recursion_depth--
	return true
}

// quadStroke().
fn (mut s PathStroker) quad_stroke(quad [3]Point, mut quad_pts QuadConstruct) bool {
	result := s.compare_quad_quad(quad, mut quad_pts)
	if result == .quad {
		s.sink_quad_to(quad_pts.quad[1], quad_pts.quad[2])
		return true
	}
	if result == .degenerate {
		s.add_degenerate_line(quad_pts)
		return true
	}
	s.recursion_depth++
	if s.recursion_depth > recursive_limit_quad {
		s.add_degenerate_line(quad_pts)
		return true
	}
	mut half := QuadConstruct{}
	half.init_with_start(quad_pts)
	if !s.quad_stroke(quad, mut half) {
		return false
	}
	half.init_with_end(quad_pts)
	if !s.quad_stroke(quad, mut half) {
		return false
	}
	s.recursion_depth--
	return true
}

fn (mut s PathStroker) cubic_to(pt1 Point, pt2 Point, pt3 Point) {
	cubic := [s.prev_pt, pt1, pt2, pt3]
	reduction_type, reduction, tangent_pt := check_cubic_linear(cubic)
	if reduction_type == .point || reduction_type == .line {
		s.line_to(pt3, none)
		return
	}
	if reduction_type != .quad {
		s.line_to_reductions(reduction, pt3)
		return
	}
	normal_ab, unit_ab := s.pre_join_to(tangent_pt, false) or {
		s.line_to(pt3, none)
		return
	}
	t_values := find_cubic_inflections(cubic)
	mut last_t := f32(0)
	for index in 0 .. t_values.len + 1 {
		next_t := if index < t_values.len { t_values[index] } else { f32(1) }
		mut quad_pts := QuadConstruct{}
		s.init_stroke(1, mut quad_pts, last_t, next_t)
		s.cubic_stroke(cubic, mut quad_pts)
		s.init_stroke(-1, mut quad_pts, last_t, next_t)
		s.cubic_stroke(cubic, mut quad_pts)
		last_t = next_t
	}
	cusp := find_cubic_cusp(cubic)
	if cusp > 0 {
		s.cusper.add_circle(eval_cubic_at(cubic, cusp), s.radius)
	}
	normal_cd, unit_cd := s.set_cubic_end_normal(cubic, normal_ab, unit_ab)
	s.post_join_to(pt3, normal_cd, unit_cd)
}

// isCurrentContourEmpty().
fn (s &PathStroker) is_current_contour_empty() bool {
	return zero_length_since_point(s.inner.points, 0)
		&& zero_length_since_point(s.outer.points, s.first_outer_pt_index_in_contour)
}

// A stroke outline as SkStroke::strokePath() builds it, with whether the
// builder knows it to be convex (a stroked rect contributing one rect or
// rounded rect, which SkPathBuilder::addRect()/addRRect() mark convex).
struct StrokeOutline {
mut:
	builder      PathBuilder
	known_convex bool
}

// SkStroke::strokeRect().
fn stroke_rect(rect Rect, width f32, join_in StrokeJoin, miter_limit f32, cw_in bool) StrokeOutline {
	mut out := StrokeOutline{}
	radius := width * f32(0.5)
	if radius <= 0 {
		return out
	}
	mut cw := cw_in
	mut rw := rect.right - rect.left
	mut rh := rect.bottom - rect.top
	if (rw < 0) != (rh < 0) {
		cw = !cw
	}
	sorted := rect_sorted(rect)
	rw = sorted.right - sorted.left
	rh = sorted.bottom - sorted.top
	outer := Rect{sorted.left - radius, sorted.top - radius, sorted.right + radius, sorted.bottom +
		radius}
	mut join := join_in
	if join == .miter && miter_limit < scalar_sqrt2 {
		join = .bevel
	}
	match join {
		.miter {
			out.builder.add_rect_dir(outer, cw, 0)
			out.known_convex = true
		}
		.bevel {
			r := sorted
			o := outer
			pts := if cw {
				[Point{r.left, o.top}, Point{r.right, o.top}, Point{o.right, r.top},
					Point{o.right, r.bottom}, Point{r.right, o.bottom}, Point{r.left, o.bottom},
					Point{o.left, r.bottom}, Point{o.left, r.top}]
			} else {
				[Point{o.left, r.top}, Point{o.left, r.bottom}, Point{r.left, o.bottom},
					Point{r.right, o.bottom}, Point{o.right, r.bottom}, Point{o.right, r.top},
					Point{r.right, o.top}, Point{r.left, o.top}]
			}
			out.builder.add_closed_polygon(pts)
		}
		.round {
			out.builder.add_round_rect(outer, radius, cw)
			out.known_convex = true
		}
	}
	if width < fmin_std(rw, rh) {
		inner := Rect{sorted.left + radius, sorted.top + radius, sorted.right - radius, sorted.bottom - radius}
		out.builder.add_rect_dir(inner, !cw, 0)
		out.known_convex = false
	}
	return out
}

// stroke_path is SkStroke::strokePath() for a stroke (not stroke-and-fill)
// of width with cap, join and miter_limit, at the resolution scale of the
// canvas matrix.
fn stroke_path(src Path, width f32, cap StrokeCap, join StrokeJoin, miter_limit f32, res_scale f32) StrokeOutline {
	radius := width * f32(0.5)
	if radius <= 0 {
		return StrokeOutline{}
	}
	if src.bounds() == none {
		return StrokeOutline{}
	}
	if rc := src.rect_contour() {
		if rc.closed {
			return stroke_rect(rc.rect, width, join, miter_limit, rc.cw)
		}
	}
	mut stroker := new_path_stroker(radius, miter_limit, cap, join, res_scale)
	mut iter := StrokeIter{
		verbs:   src.verbs
		points:  src.points
		weights: src.weights
	}
	mut last_segment := PathVerb.move
	for {
		rec := iter.next() or { break }
		p := rec.pts
		match rec.verb {
			.move {
				stroker.move_to(p[0])
			}
			.line {
				stroker.line_to(p[1], iter)
				last_segment = .line
			}
			.quad {
				stroker.quad_to(p[1], p[2])
				last_segment = .quad
			}
			.conic {
				stroker.conic_to(p[1], p[2], rec.weight)
				last_segment = .conic
			}
			.cubic {
				stroker.cubic_to(p[1], p[2], p[3])
				last_segment = .cubic
			}
			.close {
				if cap != .butt {
					if stroker.segment_count == 0 {
						stroker.line_to(stroker.first_pt, none)
						last_segment = .line
						continue
					}
					if stroker.is_current_contour_empty() {
						last_segment = .line
						continue
					}
				}
				stroker.finish_contour(true, last_segment == .line)
			}
		}
	}
	stroker.finish_contour(false, last_segment == .line)
	return StrokeOutline{
		builder: stroker.outer
	}
}

// The stroke outline mapped through m as SkPathBuilder::transform() does,
// with whether its convexity is still known.
fn (o StrokeOutline) transformed(m Matrix) (Path, bool) {
	path := Path{
		verbs:     o.builder.verbs
		points:    o.builder.points
		weights:   o.builder.weights
		fill_type: .winding
	}
	if m.is_identity() || path.verbs.len == 0 {
		return path, o.known_convex
	}
	// A transform that does not keep rects rects, or points that are not
	// axis aligned, drop the convexity (SkPathPriv::IsAxisAligned()).
	mut keeps := o.known_convex
	if keeps {
		rect_stays_rect := if m.b != 0 || m.c != 0 {
			m.a == 0 && m.d == 0 && m.b != 0 && m.c != 0
		} else {
			m.a != 0 && m.d != 0
		}
		keeps = rect_stays_rect
		for i in 1 .. path.points.len {
			if path.points[i - 1].x != path.points[i].x && path.points[i - 1].y != path.points[i].y {
				keeps = false
				break
			}
		}
	}
	return path.transform(m), keeps
}
