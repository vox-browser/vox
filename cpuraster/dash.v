module cpuraster

import math

// Dashed strokes as LibWeb Skia (google/skia ee20d565) builds them:
// SkDashPathEffect's SkDashPath::InternalFilter() cuts the source path into
// dashes with SkContourMeasure (SkPathMeasure) before the stroke is applied,
// culling lines and rects to the device clip mapped back into source space.
// Every operation is a separate float operation, as Skia is compiled with
// -ffp-contract=off.

fn C.fmodf(x f32, y f32) f32
fn C.fmod(x f64, y f64) f64

// SkDashPath::kMaxDashCount.
const max_dash_count = f32(1000000)

// A valid SkDashImpl: its intervals and the parameters computed from the
// phase by SkDashPath::CalcDashParameters().
struct DashEffect {
	intervals           []f32
	phase               f32
	initial_dash_length f32
	initial_dash_index  int
	interval_length     f32
}

// SkDashPathEffect::Make(): none when SkDashPath::ValidDashPath() rejects the
// intervals, which leaves the stroke undashed.
fn new_dash_effect(intervals []f32, phase_in f32) ?DashEffect {
	if intervals.len < 2 || intervals.len % 2 != 0 {
		return none
	}
	mut length := f32(0)
	for interval in intervals {
		if interval < 0 {
			return none
		}
		length += interval
	}
	if !(length > 0 && is_finite_f32(phase_in) && is_finite_f32(length)) {
		return none
	}
	// CalcDashParameters(): the interval length and the phase moved into
	// [0, length), flipping a negative phase.
	mut len := f32(0)
	for interval in intervals {
		len += interval
	}
	mut phase := phase_in
	if phase < 0 {
		phase = -phase
		if phase > len {
			phase = C.fmodf(phase, len)
		}
		phase = len - phase
		if phase == len {
			phase = 0
		}
	} else if phase >= len {
		phase = C.fmodf(phase, len)
	}
	// find_first_interval()
	mut initial_length := intervals[0]
	mut initial_index := 0
	mut remaining := phase
	mut found := false
	for i, gap in intervals {
		if remaining > gap || (remaining == gap && gap != 0) {
			remaining -= gap
		} else {
			initial_index = i
			initial_length = gap - remaining
			found = true
			break
		}
	}
	if !found {
		initial_index = 0
		initial_length = intervals[0]
	}
	return DashEffect{
		intervals:           intervals.clone()
		phase:               phase
		initial_dash_length: initial_length
		initial_dash_index:  initial_index
		interval_length:     len
	}
}

// SkPath::isLine().
fn (p Path) is_line() ?[2]Point {
	if p.verbs.len == 2 && p.verbs[1] == .line {
		return [p.points[0], p.points[1]]!
	}
	return none
}

// SkPath::isLastContourClosed().
fn (p Path) is_last_contour_closed() bool {
	return p.verbs.len > 0 && p.verbs.last() == .close
}

// The affine inverse of a canvas matrix with the type mask SkMatrix::invert()
// gives it, which selects the SkMatrix::mapRect() path.
struct InverseMatrix {
	m    SkAffine
	mask int
}

// SkMatrix::invert() for an affine matrix.
fn invert_matrix(m Matrix) ?InverseMatrix {
	src := SkAffine{
		sx: m.a
		kx: m.c
		tx: m.e
		ky: m.b
		sy: m.d
		ty: m.f
	}
	mask := src.type_mask()
	if mask == 0 {
		return InverseMatrix{src, 0}
	}
	if mask & affine_affine_mask == 0 {
		if mask & affine_scale_mask != 0 {
			inv_sx := f32(1) / src.sx
			inv_sy := f32(1) / src.sy
			if !is_finite_f32(inv_sx) || !is_finite_f32(inv_sy) {
				return none
			}
			neg_tx := -src.tx
			neg_ty := -src.ty
			inv_tx := neg_tx * inv_sx
			inv_ty := neg_ty * inv_sy
			if !is_finite_f32(inv_tx) || !is_finite_f32(inv_ty) {
				return none
			}
			return InverseMatrix{SkAffine{
				sx: inv_sx
				sy: inv_sy
				tx: inv_tx
				ty: inv_ty
			}, mask}
		}
		if !is_finite_f32(src.tx) || !is_finite_f32(src.ty) {
			return none
		}
		inv := SkAffine{
			tx: -src.tx
			ty: -src.ty
		}
		return InverseMatrix{inv, inv.type_mask()}
	}
	// sk_inv_determinant() and ComputeInv() without perspective.
	ad := f64(src.sx) * f64(src.sy)
	cb := f64(src.kx) * f64(src.ky)
	det := ad - cb
	tolerance := scalar_nearly_zero * scalar_nearly_zero * scalar_nearly_zero
	if abs_f32(f32(det)) <= tolerance {
		return none
	}
	inv_det := 1.0 / det
	tx0 := f64(src.kx) * f64(src.ty)
	tx1 := f64(src.sy) * f64(src.tx)
	ty0 := f64(src.ky) * f64(src.tx)
	ty1 := f64(src.sx) * f64(src.ty)
	inv := SkAffine{
		sx: f32(f64(src.sy) * inv_det)
		kx: f32(-f64(src.kx) * inv_det)
		tx: f32((tx0 - tx1) * inv_det)
		ky: f32(-f64(src.ky) * inv_det)
		sy: f32(f64(src.sx) * inv_det)
		ty: f32((ty0 - ty1) * inv_det)
	}
	for v in [inv.sx, inv.kx, inv.tx, inv.ky, inv.sy, inv.ty] {
		if !is_finite_f32(v) {
			return none
		}
	}
	return InverseMatrix{inv, mask}
}

