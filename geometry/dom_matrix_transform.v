// Copyright (c) 2023-2024, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// The mutable DOMMatrix subclass and the matrix-returning transforms of DOMMatrixReadOnly.cpp /
// DOMMatrix.cpp that only need a 4x4 matrix product: multiply/preMultiply, translate and flipX/flipY.
// Each read-only transform copies the matrix and post-multiplies a transform matrix onto the copy; the
// *_self methods mutate in place and return the matrix (for chaining).
//
// STILL DEFERRED (a follow-up turn): scale/scale3d/rotate*/skew*/invert (scale carries subtle is2D and
// transform-origin handling, rotate/skew need trig, invert needs a 4x4 inverse), toFloat32Array/
// toString, the DOMString (CSS transform-list) constructor, and the (de)serialization steps.
//
// The stored components are the spec's column-major m<column><row>; to_rows() exposes the matrix as the
// standard rows[row][col] (rows[r][c] = m<c+1><r+1>) so a point transforms as rows * vector and matrices
// compose with the ordinary row-by-column product.
// https://drafts.fxtf.org/geometry/#dommatrix
module geometry

// The matrix as standard rows[row][col], where rows[r][c] = m<c+1><r+1>.
fn (matrix &DOMMatrixReadOnly) to_rows() [4][4]f64 {
	return [
		[matrix.m11_, matrix.m21_, matrix.m31_, matrix.m41_]!,
		[matrix.m12_, matrix.m22_, matrix.m32_, matrix.m42_]!,
		[matrix.m13_, matrix.m23_, matrix.m33_, matrix.m43_]!,
		[matrix.m14_, matrix.m24_, matrix.m34_, matrix.m44_]!,
	]!
}

// The standard 4x4 matrix product a * b.
fn mat4_multiply(a [4][4]f64, b [4][4]f64) [4][4]f64 {
	mut result := [4][4]f64{}
	for i in 0 .. 4 {
		for j in 0 .. 4 {
			mut sum := 0.0
			for k in 0 .. 4 {
				sum += a[i][k] * b[k][j]
			}
			result[i][j] = sum
		}
	}
	return result
}

// The translation matrix for (x, y, z).
fn translation_rows(x f64, y f64, z f64) [4][4]f64 {
	return [
		[1.0, 0.0, 0.0, x]!,
		[0.0, 1.0, 0.0, y]!,
		[0.0, 0.0, 1.0, z]!,
		[0.0, 0.0, 0.0, 1.0]!,
	]!
}

// A diagonal matrix (used for the flips).
fn diagonal_rows(m11 f64, m22 f64, m33 f64, m44 f64) [4][4]f64 {
	return [
		[m11, 0.0, 0.0, 0.0]!,
		[0.0, m22, 0.0, 0.0]!,
		[0.0, 0.0, m33, 0.0]!,
		[0.0, 0.0, 0.0, m44]!,
	]!
}

// https://drafts.fxtf.org/geometry/#dommatrix — DOMMatrix : DOMMatrixReadOnly, with writable elements
// and in-place transforms.
@[heap]
pub struct DOMMatrix {
	DOMMatrixReadOnly
}

// DOMMatrix::create_from_dom_matrix_read_only — a mutable copy of a read-only matrix.
pub fn DOMMatrix.create_from_dom_matrix_read_only(other &DOMMatrixReadOnly) &DOMMatrix {
	return &DOMMatrix{
		DOMMatrixReadOnly: *other
	}
}

// DOMMatrix::create(realm) — the 2D identity matrix.
pub fn DOMMatrix.create() &DOMMatrix {
	return DOMMatrix.create_from_dom_matrix_read_only(DOMMatrixReadOnly.create())
}

// The numeric DOMMatrix constructor (see DOMMatrixReadOnly.construct).
pub fn DOMMatrix.construct(init ?[]f64) !&DOMMatrix {
	read_only := DOMMatrixReadOnly.construct(init)!
	return DOMMatrix.create_from_dom_matrix_read_only(read_only)
}

