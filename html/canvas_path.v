// Copyright (c) 2020-2023, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/Canvas/CanvasPath.cpp.
//
// The C++ builds up a Gfx::Path. CanvasGfxPath is the V backend for the same
// MoveTo/LineTo/Bezier/elliptical-arc segment model. CanvasPath geometry is a
// direct translation; the software painter consumes these segments in
// canvas_rendering_algorithms.v.
module html

import math

pub struct FloatPoint {
pub:
	x f64
	y f64
}

pub struct FloatSize {
pub:
	width  f64
	height f64
}

fn is_finite(value f64) bool {
	return !math.is_nan(value) && value != math.inf(1) && value != math.inf(-1)
}

// --- Gfx::Path model ---

pub enum PathSegmentKind {
	move_to
	line_to
	quadratic_bezier_curve_to
	cubic_bezier_curve_to
	elliptical_arc_to
	close_path
}

pub struct PathSegment {
pub:
	kind            PathSegmentKind
	point           FloatPoint
	control_point_0 FloatPoint
	control_point_1 FloatPoint
	radii           FloatSize
	x_axis_rotation f64
	large_arc       bool
	sweep           bool
}

@[heap]
pub struct CanvasGfxPath {
mut:
	segments       []PathSegment
	last_point_    FloatPoint
	subpath_start_ FloatPoint
}

pub fn (p &CanvasGfxPath) is_empty() bool {
	return p.segments.len == 0
}

pub fn (p &CanvasGfxPath) length() int {
	return p.segments.len
}

pub fn (p &CanvasGfxPath) segments() []PathSegment {
	return p.segments.clone()
}

pub fn (p &CanvasGfxPath) last_point() FloatPoint {
	return p.last_point_
}

pub fn (mut p CanvasGfxPath) move_to(point FloatPoint) {
	p.segments << PathSegment{
		kind:  .move_to
		point: point
	}
	p.last_point_ = point
	p.subpath_start_ = point
}

pub fn (mut p CanvasGfxPath) line_to(point FloatPoint) {
	p.segments << PathSegment{
		kind:  .line_to
		point: point
	}
	p.last_point_ = point
}

pub fn (mut p CanvasGfxPath) quadratic_bezier_curve_to(control FloatPoint, point FloatPoint) {
	p.segments << PathSegment{
		kind:            .quadratic_bezier_curve_to
		control_point_0: control
		point:           point
	}
	p.last_point_ = point
}

pub fn (mut p CanvasGfxPath) cubic_bezier_curve_to(control_0 FloatPoint, control_1 FloatPoint, point FloatPoint) {
	p.segments << PathSegment{
		kind:            .cubic_bezier_curve_to
		control_point_0: control_0
		control_point_1: control_1
		point:           point
	}
	p.last_point_ = point
}

pub fn (mut p CanvasGfxPath) elliptical_arc_to(point FloatPoint, radii FloatSize, x_axis_rotation f64, large_arc bool, sweep bool) {
	p.segments << PathSegment{
		kind:            .elliptical_arc_to
		point:           point
		radii:           radii
		x_axis_rotation: x_axis_rotation
		large_arc:       large_arc
		sweep:           sweep
	}
	p.last_point_ = point
}

// Gfx::Path::arc_to(endpoint, radius, large_arc, sweep) is an elliptical arc with equal radii.
pub fn (mut p CanvasGfxPath) arc_to(point FloatPoint, radius f64, large_arc bool, sweep bool) {
	p.elliptical_arc_to(point, FloatSize{radius, radius}, 0, large_arc, sweep)
}

pub fn (mut p CanvasGfxPath) close() {
	p.segments << PathSegment{
		kind: .close_path
	}
	// Gfx::Path makes the start of the closed subpath the current point. This
	// matters for a following relative SVG path instruction.
	p.last_point_ = p.subpath_start_
}