// SkRect::Bounds() as SkRect::setBoundsNoCheck() uses it: NaN when a point
// is not finite.
fn bounds_no_check(pts []Point) Rect {
	path := Path{
		points: pts
	}
	if r := path.bounds() {
		return r
	}
	nan := math.nan()
	return Rect{f32(nan), f32(nan), f32(nan), f32(nan)}
}

// SkMatrix::mapRect().
fn (inv InverseMatrix) map_rect(r Rect) Rect {
	m := inv.m
	if inv.mask & (affine_affine_mask | affine_scale_mask) == 0 {
		return sort_as_rect(Rect{r.left + m.tx, r.top + m.ty, r.right + m.tx, r.bottom + m.ty})
	}
	if inv.mask & affine_affine_mask == 0 {
		l := r.left * m.sx
		t := r.top * m.sy
		rr := r.right * m.sx
		b := r.bottom * m.sy
		return sort_as_rect(Rect{l + m.tx, t + m.ty, rr + m.tx, b + m.ty})
	}
	quad := [Point{r.left, r.top}, Point{r.right, r.top}, Point{r.right, r.bottom},
		Point{r.left, r.bottom}]
	mut mapped := []Point{cap: 4}
	for p in quad {
		xx := p.x * m.sx
		xy := p.y * m.kx
		x := xx + xy
		yy := p.y * m.sy
		yx := p.x * m.ky
		y := yy + yx
		mapped << Point{x + m.tx, y + m.ty}
	}
	return bounds_no_check(mapped)
}

// sort_as_rect(): skvx::min()/max() keep the first argument unless the
// second compares strictly smaller (larger), as std::min()/max() do.
fn sort_as_rect(r Rect) Rect {
	return Rect{fmin_std(r.right, r.left), fmin_std(r.bottom, r.top), fmax_std(r.left, r.right), fmax_std(r.top,
		r.bottom)}
}

// skcpu::Draw::computeConservativeLocalClipBounds() for an unclipped device.
fn local_clip_bounds(m Matrix, width int, height int) ?Rect {
	inv := invert_matrix(m)?
	return inv.map_rect(Rect{-1, -1, f32(width + 1), f32(height + 1)})
}

// The SkStrokeRec InternalFilter() sees: width 0 for a hairline.
struct DashStroke {
	width       f32
	cap         StrokeCap
	join        StrokeJoin
	miter_limit f32
	res_scale   f32
}

// SkContourMeasure segment types.
enum MeasureSegType {
	line
	quad
	cubic
	conic
}

const max_t_value = 0x3FFFFFFF

// tValue2Scalar().
@[inline]
fn t_value_to_scalar(t int) f32 {
	reciprocal := f32(1) / f32(max_t_value)
	return f32(t) * reciprocal
}

struct MeasureSegment {
	distance f32
	pt_index int
	kind     MeasureSegType
	t_value  int
}

// One contour's SkContourMeasure.
struct ContourMeasure {
	segments []MeasureSegment
	pts      []Point
	length   f32
	closed   bool
}

// SkContourMeasureIter for a path with forceClosed false.
struct ContourMeasureIter {
	verbs     []PathVerb
	points    []Point
	weights   []f32
	tolerance f32
	valid     bool
mut:
	verb_index   int
	point_index  int
	weight_index int
	segments     []MeasureSegment
	pts          []Point
}

fn new_contour_measure_iter(path Path, res_scale f32) ContourMeasureIter {
	inv_res := f32(1) / res_scale
	mut finite := true
	for p in path.points {
		if !point_is_finite(p) {
			finite = false
			break
		}
	}
	return ContourMeasureIter{
		verbs:     path.verbs
		points:    path.points
		weights:   path.weights
		tolerance: f32(0.5) * inv_res
		valid:     finite
	}
}

