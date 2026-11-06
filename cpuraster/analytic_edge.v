module cpuraster

import math.bits

// SkAnalyticEdge.cpp and SkAnalyticEdge.h (google/skia ee20d565): line,
// quadratic and cubic edges for analytic anti-aliasing, in 16.16 fixed point
// with y snapped to quarter pixels. Edges link by index into one array.

const fixed1 = i32(65536)
const fixed_half = i32(32768)
const default_accuracy = 2
const max_coeff_shift = 6
const inverse_table_size = 1024

const edge_line = u8(0)
const edge_quad = u8(1)
const edge_cubic = u8(2)

struct Edge {
mut:
	next        int
	prev        int
	x           i32
	dx          i32
	upper_x     i32
	y           i32
	upper_y     i32
	lower_y     i32
	dy          i32
	edge_type   u8
	curve_count i8
	curve_shift u8
	winding     i8
	// SkAnalyticQuadraticEdge
	qx        i32
	qy        i32
	qdx       i32
	qdy       i32
	qddx      i32
	qddy      i32
	qlast_x   i32
	qlast_y   i32
	snapped_x i32
	// Shared by quadratic and cubic edges (fSnappedY).
	snapped_y i32
	// SkAnalyticCubicEdge
	cx           i32
	cy           i32
	cdx          i32
	cdy          i32
	cddx         i32
	cddy         i32
	cdddx        i32
	cdddy        i32
	clast_x      i32
	clast_y      i32
	cubic_dshift u8
}

@[inline]
fn left_shift(value i32, shift int) i32 {
	return i32(u32(value) << u32(shift))
}

@[inline]
fn abs32(value i32) i32 {
	return if value < 0 { -value } else { value }
}

@[inline]
fn fixed_mul(a i32, b i32) i32 {
	return i32((i64(a) * i64(b)) >> 16)
}

@[inline]
fn fixed_floor_to_int(x i32) int {
	return int(x >> 16)
}

@[inline]
fn fixed_ceil_to_int(x i32) int {
	return int((x + fixed1 - 1) >> 16)
}

@[inline]
fn fixed_round_to_fixed(x i32) i32 {
	return i32(u32(x + fixed_half) & 0xffff0000)
}

@[inline]
fn fixed_ceil_to_fixed(x i32) i32 {
	return i32(u32(x + fixed1 - 1) & 0xffff0000)
}

@[inline]
fn fixed_floor_to_fixed(x i32) i32 {
	return i32(u32(x) & 0xffff0000)
}

@[inline]
fn int_to_fixed(n int) i32 {
	return i32(u32(n) << 16)
}

@[inline]
fn fdot6_to_fixed(x i32) i32 {
	return left_shift(x, 10)
}

@[inline]
fn fixed_to_fdot6(x i32) i32 {
	return x >> 10
}

// SkFixedDiv(): clamped to 32 bits.
fn fixed_div(numer i32, denom i32) i32 {
	q := (i64(u64(i64(numer)) << 16)) / i64(denom)
	return if q > max_i32 {
		max_i32
	} else if q < min_i32 {
		min_i32
	} else {
		i32(q)
	}
}

fn fdot6_div(a i32, b i32) i32 {
	if a >= min_i16 && a <= max_i16 {
		return left_shift(a, 16) / b
	}
	return fixed_div(a, b)
}

// SnapY() with kDefaultAccuracy.
@[inline]
fn snap_y(y i32) i32 {
	return i32(((u32(y) + u32(fixed1 >> (default_accuracy + 1))) >> (16 - default_accuracy)) << (16 - default_accuracy))
}

// fcvtzs: truncate toward zero, saturating, NaN to zero.
fn saturate_to_i32(v f32) i32 {
	if v != v {
		return 0
	}
	if v >= f32(2147483648.0) {
		return max_i32
	}
	if v <= f32(-2147483648.0) {
		return min_i32
	}
	return i32(v)
}

// SkScalarToFDot6(v * (1 << kDefaultAccuracy)) and int(v * 256): exact
// power-of-two scaling, then truncation.
@[inline]
fn scalar_to_fdot6_aa(v f32) i32 {
	scaled := v * f32(4)
	return saturate_to_i32(scaled * f32(64))
}

fn quick_inverse(x i32) i32 {
	if x > 0 {
		return -quick_inverse_table[inverse_table_size - x]
	}
	return quick_inverse_table[inverse_table_size + x]
}