fn transformed_ellipse(radii FloatSize, rotation f64, transform CanvasAffineTransform) (FloatSize, f64) {
	// An ellipse is R(rotation) * diag(rx, ry). Applying the affine's
	// linear part gives a new 2x2 ellipse matrix. The eigenvalues/vectors
	// of M*M^T are its squared radii and axis rotation, matching the path
	// transformation performed by Gfx::Path/SkPath upstream.
	cosine := math.cos(rotation)
	sine := math.sin(rotation)
	column_0_x := radii.width * (transform.a * cosine + transform.c * sine)
	column_0_y := radii.width * (transform.b * cosine + transform.d * sine)
	column_1_x := radii.height * (-transform.a * sine + transform.c * cosine)
	column_1_y := radii.height * (-transform.b * sine + transform.d * cosine)
	q_xx := column_0_x * column_0_x + column_1_x * column_1_x
	q_xy := column_0_x * column_0_y + column_1_x * column_1_y
	q_yy := column_0_y * column_0_y + column_1_y * column_1_y
	discriminant := math.sqrt(math.max(0.0, (q_xx - q_yy) * (q_xx - q_yy) +
		4.0 * q_xy * q_xy))
	major_squared := math.max(0.0, (q_xx + q_yy + discriminant) / 2.0)
	minor_squared := math.max(0.0, (q_xx + q_yy - discriminant) / 2.0)
	return FloatSize{
		width: math.sqrt(major_squared)
		height: math.sqrt(minor_squared)
	}, 0.5 * math.atan2(2.0 * q_xy, q_xx - q_yy)
}

// A copy of the path transformed exactly as Gfx::Path::copy_transformed().
pub fn (p &CanvasGfxPath) copy_transformed(transform CanvasAffineTransform) CanvasGfxPath {
	mut result := CanvasGfxPath{}
	for segment in p.segments {
		if segment.kind == .elliptical_arc_to {
			transformed_radii, transformed_rotation := transformed_ellipse(
				segment.radii, segment.x_axis_rotation, transform)
			result.segments << PathSegment{
				...segment
				point: transform.map(segment.point)
				radii: transformed_radii
				x_axis_rotation: transformed_rotation
				sweep: if transform.a * transform.d - transform.b * transform.c < 0 {
					!segment.sweep
				} else {
					segment.sweep
				}
			}
			continue
		}
		result.segments << PathSegment{
			...segment
			point:           transform.map(segment.point)
			control_point_0: transform.map(segment.control_point_0)
			control_point_1: transform.map(segment.control_point_1)
		}
	}
	result.last_point_ = transform.map(p.last_point_)
	result.subpath_start_ = transform.map(p.subpath_start_)
	return result
}

// Append all of `other`'s segments to this path.
pub fn (mut p CanvasGfxPath) append_path(other CanvasGfxPath) {
	for segment in other.segments {
		p.segments << segment
	}
	if other.segments.len > 0 {
		p.last_point_ = other.last_point_
		p.subpath_start_ = other.subpath_start_
	}
}

// Replace this CanvasPath's path (used by Path2D's copy constructor).
fn (mut c CanvasPath) set_path(path CanvasGfxPath) {
	c.path_ = path
}

// --- CanvasPath ---

// https://html.spec.whatwg.org/multipage/canvas.html#canvaspath
@[heap]
pub struct CanvasPath {
mut:
	path_         CanvasGfxPath
	canvas_state_ ?&CanvasState
}

pub fn CanvasPath.create() &CanvasPath {
	return &CanvasPath{}
}

pub fn CanvasPath.create_with_state(canvas_state &CanvasState) &CanvasPath {
	return &CanvasPath{
		canvas_state_: canvas_state
	}
}

pub fn (c &CanvasPath) path() CanvasGfxPath {
	return c.path_
}

fn (mut c CanvasPath) mutable_path_storage() &CanvasGfxPath {
	return &c.path_
}

