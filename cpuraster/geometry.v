module cpuraster

import math

// SkGeometry.cpp (google/skia ee20d565): the curve chopping and conic
// subdivision the edge builder and clipper use. Every operation is a separate
// float operation, as Skia is compiled with -ffp-contract=off.

const scalar_nearly_zero = f32(1) / f32(1 << 12)

fn is_not_monotonic(a f32, b f32, c f32) bool {
	ab := a - b
	mut bc := b - c
	if ab < 0 {
		bc = -bc
	}
	return ab == 0 || bc < 0
}

fn valid_unit_divide(numer_in f32, denom_in f32) ?f32 {
	mut numer := numer_in
	mut denom := denom_in
	if numer < 0 {
		numer = -numer
		denom = -denom
	}
	if denom == 0 || numer == 0 || numer >= denom {
		return none
	}
	r := numer / denom
	if r != r || r == 0 {
		return none
	}
	return r
}

// SkFindUnitQuadRoots().
fn find_unit_quad_roots(a f32, b f32, c f32) []f32 {
	if a == 0 {
		if r := valid_unit_divide(-c, b) {
			return [r]
		}
		return []
	}
	bb := f64(b) * f64(b)
	ac := 4 * f64(a)
	ac4 := ac * f64(c)
	mut dr := bb - ac4
	if dr < 0 {
		return []
	}
	dr = math.sqrt(dr)
	r := f32(dr)
	if !is_finite_f32(r) {
		return []
	}
	q := if b < 0 { -(b - r) / 2 } else { -(b + r) / 2 }
	mut roots := []f32{cap: 2}
	if root := valid_unit_divide(q, a) {
		roots << root
	}
	if root := valid_unit_divide(c, q) {
		roots << root
	}
	if roots.len == 2 {
		if roots[0] > roots[1] {
			roots[0], roots[1] = roots[1], roots[0]
		} else if roots[0] == roots[1] {
			roots.delete_last()
		}
	}
	return roots
}

// interp(): v0 + (v1 - v0) * t.
@[inline]
fn interp(v0 f32, v1 f32, t f32) f32 {
	d := v1 - v0
	m := d * t
	return v0 + m
}

fn interp_point(a Point, b Point, t f32) Point {
	return Point{interp(a.x, b.x, t), interp(a.y, b.y, t)}
}

// SkChopQuadAt().
fn chop_quad_at(src []Point, t f32) []Point {
	p01 := interp_point(src[0], src[1], t)
	p12 := interp_point(src[1], src[2], t)
	return [src[0], p01, interp_point(p01, p12, t), p12, src[2]]
}

// SkChopQuadAtYExtrema() / SkChopQuadAtXExtrema(): 1 or 2 monotonic quads.
fn chop_quad_at_extrema(src []Point, y_axis bool) []Point {
	a := if y_axis { src[0].y } else { src[0].x }
	mut b := if y_axis { src[1].y } else { src[1].x }
	c := if y_axis { src[2].y } else { src[2].x }
	if is_not_monotonic(a, b, c) {
		ab := a - b
		abb := ab - b
		denom := abb + c
		if t := valid_unit_divide(ab, denom) {
			mut dst := chop_quad_at(src, t)
			// flatten_double_quad_extrema()
			if y_axis {
				dst[1].y = dst[2].y
				dst[3].y = dst[2].y
			} else {
				dst[1].x = dst[2].x
				dst[3].x = dst[2].x
			}
			return dst
		}
		b = if f32(math.abs(a - b)) < f32(math.abs(b - c)) { a } else { c }
	}
	if y_axis {
		return [Point{src[0].x, a}, Point{src[1].x, b}, Point{src[2].x, c}]
	}
	return [Point{a, src[0].y}, Point{b, src[1].y}, Point{c, src[2].y}]
}

// SkFindCubicExtrema().
fn find_cubic_extrema(a f32, b f32, c f32, d f32) []f32 {
	bc := b - c
	three_bc := 3 * bc
	da := d - a
	big_a := da + three_bc
	ab := a - b
	abb := ab - b
	abbc := abb + c
	big_b := 2 * abbc
	big_c := b - a
	return find_unit_quad_roots(big_a, big_b, big_c)
}