fn quick_div(a i32, b i32) i32 {
	min_bits := 3
	max_abs_a := i32(1) << (31 - (22 - min_bits))
	abs_a := abs32(a)
	abs_b := abs32(b)
	if abs_b >= (i32(1) << min_bits) && abs_b < inverse_table_size && abs_a < max_abs_a {
		return (a * quick_inverse(b)) >> 6
	}
	return fdot6_div(a, b)
}

// SkAnalyticEdge::setLine().
fn (mut e Edge) set_line(p0 Point, p1 Point) bool {
	mut x0 := fdot6_to_fixed(scalar_to_fdot6_aa(p0.x)) >> default_accuracy
	mut y0 := snap_y(fdot6_to_fixed(scalar_to_fdot6_aa(p0.y)) >> default_accuracy)
	mut x1 := fdot6_to_fixed(scalar_to_fdot6_aa(p1.x)) >> default_accuracy
	mut y1 := snap_y(fdot6_to_fixed(scalar_to_fdot6_aa(p1.y)) >> default_accuracy)
	mut winding := i8(1)
	if y0 > y1 {
		x0, x1 = x1, x0
		y0, y1 = y1, y0
		winding = -1
	}
	dy := fixed_to_fdot6(y1 - y0)
	if dy == 0 {
		return false
	}
	dx := fixed_to_fdot6(x1 - x0)
	slope := quick_div(dx, dy)
	abs_slope := abs32(slope)
	e.x = x0
	e.dx = slope
	e.upper_x = x0
	e.y = y0
	e.upper_y = y0
	e.lower_y = y1
	e.dy = if dx == 0 || slope == 0 {
		max_i32
	} else if abs_slope < inverse_table_size {
		quick_inverse(abs_slope)
	} else {
		abs32(quick_div(dy, dx))
	}
	e.edge_type = edge_line
	e.curve_count = 0
	e.winding = winding
	e.curve_shift = 0
	return true
}

// SkAnalyticEdge::updateLine().
fn (mut e Edge) update_line(x0_in i32, y0_in i32, x1_in i32, y1_in i32, slope i32) bool {
	mut x0 := x0_in
	mut y0 := y0_in
	mut x1 := x1_in
	mut y1 := y1_in
	if y0 > y1 {
		x0, x1 = x1, x0
		y0, y1 = y1, y0
		e.winding = -e.winding
	}
	dx := fixed_to_fdot6(x1 - x0)
	dy := fixed_to_fdot6(y1 - y0)
	if dy == 0 {
		return false
	}
	abs_slope := abs32(fixed_to_fdot6(slope))
	e.x = x0
	e.dx = slope
	e.upper_x = x0
	e.y = y0
	e.upper_y = y0
	e.lower_y = y1
	e.dy = if dx == 0 || slope == 0 {
		max_i32
	} else if abs_slope < inverse_table_size {
		quick_inverse(abs_slope)
	} else {
		abs32(quick_div(dy, dx))
	}
	return true
}

fn (mut e Edge) update() bool {
	if e.curve_count < 0 {
		return e.update_cubic()
	} else if e.curve_count > 0 {
		return e.update_quadratic()
	}
	return false
}

@[inline]
fn (mut e Edge) go_y(y i32) {
	if y == e.y + fixed1 {
		e.x = e.x + e.dx
		e.y = y
	} else if y != e.y {
		e.x = e.upper_x + fixed_mul(e.dx, y - e.upper_y)
		e.y = y
	}
}

@[inline]
fn (mut e Edge) go_y_shift(y i32, y_shift int) {
	e.y = y
	e.x += e.dx >> y_shift
}

fn cheap_distance(dx_in i32, dy_in i32) i32 {
	mut dx := abs32(dx_in)
	dy := abs32(dy_in)
	if dx > dy {
		dx += dy >> 1
	} else {
		dx = dy + (dx >> 1)
	}
	return dx
}

fn diff_to_shift(dx i32, dy i32, shift_aa int) int {
	mut dist := cheap_distance(dx, dy)
	dist = (dist + (i32(1) << (2 + shift_aa))) >> (3 + shift_aa)
	return (32 - bits.leading_zeros_32(u32(dist))) >> 1
}

// SkFDot6ToFixedDiv2().
@[inline]
fn fdot6_to_fixed_div2(value i32) i32 {
	return left_shift(value, 16 - 6 - 1)
}