@[inline]
fn tspan_big_enough(tspan int) bool {
	return tspan >> 10 != 0
}

fn quad_too_curvy(pts []Point, tolerance f32) bool {
	sx := pts[0].x + pts[2].x
	hx := sx * f32(0.5)
	qx := hx * f32(0.5)
	px := pts[1].x * f32(0.5)
	dx := px - qx
	sy := pts[0].y + pts[2].y
	hy := sy * f32(0.5)
	qy := hy * f32(0.5)
	py := pts[1].y * f32(0.5)
	dy := py - qy
	dist := fmax_std(abs_f32(dx), abs_f32(dy))
	return dist > tolerance
}

fn conic_too_curvy(first Point, mid Point, last Point, tolerance f32) bool {
	sum := vadd(first, last)
	mid_ends := vmul(sum, f32(0.5))
	dxy := vsub(mid, mid_ends)
	dist := fmax_std(abs_f32(dxy.x), abs_f32(dxy.y))
	return dist > tolerance
}

// SkScalarInterp().
@[inline]
fn scalar_interp(a f32, b f32, t f32) f32 {
	d := b - a
	m := d * t
	return a + m
}

fn cheap_dist_exceeds_limit(pt Point, x f32, y f32, tolerance f32) bool {
	dist := fmax_std(abs_f32(x - pt.x), abs_f32(y - pt.y))
	return dist > tolerance
}

fn cubic_too_curvy(pts []Point, tolerance f32) bool {
	third := f32(1) / f32(3)
	two_thirds := f32(2) / f32(3)
	return cheap_dist_exceeds_limit(pts[1], scalar_interp(pts[0].x, pts[3].x, third),
		scalar_interp(pts[0].y, pts[3].y, third), tolerance)
		|| cheap_dist_exceeds_limit(pts[2], scalar_interp(pts[0].x, pts[3].x, two_thirds),
		scalar_interp(pts[0].y, pts[3].y, two_thirds), tolerance)
}

// kMaxRecursionDepth.
const measure_max_recursion = 8

fn (mut it ContourMeasureIter) append_segment(distance f32, pt_index int, kind MeasureSegType, t_value int) {
	it.segments << MeasureSegment{distance, pt_index, kind, t_value}
}

fn (mut it ContourMeasureIter) compute_quad_segs(pts []Point, distance_in f32, mint int, maxt int, pt_index int, depth int) f32 {
	mut distance := distance_in
	if depth < measure_max_recursion && tspan_big_enough(maxt - mint)
		&& quad_too_curvy(pts, it.tolerance) {
		tmp := chop_quad_at(pts, f32(0.5))
		halft := (mint + maxt) >> 1
		distance = it.compute_quad_segs(tmp[..3], distance, mint, halft, pt_index, depth + 1)
		distance = it.compute_quad_segs(tmp[2..], distance, halft, maxt, pt_index, depth + 1)
	} else {
		d := point_length(pts[0].x - pts[2].x, pts[0].y - pts[2].y)
		prev := distance
		distance += d
		if distance > prev {
			it.append_segment(distance, pt_index, .quad, maxt)
		}
	}
	return distance
}

fn (mut it ContourMeasureIter) compute_conic_segs(conic Conic, distance_in f32, mint int, min_pt Point, maxt int, max_pt Point, pt_index int, depth int) f32 {
	mut distance := distance_in
	halft := (mint + maxt) >> 1
	half_pt := conic_eval_at(conic, t_value_to_scalar(halft))
	if !point_is_finite(half_pt) {
		return distance
	}
	if depth < measure_max_recursion && tspan_big_enough(maxt - mint)
		&& conic_too_curvy(min_pt, half_pt, max_pt, it.tolerance) {
		distance = it.compute_conic_segs(conic, distance, mint, min_pt, halft, half_pt, pt_index,
			depth + 1)
		distance = it.compute_conic_segs(conic, distance, halft, half_pt, maxt, max_pt, pt_index,
			depth + 1)
	} else {
		d := point_length(min_pt.x - max_pt.x, min_pt.y - max_pt.y)
		prev := distance
		distance += d
		if distance > prev {
			it.append_segment(distance, pt_index, .conic, maxt)
		}
	}
	return distance
}

fn (mut it ContourMeasureIter) compute_cubic_segs(pts []Point, distance_in f32, mint int, maxt int, pt_index int, depth int) f32 {
	mut distance := distance_in
	if depth < measure_max_recursion && tspan_big_enough(maxt - mint)
		&& cubic_too_curvy(pts, it.tolerance) {
		tmp := chop_cubic_at(pts, f32(0.5))
		halft := (mint + maxt) >> 1
		distance = it.compute_cubic_segs(tmp[..4], distance, mint, halft, pt_index, depth + 1)
		distance = it.compute_cubic_segs(tmp[3..], distance, halft, maxt, pt_index, depth + 1)
	} else {
		d := point_length(pts[0].x - pts[3].x, pts[0].y - pts[3].y)
		prev := distance
		distance += d
		if distance > prev {
			it.append_segment(distance, pt_index, .cubic, maxt)
		}
	}
	return distance
}

