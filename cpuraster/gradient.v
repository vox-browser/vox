module cpuraster

import math

// SkGradientShader (google/skia ee20d565) as skia/canvas_raster.cpp's
// apply_style() builds Canvas2D gradients: linear (MakeLinear), radial
// (MakeTwoPointConical) and conic (MakeSweep) gradients with explicit stop
// positions, clamped, interpolated unpremultiplied in the destination's sRGB
// space, under the canvas transform. The raster pipeline stages are seed_shader,
// the matrix stage appendMatrix() selects, the geometry stage, clamp_x_1, the
// gradient fill stage and premul, in lowp (unfused float math, rounded to
// 16-bit lanes) or highp (NEON, fused mad) like the rest of the pipeline.

// A Canvas2D gradient in skia.Style's encoding: kind 1 linear, 2 radial and
// 3 conic; stops are offset, red, green, blue and alpha.
pub struct CanvasGradient {
pub:
	kind  int
	x0    f32
	y0    f32
	r0    f32
	x1    f32
	y1    f32
	r1    f32
	angle f32
	stops []f32
}

// What the shader factory returned: nothing (the paint keeps its black
// color), a solid SkShaders::Color(), a gradient, an image shader, or a
// shader that cannot append its stages (a non-invertible matrix), which
// draws nothing.
enum ShaderKind {
	null_
	color
	gradient
	image
	empty
}

struct CanvasShader {
	kind     ShaderKind
	color    [4]f32
	gradient GradientShader
	image    ImageShader
}

enum GradientGeometry {
	linear
	radial
	// SkConicalGradient's kRadial (concentric) type.
	concentric
	strip
	focal
	sweep
}

enum FocalStage {
	on_circle
	well_behaved
	smaller
	greater
}

enum FillKind {
	two_stop
	evenly
	arbitrary
}

// The gradient's fill stage context: per-gap factors and biases so that
// color = factor * t + bias.
struct GradientFill {
	kind       FillKind
	factors    [4][]f32
	biases     [4][]f32
	ts         []f32
	stop_count int
}

struct GradientShader {
	geometry GradientGeometry
	// The inverse total matrix seed_shader's coordinates go through.
	matrix SkAffine
	// The matrix appended after the geometry stage (concentric and sweep).
	post_matrix SkAffine
	clamp       bool
	fill        GradientFill
	premul      bool
	opaque      bool
	// SkConicalGradient's strip and focal stages.
	p0               f32
	p1               f32
	focal            FocalStage
	mask_degenerates bool
	negate           bool
	compensate_focal bool
	unswap           bool
	// SkGradientBaseShader::onAsLuminanceColor()'s SkColor: the average of
	// the stored stop colors.
	luminance u32
}

// Only the strip and focal stages lack lowp versions.
fn (g &GradientShader) needs_highp() bool {
	return g.geometry == .strip || g.geometry == .focal
}

// SkScalarNearlyZero() and SkScalarNearlyEqual(); Skia's default tolerance
// is scalar_nearly_zero (1/4096).

@[inline]
fn nearly_zero(x f32, tolerance f32) bool {
	return f32(math.abs(x)) <= tolerance
}

@[inline]
fn nearly_equal(x f32, y f32, tolerance f32) bool {
	return f32(math.abs(x - y)) <= tolerance
}

const degenerate_threshold = f32(1) / f32(1 << 15)

// SkMatrix pieces on SkAffine.

fn affine_translate(dx f32, dy f32) SkAffine {
	return SkAffine{
		tx: dx
		ty: dy
	}
}

fn affine_scale(sx f32, sy f32) SkAffine {
	return SkAffine{
		sx: sx
		sy: sy
	}
}

// SkMatrix::Concat(a, b): a applied after b.
fn sk_concat(a SkAffine, b SkAffine) SkAffine {
	if a.type_mask() == 0 {
		return b
	}
	if b.type_mask() == 0 {
		return a
	}
	return affine_concat(a, b)
}

// SkMatrix::postScale(): a no-op for a unit scale, else postConcat().
fn post_scale(m SkAffine, sx f32, sy f32) SkAffine {
	if sx == 1 && sy == 1 {
		return m
	}
	return sk_concat(affine_scale(sx, sy), m)
}