// SkAnalyticQuadraticEdge::setQuadratic().
fn (mut e Edge) set_quadratic(pts []Point) bool {
	mut x0 := scalar_to_fdot6_aa(pts[0].x)
	mut y0 := scalar_to_fdot6_aa(pts[0].y)
	x1 := scalar_to_fdot6_aa(pts[1].x)
	y1 := scalar_to_fdot6_aa(pts[1].y)
	mut x2 := scalar_to_fdot6_aa(pts[2].x)
	mut y2 := scalar_to_fdot6_aa(pts[2].y)
	mut winding := i8(1)
	if y0 > y2 {
		x0, x2 = x2, x0
		y0, y2 = y2, y0
		winding = -1
	}
	top := (y0 + 32) >> 6
	bot := (y2 + 32) >> 6
	if top == bot {
		return false
	}
	mut shift := 0
	{
		dx := (left_shift(x1, 1) - x0 - x2) >> 2
		dy := (left_shift(y1, 1) - y0 - y2) >> 2
		shift = diff_to_shift(dx, dy, default_accuracy)
	}
	if shift == 0 {
		shift = 1
	} else if shift > max_coeff_shift {
		shift = max_coeff_shift
	}
	e.winding = winding
	e.edge_type = edge_quad
	e.curve_count = i8(1 << shift)
	e.curve_shift = u8(shift - 1)
	mut a := fdot6_to_fixed_div2(x0 - x1 - x1 + x2)
	mut b := fdot6_to_fixed(x1 - x0)
	e.qx = fdot6_to_fixed(x0)
	e.qdx = b + (a >> shift)
	e.qddx = a >> (shift - 1)
	a = fdot6_to_fixed_div2(y0 - y1 - y1 + y2)
	b = fdot6_to_fixed(y1 - y0)
	e.qy = fdot6_to_fixed(y0)
	e.qdy = b + (a >> shift)
	e.qddy = a >> (shift - 1)
	e.qlast_x = fdot6_to_fixed(x2)
	e.qlast_y = fdot6_to_fixed(y2)
	e.qx >>= default_accuracy
	e.qy >>= default_accuracy
	e.qdx >>= default_accuracy
	e.qdy >>= default_accuracy
	e.qddx >>= default_accuracy
	e.qddy >>= default_accuracy
	e.qlast_x >>= default_accuracy
	e.qlast_y >>= default_accuracy
	e.qy = snap_y(e.qy)
	e.qlast_y = snap_y(e.qlast_y)
	e.snapped_x = e.qx
	e.snapped_y = e.qy
	return e.update_quadratic()
}

// SkAnalyticQuadraticEdge::updateQuadratic().
fn (mut e Edge) update_quadratic() bool {
	mut success := false
	mut count := int(e.curve_count)
	mut oldx := e.qx
	mut oldy := e.qy
	mut dx := e.qdx
	mut dy := e.qdy
	mut newx := i32(0)
	mut newy := i32(0)
	mut new_snapped_x := i32(0)
	mut new_snapped_y := i32(0)
	shift := int(e.curve_shift)
	for {
		mut slope := i32(0)
		count--
		if count > 0 {
			newx = oldx + (dx >> shift)
			newy = oldy + (dy >> shift)
			if abs32(dy >> shift) >= fixed1 * 2 && (i64(abs32(dy)) << 6) > i64(abs32(dx)) {
				diff_y := fixed_to_fdot6(newy - e.snapped_y)
				slope = if diff_y != 0 {
					quick_div(fixed_to_fdot6(newx - e.snapped_x), diff_y)
				} else {
					max_i32
				}
				rounded := fixed_round_to_fixed(newy)
				new_snapped_y = if e.qlast_y < rounded { e.qlast_y } else { rounded }
				new_snapped_x = newx - fixed_mul(slope, newy - new_snapped_y)
			} else {
				snapped := snap_y(newy)
				new_snapped_y = if e.qlast_y < snapped { e.qlast_y } else { snapped }
				new_snapped_x = newx
				diff_y := fixed_to_fdot6(new_snapped_y - e.snapped_y)
				slope = if diff_y != 0 {
					quick_div(fixed_to_fdot6(newx - e.snapped_x), diff_y)
				} else {
					max_i32
				}
			}
			dx += e.qddx
			dy += e.qddy
		} else {
			newx = e.qlast_x
			newy = e.qlast_y
			new_snapped_y = newy
			new_snapped_x = newx
			diff_y := fixed_to_fdot6(newy - e.snapped_y)
			slope = if diff_y != 0 {
				quick_div(fixed_to_fdot6(newx - e.snapped_x), diff_y)
			} else {
				max_i32
			}
		}
		if slope < max_i32 {
			success = e.update_line(e.snapped_x, e.snapped_y, new_snapped_x, new_snapped_y,
				slope)
		}
		oldx = newx
		oldy = newy
		if !(count > 0 && !success) {
			break
		}
	}
	e.qx = newx
	e.qy = newy
	e.qdx = dx
	e.qdy = dy
	e.snapped_x = new_snapped_x
	e.snapped_y = new_snapped_y
	e.curve_count = i8(count)
	return success
}