// unchecked_mix(): (b - a) * t + a.
@[inline]
fn unchecked_mix(a f32, b f32, t f32) f32 {
	d := b - a
	m := d * t
	return m + a
}

fn mix_point(a Point, b Point, t f32) Point {
	return Point{unchecked_mix(a.x, b.x, t), unchecked_mix(a.y, b.y, t)}
}

// SkChopCubicAt(src, dst[7], t).
fn chop_cubic_at(src []Point, t f32) []Point {
	if t == 1 {
		return [src[0], src[1], src[2], src[3], src[3], src[3], src[3]]
	}
	ab := mix_point(src[0], src[1], t)
	bc := mix_point(src[1], src[2], t)
	cd := mix_point(src[2], src[3], t)
	abc := mix_point(ab, bc, t)
	bcd := mix_point(bc, cd, t)
	abcd := mix_point(abc, bcd, t)
	return [src[0], ab, abc, abcd, bcd, cd, src[3]]
}

// SkChopCubicAt(src, dst[10], t0, t1).
fn chop_cubic_at2(src []Point, t0 f32, t1 f32) []Point {
	if t1 == 1 {
		mut dst := chop_cubic_at(src, t0)
		dst << [src[3], src[3], src[3]]
		return dst
	}
	ab0 := mix_point(src[0], src[1], t0)
	bc0 := mix_point(src[1], src[2], t0)
	cd0 := mix_point(src[2], src[3], t0)
	abc0 := mix_point(ab0, bc0, t0)
	bcd0 := mix_point(bc0, cd0, t0)
	abcd0 := mix_point(abc0, bcd0, t0)
	bc1 := mix_point(src[1], src[2], t1)
	cd1 := mix_point(src[2], src[3], t1)
	ab1 := mix_point(src[0], src[1], t1)
	abc1 := mix_point(ab1, bc1, t1)
	bcd1 := mix_point(bc1, cd1, t1)
	abcd1 := mix_point(abc1, bcd1, t1)
	// middle = unchecked_mix(abc, bcd, shuffle<2,3,0,1>(T)).
	middle0 := mix_point(abc0, bcd0, t1)
	middle1 := mix_point(abc1, bcd1, t0)
	return [src[0], ab0, abc0, abcd0, middle0, middle1, abcd1, bcd1, cd1, src[3]]
}

// SkChopCubicAtYExtrema() / SkChopCubicAtXExtrema().
fn chop_cubic_at_extrema(src []Point, y_axis bool) []Point {
	roots := if y_axis {
		find_cubic_extrema(src[0].y, src[1].y, src[2].y, src[3].y)
	} else {
		find_cubic_extrema(src[0].x, src[1].x, src[2].x, src[3].x)
	}
	mut dst := match roots.len {
		0 { src[..4].clone() }
		1 { chop_cubic_at(src, roots[0]) }
		else { chop_cubic_at2(src, roots[0], roots[1]) }
	}
	if roots.len > 0 {
		flatten_double_cubic_extrema(mut dst, 0, y_axis)
		if roots.len == 2 {
			flatten_double_cubic_extrema(mut dst, 3, y_axis)
		}
	}
	return dst
}

fn flatten_double_cubic_extrema(mut dst []Point, start int, y_axis bool) {
	if y_axis {
		dst[start + 2].y = dst[start + 3].y
		dst[start + 4].y = dst[start + 3].y
	} else {
		dst[start + 2].x = dst[start + 3].x
		dst[start + 4].x = dst[start + 3].x
	}
}

// SkChopCubicAt(src, dst, tValues, tCount): two chops at a time, then the
// last one rescaled into the remaining cubic.
fn chop_cubic_at_ts(src []Point, ts []f32) []Point {
	if ts.len == 0 {
		return src[..4].clone()
	}
	if ts.len == 1 {
		return chop_cubic_at(src, ts[0])
	}
	mut dst := chop_cubic_at2(src, ts[0], ts[1])
	if ts.len == 3 {
		last_t := ts[1]
		numer := ts[2] - last_t
		denom := 1 - last_t
		tail := chop_cubic_at(dst[6..10], tpin(numer / denom, 0, 1))
		dst = dst[..6].clone()
		dst << tail
	}
	return dst
}