fn post_translate(m SkAffine, dx f32, dy f32) SkAffine {
	return SkAffine{
		...m
		tx: m.tx + dx
		ty: m.ty + dy
	}
}

// SkMatrix::setSinCos() about (px, py), with its unfused sdot().
fn set_sin_cos(sin f32, cos f32, px f32, py f32) SkAffine {
	one_minus_cos := f32(1) - cos
	tx_a := sin * py
	tx_b := one_minus_cos * px
	ty_a := -sin * px
	ty_b := one_minus_cos * py
	return SkAffine{
		sx: cos
		kx: -sin
		tx: tx_a + tx_b
		ky: sin
		sy: cos
		ty: ty_a + ty_b
	}
}

fn affine_to_matrix(m SkAffine) Matrix {
	return Matrix{m.sx, m.ky, m.kx, m.sy, m.tx, m.ty}
}

fn affine_invert(m SkAffine) ?SkAffine {
	inverse := invert_matrix(affine_to_matrix(m))?
	return inverse.m
}

// SkMatrix::PolyToPoly() for two points: Poly2Proc() of both, one inverted.
fn poly_to_poly2(src [2]Point, dst [2]Point) ?SkAffine {
	proc := fn (p [2]Point) SkAffine {
		return SkAffine{
			sx: p[1].y - p[0].y
			ky: p[0].x - p[1].x
			kx: p[1].x - p[0].x
			sy: p[1].y - p[0].y
			tx: p[0].x
			ty: p[0].y
		}
	}
	inverse := affine_invert(proc(src))?
	return sk_concat(proc(dst), inverse)
}

// canvas_gradient_shader is apply_style()'s SkGradientShader factory call
// for gradient, with the canvas transform matrix.
fn canvas_gradient_shader(gradient CanvasGradient, m Matrix) CanvasShader {
	mut colors := [][4]f32{}
	mut positions := []f32{}
	for i := 0; i + 4 < gradient.stops.len; i += 5 {
		positions << gradient.stops[i]
		colors << [gradient.stops[i + 1], gradient.stops[i + 2], gradient.stops[i + 3],
			gradient.stops[i + 4]]!
	}
	// ValidGradient(): at least one color.
	if colors.len == 0 {
		return CanvasShader{}
	}
	return match gradient.kind {
		1 {
			make_linear(Point{gradient.x0, gradient.y0}, Point{gradient.x1, gradient.y1}, colors, positions, m)
		}
		2 {
			make_two_point_conical(Point{gradient.x0, gradient.y0}, gradient.r0, Point{gradient.x1, gradient.y1}, gradient.r1, colors, positions, m)
		}
		3 { make_canvas_sweep(gradient, colors, positions, m) }
		else { CanvasShader{} }
	}
}

// SkShaders::Color(): none for a non-finite color, the alpha pinned to [0, 1].
fn color_shader(c [4]f32) CanvasShader {
	for v in c {
		if !is_finite_f32(v) {
			return CanvasShader{}
		}
	}
	low := if f32(1) < c[3] { f32(1) } else { c[3] }
	alpha := if f32(0) < low { low } else { f32(0) }
	return CanvasShader{
		kind:  .color
		color: [c[0], c[1], c[2], alpha]!
	}
}

// MakeDegenerateGradient() for clamped gradients: the last color.
fn degenerate_gradient(colors [][4]f32) CanvasShader {
	return color_shader(colors.last())
}

fn make_linear(p0 Point, p1 Point, colors [][4]f32, positions []f32, m Matrix) CanvasShader {
	dx := p1.x - p0.x
	dy := p1.y - p0.y
	length := point_length(dx, dy)
	if !is_finite_f32(length) {
		return CanvasShader{}
	}
	if colors.len == 1 {
		return color_shader(colors[0])
	}
	if nearly_zero(length, degenerate_threshold) {
		return degenerate_gradient(colors)
	}
	// pts_to_unit_matrix()
	inv := if length != 0 { f32(1) / length } else { f32(0) }
	vx := dx * inv
	vy := dy * inv
	mut unit := set_sin_cos(-vy, vx, p0.x, p0.y)
	unit = post_translate(unit, -p0.x, -p0.y)
	unit = post_scale(unit, inv, inv)
	return new_gradient(.linear, unit, SkAffine{}, colors, positions, m, true)
}

