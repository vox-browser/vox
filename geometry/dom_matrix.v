// Copyright (c) 2023-2024, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the construction and inspection core of Libraries/LibWeb/Geometry/DOMMatrixReadOnly.cpp
// — the DOMMatrix2DInit/DOMMatrixInit dictionaries, their validate-and-fixup algorithms, the 2D/3D and
// number-sequence constructors, the m11..m44 / a..f accessors, is2D and isIdentity.
//
// transformPoint is also implemented here (it only needs a matrix-times-vector product, not the full
// 4x4 machinery), which in turn backs DOMPointReadOnly.matrix_transform in dom_point.v.
//
// The mutable DOMMatrix subclass and the post-multiply transforms (multiply/translate/flip/scale/skew/
// rotate) live in dom_matrix_transform.v; the inverse is in dom_matrix_invert.v. STILL OUT OF SCOPE:
// String construction/stringification and structured serialization live in
// dom_matrix_string.v and serialization.v.
//
// The 4x4 elements are stored directly in the spec's column-major m<column><row> naming; since no
// matrix arithmetic happens here, the storage layout is just the 16 named components.
// https://drafts.fxtf.org/geometry/#dommatrixreadonly
module geometry

import math

pub type DOMMatrixConstructorInit = []f64 | string

pub enum DOMMatrixStringContext {
	window
	worker
}

pub fn dom_matrix_string_context(is_window bool) DOMMatrixStringContext {
	return if is_window { .window } else { .worker }
}

// https://drafts.fxtf.org/geometry/#dictdef-dommatrix2dinit — every member is optional.
pub struct DOMMatrix2DInit {
pub mut:
	a   ?f64
	b   ?f64
	c   ?f64
	d   ?f64
	e   ?f64
	f   ?f64
	m11 ?f64
	m12 ?f64
	m21 ?f64
	m22 ?f64
	m41 ?f64
	m42 ?f64
}

// https://drafts.fxtf.org/geometry/#dictdef-dommatrixinit — the 3D members default to the identity
// (m33 = m44 = 1, the rest 0); is2D is optional.
pub struct DOMMatrixInit {
	DOMMatrix2DInit
pub mut:
	m13  f64
	m14  f64
	m23  f64
	m24  f64
	m31  f64
	m32  f64
	m33  f64 = 1
	m34  f64
	m43  f64
	m44  f64 = 1
	is2d ?bool
}

// https://drafts.fxtf.org/geometry/#dommatrixreadonly
@[heap]
pub struct DOMMatrixReadOnly {
mut:
	m11_   f64
	m12_   f64
	m13_   f64
	m14_   f64
	m21_   f64
	m22_   f64
	m23_   f64
	m24_   f64
	m31_   f64
	m32_   f64
	m33_   f64
	m34_   f64
	m41_   f64
	m42_   f64
	m43_   f64
	m44_   f64
	is_2d_ bool
}

// https://drafts.fxtf.org/geometry/#create-a-2d-matrix — the six given components with the remaining
// elements set to the identity (m33 = m44 = 1, the rest 0); is2D is true.
fn DOMMatrixReadOnly.create_2d(m11 f64, m12 f64, m21 f64, m22 f64, m41 f64, m42 f64) &DOMMatrixReadOnly {
	mut matrix := &DOMMatrixReadOnly{}
	matrix.initialize_from_create_2d_matrix(m11, m12, m21, m22, m41, m42)
	return matrix
}

// https://drafts.fxtf.org/geometry/#create-a-3d-matrix — all sixteen components; is2D is false.
fn DOMMatrixReadOnly.create_3d(m11 f64, m12 f64, m13 f64, m14 f64, m21 f64, m22 f64, m23 f64, m24 f64, m31 f64, m32 f64, m33 f64, m34 f64, m41 f64, m42 f64, m43 f64, m44 f64) &DOMMatrixReadOnly {
	mut matrix := &DOMMatrixReadOnly{}
	matrix.initialize_from_create_3d_matrix(m11, m12, m13, m14, m21, m22, m23, m24, m31, m32, m33, m34, m41, m42, m43, m44)
	return matrix
}

