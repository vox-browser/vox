// Copyright (c) 2024-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Typed equivalents of Geometry's HTML structured-serialization records.
// LibJS object graphs and transfer streams remain the platform boundary; the
// complete Geometry-owned state and restoration algorithms live here.
module geometry

pub struct SerializedDOMPoint {
pub:
	x f64
	y f64
	z f64
	w f64
}

pub fn (point &DOMPointReadOnly) serialization_steps() SerializedDOMPoint {
	return SerializedDOMPoint{
		x: point.x_
		y: point.y_
		z: point.z_
		w: point.w_
	}
}

pub fn DOMPointReadOnly.deserialize(record SerializedDOMPoint) &DOMPointReadOnly {
	return DOMPointReadOnly.construct(record.x, record.y, record.z, record.w)
}

pub fn DOMPoint.deserialize(record SerializedDOMPoint) &DOMPoint {
	return DOMPoint.construct(record.x, record.y, record.z, record.w)
}

pub struct DOMPointJSON {
pub:
	x f64
	y f64
	z f64
	w f64
}

pub fn (point &DOMPointReadOnly) to_json() DOMPointJSON {
	return DOMPointJSON{
		x: point.x_
		y: point.y_
		z: point.z_
		w: point.w_
	}
}

pub struct SerializedDOMRect {
pub:
	x      f64
	y      f64
	width  f64
	height f64
}

pub fn (rect &DOMRectReadOnly) serialization_steps() SerializedDOMRect {
	return SerializedDOMRect{
		x:      rect.x_
		y:      rect.y_
		width:  rect.width_
		height: rect.height_
	}
}

pub fn DOMRectReadOnly.deserialize(record SerializedDOMRect) &DOMRectReadOnly {
	return DOMRectReadOnly.construct(record.x, record.y, record.width, record.height)
}

pub fn DOMRect.deserialize(record SerializedDOMRect) &DOMRect {
	return DOMRect.construct(record.x, record.y, record.width, record.height)
}

pub struct DOMRectJSON {
pub:
	x      f64
	y      f64
	width  f64
	height f64
	top    f64
	right  f64
	bottom f64
	left   f64
}

pub fn (rect &DOMRectReadOnly) to_json() DOMRectJSON {
	return DOMRectJSON{
		x:      rect.x_
		y:      rect.y_
		width:  rect.width_
		height: rect.height_
		top:    rect.top()
		right:  rect.right()
		bottom: rect.bottom()
		left:   rect.left()
	}
}

pub struct SerializedDOMMatrix {
pub:
	is_2d    bool
	elements []f64
}

pub fn (matrix &DOMMatrixReadOnly) serialization_steps() SerializedDOMMatrix {
	if matrix.is_2d_ {
		return SerializedDOMMatrix{
			is_2d:    true
			elements: [matrix.m11_, matrix.m12_, matrix.m21_, matrix.m22_, matrix.m41_, matrix.m42_]
		}
	}
	return SerializedDOMMatrix{
		is_2d:    false
		elements: matrix.to_float64_array()
	}
}

pub fn DOMMatrixReadOnly.deserialize(record SerializedDOMMatrix) !&DOMMatrixReadOnly {
	if record.is_2d && record.elements.len != 6 {
		return error('DataCloneError: a serialized 2D DOMMatrix must contain 6 elements')
	}
	if !record.is_2d && record.elements.len != 16 {
		return error('DataCloneError: a serialized 3D DOMMatrix must contain 16 elements')
	}
	return DOMMatrixReadOnly.construct(record.elements)
}

pub fn DOMMatrix.deserialize(record SerializedDOMMatrix) !&DOMMatrix {
	read_only := DOMMatrixReadOnly.deserialize(record)!
	return DOMMatrix.create_from_dom_matrix_read_only(read_only)
}

pub struct DOMMatrixJSON {
pub:
	a           f64
	b           f64
	c           f64
	d           f64
	e           f64
	f           f64
	m11         f64
	m12         f64
	m13         f64
	m14         f64
	m21         f64
	m22         f64
	m23         f64
	m24         f64
	m31         f64
	m32         f64
	m33         f64
	m34         f64
	m41         f64
	m42         f64
	m43         f64
	m44         f64
	is_2d       bool
	is_identity bool
}

pub fn (matrix &DOMMatrixReadOnly) to_json() DOMMatrixJSON {
	return DOMMatrixJSON{
		a:           matrix.a()
		b:           matrix.b()
		c:           matrix.c()
		d:           matrix.d()
		e:           matrix.e()
		f:           matrix.f()
		m11:         matrix.m11()
		m12:         matrix.m12()
		m13:         matrix.m13()
		m14:         matrix.m14()
		m21:         matrix.m21()
		m22:         matrix.m22()
		m23:         matrix.m23()
		m24:         matrix.m24()
		m31:         matrix.m31()
		m32:         matrix.m32()
		m33:         matrix.m33()
		m34:         matrix.m34()
		m41:         matrix.m41()
		m42:         matrix.m42()
		m43:         matrix.m43()
		m44:         matrix.m44()
		is_2d:       matrix.is_2d()
		is_identity: matrix.is_identity()
	}
}

pub struct SerializedDOMQuad {
pub:
	p1 SerializedDOMPoint
	p2 SerializedDOMPoint
	p3 SerializedDOMPoint
	p4 SerializedDOMPoint
}

pub fn (quad &DOMQuad) serialization_steps() SerializedDOMQuad {
	return SerializedDOMQuad{
		p1: quad.p1_.serialization_steps()
		p2: quad.p2_.serialization_steps()
		p3: quad.p3_.serialization_steps()
		p4: quad.p4_.serialization_steps()
	}
}

pub fn DOMQuad.deserialize(record SerializedDOMQuad) &DOMQuad {
	return DOMQuad.construct(DOMPointInit{
		x: record.p1.x
		y: record.p1.y
		z: record.p1.z
		w: record.p1.w
	}, DOMPointInit{
		x: record.p2.x
		y: record.p2.y
		z: record.p2.z
		w: record.p2.w
	}, DOMPointInit{
		x: record.p3.x
		y: record.p3.y
		z: record.p3.z
		w: record.p3.w
	}, DOMPointInit{
		x: record.p4.x
		y: record.p4.y
		z: record.p4.z
		w: record.p4.w
	})
}

pub struct DOMQuadJSON {
pub:
	p1 DOMPointJSON
	p2 DOMPointJSON
	p3 DOMPointJSON
	p4 DOMPointJSON
}

pub fn (quad &DOMQuad) to_json() DOMQuadJSON {
	return DOMQuadJSON{
		p1: quad.p1_.to_json()
		p2: quad.p2_.to_json()
		p3: quad.p3_.to_json()
		p4: quad.p4_.to_json()
	}
}