fn make_radial(center Point, radius f32, colors [][4]f32, positions []f32, m Matrix) CanvasShader {
	if radius < 0 {
		return CanvasShader{}
	}
	if colors.len == 1 {
		return color_shader(colors[0])
	}
	if nearly_zero(radius, degenerate_threshold) {
		return degenerate_gradient(colors)
	}
	// rad_to_unit_matrix()
	inv := f32(1) / radius
	unit := post_scale(affine_translate(-center.x, -center.y), inv, inv)
	return new_gradient(.radial, unit, SkAffine{}, colors, positions, m, true)
}

fn make_two_point_conical(start Point, start_radius f32, end Point, end_radius f32, colors_in [][4]f32, positions_in []f32, m Matrix) CanvasShader {
	if start_radius < 0 || end_radius < 0 {
		return CanvasShader{}
	}
	mut colors := colors_in.clone()
	mut positions := positions_in.clone()
	if nearly_zero(point_length(start.x - end.x, start.y - end.y), degenerate_threshold) {
		if nearly_equal(start_radius, end_radius, degenerate_threshold) {
			if end_radius > degenerate_threshold {
				// A thin ring at the radius: the first color up to it, then a
				// hard stop to the last color.
				return make_radial(start, end_radius, [colors[0], colors[0], colors.last()],
					[f32(0), 1, 1], m)
			}
			return degenerate_gradient(colors)
		} else if nearly_zero(start_radius, degenerate_threshold) {
			return make_radial(start, end_radius, colors, positions, m)
		}
	}
	// EXPAND_1_COLOR()
	if colors.len == 1 {
		colors = [colors[0], colors[0]]
		positions = []
	}
	return create_conical(start, start_radius, end, end_radius, colors, positions, m)
}

// SkConicalGradient::Create() and FocalData::set().
fn create_conical(c0 Point, r0_in f32, c1 Point, r1_in f32, colors [][4]f32, positions []f32, m Matrix) CanvasShader {
	mut geometry := GradientGeometry.concentric
	mut unit := SkAffine{}
	mut post := SkAffine{}
	center_distance := point_length(c0.x - c1.x, c0.y - c1.y)
	if nearly_zero(center_distance, scalar_nearly_zero) {
		larger := if r0_in < r1_in { r1_in } else { r0_in }
		if nearly_zero(larger, scalar_nearly_zero) || nearly_equal(r0_in, r1_in, scalar_nearly_zero) {
			return CanvasShader{}
		}
		scale := f32(1) / larger
		unit = post_scale(affine_translate(-c1.x, -c1.y), scale, scale)
	} else {
		unit = poly_to_poly2([c0, c1]!, [Point{0, 0}, Point{1, 0}]!) or { return CanvasShader{} }
		geometry = if nearly_zero(r1_in - r0_in, scalar_nearly_zero) { .strip } else { .focal }
	}
	if geometry == .concentric {
		// Radial computes t for [0, r2]; the post matrix maps it to [r1, r2].
		d_radius := r1_in - r0_in
		larger := if r0_in < r1_in { r1_in } else { r0_in }
		scale := larger / d_radius
		bias := -r0_in / d_radius
		post = sk_concat(affine_translate(bias, 0), affine_scale(scale, 1))
		return new_gradient(.concentric, unit, post, colors, positions, m, false)
	}
	if geometry == .strip {
		shader := new_gradient(.strip, unit, post, colors, positions, m, false)
		// getCenterX1() is the distance between the centers.
		scaled_r0 := r0_in / center_distance
		return CanvasShader{
			...shader
			gradient: GradientShader{
				...shader.gradient
				p0: scaled_r0 * scaled_r0
			}
		}
	}
	// FocalData::set()
	mut r0 := r0_in / center_distance
	mut r1 := r1_in / center_distance
	mut swapped := false
	mut focal_x := r0 / (r0 - r1)
	if nearly_zero(focal_x - 1, scalar_nearly_zero) {
		unit = post_translate(unit, -1, 0)
		unit = post_scale(unit, -1, 1)
		r0, r1 = r1, r0
		focal_x = 0
		swapped = true
	}
	focal_matrix := poly_to_poly2([Point{focal_x, 0}, Point{1, 0}]!, [Point{0, 0}, Point{1, 0}]!) or {
		return CanvasShader{}
	}
	unit = sk_concat(focal_matrix, unit)
	focal_r1 := r1 / f32(math.abs(1 - focal_x))
	on_circle := nearly_zero(1 - focal_r1, scalar_nearly_zero)
	if on_circle {
		unit = post_scale(unit, 0.5, 0.5)
	} else {
		squared := focal_r1 * focal_r1
		denominator := squared - 1
		x_scale := focal_r1 / denominator
		y_scale := f32(1) / C.sqrtf(f32(math.abs(denominator)))
		unit = post_scale(unit, x_scale, y_scale)
	}
	one_minus_focal := f32(math.abs(1 - focal_x))
	unit = post_scale(unit, one_minus_focal, one_minus_focal)
	well_behaved := !on_circle && focal_r1 > 1
	shader := new_gradient(.focal, unit, post, colors, positions, m, false)
	if shader.kind != .gradient {
		return shader
	}
	stage := if on_circle {
		FocalStage.on_circle
	} else if well_behaved {
		FocalStage.well_behaved
	} else if swapped || 1 - focal_x < 0 {
		FocalStage.smaller
	} else {
		FocalStage.greater
	}
	g := GradientShader{
		...shader.gradient
		p0:               f32(1) / focal_r1
		p1:               focal_x
		focal:            stage
		mask_degenerates: !well_behaved
		negate:           1 - focal_x < 0
		compensate_focal: !nearly_zero(focal_x, scalar_nearly_zero)
		unswap:           swapped
	}
	return CanvasShader{
		...shader
		gradient: g
	}
}