pub fn (mut matrix DOMMatrixReadOnly) initialize_from_create_2d_matrix(m11 f64, m12 f64, m21 f64, m22 f64, m41 f64, m42 f64) {
	matrix.m11_ = m11
	matrix.m12_ = m12
	matrix.m13_ = 0
	matrix.m14_ = 0
	matrix.m21_ = m21
	matrix.m22_ = m22
	matrix.m23_ = 0
	matrix.m24_ = 0
	matrix.m31_ = 0
	matrix.m32_ = 0
	matrix.m33_ = 1
	matrix.m34_ = 0
	matrix.m41_ = m41
	matrix.m42_ = m42
	matrix.m43_ = 0
	matrix.m44_ = 1
	matrix.is_2d_ = true
}

pub fn (mut matrix DOMMatrixReadOnly) initialize_from_create_3d_matrix(m11 f64, m12 f64, m13 f64, m14 f64, m21 f64, m22 f64, m23 f64, m24 f64, m31 f64, m32 f64, m33 f64, m34 f64, m41 f64, m42 f64, m43 f64, m44 f64) {
	matrix.m11_ = m11
	matrix.m12_ = m12
	matrix.m13_ = m13
	matrix.m14_ = m14
	matrix.m21_ = m21
	matrix.m22_ = m22
	matrix.m23_ = m23
	matrix.m24_ = m24
	matrix.m31_ = m31
	matrix.m32_ = m32
	matrix.m33_ = m33
	matrix.m34_ = m34
	matrix.m41_ = m41
	matrix.m42_ = m42
	matrix.m43_ = m43
	matrix.m44_ = m44
	matrix.is_2d_ = false
}

// DOMMatrixReadOnly::create(realm) — the 2D identity matrix.
pub fn DOMMatrixReadOnly.create() &DOMMatrixReadOnly {
	return DOMMatrixReadOnly.create_2d(1, 0, 0, 1, 0, 0)
}

// https://drafts.fxtf.org/geometry/#dommatrixreadonly-dommatrixreadonly — the numeric constructor:
// omitted init is the 2D identity, a 6-element sequence is a 2D matrix, a 16-element sequence is a 3D
// matrix, and any other length is an error. The DOMString (CSS transform-list) variant is out of scope.
pub fn DOMMatrixReadOnly.construct(init ?[]f64) !&DOMMatrixReadOnly {
	numbers := init or { return DOMMatrixReadOnly.create() }
	if numbers.len == 6 {
		return DOMMatrixReadOnly.create_2d(numbers[0], numbers[1], numbers[2], numbers[3], numbers[4], numbers[5])
	}
	if numbers.len == 16 {
		return DOMMatrixReadOnly.create_3d(numbers[0], numbers[1], numbers[2], numbers[3], numbers[4], numbers[5], numbers[6], numbers[7], numbers[8], numbers[9], numbers[10], numbers[11], numbers[12], numbers[13], numbers[14], numbers[15])
	}
	return error('Sequence must contain exactly 6 or 16 elements, got ${numbers.len} element(s)')
}

pub fn DOMMatrixReadOnly.construct_impl(init ?DOMMatrixConstructorInit, is_window bool) !&DOMMatrixReadOnly {
	return DOMMatrixReadOnly.create_for_constructor(is_window, init)
}

pub fn DOMMatrixReadOnly.create_from_constructor(init ?DOMMatrixConstructorInit, string_context DOMMatrixStringContext) !&DOMMatrixReadOnly {
	value := init or { return DOMMatrixReadOnly.create() }
	return match value {
		[]f64 { DOMMatrixReadOnly.construct(value)! }
		string { DOMMatrixReadOnly.construct_from_string(value, string_context == .window)! }
	}
}

pub fn DOMMatrixReadOnly.create_for_constructor(is_window bool, init ?DOMMatrixConstructorInit) !&DOMMatrixReadOnly {
	return DOMMatrixReadOnly.create_from_constructor(init, dom_matrix_string_context(is_window))
}

// https://drafts.fxtf.org/geometry/#create-a-dommatrixreadonly-from-the-2d-dictionary
pub fn DOMMatrixReadOnly.create_from_dom_matrix_2d_init(mut init DOMMatrix2DInit) !&DOMMatrixReadOnly {
	validate_and_fixup_dom_matrix_2d_init(mut init)!
	// After validation the six 2D members all have values.
	return DOMMatrixReadOnly.create_2d(init.m11 or { 0 }, init.m12 or { 0 }, init.m21 or { 0 }, init.m22 or {
		0
	}, init.m41 or { 0 }, init.m42 or { 0 })
}