fn (c &CanvasPath) active_transform() CanvasAffineTransform {
	if state := c.canvas_state_ {
		return state.drawing_state.transform
	}
	return CanvasAffineTransform{}
}

fn (mut c CanvasPath) ensure_subpath(x f64, y f64) {
	if c.path_.is_empty() {
		c.path_.move_to(FloatPoint{x, y})
	}
}

// https://html.spec.whatwg.org/multipage/canvas.html#dom-context-2d-closepath
pub fn (mut c CanvasPath) close_path() {
	// Do nothing if the path has no subpaths; otherwise close the last subpath.
	if c.path_.is_empty() {
		return
	}
	c.path_.close()
}

// https://html.spec.whatwg.org/multipage/canvas.html#dom-context-2d-moveto
pub fn (mut c CanvasPath) move_to(x f64, y f64) {
	// 1. If either argument is infinite or NaN, return.
	if !is_finite(x) || !is_finite(y) {
		return
	}
	// 2. Create a new subpath with the point as its only point.
	c.path_.move_to(FloatPoint{x, y})
}

// https://html.spec.whatwg.org/multipage/canvas.html#dom-context-2d-lineto
pub fn (mut c CanvasPath) line_to(x f64, y f64) {
	// 1. If either argument is infinite or NaN, return.
	if !is_finite(x) || !is_finite(y) {
		return
	}
	if c.path_.is_empty() {
		// 2. If the path has no subpaths, ensure there is a subpath for (x, y).
		c.ensure_subpath(x, y)
	} else {
		// 3. Otherwise, connect the last point to (x, y) with a straight line.
		c.path_.line_to(FloatPoint{x, y})
	}
}

// https://html.spec.whatwg.org/multipage/canvas.html#dom-context-2d-quadraticcurveto
pub fn (mut c CanvasPath) quadratic_curve_to(cpx f64, cpy f64, x f64, y f64) {
	// 1. If any argument is infinite or NaN, return.
	if !is_finite(cpx) || !is_finite(cpy) || !is_finite(x) || !is_finite(y) {
		return
	}
	// 2. Ensure there is a subpath for (cpx, cpy).
	c.ensure_subpath(cpx, cpy)
	// 3-4. Add a quadratic Bézier curve with control point (cpx, cpy) to (x, y).
	c.path_.quadratic_bezier_curve_to(FloatPoint{cpx, cpy}, FloatPoint{x, y})
}

// https://html.spec.whatwg.org/multipage/canvas.html#dom-context-2d-beziercurveto
pub fn (mut c CanvasPath) bezier_curve_to(cp1x f64, cp1y f64, cp2x f64, cp2y f64, x f64, y f64) {
	// 1. If any argument is infinite or NaN, return.
	if !is_finite(cp1x) || !is_finite(cp1y) || !is_finite(cp2x) || !is_finite(cp2y) || !is_finite(x)
		|| !is_finite(y) {
		return
	}
	// 2. Ensure there is a subpath for (cp1x, cp1y).
	c.ensure_subpath(cp1x, cp1y)
	// 3-4. Add a cubic Bézier curve with control points (cp1x, cp1y) and (cp2x, cp2y) to (x, y).
	c.path_.cubic_bezier_curve_to(FloatPoint{cp1x, cp1y}, FloatPoint{cp2x, cp2y}, FloatPoint{x, y})
}

// https://html.spec.whatwg.org/multipage/canvas.html#dom-context-2d-arc
pub fn (mut c CanvasPath) arc(x f64, y f64, radius f64, start_angle f64, end_angle f64, counter_clockwise bool) ! {
	if radius < 0 && is_finite(radius) {
		return error('The radius provided (${radius}) is negative.')
	}
	return c.ellipse(x, y, radius, radius, 0, start_angle, end_angle, counter_clockwise)
}