fn cubic_delta_from_line(a i32, b i32, c i32, d i32) i32 {
	one_third := ((a * 8 - b * 15 + 6 * c + d) * 19) >> 9
	two_third := ((a + 6 * b - c * 15 + d * 8) * 19) >> 9
	o := abs32(one_third)
	t := abs32(two_third)
	return if o > t { o } else { t }
}

// SkAnalyticCubicEdge::setCubic().
fn (mut e Edge) set_cubic(pts []Point) bool {
	mut x0 := scalar_to_fdot6_aa(pts[0].x)
	mut y0 := scalar_to_fdot6_aa(pts[0].y)
	mut x1 := scalar_to_fdot6_aa(pts[1].x)
	mut y1 := scalar_to_fdot6_aa(pts[1].y)
	mut x2 := scalar_to_fdot6_aa(pts[2].x)
	mut y2 := scalar_to_fdot6_aa(pts[2].y)
	mut x3 := scalar_to_fdot6_aa(pts[3].x)
	mut y3 := scalar_to_fdot6_aa(pts[3].y)
	mut winding := i8(1)
	if y0 > y3 {
		x0, x3 = x3, x0
		x1, x2 = x2, x1
		y0, y3 = y3, y0
		y1, y2 = y2, y1
		winding = -1
	}
	top := (y0 + 32) >> 6
	bot := (y3 + 32) >> 6
	if top == bot {
		return false
	}
	mut shift := 0
	{
		dx := cubic_delta_from_line(x0, x1, x2, x3)
		dy := cubic_delta_from_line(y0, y1, y2, y3)
		shift = diff_to_shift(dx, dy, 2) + 1
	}
	if shift > max_coeff_shift {
		shift = max_coeff_shift
	}
	mut up_shift := 6
	mut down_shift := shift + up_shift - 10
	if down_shift < 0 {
		down_shift = 0
		up_shift = 10 - shift
	}
	e.winding = winding
	e.edge_type = edge_cubic
	e.curve_count = i8(left_shift(-1, shift))
	e.curve_shift = u8(shift)
	e.cubic_dshift = u8(down_shift)
	mut b := left_shift(3 * (x1 - x0), up_shift)
	mut c := left_shift(3 * (x0 - x1 - x1 + x2), up_shift)
	mut d := left_shift(x3 + 3 * (x1 - x2) - x0, up_shift)
	e.cx = fdot6_to_fixed(x0)
	e.cdx = b + (c >> shift) + (d >> (2 * shift))
	e.cddx = 2 * c + ((3 * d) >> (shift - 1))
	e.cdddx = (3 * d) >> (shift - 1)
	b = left_shift(3 * (y1 - y0), up_shift)
	c = left_shift(3 * (y0 - y1 - y1 + y2), up_shift)
	d = left_shift(y3 + 3 * (y1 - y2) - y0, up_shift)
	e.cy = fdot6_to_fixed(y0)
	e.cdy = b + (c >> shift) + (d >> (2 * shift))
	e.cddy = 2 * c + ((3 * d) >> (shift - 1))
	e.cdddy = (3 * d) >> (shift - 1)
	e.clast_x = fdot6_to_fixed(x3)
	e.clast_y = fdot6_to_fixed(y3)
	e.cx >>= default_accuracy
	e.cy >>= default_accuracy
	e.cdx >>= default_accuracy
	e.cdy >>= default_accuracy
	e.cddx >>= default_accuracy
	e.cddy >>= default_accuracy
	e.cdddx >>= default_accuracy
	e.cdddy >>= default_accuracy
	e.clast_x >>= default_accuracy
	e.clast_y >>= default_accuracy
	e.cy = snap_y(e.cy)
	e.snapped_y = e.cy
	e.clast_y = snap_y(e.clast_y)
	return e.update_cubic()
}

