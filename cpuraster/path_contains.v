module cpuraster

// SkPathPriv::Contains(): crossings of monotonic edges, followed by tangent
// cancellation when a winding query lies on coincident curves.
pub fn (path Path) contains(x f32, y f32) bool {
	inverse := path.is_inverse_fill()
	bounds := path.bounds() or { return false }
	if path.verbs.len == 0 { return inverse }
	if !(bounds.left <= x && x <= bounds.right && bounds.top <= y && y <= bounds.bottom) {
		return inverse
	}
	edges := path_edges(path)
	mut winding := 0
	mut on_curve := 0
	for edge in edges {
		w, on := contains_winding(edge, x, y)
		winding += w
		on_curve += on
	}
	if path.is_even_odd() { winding &= 1 }
	if winding != 0 { return !inverse }
	if on_curve <= 1 { return (on_curve != 0) != inverse }
	if on_curve & 1 != 0 || path.is_even_odd() { return (on_curve & 1 != 0) != inverse }
	mut tangents := []Point{}
	for edge in edges {
		old_count := tangents.len
		tangents << contains_tangents(edge, x, y)
		if tangents.len <= old_count { continue }
		last := tangents.len - 1
		tangent := tangents[last]
		xx, yy := tangent.x * tangent.x, tangent.y * tangent.y
		if nearly_zero(xx + yy, scalar_nearly_zero) {
			tangents.delete_last()
			continue
		}
		for index in 0 .. last {
			test := tangents[index]
			xy, yx := test.x * tangent.y, test.y * tangent.x
			if nearly_zero(xy - yx, scalar_nearly_zero)
				&& contains_sign(tangent.x * test.x) <= 0
				&& contains_sign(tangent.y * test.y) <= 0 {
				tangents.delete_last()
				tangents[index] = tangents.last()
				tangents.delete_last()
				break
			}
		}
	}
	return (tangents.len != 0) != inverse
}

fn contains_sign(value f32) int {
	return int(value > 0) - int(value < 0)
}

fn contains_on_curve(x f32, y f32, start Point, end Point) bool {
	return if start.y == end.y {
		between(start.x, x, end.x) && x != end.x
	} else {
		x == start.x && y == start.y
	}
}

fn contains_mono_quad(p []Point) bool {
	return if p[0].y == p[1].y {
		true
	} else if p[0].y < p[1].y {
		p[1].y <= p[2].y
	} else {
		p[1].y >= p[2].y
	}
}

// The containment polynomial uses sequential subtractions, including in its
// cubic coefficient. Keep its arithmetic distinct from SkCubicCoeff's.
fn contains_poly(a f32, b f32, c f32, t f32) f32 {
	at := a * t
	atb := at + b
	product := atb * t
	return product + c
}

fn contains_cubic_x(p []Point, t f32) f32 {
	diff := p[1].x - p[2].x
	three := f32(3) * diff
	a0 := p[3].x + three
	a := a0 - p[0].x
	b0 := p[2].x - p[1].x
	b1 := b0 - p[1].x
	b2 := b1 + p[0].x
	b := f32(3) * b2
	c := f32(3) * (p[1].x - p[0].x)
	at := a * t
	atb := at + b
	atbt := atb * t
	atbtc := atbt + c
	product := atbtc * t
	return product + p[0].x
}

// SkCubicClipper::ChopMonoAtY() uses float bisection, unlike the double
// polynomial intersection used by the raster edge clipper.
fn contains_cubic_t(p []Point, y f32) ?f32 {
	a, b, c, d := p[0].y - y, p[1].y - y, p[2].y - y, p[3].y - y
	mut negative, mut positive := f32(0), f32(1)
	if a < 0 {
		if d < 0 { return none }
	} else if a > 0 {
		if d > 0 { return none }
		negative, positive = 1, 0
	} else {
		return 0
	}
	for {
		t := (positive + negative) / f32(2)
		ab, bc, cd := interp(a, b, t), interp(b, c, t), interp(c, d, t)
		abc, bcd := interp(ab, bc, t), interp(bc, cd, t)
		value := interp(abc, bcd, t)
		if value == 0 { return t }
		if value < 0 { negative = t } else { positive = t }
		if nearly_zero(positive - negative, f32(1) / f32(65536)) { break }
	}
	return (negative + positive) / f32(2)
}