// SkTPin(): std::max(lo, std::min(x, hi)).
@[inline]
fn tpin(x f32, lo f32, hi f32) f32 {
	m := if hi < x { hi } else { x }
	return if lo < m { m } else { lo }
}

// SkFindCubicMaxCurvature()'s solve_cubic_poly(): the distinct roots of
// coeff[0]t^3 + coeff[1]t^2 + coeff[2]t + coeff[3], pinned to [0, 1] and sorted.
fn solve_cubic_poly(coeff [4]f32) []f32 {
	if f32(math.abs(coeff[0])) <= scalar_nearly_zero {
		return find_unit_quad_roots(coeff[1], coeff[2], coeff[3])
	}
	inva := f32(1) / coeff[0]
	a := coeff[1] * inva
	b := coeff[2] * inva
	c := coeff[3] * inva
	aa := a * a
	b3 := b * 3
	q := (aa - b3) / 9
	a2 := 2 * a
	a2a := a2 * a
	a2aa := a2a * a
	a9 := 9 * a
	a9b := a9 * b
	r_partial := a2aa - a9b
	c27 := 27 * c
	r_sum := r_partial + c27
	r := r_sum / 54
	qq := q * q
	q3 := qq * q
	rr := r * r
	r2_minus_q3 := rr - q3
	adiv3 := a / 3
	if r2_minus_q3 < 0 {
		theta := C.acosf(tpin(r / C.sqrtf(q3), -1, 1))
		neg2_root_q := -2 * C.sqrtf(q)
		two_pi := f32(2) * scalar_pi
		mut roots := []f32{len: 3}
		for i, angle in [theta, theta + two_pi, theta - two_pi] {
			cosine := C.cosf(angle / 3)
			scaled := neg2_root_q * cosine
			roots[i] = tpin(scaled - adiv3, 0, 1)
		}
		for i := 2; i > 0; i-- {
			for j := i; j > 0; j-- {
				if roots[j] < roots[j - 1] {
					roots[j], roots[j - 1] = roots[j - 1], roots[j]
				}
			}
		}
		// collaps_duplicates()
		mut count := 3
		mut start := 0
		for n := 3; n > 1; n-- {
			if roots[start] == roots[start + 1] {
				for i in start + 1 .. start + n {
					roots[i - 1] = roots[i]
				}
				count--
			} else {
				start++
			}
		}
		return roots[..count]
	}
	sqrt_disc := C.sqrtf(r2_minus_q3)
	mut big_a := f32(math.abs(r)) + sqrt_disc
	big_a = C.powf(big_a, f32(0.3333333))
	if r > 0 {
		big_a = -big_a
	}
	if big_a != 0 {
		big_a += q / big_a
	}
	return [tpin(big_a - adiv3, 0, 1)]
}

// formulate_F1DotF2() on one axis: F' dot F'' as a cubic in t.
fn f1_dot_f2(p0 f32, p1 f32, p2 f32, p3 f32) [4]f32 {
	a := p1 - p0
	p1_2 := 2 * p1
	b_partial := p2 - p1_2
	b := b_partial + p0
	diff := p1 - p2
	diff3 := 3 * diff
	c_partial := p3 + diff3
	c := c_partial - p0
	b3 := 3 * b
	bb2 := 2 * b
	bb := bb2 * b
	ca := c * a
	return [c * c, b3 * c, bb + ca, a * b]!
}

// SkChopCubicAtMaxCurvature(): count + 1 cubics sharing end points.
fn chop_cubic_at_max_curvature(src []Point) []Point {
	x := f1_dot_f2(src[0].x, src[1].x, src[2].x, src[3].x)
	y := f1_dot_f2(src[0].y, src[1].y, src[2].y, src[3].y)
	mut coeff := [4]f32{}
	for i in 0 .. 4 {
		coeff[i] = x[i] + y[i]
	}
	mut ts := []f32{cap: 3}
	for root in solve_cubic_poly(coeff) {
		if 0 < root && root < 1 {
			ts << root
		}
	}
	return chop_cubic_at_ts(src, ts)
}