// https://drafts.fxtf.org/geometry/#create-a-dommatrixreadonly-from-the-dictionary
pub fn DOMMatrixReadOnly.create_from_dom_matrix_init(mut init DOMMatrixInit) !&DOMMatrixReadOnly {
	validate_and_fixup_dom_matrix_init(mut init)!
	if is2d := init.is2d {
		if is2d {
			return DOMMatrixReadOnly.create_2d(init.m11 or { 0 }, init.m12 or { 0 }, init.m21 or {
				0
			}, init.m22 or { 0 }, init.m41 or { 0 }, init.m42 or { 0 })
		}
	}
	return DOMMatrixReadOnly.create_3d(init.m11 or { 0 }, init.m12 or { 0 }, init.m13, init.m14, init.m21 or {
		0
	}, init.m22 or { 0 }, init.m23, init.m24, init.m31, init.m32, init.m33, init.m34, init.m41 or {
		0
	}, init.m42 or { 0 }, init.m43, init.m44)
}

// https://drafts.fxtf.org/geometry/#dom-dommatrixreadonly-frommatrix
pub fn DOMMatrixReadOnly.from_matrix(mut other DOMMatrixInit) !&DOMMatrixReadOnly {
	return DOMMatrixReadOnly.create_from_dom_matrix_init(mut other)
}

// --- Component accessors (https://drafts.fxtf.org/geometry/#dommatrix-attributes) ---

pub fn (matrix &DOMMatrixReadOnly) m11() f64 {
	return matrix.m11_
}

pub fn (matrix &DOMMatrixReadOnly) m12() f64 {
	return matrix.m12_
}

pub fn (matrix &DOMMatrixReadOnly) m13() f64 {
	return matrix.m13_
}

pub fn (matrix &DOMMatrixReadOnly) m14() f64 {
	return matrix.m14_
}

pub fn (matrix &DOMMatrixReadOnly) m21() f64 {
	return matrix.m21_
}

pub fn (matrix &DOMMatrixReadOnly) m22() f64 {
	return matrix.m22_
}

pub fn (matrix &DOMMatrixReadOnly) m23() f64 {
	return matrix.m23_
}

pub fn (matrix &DOMMatrixReadOnly) m24() f64 {
	return matrix.m24_
}

pub fn (matrix &DOMMatrixReadOnly) m31() f64 {
	return matrix.m31_
}

pub fn (matrix &DOMMatrixReadOnly) m32() f64 {
	return matrix.m32_
}

pub fn (matrix &DOMMatrixReadOnly) m33() f64 {
	return matrix.m33_
}

pub fn (matrix &DOMMatrixReadOnly) m34() f64 {
	return matrix.m34_
}

pub fn (matrix &DOMMatrixReadOnly) m41() f64 {
	return matrix.m41_
}

pub fn (matrix &DOMMatrixReadOnly) m42() f64 {
	return matrix.m42_
}

pub fn (matrix &DOMMatrixReadOnly) m43() f64 {
	return matrix.m43_
}

pub fn (matrix &DOMMatrixReadOnly) m44() f64 {
	return matrix.m44_
}

// The 2D aliases: a/b/c/d/e/f map to m11/m12/m21/m22/m41/m42.
pub fn (matrix &DOMMatrixReadOnly) a() f64 {
	return matrix.m11_
}

pub fn (matrix &DOMMatrixReadOnly) b() f64 {
	return matrix.m12_
}

pub fn (matrix &DOMMatrixReadOnly) c() f64 {
	return matrix.m21_
}

pub fn (matrix &DOMMatrixReadOnly) d() f64 {
	return matrix.m22_
}

pub fn (matrix &DOMMatrixReadOnly) e() f64 {
	return matrix.m41_
}

pub fn (matrix &DOMMatrixReadOnly) f() f64 {
	return matrix.m42_
}

pub fn (matrix &DOMMatrixReadOnly) is_2d() bool {
	return matrix.is_2d_
}

pub fn (matrix &DOMMatrixReadOnly) is2d() bool {
	return matrix.is_2d()
}