// https://html.spec.whatwg.org/multipage/canvas.html#dom-context-2d-ellipse
pub fn (mut c CanvasPath) ellipse(x f64, y f64, radius_x f64, radius_y f64, rotation f64, start_angle_in f64, end_angle_in f64, counter_clockwise_in bool) ! {
	mut start_angle := start_angle_in
	mut end_angle := end_angle_in
	mut counter_clockwise := counter_clockwise_in
	// 1. If any argument is infinite or NaN, return.
	if !is_finite(x) || !is_finite(y) || !is_finite(radius_x) || !is_finite(radius_y)
		|| !is_finite(rotation) || !is_finite(start_angle) || !is_finite(end_angle) {
		return
	}
	// 2. If either radius is negative, throw an "IndexSizeError".
	if radius_x < 0 {
		return error('The major-axis radius provided (${radius_x}) is negative.')
	}
	if radius_y < 0 {
		return error('The minor-axis radius provided (${radius_y}) is negative.')
	}
	if radius_x == 0 || radius_y == 0 {
		start_point := FloatPoint{x, y}
		if !c.path_.is_empty() {
			c.path_.line_to(start_point)
		} else {
			c.path_.move_to(start_point)
		}
		return
	}
	tau := math.pi * 2
	// Full-circumference cases: whole ellipse, or a non-zero whole number of turns.
	if (!counter_clockwise && (end_angle - start_angle) >= tau)
		|| (counter_clockwise && (start_angle - end_angle) >= tau)
		|| (start_angle != end_angle && math.fmod(start_angle - end_angle, tau) == 0) {
		start_angle = 0
		// FIXME: mirrors the C++ fudge to work around elliptical_arc_to near-coincident endpoints.
		end_angle = tau * 0.9999
		counter_clockwise = false
	} else {
		start_angle = math.fmod(start_angle, tau)
		end_angle = math.fmod(end_angle, tau)
	}
	sin_rotation := math.sin(rotation)
	cos_rotation := math.cos(rotation)
	resolve_point_with_angle := fn [radius_x, radius_y, sin_rotation, cos_rotation, x, y] (angle f64) FloatPoint {
		tan_relative := math.tan(angle)
		tan2 := tan_relative * tan_relative
		ab := radius_x * radius_y
		a2 := radius_x * radius_x
		b2 := radius_y * radius_y
		sqrt := math.sqrt(b2 + a2 * tan2)
		mut relative_x_position := ab / sqrt
		mut relative_y_position := ab * tan_relative / sqrt
		// -1 if 0 ≤ θ < 90° or 270° < θ ≤ 360°; 1 if 90° < θ < 270°.
		sn := if math.cos(angle) >= 0 { f64(1) } else { f64(-1) }
		relative_x_position *= sn
		relative_y_position *= sn
		// Rotate (back) around the center by 'rotation', then translate to the actual origin.
		relative_rotated_x_position := relative_x_position * cos_rotation - relative_y_position * sin_rotation
		relative_rotated_y_position := relative_x_position * sin_rotation +
			relative_y_position * cos_rotation
		return FloatPoint{relative_rotated_x_position + x, relative_rotated_y_position + y}
	}
	start_point := resolve_point_with_angle(start_angle)
	end_point := resolve_point_with_angle(end_angle)
	mut delta_theta := if counter_clockwise {
		start_angle - end_angle
	} else {
		end_angle - start_angle
	}
	if delta_theta < 0 {
		delta_theta += math.pi * 2
	}
	// 3. If the path has any subpaths, add a straight line to the arc's start point.
	if !c.path_.is_empty() {
		c.path_.line_to(start_point)
	} else {
		c.path_.move_to(start_point)
	}
	// 4. Add the arc from the start to the end point.
	c.path_.elliptical_arc_to(end_point, FloatSize{radius_x, radius_y}, rotation,
		delta_theta > math.pi, !counter_clockwise)
}