// https://drafts.fxtf.org/geometry/#create-a-dommatrix-from-the-dictionary
pub fn DOMMatrix.create_from_dom_matrix_init(mut init DOMMatrixInit) !&DOMMatrix {
	read_only := DOMMatrixReadOnly.create_from_dom_matrix_init(mut init)!
	return DOMMatrix.create_from_dom_matrix_read_only(read_only)
}

// https://drafts.fxtf.org/geometry/#dom-dommatrix-frommatrix
pub fn DOMMatrix.from_matrix(mut other DOMMatrixInit) !&DOMMatrix {
	return DOMMatrix.create_from_dom_matrix_init(mut other)
}

// Write the standard rows[row][col] back into the stored m<column><row> components.
fn (mut matrix DOMMatrix) apply_rows(rows [4][4]f64) {
	matrix.m11_ = rows[0][0]
	matrix.m21_ = rows[0][1]
	matrix.m31_ = rows[0][2]
	matrix.m41_ = rows[0][3]
	matrix.m12_ = rows[1][0]
	matrix.m22_ = rows[1][1]
	matrix.m32_ = rows[1][2]
	matrix.m42_ = rows[1][3]
	matrix.m13_ = rows[2][0]
	matrix.m23_ = rows[2][1]
	matrix.m33_ = rows[2][2]
	matrix.m43_ = rows[2][3]
	matrix.m14_ = rows[3][0]
	matrix.m24_ = rows[3][1]
	matrix.m34_ = rows[3][2]
	matrix.m44_ = rows[3][3]
}

// --- Element setters (https://drafts.fxtf.org/geometry/#dommatrix-attributes) ---
// The 2D elements set plainly; the 3D-only elements clear is2D when set to a non-identity value.

pub fn (mut matrix DOMMatrix) set_m11(value f64) {
	matrix.m11_ = value
}

pub fn (mut matrix DOMMatrix) set_m12(value f64) {
	matrix.m12_ = value
}

pub fn (mut matrix DOMMatrix) set_m13(value f64) {
	matrix.m13_ = value
	if value != 0.0 {
		matrix.is_2d_ = false
	}
}

pub fn (mut matrix DOMMatrix) set_m14(value f64) {
	matrix.m14_ = value
	if value != 0.0 {
		matrix.is_2d_ = false
	}
}

pub fn (mut matrix DOMMatrix) set_m21(value f64) {
	matrix.m21_ = value
}

pub fn (mut matrix DOMMatrix) set_m22(value f64) {
	matrix.m22_ = value
}

pub fn (mut matrix DOMMatrix) set_m23(value f64) {
	matrix.m23_ = value
	if value != 0.0 {
		matrix.is_2d_ = false
	}
}

pub fn (mut matrix DOMMatrix) set_m24(value f64) {
	matrix.m24_ = value
	if value != 0.0 {
		matrix.is_2d_ = false
	}
}

pub fn (mut matrix DOMMatrix) set_m31(value f64) {
	matrix.m31_ = value
	if value != 0.0 {
		matrix.is_2d_ = false
	}
}

pub fn (mut matrix DOMMatrix) set_m32(value f64) {
	matrix.m32_ = value
	if value != 0.0 {
		matrix.is_2d_ = false
	}
}

pub fn (mut matrix DOMMatrix) set_m33(value f64) {
	matrix.m33_ = value
	if value != 1.0 {
		matrix.is_2d_ = false
	}
}

pub fn (mut matrix DOMMatrix) set_m34(value f64) {
	matrix.m34_ = value
	if value != 0.0 {
		matrix.is_2d_ = false
	}
}

pub fn (mut matrix DOMMatrix) set_m41(value f64) {
	matrix.m41_ = value
}

pub fn (mut matrix DOMMatrix) set_m42(value f64) {
	matrix.m42_ = value
}

pub fn (mut matrix DOMMatrix) set_m43(value f64) {
	matrix.m43_ = value
	if value != 0.0 {
		matrix.is_2d_ = false
	}
}

pub fn (mut matrix DOMMatrix) set_m44(value f64) {
	matrix.m44_ = value
	if value != 1.0 {
		matrix.is_2d_ = false
	}
}