fn contains_conic_roots(p []Point, weight f32, y f32) []f32 {
	weighted, intercept := p[1].y * weight, y * weight
	base := weighted - intercept
	b0 := base + y
	twice := f32(2) * b0
	a0 := p[0].y - twice
	a := p[2].y + a0
	b := b0 - p[0].y
	c := p[0].y - y
	return find_unit_quad_roots(a, f32(2) * b, c)
}

fn contains_conic_x(p []Point, weight f32, t f32) f32 {
	weighted := p[1].x * weight
	twice := f32(2) * weighted
	a0 := p[2].x - twice
	a := a0 + p[0].x
	b := f32(2) * (weighted - p[0].x)
	numerator := contains_poly(a, b, p[0].x, t)
	d := f32(2) * (weight - f32(1))
	denominator := contains_poly(-d, d, 1, t)
	return f32(f64(numerator) / f64(denominator))
}

fn contains_conic_chop_y(conic Conic) ?[2]Conic {
	p := conic.pts
	p20, p10 := p[2].y - p[0].y, p[1].y - p[0].y
	weighted := conic.w * p10
	wp20 := conic.w * p20
	a := wp20 - p20
	twice := f32(2) * weighted
	root := find_unit_quad_roots(a, p20 - twice, weighted)
	if root.len != 1 { return none }
	t := root[0]
	wx, wy := p[1].x * conic.w, p[1].y * conic.w
	ax, ay, az := interp(p[0].x, wx, t), interp(p[0].y, wy, t), interp(1, conic.w, t)
	bx, by, bz := interp(wx, p[2].x, t), interp(wy, p[2].y, t), interp(conic.w, 1, t)
	mx, my, mz := interp(ax, bx, t), interp(ay, by, t), interp(az, bz, t)
	mid := Point{mx / mz, my / mz}
	root_weight := C.sqrtf(mz)
	mut pair := [Conic{[p[0], Point{ax / az, ay / az}, mid]!, az / root_weight},
		Conic{[mid, Point{bx / bz, by / bz}, p[2]]!, bz / root_weight}]!
	for c in pair {
		if !is_finite_f32(c.w) || !c.pts[..].all(point_is_finite(it)) { return none }
	}
	pair[0].pts[1].y = mid.y
	pair[1].pts[0].y = mid.y
	pair[1].pts[1].y = mid.y
	return pair
}

fn contains_winding_mono(edge PathEdge, x f32, y f32) (int, int) {
	p := edge.pts
	end := p.last()
	low, high := fmin_std(p[0].y, end.y), fmax_std(p[0].y, end.y)
	direction := if p[0].y > end.y { -1 } else { 1 }
	if y < low || y > high { return 0, 0 }
	if contains_on_curve(x, y, p[0], end) { return 0, 1 }
	if y == high { return 0, 0 }
	if edge.verb == .line {
		x1, x2 := (end.x - p[0].x) * (y - p[0].y), (end.y - p[0].y) * (x - p[0].x)
		cross := x1 - x2
		if cross == 0 { return 0, int(x != end.x || y != end.y) }
		return if contains_sign(cross) == direction { 0 } else { direction }, 0
	}
	mut xt := f32(0)
	if edge.verb == .cubic {
		mut left, mut right := p[0].x, p[0].x
		for point in p[1..] {
			left = fmin_std(left, point.x)
			right = fmax_std(right, point.x)
		}
		if x < left { return 0, 0 }
		if x > right { return direction, 0 }
		t := contains_cubic_t(p, y) or { return 0, 0 }
		xt = contains_cubic_x(p, t)
	} else {
		roots := if edge.verb == .conic {
			contains_conic_roots(p, edge.weight, y)
		} else {
			twice := f32(2) * p[1].y
			a0 := p[0].y - twice
			find_unit_quad_roots(a0 + p[2].y, f32(2) * (p[1].y - p[0].y), p[0].y - y)
		}
		if roots.len == 0 {
			xt = p[1 - direction].x
		} else if edge.verb == .conic {
			xt = contains_conic_x(p, edge.weight, roots[0])
		} else {
			twice := f32(2) * p[1].x
			a0 := p[2].x - twice
			xt = contains_poly(a0 + p[0].x, f32(2) * (p[1].x - p[0].x), p[0].x, roots[0])
		}
	}
	if nearly_equal(xt, x, scalar_nearly_zero) && (x != end.x || y != end.y) { return 0, 1 }
	return if xt < x { direction } else { 0 }, 0
}