// SkConic.
struct Conic {
mut:
	pts [3]Point
	w   f32
}

const max_conic_to_quad_pow2 = 5

// AS_QUAD_ERROR_SETUP and SkConic::computeQuadPOW2().
fn (c Conic) compute_quad_pow2(tol f32) int {
	for p in c.pts {
		if !is_finite_f32(p.x) || !is_finite_f32(p.y) {
			return 0
		}
	}
	if c.w < 0 || !is_finite_f32(c.w) {
		return 0
	}
	a := c.w - 1
	two_a := 2 + a
	four := 4 * two_a
	k := a / four
	x2 := 2 * c.pts[1].x
	xs := c.pts[0].x - x2
	xd := xs + c.pts[2].x
	x := k * xd
	y2 := 2 * c.pts[1].y
	ys := c.pts[0].y - y2
	yd := ys + c.pts[2].y
	y := k * yd
	xx := x * x
	yy := y * y
	sum := xx + yy
	mut err := f32(math.sqrt(f64(sum)))
	mut pow2 := 0
	for pow2 = 0; pow2 < max_conic_to_quad_pow2; pow2++ {
		if err <= tol {
			break
		}
		err *= 0.25
	}
	return pow2
}

fn subdivide_w_value(w f32) f32 {
	half_w := w * 0.5
	return f32(math.sqrt(f64(f32(0.5) + half_w)))
}

// SkConic::chop() without SK_SUPPORT_LEGACY_CONIC_CHOP.
fn (c Conic) chop() [2]Conic {
	scale := f32(1) / (f32(1) + c.w)
	ws := c.w * scale
	t0 := Point{c.pts[0].x * scale, c.pts[0].y * scale}
	t1 := Point{c.pts[1].x * ws, c.pts[1].y * ws}
	t2 := Point{c.pts[2].x * scale, c.pts[2].y * scale}
	p1 := Point{t0.x + t1.x, t0.y + t1.y}
	p3 := Point{t1.x + t2.x, t1.y + t2.y}
	hx0 := f32(0.5) * t0.x
	hy0 := f32(0.5) * t0.y
	hx2 := f32(0.5) * t2.x
	hy2 := f32(0.5) * t2.y
	mx := hx0 + t1.x
	my := hy0 + t1.y
	p2 := Point{mx + hx2, my + hy2}
	new_w := subdivide_w_value(c.w)
	return [Conic{[c.pts[0], p1, p2]!, new_w}, Conic{[p2, p3, c.pts[2]]!, new_w}]!
}

fn between(a f32, b f32, c f32) bool {
	ab := a - b
	cb := c - b
	return ab * cb <= 0
}

fn subdivide_conic(src Conic, mut pts []Point, level int) {
	if level == 0 {
		pts << src.pts[1]
		pts << src.pts[2]
		return
	}
	mut dst := src.chop()
	start_y := src.pts[0].y
	end_y := src.pts[2].y
	if between(start_y, src.pts[1].y, end_y) {
		mid_y := dst[0].pts[2].y
		if !between(start_y, mid_y, end_y) {
			closer := if f32(math.abs(mid_y - start_y)) < f32(math.abs(mid_y - end_y)) {
				start_y
			} else {
				end_y
			}
			dst[0].pts[2].y = closer
			dst[1].pts[0].y = closer
		}
		if !between(start_y, dst[0].pts[1].y, dst[0].pts[2].y) {
			dst[0].pts[1].y = start_y
		}
		if !between(dst[1].pts[0].y, dst[1].pts[1].y, end_y) {
			dst[1].pts[1].y = end_y
		}
	}
	subdivide_conic(dst[0], mut pts, level - 1)
	subdivide_conic(dst[1], mut pts, level - 1)
}