// SkAnalyticCubicEdge::updateCubic().
fn (mut e Edge) update_cubic() bool {
	mut success := false
	mut count := int(e.curve_count)
	mut oldx := e.cx
	mut oldy := e.cy
	mut newx := i32(0)
	mut newy := i32(0)
	ddshift := int(e.curve_shift)
	dshift := int(e.cubic_dshift)
	for {
		count++
		if count < 0 {
			newx = oldx + (e.cdx >> dshift)
			e.cdx += e.cddx >> ddshift
			e.cddx += e.cdddx
			newy = oldy + (e.cdy >> dshift)
			e.cdy += e.cddy >> ddshift
			e.cddy += e.cdddy
		} else {
			newx = e.clast_x
			newy = e.clast_y
		}
		if newy < oldy {
			newy = oldy
		}
		mut new_snapped_y := snap_y(newy)
		if e.clast_y < new_snapped_y {
			new_snapped_y = e.clast_y
			count = 0
		}
		slope := if fixed_to_fdot6(new_snapped_y - e.snapped_y) == 0 {
			max_i32
		} else {
			fdot6_div(fixed_to_fdot6(newx - oldx), fixed_to_fdot6(new_snapped_y - e.snapped_y))
		}
		success = e.update_line(oldx, e.snapped_y, newx, new_snapped_y, slope)
		oldx = newx
		oldy = newy
		e.snapped_y = new_snapped_y
		if !(count < 0 && !success) {
			break
		}
	}
	e.cx = newx
	e.cy = newy
	e.curve_count = i8(count)
	return success
}

// SkAnalyticQuadraticEdge::keepContinuous() / SkAnalyticCubicEdge::keepContinuous().
fn (mut e Edge) keep_continuous() {
	if e.curve_count < 0 {
		e.cx = e.x
		e.snapped_y = e.y
	} else {
		e.snapped_x = e.x
		e.snapped_y = e.y
	}
}