fn (mut it ContourMeasureIter) compute_line_seg(p0 Point, p1 Point, distance_in f32, pt_index int) f32 {
	mut distance := distance_in
	d := point_length(p0.x - p1.x, p0.y - p1.y)
	prev := distance
	distance += d
	if distance > prev {
		it.append_segment(distance, pt_index, .line, max_t_value)
	}
	return distance
}

// buildSegments(): the next contour, or none when it has no length.
fn (mut it ContourMeasureIter) build_segments() ?ContourMeasure {
	mut pt_index := -1
	mut distance := f32(0)
	mut have_seen_close := false
	mut have_seen_move := false
	it.segments = []MeasureSegment{}
	it.pts = []Point{}
	for it.verb_index < it.verbs.len {
		verb := it.verbs[it.verb_index]
		if have_seen_move && verb == .move {
			break
		}
		pi := it.point_index
		match verb {
			.move {
				pt_index++
				it.pts << it.points[pi]
				have_seen_move = true
			}
			.line {
				prev := distance
				distance = it.compute_line_seg(it.points[pi - 1], it.points[pi], distance,
					pt_index)
				if distance > prev {
					it.pts << it.points[pi]
					pt_index++
				}
			}
			.quad {
				prev := distance
				distance = it.compute_quad_segs(it.points[pi - 1..pi + 2], distance, 0,
					max_t_value, pt_index, 0)
				if distance > prev {
					it.pts << it.points[pi]
					it.pts << it.points[pi + 1]
					pt_index += 2
				}
			}
			.conic {
				w := it.weights[it.weight_index]
				conic := Conic{[it.points[pi - 1], it.points[pi], it.points[pi + 1]]!, w}
				prev := distance
				distance = it.compute_conic_segs(conic, distance, 0, conic.pts[0], max_t_value,
					conic.pts[2], pt_index, 0)
				if distance > prev {
					it.pts << Point{w, 0}
					it.pts << it.points[pi]
					it.pts << it.points[pi + 1]
					pt_index += 3
				}
			}
			.cubic {
				prev := distance
				distance = it.compute_cubic_segs(it.points[pi - 1..pi + 3], distance, 0,
					max_t_value, pt_index, 0)
				if distance > prev {
					it.pts << it.points[pi]
					it.pts << it.points[pi + 1]
					it.pts << it.points[pi + 2]
					pt_index += 3
				}
			}
			.close {
				have_seen_close = true
			}
		}
		// RangeIter::operator++().
		it.point_index += match verb {
			.move, .line { 1 }
			.quad, .conic { 2 }
			.cubic { 3 }
			.close { 0 }
		}
		if verb == .conic {
			it.weight_index++
		}
		it.verb_index++
	}
	if !is_finite_f32(distance) || it.segments.len == 0 {
		return none
	}
	if have_seen_close {
		prev := distance
		first_pt := it.pts[0]
		distance = it.compute_line_seg(it.pts[pt_index], first_pt, distance, pt_index)
		if distance > prev {
			it.pts << first_pt
		}
	}
	return ContourMeasure{
		segments: it.segments
		pts:      it.pts
		length:   distance
		closed:   have_seen_close
	}
}

// SkContourMeasureIter::next().
fn (mut it ContourMeasureIter) next() ?ContourMeasure {
	if !it.valid {
		return none
	}
	for it.verb_index < it.verbs.len {
		if cm := it.build_segments() {
			return cm
		}
	}
	return none
}

// SkContourMeasure::distanceToSegment(): the segment index and its t.
fn (cm &ContourMeasure) distance_to_segment(distance f32) (int, f32) {
	count := cm.segments.len
	// SkTKSearch()
	mut lo := 0
	mut hi := count - 1
	for lo < hi {
		mid := (hi + lo) >> 1
		if cm.segments[mid].distance < distance {
			lo = mid + 1
		} else {
			hi = mid
		}
	}
	if cm.segments[hi].distance < distance {
		hi += 1
	}
	index := hi
	seg := cm.segments[index]
	mut start_t := f32(0)
	mut start_d := f32(0)
	if index > 0 {
		start_d = cm.segments[index - 1].distance
		if cm.segments[index - 1].pt_index == seg.pt_index {
			start_t = t_value_to_scalar(cm.segments[index - 1].t_value)
		}
	}
	span := t_value_to_scalar(seg.t_value) - start_t
	along := distance - start_d
	numer := span * along
	denom := seg.distance - start_d
	return index, start_t + numer / denom
}