// SkAutoConicToQuads::computeQuads(): 2 * count + 1 points.
fn conic_to_quads(pts []Point, w f32, tol f32) []Point {
	conic := Conic{[pts[0], pts[1], pts[2]]!, w}
	mut pow2 := conic.compute_quad_pow2(tol)
	if w < 0 || !is_finite_f32(w) {
		pow2 = 0
	}
	mut out := [pts[0]]
	mut done := false
	if pow2 == max_conic_to_quad_pow2 {
		dst := conic.chop()
		if points_equal_within_tolerance(dst[0].pts[1], dst[0].pts[2])
			&& points_equal_within_tolerance(dst[1].pts[0], dst[1].pts[1]) {
			out << [dst[0].pts[1], dst[0].pts[1], dst[0].pts[1], dst[1].pts[2]]
			pow2 = 1
			done = true
		}
	}
	if !done {
		subdivide_conic(conic, mut out, pow2)
	}
	mut finite := true
	for p in out {
		if !is_finite_f32(p.x) || !is_finite_f32(p.y) {
			finite = false
		}
	}
	if !finite {
		for i in 1 .. out.len - 1 {
			out[i] = pts[1]
		}
	}
	return out
}

// SkPointPriv::EqualsWithinTolerance(): !CanNormalize(dx, dy).
fn points_equal_within_tolerance(a Point, b Point) bool {
	dx := a.x - b.x
	dy := a.y - b.y
	return !(is_finite_f32(dx) && is_finite_f32(dy) && (dx != 0 || dy != 0))
}

// SkCubics, SkQuads and SkBezierCubic (src/base): the double-precision root
// finding behind SkChopMonoCubicAtX/Y. libm supplies acos, cos and cbrt, as
// for Skia.
fn C.acos(x f64) f64
fn C.cos(x f64) f64
fn C.cbrt(x f64) f64
fn C.fma(x f64, y f64, z f64) f64
fn C.acosf(x f32) f32
fn C.powf(x f32, y f32) f32

const float_epsilon = f64(1.1920928955078125e-07)
const double_pi = f64(3.14159265358979323846264338327950288)

fn double_magnitude(a f64) f64 {
	return math.f64_from_bits(math.f64_bits(a) & 0x7ff0000000000000)
}

// sk_doubles_nearly_equal_ulps() with maxUlpsDiff 16.
fn doubles_nearly_equal_ulps(a f64, b f64) bool {
	min_magnitude := f64(2.2250738585072014e-308)
	mag_a := double_magnitude(a)
	mut max_magnitude := if mag_a < min_magnitude { min_magnitude } else { mag_a }
	mag_b := double_magnitude(b)
	if max_magnitude < mag_b {
		max_magnitude = mag_b
	}
	tolerance := max_magnitude * (f64(2.220446049250313e-16) * 17)
	return a == b || math.abs(b - a) < tolerance
}

fn double_nearly_zero(a f64) bool {
	return a == 0 || math.abs(a) < float_epsilon
}

fn doubles_nearly_equal(x f64, y f64) bool {
	if double_nearly_zero(x) {
		return double_nearly_zero(y)
	}
	return doubles_nearly_equal_ulps(x, y)
}

fn is_finite_f64(v f64) bool {
	return math.f64_bits(v) & 0x7ff0000000000000 != 0x7ff0000000000000
}

fn solve_linear(m f64, b f64) []f64 {
	if double_nearly_zero(m) {
		if double_nearly_zero(b) {
			return [f64(0)]
		}
		return []
	}
	root := -b / m
	if !is_finite_f64(root) {
		return []
	}
	return [root]
}

fn quads_discriminant(a f64, b f64, c f64) f64 {
	b2 := b * b
	ac := a * c
	rough := b2 - ac
	sum := b2 + ac
	if 3 * math.abs(rough) >= sum {
		return rough
	}
	b2_error := C.fma(b, b, -b2)
	ac_error := C.fma(a, c, -ac)
	main := b2 - ac
	err := b2_error - ac_error
	return main + err
}