// https://drafts.fxtf.org/geometry/#dom-dommatrixreadonly-isidentity — every off-diagonal element is
// 0 (±0) and every diagonal element is 1.
// NOTE: upstream DOMMatrixReadOnly::is_identity has a copy-paste typo pairing m23&&m24, m31&&m32 and
// m41&&m42 (masked because `x != -0.0` is equivalent to `x != 0.0`); this follows the spec and checks
// every off-diagonal element independently.
pub fn (matrix &DOMMatrixReadOnly) is_identity() bool {
	if matrix.m12_ != 0.0 || matrix.m13_ != 0.0 || matrix.m14_ != 0.0 {
		return false
	}
	if matrix.m21_ != 0.0 || matrix.m23_ != 0.0 || matrix.m24_ != 0.0 {
		return false
	}
	if matrix.m31_ != 0.0 || matrix.m32_ != 0.0 || matrix.m34_ != 0.0 {
		return false
	}
	if matrix.m41_ != 0.0 || matrix.m42_ != 0.0 || matrix.m43_ != 0.0 {
		return false
	}
	return matrix.m11_ == 1.0 && matrix.m22_ == 1.0 && matrix.m33_ == 1.0 && matrix.m44_ == 1.0
}

// https://drafts.fxtf.org/geometry/#dom-dommatrixreadonly-tofloat32array — the 16 elements m11..m44 in
// column-major order. The JS Float32Array/ArrayBuffer wrapping is binding-layer; the raw f32 sequence
// is returned here.
pub fn (matrix &DOMMatrixReadOnly) to_float32_array() []f32 {
	return [f32(matrix.m11_), f32(matrix.m12_), f32(matrix.m13_), f32(matrix.m14_), f32(matrix.m21_),
		f32(matrix.m22_), f32(matrix.m23_), f32(matrix.m24_), f32(matrix.m31_), f32(matrix.m32_),
		f32(matrix.m33_), f32(matrix.m34_), f32(matrix.m41_), f32(matrix.m42_), f32(matrix.m43_),
		f32(matrix.m44_)]
}

// https://drafts.fxtf.org/geometry/#dom-dommatrixreadonly-tofloat64array — the 16 elements m11..m44 in
// column-major order as a raw f64 sequence.
pub fn (matrix &DOMMatrixReadOnly) to_float64_array() []f64 {
	return [matrix.m11_, matrix.m12_, matrix.m13_, matrix.m14_, matrix.m21_, matrix.m22_,
		matrix.m23_, matrix.m24_, matrix.m31_, matrix.m32_, matrix.m33_, matrix.m34_, matrix.m41_,
		matrix.m42_, matrix.m43_, matrix.m44_]
}

// --- transform a point (https://drafts.fxtf.org/geometry/#transform-a-point-with-a-matrix) ---

// Multiply the matrix by the column vector (x, y, z, w) and return the resulting DOMPoint. With the
// spec's column-major storage this is result[row] = sum over columns of m<column><row> * vector.
fn (matrix &DOMMatrixReadOnly) transform_coordinates(x f64, y f64, z f64, w f64) &DOMPoint {
	return DOMPoint.construct(matrix.m11_ * x + matrix.m21_ * y + matrix.m31_ * z + matrix.m41_ * w, matrix.m12_ * x + matrix.m22_ * y + matrix.m32_ * z + matrix.m42_ * w, matrix.m13_ * x + matrix.m23_ * y + matrix.m33_ * z + matrix.m43_ * w, matrix.m14_ * x + matrix.m24_ * y + matrix.m34_ * z + matrix.m44_ * w)
}

// https://drafts.fxtf.org/geometry/#dom-dommatrixreadonly-transformpoint — transform an existing point.
// The passed point is not modified.
pub fn (matrix &DOMMatrixReadOnly) transform_point(point &DOMPointReadOnly) &DOMPoint {
	return matrix.transform_coordinates(point.x(), point.y(), point.z(), point.w())
}

// The transformPoint(DOMPointInit) overload: create a point from the dictionary, then transform it.
// Reading the init's members directly is equivalent (DOMPoint.from_point just copies them).
pub fn (matrix &DOMMatrixReadOnly) transform_point_from_init(point DOMPointInit) &DOMPoint {
	return matrix.transform_coordinates(point.x, point.y, point.z, point.w)
}