// MakeSweep() for a Canvas2D conic gradient: the angle in degrees through
// a full turn.
fn make_canvas_sweep(gradient CanvasGradient, colors [][4]f32, positions []f32, m Matrix) CanvasShader {
	pi := f32(3.14159265358979323846)
	scaled := gradient.angle * f32(180)
	start := scaled / pi
	end := start + f32(360)
	if colors.len == 1 {
		return color_shader(colors[0])
	}
	if !is_finite_f32(start) || !is_finite_f32(end) || start > end {
		return CanvasShader{}
	}
	if nearly_equal(start, end, degenerate_threshold) {
		if end > degenerate_threshold {
			return sweep_shader(gradient.x0, gradient.y0, [colors[0], colors[0], colors.last()],
				[f32(0), 1, 1], 0, end, m)
		}
		return degenerate_gradient(colors)
	}
	return sweep_shader(gradient.x0, gradient.y0, colors, positions, start, end, m)
}

fn sweep_shader(cx f32, cy f32, colors [][4]f32, positions []f32, start f32, end f32, m Matrix) CanvasShader {
	t0 := start / f32(360)
	t1 := end / f32(360)
	bias := -t0
	scale := f32(1) / (t1 - t0)
	post := sk_concat(affine_scale(scale, 1), affine_translate(bias, 0))
	return new_gradient(.sweep, affine_translate(-cx, -cy), post, colors, positions, m, true)
}

// The SkGradientBaseShader constructor and appendStages() for colors and
// positions under the canvas matrix m. opaque_capable is false for conical
// gradients, which never report opacity.
fn new_gradient(geometry GradientGeometry, unit SkAffine, post SkAffine, colors_in [][4]f32, positions_in []f32, m Matrix, opaque_capable bool) CanvasShader {
	// MatrixRec::apply(): the inverse CTM, then the gradient's unit matrix.
	ctm := SkAffine{
		sx: m.a
		kx: m.c
		tx: m.e
		ky: m.b
		sy: m.d
		ty: m.f
	}
	inverse := affine_invert(ctm) or {
		return CanvasShader{
			kind: .empty
		}
	}
	total := sk_concat(unit, inverse)
	mut colors_are_opaque := true
	for c in colors_in {
		colors_are_opaque = colors_are_opaque && c[3] == 1
	}
	colors, positions := gradient_stops(colors_in, positions_in)
	return CanvasShader{
		kind:     .gradient
		gradient: GradientShader{
			geometry:    geometry
			matrix:      total
			post_matrix: post
			clamp:       positions.len == 0
			fill:        gradient_fill(colors, positions)
			premul:      !colors_are_opaque
			opaque:      opaque_capable && colors_are_opaque
			luminance:   average_color(colors)
		}
	}
}