// SkQuads::RootsReal().
fn quads_roots_real(a f64, b f64, c f64) []f64 {
	if a == 0 || math.abs(b / a) >= 1.0e+16 {
		return solve_linear(b, c)
	}
	half_b := -0.5 * b
	discriminant := quads_discriminant(a, half_b, c)
	if !is_finite_f64(discriminant) || discriminant < 0 {
		return []
	}
	mut root0 := f64(0)
	mut root1 := f64(0)
	if discriminant == 0 {
		root0 = half_b / a
		root1 = root0
	} else {
		d := math.sqrt(discriminant)
		r := if half_b > 0 { half_b + d } else { half_b - d }
		root0 = r / a
		root1 = c / r
	}
	mut roots := []f64{}
	r0 := if double_nearly_zero(root0) { f64(0) } else { root0 }
	if is_finite_f64(r0) {
		roots << r0
	}
	r1 := if double_nearly_zero(root1) { f64(0) } else { root1 }
	if is_finite_f64(r1) {
		roots << r1
	}
	if roots.len == 2 && doubles_nearly_equal_ulps(roots[0], roots[1]) {
		roots.delete_last()
	}
	return roots
}

// SkCubics::RootsReal().
fn cubics_roots_real(a_in f64, b_in f64, c_in f64, d_in f64) []f64 {
	mut big_a := a_in
	big_b := b_in
	big_c := c_in
	big_d := d_in
	close_to_quadratic := if double_nearly_zero(big_b) {
		double_nearly_zero(big_a)
	} else {
		math.abs(big_a / big_b) < 1.0e-7
	}
	if close_to_quadratic {
		return quads_roots_real(big_b, big_c, big_d)
	}
	if double_nearly_zero(big_d) {
		mut roots := quads_roots_real(big_a, big_b, big_c)
		for r in roots {
			if double_nearly_zero(r) {
				return roots
			}
		}
		roots << 0
		return roots
	}
	ab := big_a + big_b
	abc := ab + big_c
	if double_nearly_zero(abc + big_d) {
		mut roots := quads_roots_real(big_a, ab, -big_d)
		for r in roots {
			if doubles_nearly_equal_ulps(r, 1) {
				return roots
			}
		}
		roots << 1
		return roots
	}
	inv_a := 1 / big_a
	a := big_b * inv_a
	b := big_c * inv_a
	c := big_d * inv_a
	a2 := a * a
	b3 := b * 3
	q := (a2 - b3) / 9
	two_a2 := 2 * a2
	two_a3 := two_a2 * a
	nine_a := 9 * a
	nine_ab := nine_a * b
	r_num := two_a3 - nine_ab
	c27 := 27 * c
	r := (r_num + c27) / 54
	r2 := r * r
	q2 := q * q
	q3 := q2 * q
	r2_minus_q3 := r2 - q3
	if !is_finite_f64(r2_minus_q3) {
		return []
	}
	adiv3 := a / 3
	mut roots := []f64{}
	if r2_minus_q3 < 0 {
		ratio := r / math.sqrt(q3)
		theta := C.acos(if ratio < -1 {
			-1
		} else if ratio > 1 {
			1
		} else {
			ratio
		})
		neg2_root_q := -2 * math.sqrt(q)
		// Each product is its own statement: SkCubics is compiled with
		// -ffp-contract=off, and clang would fuse it into the subtraction.
		first := neg2_root_q * C.cos(theta / 3)
		roots << first - adiv3
		second := neg2_root_q * C.cos((theta + 2 * double_pi) / 3)
		mut root := second - adiv3
		if !doubles_nearly_equal(roots[0], root) {
			roots << root
		}
		third := neg2_root_q * C.cos((theta - 2 * double_pi) / 3)
		root = third - adiv3
		if !doubles_nearly_equal(roots[0], root)
			&& (roots.len == 1 || !doubles_nearly_equal(roots[1], root)) {
			roots << root
		}
	} else {
		sqrt_r2_minus_q3 := math.sqrt(r2_minus_q3)
		big_a = math.abs(r) + sqrt_r2_minus_q3
		big_a = C.cbrt(big_a)
		if r > 0 {
			big_a = -big_a
		}
		if !double_nearly_zero(big_a) {
			big_a += q / big_a
		}
		roots << big_a - adiv3
		if !double_nearly_zero(r2) && doubles_nearly_equal_ulps(r2, q3) {
			root := -big_a / 2 - adiv3
			if !doubles_nearly_equal(roots[0], root) {
				roots << root
			}
		}
	}
	return roots
}

