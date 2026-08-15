// Copyright (c) 2022-2024, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the self-contained core of Libraries/LibWeb/Geometry/DOMPointReadOnly.cpp and
// DOMPoint.cpp — a 4-D point (x, y, z, w) with a read-only base and a mutable subclass. matrixTransform()
// is implemented (via DOMMatrixReadOnly.transform_point); the (de)serialization steps need HTML
// StructuredSerialize (the JS runtime) and are out of scope. V has no default arguments, so the
// IDL coordinate defaults (x=0, y=0, z=0, w=1) live on the DOMPointInit dictionary used by fromPoint,
// and the constructors take explicit coordinates (as the port's other geometry records do).
// https://drafts.fxtf.org/geometry/#dompointreadonly
module geometry

// https://drafts.fxtf.org/geometry/#dictdef-dompointinit
pub struct DOMPointInit {
pub mut:
	x f64
	y f64
	z f64
	w f64 = 1
}

// https://drafts.fxtf.org/geometry/#dompointreadonly
@[heap]
pub struct DOMPointReadOnly {
mut:
	x_ f64
	y_ f64
	z_ f64
	w_ f64
}

// The DOMPointReadOnly(x, y, z, w) constructor.
pub fn DOMPointReadOnly.construct(x f64, y f64, z f64, w f64) &DOMPointReadOnly {
	return &DOMPointReadOnly{
		x_: x
		y_: y
		z_: z
		w_: w
	}
}

// DOMPointReadOnly::create(realm) — the empty point (used for deserialization); mirrors the empty C++
// constructor, whose coordinates default-initialize to 0.
pub fn DOMPointReadOnly.create() &DOMPointReadOnly {
	return &DOMPointReadOnly{}
}

// https://drafts.fxtf.org/geometry/#dom-dompointreadonly-frompoint
pub fn DOMPointReadOnly.from_point(other DOMPointInit) &DOMPointReadOnly {
	return DOMPointReadOnly.construct(other.x, other.y, other.z, other.w)
}

pub fn (point &DOMPointReadOnly) x() f64 {
	return point.x_
}

pub fn (point &DOMPointReadOnly) y() f64 {
	return point.y_
}

pub fn (point &DOMPointReadOnly) z() f64 {
	return point.z_
}

pub fn (point &DOMPointReadOnly) w() f64 {
	return point.w_
}

// https://drafts.fxtf.org/geometry/#dom-dompointreadonly-matrixtransform — create a matrix from the
// dictionary and return this point transformed by it. This point is not modified. (Inherited by
// DOMPoint via embedding.)
pub fn (point &DOMPointReadOnly) matrix_transform(mut matrix DOMMatrixInit) !&DOMPoint {
	matrix_object := DOMMatrixReadOnly.create_from_dom_matrix_init(mut matrix)!
	return matrix_object.transform_point(point)
}

// https://drafts.fxtf.org/geometry/#dompoint — DOMPoint : DOMPointReadOnly, adding writable coordinates.
@[heap]
pub struct DOMPoint {
	DOMPointReadOnly
}

// The DOMPoint(x, y, z, w) constructor.
pub fn DOMPoint.construct(x f64, y f64, z f64, w f64) &DOMPoint {
	return &DOMPoint{
		DOMPointReadOnly: DOMPointReadOnly{
			x_: x
			y_: y
			z_: z
			w_: w
		}
	}
}

// DOMPoint::create(realm) — the empty point.
pub fn DOMPoint.create() &DOMPoint {
	return &DOMPoint{}
}

// https://drafts.fxtf.org/geometry/#dom-dompoint-frompoint
pub fn DOMPoint.from_point(other DOMPointInit) &DOMPoint {
	return DOMPoint.construct(other.x, other.y, other.z, other.w)
}

pub fn (mut point DOMPoint) set_x(x f64) {
	point.x_ = x
}

pub fn (mut point DOMPoint) set_y(y f64) {
	point.y_ = y
}

pub fn (mut point DOMPoint) set_z(z f64) {
	point.z_ = z
}

pub fn (mut point DOMPoint) set_w(w f64) {
	point.w_ = w
}