// compute_pos_tan()'s position.
fn (cm &ContourMeasure) position(seg MeasureSegment, t f32) Point {
	p := cm.pts[seg.pt_index..]
	return match seg.kind {
		.line { Point{scalar_interp(p[0].x, p[1].x, t), scalar_interp(p[0].y, p[1].y, t)} }
		.quad { eval_quad_at([p[0], p[1], p[2]]!, t) }
		.conic { conic_eval_at(Conic{[p[0], p[2], p[3]]!, p[1].x}, t) }
		.cubic { eval_cubic_at(p[..4], t) }
	}
}

// SkConic::chopAt(t, dst[2]): false when the halves are not finite.
fn conic_chop_at(c Conic, t f32) ?[2]Conic {
	// ratquad_mapTo3D() and p3d_interp() on each coordinate.
	interp3 := fn (a f32, b f32, c f32, t f32) [3]f32 {
		ab := scalar_interp(a, b, t)
		bc := scalar_interp(b, c, t)
		return [ab, scalar_interp(ab, bc, t), bc]!
	}
	x1 := c.pts[1].x * c.w
	y1 := c.pts[1].y * c.w
	x0 := c.pts[0].x * f32(1)
	y0 := c.pts[0].y * f32(1)
	x2 := c.pts[2].x * f32(1)
	y2 := c.pts[2].y * f32(1)
	tx := interp3(x0, x1, x2, t)
	ty := interp3(y0, y1, y2, t)
	tz := interp3(1, c.w, 1, t)
	p1 := Point{tx[0] / tz[0], ty[0] / tz[0]}
	p2 := Point{tx[1] / tz[1], ty[1] / tz[1]}
	p3 := Point{tx[2] / tz[2], ty[2] / tz[2]}
	root := C.sqrtf(tz[1])
	w0 := tz[0] / root
	w1 := tz[2] / root
	halves := [Conic{[c.pts[0], p1, p2]!, w0}, Conic{[p2, p3, c.pts[2]]!, w1}]!
	for h in halves {
		for p in h.pts {
			if !point_is_finite(p) {
				return none
			}
		}
		if !is_finite_f32(h.w) {
			return none
		}
	}
	return halves
}

// SkConicCoeff numerator and denominator at t.
fn conic_coeff_numer_denom(c Conic, t f32) (Point, f32) {
	numer := Point{conic_numer_axis(c.pts[0].x, c.pts[1].x, c.pts[2].x, c.w, t), conic_numer_axis(c.pts[0].y,
		c.pts[1].y, c.pts[2].y, c.w, t)}
	wm1 := c.w - 1
	db := wm1 + wm1
	da := 0 - db
	d0 := da * t
	d1 := d0 + db
	d2 := d1 * t
	return numer, d2 + 1
}

fn conic_numer_axis(p0 f32, p1 f32, p2 f32, w f32, t f32) f32 {
	p1w := p1 * w
	p1w2 := p1w + p1w
	na0 := p2 - p1w2
	na := na0 + p0
	nb0 := p1w - p0
	nb := nb0 + nb0
	n0 := na * t
	n1 := n0 + nb
	n2 := n1 * t
	return n2 + p0
}

// SkConic::chopAt(t1, t2, dst).
fn conic_chop_between(c Conic, t1 f32, t2 f32) Conic {
	if t1 == 0 || t2 == 1 {
		if t1 == 0 && t2 == 1 {
			return c
		}
		if pair := conic_chop_at(c, if t1 != 0 { t1 } else { t2 }) {
			return pair[if t1 != 0 { 1 } else { 0 }]
		}
	}
	a_xy, a_zz := conic_coeff_numer_denom(c, t1)
	sum := t1 + t2
	mid_t := sum / 2
	d_xy, d_zz := conic_coeff_numer_denom(c, mid_t)
	c_xy, c_zz := conic_coeff_numer_denom(c, t2)
	b_xy := Point{conic_mid_axis(a_xy.x, d_xy.x, c_xy.x), conic_mid_axis(a_xy.y, d_xy.y,
		c_xy.y)}
	b_zz := conic_mid_axis(a_zz, d_zz, c_zz)
	ac := a_zz * c_zz
	w := b_zz / C.sqrtf(ac)
	return Conic{[Point{a_xy.x / a_zz, a_xy.y / a_zz}, Point{b_xy.x / b_zz, b_xy.y / b_zz},
		Point{c_xy.x / c_zz, c_xy.y / c_zz}]!, w}
}

// times_2(d) - (a + c) * 0.5f.
fn conic_mid_axis(a f32, d f32, c f32) f32 {
	d2 := d + d
	ac := a + c
	half := ac * f32(0.5)
	return d2 - half
}