// SkCubics::RootsValidT().
fn cubics_roots_valid_t(a f64, b f64, c f64, d f64) []f64 {
	mut solution := []f64{}
	for t in cubics_roots_real(a, b, c, d) {
		if t <= 1.00005 && (t >= 1.0 || doubles_nearly_equal_ulps(t, 1.0)) {
			if (solution.len < 1 || !doubles_nearly_equal_ulps(solution[0], 1))
				&& (solution.len < 2 || !doubles_nearly_equal_ulps(solution[1], 1)) {
				solution << 1
			}
		} else if t >= -0.00005 && (t <= 0.0 || double_nearly_zero(t)) {
			if (solution.len < 1 || !double_nearly_zero(solution[0]))
				&& (solution.len < 2 || !double_nearly_zero(solution[1])) {
				solution << 0
			}
		} else if t > 0.0 && t < 1.0 {
			solution << t
		}
	}
	return solution
}

// SkCubics::EvalAt().
fn cubics_eval_at(a f64, b f64, c f64, d f64, t f64) f64 {
	return C.fma(t, C.fma(t, C.fma(t, a, b), c), d)
}

fn approximately_zero(x f64) bool {
	return math.abs(x) < 0.00000001
}

fn cubics_binary_search(a f64, b f64, c f64, d f64, start_in f64, stop_in f64) f64 {
	mut start := start_in
	mut stop := stop_in
	left := cubics_eval_at(a, b, c, d, start)
	if approximately_zero(left) {
		return start
	}
	right := cubics_eval_at(a, b, c, d, stop)
	if !is_finite_f64(left) || !is_finite_f64(right) {
		return -1
	}
	if (left > 0 && right > 0) || (left < 0 && right < 0) {
		return -1
	}
	for _ in 0 .. 1000 {
		step := (start + stop) / 2
		curr := cubics_eval_at(a, b, c, d, step)
		if approximately_zero(curr) {
			return step
		}
		if (curr < 0 && left < 0) || (curr > 0 && left > 0) {
			start = step
		} else {
			stop = step
		}
	}
	return -1
}

// SkCubics::BinarySearchRootsValidT().
fn cubics_binary_search_roots(a f64, b f64, c f64, d f64) []f64 {
	if !is_finite_f64(a) || !is_finite_f64(b) || !is_finite_f64(c) || !is_finite_f64(d) {
		return []
	}
	mut regions := [f64(0), 0, 0, 1]
	mut extrema := []f64{}
	for t in quads_roots_real(3 * a, 2 * b, c) {
		if t >= 0 && t <= 1.0 {
			extrema << t
		}
	}
	mut start := 2 - extrema.len
	if extrema.len == 1 {
		regions[start + 1] = extrema[0]
	}
	if extrema.len == 2 {
		regions[start + 1] = math.min(extrema[0], extrema[1])
		regions[start + 2] = math.max(extrema[0], extrema[1])
	}
	mut solution := []f64{}
	for ; start < 3; start++ {
		root := cubics_binary_search(a, b, c, d, regions[start], regions[start + 1])
		if root >= 0 {
			if (solution.len < 1 || !approximately_zero(solution[0] - root))
				&& (solution.len < 2 || !approximately_zero(solution[1] - root)) {
				solution << root
			}
		}
	}
	return solution
}

// SkBezierCubic::ConvertToPolynomial().
fn bezier_polynomial(p []f64) [4]f64 {
	t1 := 3 * p[1]
	s0 := -p[0] + t1
	t2 := 3 * p[2]
	s1 := s0 - t2
	a := s1 + p[3]
	u0 := 3 * p[0]
	u1 := 6 * p[1]
	u2 := 3 * p[2]
	v0 := u0 - u1
	b := v0 + u2
	w0 := -3 * p[0]
	w1 := 3 * p[1]
	c := w0 + w1
	return [a, b, c, p[0]]!
}