// The 2D aliases set the corresponding m-element.
pub fn (mut matrix DOMMatrix) set_a(value f64) {
	matrix.m11_ = value
}

pub fn (mut matrix DOMMatrix) set_b(value f64) {
	matrix.m12_ = value
}

pub fn (mut matrix DOMMatrix) set_c(value f64) {
	matrix.m21_ = value
}

pub fn (mut matrix DOMMatrix) set_d(value f64) {
	matrix.m22_ = value
}

pub fn (mut matrix DOMMatrix) set_e(value f64) {
	matrix.m41_ = value
}

pub fn (mut matrix DOMMatrix) set_f(value f64) {
	matrix.m42_ = value
}

// --- In-place transforms (*_self) ---

// https://drafts.fxtf.org/geometry/#dom-dommatrix-multiplyself — post-multiply other onto the matrix.
pub fn (mut matrix DOMMatrix) multiply_self(mut other DOMMatrixInit) !&DOMMatrix {
	other_object := DOMMatrixReadOnly.create_from_dom_matrix_init(mut other)!
	matrix.apply_rows(mat4_multiply(matrix.to_rows(), other_object.to_rows()))
	if !other_object.is_2d_ {
		matrix.is_2d_ = false
	}
	return matrix
}

// https://drafts.fxtf.org/geometry/#dom-dommatrix-premultiplyself — pre-multiply other onto the matrix.
pub fn (mut matrix DOMMatrix) pre_multiply_self(mut other DOMMatrixInit) !&DOMMatrix {
	other_object := DOMMatrixReadOnly.create_from_dom_matrix_init(mut other)!
	matrix.apply_rows(mat4_multiply(other_object.to_rows(), matrix.to_rows()))
	if !other_object.is_2d_ {
		matrix.is_2d_ = false
	}
	return matrix
}

// https://drafts.fxtf.org/geometry/#dom-dommatrix-translateself — post-multiply a translation.
pub fn (mut matrix DOMMatrix) translate_self(tx ?f64, ty ?f64, tz ?f64) &DOMMatrix {
	z := tz or { 0.0 }
	matrix.apply_rows(mat4_multiply(matrix.to_rows(), translation_rows(tx or { 0.0 }, ty or { 0.0 },
		z)))
	// If tz is specified and non-zero, the matrix is no longer 2D.
	if tz != none && z != 0.0 {
		matrix.is_2d_ = false
	}
	return matrix
}

// --- Read-only transforms (each copies then applies the matching *_self) ---

// https://drafts.fxtf.org/geometry/#dom-dommatrixreadonly-multiply
pub fn (matrix &DOMMatrixReadOnly) multiply(mut other DOMMatrixInit) !&DOMMatrix {
	mut result := DOMMatrix.create_from_dom_matrix_read_only(matrix)
	return result.multiply_self(mut other)
}

// https://drafts.fxtf.org/geometry/#dom-dommatrixreadonly-translate
pub fn (matrix &DOMMatrixReadOnly) translate(tx ?f64, ty ?f64, tz ?f64) &DOMMatrix {
	mut result := DOMMatrix.create_from_dom_matrix_read_only(matrix)
	return result.translate_self(tx, ty, tz)
}

// https://drafts.fxtf.org/geometry/#dom-dommatrixreadonly-flipx — post-multiply diag(-1, 1, 1, 1).
pub fn (matrix &DOMMatrixReadOnly) flip_x() &DOMMatrix {
	mut result := DOMMatrix.create_from_dom_matrix_read_only(matrix)
	result.apply_rows(mat4_multiply(result.to_rows(), diagonal_rows(-1.0, 1.0, 1.0, 1.0)))
	return result
}

// https://drafts.fxtf.org/geometry/#dom-dommatrixreadonly-flipy — post-multiply diag(1, -1, 1, 1).
pub fn (matrix &DOMMatrixReadOnly) flip_y() &DOMMatrix {
	mut result := DOMMatrix.create_from_dom_matrix_read_only(matrix)
	result.apply_rows(mat4_multiply(result.to_rows(), diagonal_rows(1.0, -1.0, 1.0, 1.0)))
	return result
}