// SkContourMeasure_segTo().
fn measure_seg_to(pts []Point, kind MeasureSegType, start_t f32, stop_t f32, mut dst PathBuilder) {
	if start_t == stop_t {
		if dst.verbs.len > 0 {
			last := dst.points.last()
			dst.line_to_pt(last)
		}
		return
	}
	match kind {
		.line {
			if stop_t == 1 {
				dst.line_to_pt(pts[1])
			} else {
				dst.line_to(scalar_interp(pts[0].x, pts[1].x, stop_t), scalar_interp(pts[0].y,
					pts[1].y, stop_t))
			}
		}
		.quad {
			if start_t == 0 {
				if stop_t == 1 {
					dst.quad_to_pts(pts[1], pts[2])
				} else {
					tmp0 := chop_quad_at(pts, stop_t)
					dst.quad_to_pts(tmp0[1], tmp0[2])
				}
			} else {
				tmp0 := chop_quad_at(pts, start_t)
				if stop_t == 1 {
					dst.quad_to_pts(tmp0[3], tmp0[4])
				} else {
					numer := stop_t - start_t
					denom := 1 - start_t
					tmp1 := chop_quad_at(tmp0[2..], numer / denom)
					dst.quad_to_pts(tmp1[1], tmp1[2])
				}
			}
		}
		.conic {
			conic := Conic{[pts[0], pts[2], pts[3]]!, pts[1].x}
			if start_t == 0 {
				if stop_t == 1 {
					dst.conic_to_pts(conic.pts[1], conic.pts[2], conic.w)
				} else if pair := conic_chop_at(conic, stop_t) {
					dst.conic_to_pts(pair[0].pts[1], pair[0].pts[2], pair[0].w)
				}
			} else {
				if stop_t == 1 {
					if pair := conic_chop_at(conic, start_t) {
						dst.conic_to_pts(pair[1].pts[1], pair[1].pts[2], pair[1].w)
					}
				} else {
					part := conic_chop_between(conic, start_t, stop_t)
					dst.conic_to_pts(part.pts[1], part.pts[2], part.w)
				}
			}
		}
		.cubic {
			if start_t == 0 {
				if stop_t == 1 {
					dst.cubic_to_pts(pts[1], pts[2], pts[3])
				} else {
					tmp0 := chop_cubic_at(pts, stop_t)
					dst.cubic_to_pts(tmp0[1], tmp0[2], tmp0[3])
				}
			} else {
				tmp0 := chop_cubic_at(pts, start_t)
				if stop_t == 1 {
					dst.cubic_to_pts(tmp0[4], tmp0[5], tmp0[6])
				} else {
					numer := stop_t - start_t
					denom := 1 - start_t
					tmp1 := chop_cubic_at(tmp0[3..], numer / denom)
					dst.cubic_to_pts(tmp1[1], tmp1[2], tmp1[3])
				}
			}
		}
	}
}

// SkContourMeasure::getSegment().
fn (cm &ContourMeasure) get_segment(start_d_in f32, stop_d_in f32, mut dst PathBuilder, start_with_move_to bool) bool {
	mut start_d := start_d_in
	mut stop_d := stop_d_in
	if start_d < 0 {
		start_d = 0
	}
	if stop_d > cm.length {
		stop_d = cm.length
	}
	if !(start_d <= stop_d) {
		return false
	}
	if cm.segments.len == 0 {
		return false
	}
	mut seg_index, mut start_t := cm.distance_to_segment(start_d)
	if !is_finite_f32(start_t) {
		return false
	}
	stop_index, stop_t := cm.distance_to_segment(stop_d)
	if !is_finite_f32(stop_t) {
		return false
	}
	if start_with_move_to {
		dst.move_to_pt(cm.position(cm.segments[seg_index], start_t))
	}
	seg := cm.segments[seg_index]
	stop_seg := cm.segments[stop_index]
	if seg.pt_index == stop_seg.pt_index {
		measure_seg_to(cm.pts[seg.pt_index..], seg.kind, start_t, stop_t, mut dst)
	} else {
		for {
			current := cm.segments[seg_index]
			measure_seg_to(cm.pts[current.pt_index..], current.kind, start_t, 1, mut dst)
			// Segment::Next()
			for {
				seg_index++
				if cm.segments[seg_index].pt_index != current.pt_index {
					break
				}
			}
			start_t = 0
			if cm.segments[seg_index].pt_index >= stop_seg.pt_index {
				break
			}
		}
		last := cm.segments[seg_index]
		measure_seg_to(cm.pts[last.pt_index..], last.kind, 0, stop_t, mut dst)
	}
	return true
}