// onAsLuminanceColor(): the stop colors summed from opaque black and
// scaled by 1 / count, as an opaque SkColor.
fn average_color(colors [][4]f32) u32 {
	mut sum := [f32(0), 0, 0]!
	for c in colors {
		for i in 0 .. 3 {
			sum[i] += c[i]
		}
	}
	scale := f32(1) / f32(colors.len)
	mut out := u32(0xff000000)
	for i in 0 .. 3 {
		out |= color4f_byte(sum[i] * scale) << (16 - 8 * i)
	}
	return out
}

// The constructor's stops: implicit first and last stops, positions pinned
// monotonic, uniform positions dropped and runs of duplicate positions
// reduced to their outer stops. Empty positions mean evenly spaced stops.
fn gradient_stops(colors_in [][4]f32, desc_positions []f32) ([][4]f32, []f32) {
	n := colors_in.len
	if desc_positions.len == 0 {
		return colors_in, []f32{}
	}
	first_implicit := desc_positions[0] > 0
	mut last_implicit := desc_positions[n - 1] != 1
	mut colors := [][4]f32{}
	if first_implicit {
		colors << colors_in[0]
	}
	colors << colors_in
	if last_implicit {
		colors << colors_in[n - 1]
	}
	count := colors.len
	mut positions := []f32{len: count}
	mut prev := f32(0)
	positions[0] = prev
	start_index := if first_implicit { 0 } else { 1 }
	end := n + int(last_implicit)
	mut uniform := true
	uniform_step := desc_positions[start_index] - prev
	mut p := 1
	for i in start_index .. end {
		mut curr := f32(1)
		if i != n {
			// SkTPin(pos, prev, 1)
			low := if f32(1) < desc_positions[i] { f32(1) } else { desc_positions[i] }
			curr = if prev < low { low } else { prev }
			if curr == 1 && last_implicit {
				last_implicit = false
			}
		}
		uniform = uniform && nearly_equal(uniform_step, curr - prev, scalar_nearly_zero)
		prev = curr
		positions[p] = curr
		p++
	}
	if uniform {
		return colors, []f32{}
	}
	// Clamped: keep the leftmost and rightmost stop of each duplicate run.
	mut out_colors := [][4]f32{}
	mut out_positions := []f32{}
	mut i := 0
	for j in 1 .. count + 1 {
		if j == count || positions[i] != positions[j] {
			out_positions << positions[i]
			out_colors << colors[i]
			if j - i > 1 {
				out_positions << positions[j - 1]
				out_colors << colors[j - 1]
			}
			i = j
		}
	}
	return out_colors, out_positions
}

fn colors_equal(a [4]f32, b [4]f32) bool {
	return a[0] == b[0] && a[1] == b[1] && a[2] == b[2] && a[3] == b[3]
}

// AppendGradientFillStages().
fn gradient_fill(colors [][4]f32, positions []f32) GradientFill {
	count := colors.len
	if count == 2 && positions.len == 0 {
		mut factors := [4][]f32{}
		mut biases := [4][]f32{}
		for c in 0 .. 4 {
			factors[c] = [colors[1][c] - colors[0][c]]
			biases[c] = [colors[0][c]]
		}
		return GradientFill{
			kind:    .two_stop
			factors: factors
			biases:  biases
		}
	}
	mut factors := [4][]f32{}
	mut biases := [4][]f32{}
	for c in 0 .. 4 {
		factors[c] = []f32{}
		biases[c] = []f32{}
	}
	if positions.len == 0 {
		gap_count := f32(count - 1)
		mut left := colors[0]
		for i in 0 .. count - 1 {
			right := colors[i + 1]
			// init_stop_evenly()
			step := f32(i) / gap_count
			for c in 0 .. 4 {
				diff := right[c] - left[c]
				factor := diff * gap_count
				offset := factor * step
				factors[c] << factor
				biases[c] << left[c] - offset
			}
			left = right
		}
		for c in 0 .. 4 {
			factors[c] << 0
			biases[c] << left[c]
		}
		return GradientFill{
			kind:       .evenly
			factors:    factors
			biases:     biases
			stop_count: count
		}
	}
	first := if count > 2 {
		if !colors_equal(colors[0], colors[1]) { 0 } else { 1 }
	} else {
		0
	}
	last := if count > 2 {
		if !colors_equal(colors[count - 2], colors[count - 1]) { count - 1 } else { count - 2 }
	} else {
		1
	}
	mut ts := []f32{}
	mut t_l := positions[first]
	mut c_l := colors[first]
	for c in 0 .. 4 {
		factors[c] << 0
		biases[c] << c_l[c]
	}
	ts << 0
	for i in first .. last {
		t_r := positions[i + 1]
		c_r := colors[i + 1]
		if t_l < t_r {
			gap := t_r - t_l
			c_scale := f32(1) / gap
			if is_finite_f32(c_scale) {
				// init_stop_pos()
				for c in 0 .. 4 {
					diff := c_r[c] - c_l[c]
					factor := diff * c_scale
					offset := factor * t_l
					factors[c] << factor
					biases[c] << c_l[c] - offset
				}
				ts << t_l
			}
		}
		t_l = t_r
		c_l = c_r
	}
	ts << t_l
	for c in 0 .. 4 {
		factors[c] << 0
		biases[c] << c_l[c]
	}
	return GradientFill{
		kind:       .arbitrary
		factors:    factors
		biases:     biases
		ts:         ts
		stop_count: ts.len
	}
}