// --- validate and fixup (https://drafts.fxtf.org/geometry/#validate-and-fixup-2d) ---

// SameValueZero for doubles: equal (with +0 and -0 treated as equal), or both NaN.
fn same_value_zero(a f64, b f64) bool {
	if math.is_nan(a) && math.is_nan(b) {
		return true
	}
	return a == b
}

// Two aliased 2D members must agree (SameValueZero) when both are present.
fn dom_matrix_2d_aliases_agree(first ?f64, second ?f64) bool {
	if a := first {
		if b := second {
			return same_value_zero(a, b)
		}
	}
	return true
}

// https://drafts.fxtf.org/geometry/#validate-and-fixup-2d
pub fn validate_and_fixup_dom_matrix_2d_init(mut init DOMMatrix2DInit) ! {
	// 1. Each aliased pair (a/m11, b/m12, c/m21, d/m22, e/m41, f/m42) must agree when both are present.
	if !dom_matrix_2d_aliases_agree(init.a, init.m11) {
		return error('DOMMatrix2DInit.a and DOMMatrix2DInit.m11 must have the same value if both are present')
	}
	if !dom_matrix_2d_aliases_agree(init.b, init.m12) {
		return error('DOMMatrix2DInit.b and DOMMatrix2DInit.m12 must have the same value if both are present')
	}
	if !dom_matrix_2d_aliases_agree(init.c, init.m21) {
		return error('DOMMatrix2DInit.c and DOMMatrix2DInit.m21 must have the same value if both are present')
	}
	if !dom_matrix_2d_aliases_agree(init.d, init.m22) {
		return error('DOMMatrix2DInit.d and DOMMatrix2DInit.m22 must have the same value if both are present')
	}
	if !dom_matrix_2d_aliases_agree(init.e, init.m41) {
		return error('DOMMatrix2DInit.e and DOMMatrix2DInit.m41 must have the same value if both are present')
	}
	if !dom_matrix_2d_aliases_agree(init.f, init.m42) {
		return error('DOMMatrix2DInit.f and DOMMatrix2DInit.m42 must have the same value if both are present')
	}
	// 2-7. Fill any absent m-member from its alias, or the identity default (1 on the diagonal, else 0).
	if init.m11 == none {
		init.m11 = init.a or { 1.0 }
	}
	if init.m12 == none {
		init.m12 = init.b or { 0.0 }
	}
	if init.m21 == none {
		init.m21 = init.c or { 0.0 }
	}
	if init.m22 == none {
		init.m22 = init.d or { 1.0 }
	}
	if init.m41 == none {
		init.m41 = init.e or { 0.0 }
	}
	if init.m42 == none {
		init.m42 = init.f or { 0.0 }
	}
}

// Whether the 3D-only members carry a non-identity value (any of m13/m14/m23/m24/m31/m32/m34/m43 is
// non-zero, or m33/m44 is not 1).
fn dom_matrix_init_has_3d_components(init DOMMatrixInit) bool {
	return init.m13 != 0.0 || init.m14 != 0.0 || init.m23 != 0.0 || init.m24 != 0.0
		|| init.m31 != 0.0 || init.m32 != 0.0 || init.m34 != 0.0 || init.m43 != 0.0
		|| init.m33 != 1.0 || init.m44 != 1.0
}

// https://drafts.fxtf.org/geometry/#validate-and-fixup
pub fn validate_and_fixup_dom_matrix_init(mut init DOMMatrixInit) ! {
	// 1. Validate and fixup the 2D members.
	validate_and_fixup_dom_matrix_2d_init(mut init.DOMMatrix2DInit)!
	has_3d := dom_matrix_init_has_3d_components(init)
	// 2. If is2D is present and true but 3D members are set, that is a contradiction.
	if is2d := init.is2d {
		if is2d && has_3d {
			return error('DOMMatrixInit.is2D is true, but the given matrix is not a 2D matrix')
		}
	} else if has_3d {
		// 3. If is2D is absent and 3D members are set, the matrix is 3D.
		init.is2d = false
	}
	// 4. If is2D is still absent, the matrix is 2D.
	if init.is2d == none {
		init.is2d = true
	}
}