fn first_axis_intersection(coords []f64, intercept f64) ?f64 {
	poly := bezier_polynomial(coords)
	d := poly[3] - intercept
	for search in [false, true] {
		roots := if search {
			cubics_binary_search_roots(poly[0], poly[1], poly[2], d)
		} else {
			cubics_roots_valid_t(poly[0], poly[1], poly[2], d)
		}
		for root in roots {
			// close_enough_to_zero()
			if math.abs(cubics_eval_at(poly[0], poly[1], poly[2], d, root)) < 0.00001 {
				return root
			}
		}
		if roots.len == 0 && !search {
			return none
		}
	}
	return none
}

@[inline]
fn interpolate_f64(a f64, b f64, t f64) f64 {
	d := b - a
	m := d * t
	return a + m
}

// SkChopMonoCubicAtY() / SkChopMonoCubicAtX(): 7 points, or none.
fn chop_mono_cubic_at(src []Point, value f32, y_axis bool) ?[]Point {
	coords := if y_axis {
		[f64(src[0].y), src[1].y, src[2].y, src[3].y]
	} else {
		[f64(src[0].x), src[1].x, src[2].x, src[3].x]
	}
	t := first_axis_intersection(coords, f64(value))?
	xs := [f64(src[0].x), src[1].x, src[2].x, src[3].x]
	ys := [f64(src[0].y), src[1].y, src[2].y, src[3].y]
	sx := subdivide_cubic_f64(xs, t)
	sy := subdivide_cubic_f64(ys, t)
	mut dst := []Point{len: 7}
	for i in 0 .. 7 {
		dst[i] = Point{f32(sx[i]), f32(sy[i])}
	}
	return dst
}

// SkBezierCubic::Subdivide() for one coordinate.
fn subdivide_cubic_f64(p []f64, t f64) [7]f64 {
	p01 := interpolate_f64(p[0], p[1], t)
	p12 := interpolate_f64(p[1], p[2], t)
	p23 := interpolate_f64(p[2], p[3], t)
	a2 := interpolate_f64(p01, p12, t)
	b1 := interpolate_f64(p12, p23, t)
	mid := interpolate_f64(a2, b1, t)
	return [p[0], p01, a2, mid, b1, p23, p[3]]!
}

// mono_cubic_closestT() in SkEdgeClipper.cpp.
fn mono_cubic_closest_t(c []f32, x_in f32) f32 {
	mut t := f32(0.5)
	mut last_t := f32(0)
	mut best_t := f32(0)
	mut step := f32(0.25)
	d := c[0]
	c12 := c[1] - c[2]
	three_c12 := 3 * c12
	a0 := c[3] + three_c12
	a := a0 - d
	b0 := c[2] - c[1]
	b1 := b0 - c[1]
	b2 := b1 + d
	b := 3 * b2
	c1d := c[1] - d
	cc := 3 * c1d
	x := x_in - d
	mut closest := f32(3.4028235e38)
	for {
		at := a * t
		atb := at + b
		atbt := atb * t
		atbtc := atbt + cc
		loc := atbtc * t
		diff := loc - x
		dist := if diff < 0 { -diff } else { diff }
		if closest > dist {
			closest = dist
			best_t = t
		}
		last_t = t
		t += if loc < x { step } else { -step }
		step *= 0.5
		if !(closest > 0.25 && last_t != t) {
			break
		}
	}
	return best_t
}

// chop_mono_cubic_at_y() / chop_mono_cubic_at_x() in SkEdgeClipper.cpp.
fn chop_mono_cubic_at_clip(src []Point, value f32, y_axis bool) []Point {
	if dst := chop_mono_cubic_at(src, value, y_axis) {
		return dst
	}
	coords := if y_axis {
		[src[0].y, src[1].y, src[2].y, src[3].y]
	} else {
		[src[0].x, src[1].x, src[2].x, src[3].x]
	}
	return chop_cubic_at(src, mono_cubic_closest_t(coords, value))
}