// https://html.spec.whatwg.org/multipage/canvas.html#dom-context-2d-arcto
pub fn (mut c CanvasPath) arc_to(x1 f64, y1 f64, x2 f64, y2 f64, radius f64) ! {
	// 1. If any argument is infinite or NaN, return.
	if !is_finite(x1) || !is_finite(y1) || !is_finite(x2) || !is_finite(y2) || !is_finite(radius) {
		return
	}
	// 2. Ensure there is a subpath for (x1, y1).
	c.ensure_subpath(x1, y1)
	// 3. If radius is negative, throw an "IndexSizeError".
	if radius < 0 {
		return error('The radius provided (${radius}) is negative.')
	}
	transform := c.active_transform()
	inverse := transform.inverse() or { CanvasAffineTransform{} }
	// 4. Let (x0, y0) be the last point, transformed by the inverse of the current transform.
	p0 := inverse.map(c.path_.last_point())
	p1 := FloatPoint{x1, y1}
	p2 := FloatPoint{x2, y2}
	// 5. If p0 == p1, or p1 == p2, or radius is zero: add a straight line to p1.
	if p0 == p1 || p1 == p2 || radius == 0 {
		c.path_.line_to(p1)
		return
	}
	v1x := p0.x - p1.x
	v1y := p0.y - p1.y
	v2x := p2.x - p1.x
	v2y := p2.y - p1.y
	v1_length := math.sqrt(v1x * v1x + v1y * v1y)
	v2_length := math.sqrt(v2x * v2x + v2y * v2y)
	cos_theta := (v1x * v2x + v1y * v2y) / (v1_length * v2_length)
	// 6. If the three points are collinear, add a straight line to p1.
	if cos_theta == -1 || cos_theta == 1 {
		c.path_.line_to(p1)
		return
	}
	// 7. Otherwise, compute the two tangent points and connect them with the arc.
	adjacent := radius / math.tan(math.acos(cos_theta) / 2)
	factor1 := adjacent / v1_length
	start_tangent := FloatPoint{p1.x + factor1 * (p0.x - p1.x), p1.y + factor1 * (p0.y - p1.y)}
	factor2 := adjacent / v2_length
	end_tangent := FloatPoint{p1.x + factor2 * (p2.x - p1.x), p1.y + factor2 * (p2.y - p1.y)}
	c.path_.line_to(start_tangent)
	large_arc := false
	cross_product := v1x * v2y - v1y * v2x
	sweep := cross_product < 0
	c.path_.arc_to(end_tangent, radius, large_arc, sweep)
}

// https://html.spec.whatwg.org/multipage/canvas.html#dom-context-2d-rect
pub fn (mut c CanvasPath) rect(x f64, y f64, w f64, h f64) {
	// 1. If any argument is infinite or NaN, return.
	if !is_finite(x) || !is_finite(y) || !is_finite(w) || !is_finite(h) {
		return
	}
	// 2. Create a subpath of the four corners, connected by straight lines.
	c.path_.move_to(FloatPoint{x, y})
	c.path_.line_to(FloatPoint{x + w, y})
	c.path_.line_to(FloatPoint{x + w, y + h})
	c.path_.line_to(FloatPoint{x, y + h})
	// 3. Mark the subpath as closed.
	c.path_.close()
	// 4. Create a new subpath with (x, y) as the only point.
	c.path_.move_to(FloatPoint{x, y})
}

// A normalized corner radius (Geometry::DOMPointInit). The IDL union coercion (a bare double
// expands to «radius, radius», a single value to a one-item list) is a binding-layer concern;
// this takes the already-normalized list.
pub struct RoundRectRadius {
pub:
	x f64
	y f64
}