// quick_inverse(): -(1 << 22) / x for FDot6 x in [-1024, 0], then 0.
const quick_inverse_table = [
	i32(-4096),
	-4100,
	-4104,
	-4108,
	-4112,
	-4116,
	-4120,
	-4124,
	-4128,
	-4132,
	-4136,
	-4140,
	-4144,
	-4148,
	-4152,
	-4156,
	-4161,
	-4165,
	-4169,
	-4173,
	-4177,
	-4181,
	-4185,
	-4190,
	-4194,
	-4198,
	-4202,
	-4206,
	-4211,
	-4215,
	-4219,
	-4223,
	-4228,
	-4232,
	-4236,
	-4240,
	-4245,
	-4249,
	-4253,
	-4258,
	-4262,
	-4266,
	-4271,
	-4275,
	-4279,
	-4284,
	-4288,
	-4293,
	-4297,
	-4301,
	-4306,
	-4310,
	-4315,
	-4319,
	-4324,
	-4328,
	-4332,
	-4337,
	-4341,
	-4346,
	-4350,
	-4355,
	-4359,
	-4364,
	-4369,
	-4373,
	-4378,
	-4382,
	-4387,
	-4391,
	-4396,
	-4401,
	-4405,
	-4410,
	-4415,
	-4419,
	-4424,
	-4429,
	-4433,
	-4438,
	-4443,
	-4447,
	-4452,
	-4457,
	-4462,
	-4466,
	-4471,
	-4476,
	-4481,
	-4485,
	-4490,
	-4495,
	-4500,
	-4505,
	-4510,
	-4514,
	-4519,
	-4524,
	-4529,
	-4534,
	-4539,
	-4544,
	-4549,
	-4554,
	-4559,
	-4563,
	-4568,
	-4573,
	-4578,
	-4583,
	-4588,
	-4593,
	-4599,
	-4604,
	-4609,
	-4614,
	-4619,
	-4624,
	-4629,
	-4634,
	-4639,
	-4644,
	-4650,
	-4655,
	-4660,
	-4665,
	-4670,
	-4675,
	-4681,
	-4686,
	-4691,
	-4696,
	-4702,
	-4707,
	-4712,
	-4718,
	-4723,
	-4728,
	-4733,
	-4739,
	-4744,
	-4750,
	-4755,
	-4760,
	-4766,
	-4771,
	-4777,
	-4782,
	-4788,
	-4793,
	-4798,
	-4804,
	-4809,
	-4815,
	-4821,
	-4826,
	-4832,
	-4837,
	-4843,
	-4848,
	-4854,
	-4860,
	-4865,
	-4871,
	-4877,
	-4882,
	-4888,
	-4894,
	-4899,
	-4905,
	-4911,
	-4917,
	-4922,
	-4928,
	-4934,
	-4940,
	-4946,
	-4951,
	-4957,
	-4963,
	-4969,
	-4975,
	-4981,
	-4987,
	-4993,
	-4999,
	-5005,
	-5011,
	-5017,
	-5023,
	-5029,
	-5035,
	-5041,
	-5047,
	-5053,
	-5059,
	-5065,
	-5071,
	-5077,
	-5084,
	-5090,
	-5096,
	-5102,
	-5108,
	-5115,
	-5121,
	-5127,
	-5133,
	-5140,
	-5146,
	-5152,
	-5159,
	-5165,
	-5171,
	-5178,
	-5184,
	-5190,
	-5197,
	-5203,
	-5210,
	-5216,
	-5223,
	-5229,
	-5236,
	-5242,
	-5249,
	-5256,
	-5262,
	-5269,
	-5275,
	-5282,
	-5289,
	-5295,
	-5302,
	-5309,
	-5315,
	-5322,
	-5329,
	-5336,
	-5343,
	-5349,
	-5356,
	-5363,
	-5370,
	-5377,
	-5384,
	-5391,
	-5398,
	-5405,
	-5412,
	-5418,
	-5426,
	-5433,
	-5440,
	-5447,
	-5454,
	-5461,
	-5468,
	-5475,
	-5482,
	-5489,
	-5497,
	-5504,
	-5511,
	-5518,
	-5526,
	-5533,
	-5540,
	-5548,
	-5555,
	-5562,
	-5570,
	-5577,
	-5584,
	-5592,
	-5599,
	-5607,
	-5614,
	-5622,
	-5629,
	-5637,
	-5645,
	-5652,
	-5660,
	-5667,
	-5675,
	-5683,
	-5691,
	-5698,
	-5706,
	-5714,
	-5722,
	-5729,
	-5737,
	-5745,
	-5753,
	-5761,
	-5769,
	-5777,
	-5785,
	-5793,
	-5801,
	-5809,
	-5817,
	-5825,
	-5833,
	-5841,
	-5849,
	-5857,
	-5866,
	-5874,
	-5882,
	-5890,
	-5899,
	-5907,
	-5915,
	-5924,
	-5932,
	-5940,
	-5949,
	-5957,
	-5966,
	-5974,
	-5983,
	-5991,
	-6000,
	-6009,
	-6017,
	-6026,
	-6034,
	-6043,
	-6052,
	-6061,
	-6069,
	-6078,
	-6087,
	-6096,
	-6105,
	-6114,
	-6123,
	-6132,
	-6141,
	-6150,
	-6159,
	-6168,
	-6177,
	-6186,
	-6195,
	-6204,
	-6213,
	-6223,
	-6232,
	-6241,
	-6250,
	-6260,
	-6269,
	-6278,
	-6288,
	-6297,
	-6307,
	-6316,
	-6326,
	-6335,
	-6345,
	-6355,
	-6364,
	-6374,
	-6384,
	-6393,
	-6403,
	-6413,
	-6423,
	-6432,
	-6442,
	-6452,
	-6462,
	-6472,
	-6482,
	-6492,
	-6502,
	-6512,
	-6523,
	-6533,
	-6543,
	-6553,
	-6563,
	-6574,
	-6584,
	-6594,
	-6605,
	-6615,
	-6626,
	-6636,
	-6647,
	-6657,
	-6668,
	-6678,
	-6689,
	-6700,
	-6710,
	-6721,
	-6732,
	-6743,
	-6754,
	-6765,
	-6775,
	-6786,
	-6797,
	-6808,
	-6820,
	-6831,
	-6842,
	-6853,
	-6864,
	-6875,
	-6887,
	-6898,
	-6909,
	-6921,
	-6932,
	-6944,
	-6955,
	-6967,
	-6978,
	-6990,
	-7002,
	-7013,
	-7025,
	-7037,
	-7049,
	-7061,
	-7073,
	-7084,
	-7096,
	-7108,
	-7121,
	-7133,
	-7145,
	-7157,
	-7169,
	-7182,
	-7194,
	-7206,
	-7219,
	-7231,
	-7244,
	-7256,
	-7269,
	-7281,
	-7294,
	-7307,
	-7319,
	-7332,
	-7345,
	-7358,
	-7371,
	-7384,
	-7397,
	-7410,
	-7423,
	-7436,
	-7449,
	-7463,
	-7476,
	-7489,
	-7503,
	-7516,
	-7530,
	-7543,
	-7557,
	-7570,
	-7584,
	-7598,
	-7612,
	-7626,
	-7639,
	-7653,
	-7667,
	-7681,
	-7695,
	-7710,
	-7724,
	-7738,
	-7752,
	-7767,
	-7781,
	-7796,
	-7810,
	-7825,
	-7839,
	-7854,
	-7869,
	-7884,
	-7898,
	-7913,
	-7928,
	-7943,
	-7958,
	-7973,
	-7989,
	-8004,
	-8019,
	-8035,
	-8050,
	-8065,
	-8081,
	-8097,
	-8112,
	-8128,
	-8144,
	-8160,
	-8176,
	-8192,
	-8208,
	-8224,
	-8240,
	-8256,
	-8272,
	-8289,
	-8305,
	-8322,
	-8338,
	-8355,
	-8371,
	-8388,
	-8405,
	-8422,
	-8439,
	-8456,
	-8473,
	-8490,
	-8507,
	-8525,
	-8542,
	-8559,
	-8577,
	-8594,
	-8612,
	-8630,
	-8648,
	-8665,
	-8683,
	-8701,
	-8719,
	-8738,
	-8756,
	-8774,
	-8793,
	-8811,
	-8830,
	-8848,
	-8867,
	-8886,
	-8905,
	-8924,
	-8943,
	-8962,
	-8981,
	-9000,
	-9020,
	-9039,
	-9058,
	-9078,
	-9098,
	-9118,
	-9137,
	-9157,
	-9177,
	-9198,
	-9218,
	-9238,
	-9258,
	-9279,
	-9300,
	-9320,
	-9341,
	-9362,
	-9383,
	-9404,
	-9425,
	-9446,
	-9467,
	-9489,
	-9510,
	-9532,
	-9554,
	-9576,
	-9597,
	-9619,
	-9642,
	-9664,
	-9686,
	-9709,
	-9731,
	-9754,
	-9776,
	-9799,
	-9822,
	-9845,
	-9868,
	-9892,
	-9915,
	-9939,
	-9962,
	-9986,
	-10010,
	-10034,
	-10058,
	-10082,
	-10106,
	-10131,
	-10155,
	-10180,
	-10205,
	-10230,
	-10255,
	-10280,
	-10305,
	-10330,
	-10356,
	-10381,
	-10407,
	-10433,
	-10459,
	-10485,
	-10512,
	-10538,
	-10564,
	-10591,
	-10618,
	-10645,
	-10672,
	-10699,
	-10727,
	-10754,
	-10782,
	-10810,
	-10837,
	-10866,
	-10894,
	-10922,
	-10951,
	-10979,
	-11008,
	-11037,
	-11066,
	-11096,
	-11125,
	-11155,
	-11184,
	-11214,
	-11244,
	-11275,
	-11305,
	-11335,
	-11366,
	-11397,
	-11428,
	-11459,
	-11491,
	-11522,
	-11554,
	-11586,
	-11618,
	-11650,
	-11683,
	-11715,
	-11748,
	-11781,
	-11814,
	-11848,
	-11881,
	-11915,
	-11949,
	-11983,
	-12018,
	-12052,
	-12087,
	-12122,
	-12157,
	-12192,
	-12228,
	-12264,
	-12300,
	-12336,
	-12372,
	-12409,
	-12446,
	-12483,
	-12520,
	-12557,
	-12595,
	-12633,
	-12671,
	-12710,
	-12748,
	-12787,
	-12826,
	-12865,
	-12905,
	-12945,
	-12985,
	-13025,
	-13066,
	-13107,
	-13148,
	-13189,
	-13231,
	-13273,
	-13315,
	-13357,
	-13400,
	-13443,
	-13486,
	-13530,
	-13573,
	-13617,
	-13662,
	-13706,
	-13751,
	-13797,
	-13842,
	-13888,
	-13934,
	-13981,
	-14027,
	-14074,
	-14122,
	-14169,
	-14217,
	-14266,
	-14315,
	-14364,
	-14413,
	-14463,
	-14513,
	-14563,
	-14614,
	-14665,
	-14716,
	-14768,
	-14820,
	-14873,
	-14926,
	-14979,
	-15033,
	-15087,
	-15141,
	-15196,
	-15252,
	-15307,
	-15363,
	-15420,
	-15477,
	-15534,
	-15592,
	-15650,
	-15709,
	-15768,
	-15827,
	-15887,
	-15947,
	-16008,
	-16070,
	-16131,
	-16194,
	-16256,
	-16320,
	-16384,
	-16448,
	-16513,
	-16578,
	-16644,
	-16710,
	-16777,
	-16844,
	-16912,
	-16980,
	-17050,
	-17119,
	-17189,
	-17260,
	-17331,
	-17403,
	-17476,
	-17549,
	-17623,
	-17697,
	-17772,
	-17848,
	-17924,
	-18001,
	-18078,
	-18157,
	-18236,
	-18315,
	-18396,
	-18477,
	-18558,
	-18641,
	-18724,
	-18808,
	-18893,
	-18978,
	-19065,
	-19152,
	-19239,
	-19328,
	-19418,
	-19508,
	-19599,
	-19691,
	-19784,
	-19878,
	-19972,
	-20068,
	-20164,
	-20262,
	-20360,
	-20460,
	-20560,
	-20661,
	-20763,
	-20867,
	-20971,
	-21076,
	-21183,
	-21290,
	-21399,
	-21509,
	-21620,
	-21732,
	-21845,
	-21959,
	-22075,
	-22192,
	-22310,
	-22429,
	-22550,
	-22671,
	-22795,
	-22919,
	-23045,
	-23172,
	-23301,
	-23431,
	-23563,
	-23696,
	-23831,
	-23967,
	-24105,
	-24244,
	-24385,
	-24528,
	-24672,
	-24818,
	-24966,
	-25115,
	-25266,
	-25420,
	-25575,
	-25731,
	-25890,
	-26051,
	-26214,
	-26379,
	-26546,
	-26715,
	-26886,
	-27060,
	-27235,
	-27413,
	-27594,
	-27776,
	-27962,
	-28149,
	-28339,
	-28532,
	-28728,
	-28926,
	-29127,
	-29330,
	-29537,
	-29746,
	-29959,
	-30174,
	-30393,
	-30615,
	-30840,
	-31068,
	-31300,
	-31536,
	-31775,
	-32017,
	-32263,
	-32513,
	-32768,
	-33026,
	-33288,
	-33554,
	-33825,
	-34100,
	-34379,
	-34663,
	-34952,
	-35246,
	-35544,
	-35848,
	-36157,
	-36472,
	-36792,
	-37117,
	-37449,
	-37786,
	-38130,
	-38479,
	-38836,
	-39199,
	-39568,
	-39945,
	-40329,
	-40721,
	-41120,
	-41527,
	-41943,
	-42366,
	-42799,
	-43240,
	-43690,
	-44150,
	-44620,
	-45100,
	-45590,
	-46091,
	-46603,
	-47127,
	-47662,
	-48210,
	-48770,
	-49344,
	-49932,
	-50533,
	-51150,
	-51781,
	-52428,
	-53092,
	-53773,
	-54471,
	-55188,
	-55924,
	-56679,
	-57456,
	-58254,
	-59074,
	-59918,
	-60787,
	-61680,
	-62601,
	-63550,
	-64527,
	-65536,
	-66576,
	-67650,
	-68759,
	-69905,
	-71089,
	-72315,
	-73584,
	-74898,
	-76260,
	-77672,
	-79137,
	-80659,
	-82241,
	-83886,
	-85598,
	-87381,
	-89240,
	-91180,
	-93206,
	-95325,
	-97541,
	-99864,
	-102300,
	-104857,
	-107546,
	-110376,
	-113359,
	-116508,
	-119837,
	-123361,
	-127100,
	-131072,
	-135300,
	-139810,
	-144631,
	-149796,
	-155344,
	-161319,
	-167772,
	-174762,
	-182361,
	-190650,
	-199728,
	-209715,
	-220752,
	-233016,
	-246723,
	-262144,
	-279620,
	-299593,
	-322638,
	-349525,
	-381300,
	-419430,
	-466033,
	-524288,
	-599186,
	-699050,
	-838860,
	-1048576,
	-1398101,
	-2097152,
	-4194304,
	0,
]!
