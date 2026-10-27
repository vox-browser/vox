// Copyright (c) 2023, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the self-contained core of Libraries/LibWeb/Geometry/DOMQuad.cpp — a quadrilateral of
// four DOMPoints (p1..p4), with fromRect (a rectangle's corners), fromQuad, and getBounds (the
// axis-aligned bounding DOMRect). getBounds uses the NaN-safe minimum/maximum: NaN if any coordinate is
// NaN, otherwise the min/max. Typed structured-clone records are in serialization.v.
// https://drafts.fxtf.org/geometry/#domquad
module geometry

import math

// https://drafts.fxtf.org/geometry/#dictdef-domquadinit
pub struct DOMQuadInit {
pub mut:
	p1 DOMPointInit
	p2 DOMPointInit
	p3 DOMPointInit
	p4 DOMPointInit
}

// https://drafts.fxtf.org/geometry/#domquad
@[heap]
pub struct DOMQuad {
mut:
	p1_ &DOMPoint
	p2_ &DOMPoint
	p3_ &DOMPoint
	p4_ &DOMPoint
}

pub fn point_from_init(point DOMPointInit) &DOMPoint {
	return DOMPoint.construct(point.x, point.y, point.z, point.w)
}

pub fn point_from_coordinates(x f64, y f64) &DOMPoint {
	return DOMPoint.construct(x, y, 0, 1)
}

// The DOMQuad(p1, p2, p3, p4) constructor: each DOMPointInit becomes a DOMPoint.
pub fn DOMQuad.construct(p1 DOMPointInit, p2 DOMPointInit, p3 DOMPointInit, p4 DOMPointInit) &DOMQuad {
	return &DOMQuad{
		p1_: point_from_init(p1)
		p2_: point_from_init(p2)
		p3_: point_from_init(p3)
		p4_: point_from_init(p4)
	}
}

pub fn DOMQuad.construct_impl(p1 DOMPointInit, p2 DOMPointInit, p3 DOMPointInit, p4 DOMPointInit) &DOMQuad {
	return DOMQuad.construct(p1, p2, p3, p4)
}

// DOMQuad::create(realm) — the empty quad (four default-initialized points).
pub fn DOMQuad.create() &DOMQuad {
	return &DOMQuad{
		p1_: DOMPoint.create()
		p2_: DOMPoint.create()
		p3_: DOMPoint.create()
		p4_: DOMPoint.create()
	}
}

// https://drafts.fxtf.org/geometry/#dom-domquad-fromrect — a DOMQuad from a rectangle's four corners.
pub fn DOMQuad.from_rect(other DOMRectInit) &DOMQuad {
	return DOMQuad.dom_quad_from_rect(other)
}

pub fn DOMQuad.dom_quad_from_rect(other DOMRectInit) &DOMQuad {
	return &DOMQuad{
		p1_: point_from_coordinates(other.x, other.y)
		p2_: point_from_coordinates(other.x + other.width, other.y)
		p3_: point_from_coordinates(other.x + other.width, other.y + other.height)
		p4_: point_from_coordinates(other.x, other.y + other.height)
	}
}

// https://drafts.fxtf.org/geometry/#dom-domquad-fromquad
pub fn DOMQuad.from_quad(other DOMQuadInit) &DOMQuad {
	return DOMQuad.dom_quad_from_quad(other)
}

pub fn DOMQuad.dom_quad_from_quad(other DOMQuadInit) &DOMQuad {
	return DOMQuad.construct(other.p1, other.p2, other.p3, other.p4)
}

pub fn DOMQuad.p1_offset() uint {
	return uint(__offsetof(DOMQuad, p1_))
}

pub fn DOMQuad.p2_offset() uint {
	return uint(__offsetof(DOMQuad, p2_))
}

pub fn DOMQuad.p3_offset() uint {
	return uint(__offsetof(DOMQuad, p3_))
}

pub fn DOMQuad.p4_offset() uint {
	return uint(__offsetof(DOMQuad, p4_))
}

pub fn (quad &DOMQuad) p1() &DOMPoint {
	return quad.p1_
}

pub fn (quad &DOMQuad) p2() &DOMPoint {
	return quad.p2_
}

pub fn (quad &DOMQuad) p3() &DOMPoint {
	return quad.p3_
}

pub fn (quad &DOMQuad) p4() &DOMPoint {
	return quad.p4_
}

// https://drafts.fxtf.org/geometry/#dom-domquad-getbounds
pub fn (quad &DOMQuad) get_bounds() &DOMRect {
	// 2-3. left/top are the NaN-safe minima of the four x/y coordinates.
	left := nan_safe_minimum(quad.p1_.x(), quad.p2_.x(), quad.p3_.x(), quad.p4_.x())
	top := nan_safe_minimum(quad.p1_.y(), quad.p2_.y(), quad.p3_.y(), quad.p4_.y())
	// 4-5. right/bottom are the NaN-safe maxima.
	right := nan_safe_maximum(quad.p1_.x(), quad.p2_.x(), quad.p3_.x(), quad.p4_.x())
	bottom := nan_safe_maximum(quad.p1_.y(), quad.p2_.y(), quad.p3_.y(), quad.p4_.y())
	// 1,6,7. Return a DOMRect at (left, top) with dimensions right - left and bottom - top.
	return DOMRect.construct(left, top, right - left, bottom - top)
}

// The NaN-safe minimum: NaN if any member is NaN, otherwise the minimum of the four values.
fn nan_safe_minimum(a f64, b f64, c f64, d f64) f64 {
	if math.is_nan(a) || math.is_nan(b) || math.is_nan(c) || math.is_nan(d) {
		return math.nan()
	}
	mut m := a
	if b < m {
		m = b
	}
	if c < m {
		m = c
	}
	if d < m {
		m = d
	}
	return m
}

// The NaN-safe maximum: NaN if any member is NaN, otherwise the maximum of the four values.
fn nan_safe_maximum(a f64, b f64, c f64, d f64) f64 {
	if math.is_nan(a) || math.is_nan(b) || math.is_nan(c) || math.is_nan(d) {
		return math.nan()
	}
	mut m := a
	if b > m {
		m = b
	}
	if c > m {
		m = c
	}
	if d > m {
		m = d
	}
	return m
}