// outset_for_stroke().
fn outset_for_dash_stroke(r Rect, stroke DashStroke) Rect {
	mut radius := stroke.width * f32(0.5)
	if radius == 0 {
		radius = 1
	}
	if stroke.join == .miter {
		radius *= stroke.miter_limit
	}
	return Rect{r.left - radius, r.top - radius, r.right + radius, r.bottom + radius}
}

// adjust_zero_length_line(): bumps the end so the line has a length.
fn adjust_zero_length_line(mut pts [2]Point) {
	scale := fmax_std(f32(1.001), pts[1].x)
	bump := scale * scalar_nearly_zero
	pts[1].x += bump
}

// clip_line(): trims a horizontal or vertical line to bounds, in phase with
// the dashes.
fn clip_dash_line(mut pts [2]Point, bounds Rect, interval_length f32, prior_phase f32) bool {
	dxy := vsub(pts[1], pts[0])
	if dxy.x != 0 && dxy.y != 0 {
		return false
	}
	vertical := dxy.y != 0
	mut min_xy := if vertical { pts[0].y } else { pts[0].x }
	mut max_xy := if vertical { pts[1].y } else { pts[1].x }
	swapped := max_xy < min_xy
	if swapped {
		min_xy, max_xy = max_xy, min_xy
	}
	left_top := if vertical { bounds.top } else { bounds.left }
	right_bottom := if vertical { bounds.bottom } else { bounds.right }
	if max_xy < left_top || min_xy > right_bottom {
		return false
	}
	if min_xy < left_top {
		mod := C.fmodf(left_top - min_xy, interval_length)
		min_xy = left_top - mod
		if !swapped {
			min_xy -= prior_phase
		}
	}
	if max_xy > right_bottom {
		mod := C.fmodf(max_xy - right_bottom, interval_length)
		max_xy = right_bottom + mod
		if swapped {
			max_xy += prior_phase
		}
	}
	if swapped {
		min_xy, max_xy = max_xy, min_xy
	}
	if vertical {
		pts[0].y = min_xy
		pts[1].y = max_xy
	} else {
		pts[0].x = min_xy
		pts[1].x = max_xy
	}
	if min_xy == max_xy {
		adjust_zero_length_line(mut pts)
	}
	return true
}

// cull_path(): a line or rect trimmed to the cull bounds, or none.
fn cull_path(src Path, stroke DashStroke, cull_rect ?Rect, interval_length f32) ?PathBuilder {
	mut builder := PathBuilder{}
	bounds_in := cull_rect or {
		if line := src.is_line() {
			if line[0] == line[1] {
				mut pts := line
				adjust_zero_length_line(mut pts)
				builder.move_to_pt(pts[0])
				builder.line_to_pt(pts[1])
				return builder
			}
		}
		return none
	}
	bounds := outset_for_dash_stroke(bounds_in, stroke)
	if line := src.is_line() {
		mut pts := line
		if clip_dash_line(mut pts, bounds, interval_length, 0) {
			builder.move_to_pt(pts[0])
			builder.line_to_pt(pts[1])
			return builder
		}
		return none
	}
	if _ := src.rect_contour() {
		mut iter := StrokeIter{
			verbs:   src.verbs
			points:  src.points
			weights: src.weights
		}
		iter.next() or { return none }
		mut accum := f64(0)
		for {
			rec := iter.next() or { break }
			if rec.verb != .line {
				break
			}
			v := vsub(rec.pts[1], rec.pts[0])
			mut pts := [rec.pts[0], rec.pts[1]]!
			phase := f32(C.fmod(accum, f64(interval_length)))
			if clip_dash_line(mut pts, bounds, interval_length, phase) {
				mut need_move := true
				if last := builder.last_point() {
					need_move = last != pts[0]
				}
				if need_move {
					builder.move_to_pt(pts[0])
				}
				builder.line_to_pt(pts[1])
			}
			sum := v.x + v.y
			accum += f64(abs_f32(sum))
		}
		if builder.verbs.len == 0 {
			return none
		}
		return builder
	}
	return none
}

// SpecialLineRec: a butt-capped stroked line dashed directly into filled
// quadrilaterals.
struct SpecialLine {
	pts         [2]Point
	tangent     Point
	normal      Point
	path_length f32
}

fn special_line(src Path, stroke DashStroke, interval_count int, interval_length f32) ?SpecialLine {
	if stroke.width == 0 {
		return none
	}
	pts := src.is_line() or { return none }
	if stroke.cap != .butt {
		return none
	}
	path_length := point_length(pts[0].x - pts[1].x, pts[0].y - pts[1].y)
	mut tangent := vsub(pts[1], pts[0])
	if vzero(tangent) {
		return none
	}
	inv := f32(1) / path_length
	tangent = vmul(tangent, inv)
	if !point_is_finite(tangent) {
		return none
	}
	mut normal := Point{tangent.y, -tangent.x}
	normal = vmul(normal, stroke.width * f32(0.5))
	scaled := path_length * f32(interval_count)
	pt_count := scaled / interval_length
	if pt_count != pt_count {
		return none
	}
	return SpecialLine{pts, tangent, normal, path_length}
}