fn contains_winding(edge PathEdge, x f32, y f32) (int, int) {
	mut parts := []PathEdge{}
	match edge.verb {
		.cubic {
			p := chop_cubic_at_extrema(edge.pts, true)
			for i := 0; i + 3 < p.len; i += 3 { parts << PathEdge{.cubic, p[i..i + 4], 0} }
		}
		.quad {
			p := if contains_mono_quad(edge.pts) {
				edge.pts
			} else {
				chop_quad_at_extrema(edge.pts, true)
			}
			for i := 0; i + 2 < p.len; i += 2 { parts << PathEdge{.quad, p[i..i + 3], 0} }
		}
		.conic {
			if !contains_mono_quad(edge.pts) {
				if pair := contains_conic_chop_y(Conic{[edge.pts[0], edge.pts[1], edge.pts[2]]!, edge.weight}) {
					for c in pair { parts << PathEdge{.conic, c.pts[..].clone(), c.w} }
				}
			}
			if parts.len == 0 { parts << edge }
		}
		else { return contains_winding_mono(edge, x, y) }
	}
	mut winding, mut on := 0, 0
	for part in parts {
		w, n := contains_winding_mono(part, x, y)
		winding += w
		on += n
	}
	return winding, on
}

fn contains_tangents(edge PathEdge, x f32, y f32) []Point {
	p := edge.pts
	mut x_inside, mut y_inside := false, false
	for i in 0 .. p.len - 1 {
		x_inside = x_inside || between(p[i].x, x, p[i + 1].x)
		y_inside = y_inside || between(p[i].y, y, p[i + 1].y)
	}
	if !x_inside || !y_inside { return [] }
	if edge.verb == .line {
		dx, dy := p[1].x - p[0].x, p[1].y - p[0].y
		xy, yx := (x - p[0].x) * dy, dx * (y - p[0].y)
		return if nearly_equal(xy, yx, scalar_nearly_zero) { [Point{dx, dy}] } else { [] }
	}
	mut tangents := []Point{}
	if edge.verb == .cubic {
		parts := chop_cubic_at_extrema(p, true)
		for i := 0; i + 3 < parts.len; i += 3 {
			c := parts[i..i + 4]
			t := contains_cubic_t(c, y) or { continue }
			if nearly_equal(x, contains_cubic_x(c, t), scalar_nearly_zero) {
				tangents << eval_cubic_tangent_at(c, t)
			}
		}
		return tangents
	}
	roots := if edge.verb == .conic {
		contains_conic_roots(p, edge.weight, y)
	} else {
		twice := f32(2) * p[1].y
		a0 := p[0].y - twice
		find_unit_quad_roots(a0 + p[2].y, f32(2) * (p[1].y - p[0].y), p[0].y - y)
	}
	for t in roots {
		if edge.verb == .quad {
			twice := f32(2) * p[1].x
			a0 := p[2].x - twice
			xt := contains_poly(a0 + p[0].x, f32(2) * (p[1].x - p[0].x), p[0].x, t)
			if nearly_equal(x, xt, scalar_nearly_zero) {
				tangents << eval_quad_tangent_at([p[0], p[1], p[2]]!, t)
			}
		} else if nearly_equal(x, contains_conic_x(p, edge.weight, t), scalar_nearly_zero) {
			if (t == 0 && p[0] == p[1]) || (t == 1 && p[1] == p[2]) {
				tangents << vsub(p[2], p[0])
				continue
			}
			p20, p10 := vsub(p[2], p[0]), vsub(p[1], p[0])
			c := vmul(p10, edge.weight)
			a := vsub(vmul(p20, edge.weight), p20)
			b := vsub(vsub(p20, c), c)
			at := vmul(a, t)
			atb := vadd(at, b)
			product := vmul(atb, t)
			tangents << vadd(product, c)
		}
	}
	return tangents
}