// https://html.spec.whatwg.org/multipage/canvas.html#dom-context-2d-roundrect
pub fn (mut c CanvasPath) round_rect(x f64, y f64, w f64, h f64, radii []RoundRectRadius) ! {
	// 1. If any of x, y, w, or h are infinite or NaN, return.
	if !is_finite(x) || !is_finite(y) || !is_finite(w) || !is_finite(h) {
		return
	}
	// 3. radii must be a list of size one, two, three, or four.
	if radii.len == 0 || radii.len > 4 {
		return error('roundRect: Can have between 1 and 4 radii')
	}
	// 4-5. Normalize the radii, validating each.
	mut normalized_radii := []RoundRectRadius{}
	for radius in radii {
		// 5.x.1. If x or y is infinite or NaN, return.
		if !is_finite(radius.x) || !is_finite(radius.y) {
			return
		}
		// 5.x.2. If x or y is negative, throw a RangeError.
		if radius.x < 0 || radius.y < 0 {
			return error("roundRect: Radius can't be negative")
		}
		normalized_radii << radius
	}
	// 6-10. Assign the four corner radii from the normalized list by its size.
	mut upper_left := RoundRectRadius{}
	mut upper_right := RoundRectRadius{}
	mut lower_right := RoundRectRadius{}
	mut lower_left := RoundRectRadius{}
	match normalized_radii.len {
		4 {
			upper_left = normalized_radii[0]
			upper_right = normalized_radii[1]
			lower_right = normalized_radii[2]
			lower_left = normalized_radii[3]
		}
		3 {
			upper_left = normalized_radii[0]
			upper_right = normalized_radii[1]
			lower_left = normalized_radii[1]
			lower_right = normalized_radii[2]
		}
		2 {
			upper_left = normalized_radii[0]
			lower_right = normalized_radii[0]
			upper_right = normalized_radii[1]
			lower_left = normalized_radii[1]
		}
		else {
			upper_left = normalized_radii[0]
			upper_right = normalized_radii[0]
			lower_right = normalized_radii[0]
			lower_left = normalized_radii[0]
		}
	}
	// 11. Scale all radii so the corner curves do not overlap.
	top := upper_left.x + upper_right.x
	right := upper_right.y + lower_right.y
	bottom := lower_right.x + lower_left.x
	left := upper_left.y + lower_left.y
	scale := math.min(math.min(w / top, h / right), math.min(w / bottom, h / left))
	if scale < 1 {
		upper_left = RoundRectRadius{upper_left.x * scale, upper_left.y * scale}
		upper_right = RoundRectRadius{upper_right.x * scale, upper_right.y * scale}
		lower_left = RoundRectRadius{lower_left.x * scale, lower_left.y * scale}
		lower_right = RoundRectRadius{lower_right.x * scale, lower_right.y * scale}
	}
	// 12. Build the rounded-rectangle subpath.
	large_arc := false
	sweep := true
	c.path_.move_to(FloatPoint{x + upper_left.x, y})
	c.path_.line_to(FloatPoint{x + w - upper_right.x, y})
	c.path_.elliptical_arc_to(FloatPoint{x + w, y + upper_right.y}, FloatSize{upper_right.x, upper_right.y},
		0, large_arc, sweep)
	c.path_.line_to(FloatPoint{x + w, y + h - lower_right.y})
	c.path_.elliptical_arc_to(FloatPoint{x + w - lower_right.x, y + h}, FloatSize{lower_right.x, lower_right.y},
		0, large_arc, sweep)
	c.path_.line_to(FloatPoint{x + lower_left.x, y + h})
	c.path_.elliptical_arc_to(FloatPoint{x, y + h - lower_left.y}, FloatSize{lower_left.x, lower_left.y},
		0, large_arc, sweep)
	c.path_.line_to(FloatPoint{x, y + upper_left.y})
	c.path_.elliptical_arc_to(FloatPoint{x + upper_left.x, y}, FloatSize{upper_left.x, upper_left.y},
		0, large_arc, sweep)
	// 13. Mark the subpath as closed.
	c.path_.close()
	// 14. Create a new subpath with (x, y) as the only point.
	c.path_.move_to(FloatPoint{x, y})
}