// The fill stage's gap index for t.
fn (f &GradientFill) index(t f32) int {
	return match f.kind {
		.two_stop {
			0
		}
		.evenly {
			// trunc_(t * (stopCount - 1)): vcvtq_s32_f32 saturates and maps
			// NaN to 0.
			scaled := t * f32(f.stop_count - 1)
			if scaled != scaled {
				0
			} else {
				int(scaled)
			}
		}
		.arbitrary {
			mut idx := 0
			for i in 1 .. f.stop_count {
				if t >= f.ts[i] {
					idx++
				}
			}
			idx
		}
	}
}

// One matrix stage: appendMatrix() selects translate, scale-translate or
// 2x3 by type; highp fuses the multiply-adds, lowp does not.
fn apply_matrix(m SkAffine, x f32, y f32, fused bool) (f32, f32) {
	mask := m.type_mask()
	if mask == 0 {
		return x, y
	}
	if mask == affine_translate_mask {
		return x + m.tx, y + m.ty
	}
	if mask & affine_affine_mask == 0 {
		if fused {
			return mad(x, m.sx, m.tx), mad(y, m.sy, m.ty)
		}
		xs := x * m.sx
		ys := y * m.sy
		return m.tx + xs, m.ty + ys
	}
	if fused {
		return mad(x, m.sx, mad(y, m.kx, m.tx)), mad(x, m.ky, mad(y, m.sy, m.ty))
	}
	yk := y * m.kx
	inner_x := m.tx + yk
	xs := x * m.sx
	ys := y * m.sy
	inner_y := m.ty + ys
	xk := x * m.ky
	return inner_x + xs, inner_y + xk
}

// xy_to_unit_angle's polynomial atan, with the precision's min, max and abs.
fn unit_angle(x f32, y f32, highp bool) f32 {
	xabs := f32(math.abs(x))
	yabs := f32(math.abs(y))
	low := if highp { neon_min(xabs, yabs) } else { lowp_fmin(xabs, yabs) }
	high := if highp { neon_max(xabs, yabs) } else { lowp_fmax(xabs, yabs) }
	slope := low / high
	s := slope * slope
	c1 := math.f32_from_bits(0x3e22f0a9) // 0.15912117063999176025390625
	c2 := math.f32_from_bits(0xbd5464d4) // -5.185396969318389892578125e-2
	c3 := math.f32_from_bits(0x3ccad79f) // 2.476101927459239959716796875e-2
	c4 := math.f32_from_bits(0xbbe72b6f) // -7.0547382347285747528076171875e-3
	sc4 := s * c4
	inner3 := c3 + sc4
	sc3 := s * inner3
	inner2 := c2 + sc3
	sc2 := s * inner2
	inner1 := c1 + sc2
	mut phi := slope * inner1
	if xabs < yabs {
		phi = f32(0.25) - phi
	}
	if x < 0 {
		phi = f32(0.5) - phi
	}
	if y < 0 {
		phi = f32(1) - phi
	}
	if phi != phi {
		phi = 0
	}
	return phi
}

// lowp's min() and max(): x < y comparisons.
@[inline]
fn lowp_fmin(a f32, b f32) f32 {
	return if a < b { a } else { b }
}