fn (l &SpecialLine) add_segment(d0 f32, d1_in f32, mut path PathBuilder) {
	mut d1 := d1_in
	if d1 > l.path_length {
		d1 = l.path_length
	}
	tx0 := l.tangent.x * d0
	tx1 := l.tangent.x * d1
	ty0 := l.tangent.y * d0
	ty1 := l.tangent.y * d1
	x0 := l.pts[0].x + tx0
	x1 := l.pts[0].x + tx1
	y0 := l.pts[0].y + ty0
	y1 := l.pts[0].y + ty1
	path.move_to(x0 + l.normal.x, y0 + l.normal.y)
	path.line_to(x1 + l.normal.x, y1 + l.normal.y)
	path.line_to(x1 - l.normal.x, y1 - l.normal.y)
	path.line_to(x0 - l.normal.x, y0 - l.normal.y)
}

// The outcome of SkDashPathEffect::filterPath().
struct DashResult {
	// Whether the effect replaced the path; when false the source path is
	// stroked (or filled, if fill is set) instead.
	applied bool
	path    Path
	// SpecialLineRec switched the stroke record to fill: the dashes are
	// already stroked outlines.
	fill bool
}

// SkDashPath::InternalFilter() with StrokeRecApplication::kAllow.
fn dash_path(src Path, dash DashEffect, stroke DashStroke, cull_rect ?Rect) DashResult {
	mut dst := PathBuilder{}
	if src.points.len == 0 {
		return DashResult{
			applied: true
			path:    dst.detach()
		}
	}
	count := dash.intervals.len
	intervals := dash.intervals
	mut dash_count := f32(0)
	mut measured := src
	if mut culled := cull_path(src, stroke, cull_rect, dash.interval_length) {
		if _ := src.rect_contour() {
			if src.is_last_contour_closed() && dash.initial_dash_index % 2 == 0 {
				mut first := new_contour_measure_iter(src, stroke.res_scale)
				path_length := if cm := first.next() { cm.length } else { f32(0) }
				sum := path_length + dash.phase
				mut end_phase := C.fmodf(sum, dash.interval_length)
				mut index := 0
				for end_phase > intervals[index] {
					end_phase -= intervals[index]
					index++
					if index == count {
						end_phase = 0
						break
					}
				}
				if (index % 2 == 0) == (end_phase > 0) {
					src_pts := src.points
					mid_point := src_pts[0]
					mut last := src_pts.len - 1
					for mid_point == src_pts[last] {
						last--
					}
					mut next := 1
					for mid_point == src_pts[next] {
						next++
					}
					tiny := scalar_nearly_zero
					v0 := vmul(vsub(mid_point, src_pts[last]), tiny)
					culled.move_to_pt(vsub(mid_point, v0))
					culled.line_to_pt(mid_point)
					v1 := vmul(vsub(mid_point, src_pts[next]), tiny)
					culled.line_to_pt(vsub(mid_point, v1))
				}
			}
		}
		measured = culled.detach()
	}
	line := special_line(measured, stroke, count >> 1, dash.interval_length)
	mut meas := new_contour_measure_iter(measured, stroke.res_scale)
	mut contour := meas.next()
	for {
		cm := contour or { ContourMeasure{} }
		closed := cm.closed
		mut skip_first_segment := closed
		mut added_segment := false
		length := cm.length
		mut index := dash.initial_dash_index
		half := f32(count >> 1)
		scaled := length * half
		dash_count += scaled / dash.interval_length
		if dash_count > max_dash_count {
			return DashResult{
				applied: false
				fill:    line != none
			}
		}
		mut distance := f64(0)
		mut dlen := f64(dash.initial_dash_length)
		for distance < f64(length) {
			added_segment = false
			if index % 2 == 0 && !skip_first_segment {
				added_segment = true
				if l := line {
					l.add_segment(f32(distance), f32(distance + dlen), mut dst)
				} else if contour != none {
					cm.get_segment(f32(distance), f32(distance + dlen), mut dst, true)
				}
			}
			distance += dlen
			skip_first_segment = false
			index++
			if index == count {
				index = 0
			}
			dlen = f64(intervals[index])
		}
		if closed && dash.initial_dash_index % 2 == 0 && dash.initial_dash_length >= 0 {
			cm.get_segment(0, dash.initial_dash_length, mut dst, !added_segment)
		}
		contour = meas.next()
		if contour == none {
			break
		}
	}
	return DashResult{
		applied: true
		path:    dst.detach()
		fill:    line != none
	}
}