@[inline]
fn lowp_fmax(a f32, b f32) f32 {
	return if a < b { b } else { a }
}

// The geometry stages: t for (x, y), and whether a conical mask keeps it.
fn (g &GradientShader) geometry_t(x f32, y f32, highp bool) (f32, bool) {
	match g.geometry {
		.linear {
			return x, true
		}
		.radial, .concentric {
			x2 := x * x
			y2 := y * y
			sum := x2 + y2
			return C.sqrtf(sum), true
		}
		.sweep {
			return unit_angle(x, y, highp), true
		}
		.strip {
			yy := y * y
			diff := g.p0 - yy
			mut t := x + C.sqrtf(diff)
			degenerate := t != t
			if degenerate {
				t = 0
			}
			return t, !degenerate
		}
		.focal {
			mut t := f32(0)
			match g.focal {
				.on_circle {
					yy := y * y
					ratio := yy / x
					t = x + ratio
				}
				.well_behaved {
					xx := x * x
					yy := y * y
					root := C.sqrtf(xx + yy)
					scaled := x * g.p0
					t = root - scaled
				}
				.greater, .smaller {
					xx := x * x
					yy := y * y
					root := C.sqrtf(xx - yy)
					scaled := x * g.p0
					t = if g.focal == .greater { root - scaled } else { -root - scaled }
				}
			}
			mut keep := true
			if g.mask_degenerates {
				degenerate := t <= 0 || t != t
				if degenerate {
					t = 0
				}
				keep = !degenerate
			}
			if g.negate {
				t = -t
			}
			if g.compensate_focal {
				t = t + g.p1
			}
			if g.unswap {
				t = f32(1) - t
			}
			return t, keep
		}
	}
}

// The coordinate pipeline up to the fill stage: seed_shader's pixel
// center, the matrices, the geometry and clamp_x_1.
fn (g &GradientShader) gradient_t(px int, py int, highp bool) (f32, bool) {
	sx := f32(px) + f32(0.5)
	sy := f32(py) + f32(0.5)
	x, y := apply_matrix(g.matrix, sx, sy, highp)
	mut t, keep := g.geometry_t(x, y, highp)
	if g.geometry == .concentric || g.geometry == .sweep {
		t, _ = apply_matrix(g.post_matrix, t, 0, highp)
	}
	if g.clamp {
		t = if highp { neon_min(neon_max(0, t), 1) } else { lowp_fmin(lowp_fmax(0, t), 1) }
	}
	return t, keep
}

// shade_highp: the premultiplied float color at pixel (px, py), with the
// conical mask applied after premul.
fn (g &GradientShader) shade_highp(px int, py int) [4]f32 {
	t, keep := g.gradient_t(px, py, true)
	idx := g.fill.index(t)
	mut c := [4]f32{}
	for i in 0 .. 4 {
		c[i] = mad(t, g.fill.factors[i][idx], g.fill.biases[i][idx])
	}
	if g.premul {
		for i in 0 .. 3 {
			c[i] = c[i] * c[3]
		}
	}
	if !keep {
		return [f32(0), 0, 0, 0]!
	}
	return c
}

// shade_lowp: round_F_to_U16() of the unfused fill, then lowp premul.
fn (g &GradientShader) shade_lowp(px int, py int) [4]u32 {
	t, _ := g.gradient_t(px, py, false)
	idx := g.fill.index(t)
	mut c := [4]u32{}
	for i in 0 .. 4 {
		scaled := t * g.fill.factors[i][idx]
		v := g.fill.biases[i][idx] + scaled
		clamped := if i == 3 { v } else { lowp_fmin(lowp_fmax(0, v), 1) }
		times := clamped * f32(255)
		c[i] = f32_to_u16(times + f32(0.5))
	}
	if g.premul {
		for i in 0 .. 3 {
			c[i] = lowp_div255(u16w(c[i] * c[3]))
		}
	}
	return c
}

// cast<U16>(float) on arm64: fcvtzu saturates and maps NaN to 0, then the
// 16-bit narrowing keeps the low bits.
fn f32_to_u16(v f32) u32 {
	if v != v || v <= 0 {
		return 0
	}
	if v >= f32(4294967295.0) {
		return 0xffff
	}
	return u32(u64(v)) & 0xffff
}
