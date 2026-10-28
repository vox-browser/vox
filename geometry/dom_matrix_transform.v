// Copyright (c) 2023-2024, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// The mutable DOMMatrix subclass and the matrix-returning transforms of DOMMatrixReadOnly.cpp /
// DOMMatrix.cpp that build a transform matrix and post-multiply it: multiply/preMultiply, translate,
// flipX/flipY, scale/scale3d/scaleNonUniform, skewX/skewY, and the rotate family (rotate/
// rotateAxisAngle/rotateFromVector). Each read-only transform copies the matrix and post-multiplies a
// transform matrix onto the copy; the *_self methods mutate in place and return the matrix (for chaining).
//
// Inversion lives in dom_matrix_invert.v; string parsing/stringification and
// typed structured-clone records live in their focused companion files.
//
// The stored components are the spec's column-major m<column><row>; to_rows() exposes the matrix as the
// standard rows[row][col] (rows[r][c] = m<c+1><r+1>) so a point transforms as rows * vector and matrices
// compose with the ordinary row-by-column product.
// https://drafts.fxtf.org/geometry/#dommatrix
module geometry

import math

// Degrees to radians (transform angles are given in degrees).
fn to_radians(degrees f64) f64 {
	return degrees * math.pi / 180.0
}

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

pub fn DOMMatrix.construct_impl(init ?DOMMatrixConstructorInit, is_window bool) !&DOMMatrix {
	return DOMMatrix.create_for_constructor(is_window, init)
}

pub fn DOMMatrix.create_from_constructor(init ?DOMMatrixConstructorInit, string_context DOMMatrixStringContext) !&DOMMatrix {
	value := init or { return DOMMatrix.create() }
	return match value {
		[]f64 { DOMMatrix.construct(value)! }
		string { DOMMatrix.construct_from_string(value, string_context == .window)! }
	}
}

pub fn DOMMatrix.create_for_constructor(is_window bool, init ?DOMMatrixConstructorInit) !&DOMMatrix {
	return DOMMatrix.create_from_constructor(init, dom_matrix_string_context(is_window))
}

pub fn DOMMatrix.create_from_dom_matrix_2d_init(mut init DOMMatrix2DInit) !&DOMMatrix {
	read_only := DOMMatrixReadOnly.create_from_dom_matrix_2d_init(mut init)!
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
	matrix.apply_rows(mat4_multiply(matrix.to_rows(), translation_rows(tx or { 0.0 }, ty or { 0.0 }, z)))
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

// --- Scale ---

// https://drafts.fxtf.org/geometry/#dom-dommatrix-scaleself — post-multiply a (possibly non-uniform)
// scale about an optional origin. scaleX defaults to 1, scaleY to scaleX, scaleZ to 1, origins to 0.
pub fn (mut matrix DOMMatrix) scale_self(scale_x ?f64, scale_y ?f64, scale_z ?f64, origin_x ?f64, origin_y ?f64, origin_z ?f64) &DOMMatrix {
	sx := scale_x or { 1.0 }
	sy := scale_y or { sx }
	sz := scale_z or { 1.0 }
	ox := origin_x or { 0.0 }
	oy := origin_y or { 0.0 }
	oz := origin_z or { 0.0 }
	// 1. Translate to the origin.
	matrix.translate_self(ox, oy, oz)
	// 3. Post-multiply the scale.
	matrix.apply_rows(mat4_multiply(matrix.to_rows(), diagonal_rows(sx, sy, sz, 1.0)))
	// 4-5. Translate back by the negated origin.
	matrix.translate_self(-ox, -oy, -oz)
	// 6. A z-scale other than 1 makes the matrix 3D.
	if sz != 1.0 {
		matrix.is_2d_ = false
	}
	return matrix
}

// https://drafts.fxtf.org/geometry/#dom-dommatrix-scale3dself — post-multiply a uniform 3D scale.
pub fn (mut matrix DOMMatrix) scale3d_self(scale ?f64, origin_x ?f64, origin_y ?f64, origin_z ?f64) &DOMMatrix {
	s := scale or { 1.0 }
	ox := origin_x or { 0.0 }
	oy := origin_y or { 0.0 }
	oz := origin_z or { 0.0 }
	// 1. Translate to the origin.
	matrix.translate_self(ox, oy, oz)
	// 2. Post-multiply the uniform scale.
	matrix.apply_rows(mat4_multiply(matrix.to_rows(), diagonal_rows(s, s, s, 1.0)))
	// 3. Translate back by the negated origin.
	matrix.translate_self(-ox, -oy, -oz)
	// 4. A scale other than 1 makes the matrix 3D.
	if s != 1.0 {
		matrix.is_2d_ = false
	}
	return matrix
}

// https://drafts.fxtf.org/geometry/#dom-dommatrixreadonly-scale
pub fn (matrix &DOMMatrixReadOnly) scale(scale_x ?f64, scale_y ?f64, scale_z ?f64, origin_x ?f64, origin_y ?f64, origin_z ?f64) &DOMMatrix {
	mut result := DOMMatrix.create_from_dom_matrix_read_only(matrix)
	return result.scale_self(scale_x, scale_y, scale_z, origin_x, origin_y, origin_z)
}

// https://drafts.fxtf.org/geometry/#dom-dommatrixreadonly-scalenonuniform — scaleX/scaleY both default
// to 1 (unlike scale, where scaleY follows scaleX).
pub fn (matrix &DOMMatrixReadOnly) scale_non_uniform(scale_x ?f64, scale_y ?f64) &DOMMatrix {
	mut result := DOMMatrix.create_from_dom_matrix_read_only(matrix)
	sx := scale_x or { 1.0 }
	sy := scale_y or { 1.0 }
	return result.scale_self(sx, sy, 1.0, 0.0, 0.0, 0.0)
}

// https://drafts.fxtf.org/geometry/#dom-dommatrixreadonly-scale3d
pub fn (matrix &DOMMatrixReadOnly) scale3d(scale ?f64, origin_x ?f64, origin_y ?f64, origin_z ?f64) &DOMMatrix {
	mut result := DOMMatrix.create_from_dom_matrix_read_only(matrix)
	return result.scale3d_self(scale, origin_x, origin_y, origin_z)
}

// --- Skew (2D shears; angles in degrees) ---

// https://drafts.fxtf.org/geometry/#dom-dommatrix-skewxself — post-multiply a skewX shear.
pub fn (mut matrix DOMMatrix) skew_x_self(sx f64) &DOMMatrix {
	skew := [
		[1.0, math.tan(to_radians(sx)), 0.0, 0.0]!,
		[0.0, 1.0, 0.0, 0.0]!,
		[0.0, 0.0, 1.0, 0.0]!,
		[0.0, 0.0, 0.0, 1.0]!,
	]!
	matrix.apply_rows(mat4_multiply(matrix.to_rows(), skew))
	return matrix
}

// https://drafts.fxtf.org/geometry/#dom-dommatrix-skewyself — post-multiply a skewY shear.
pub fn (mut matrix DOMMatrix) skew_y_self(sy f64) &DOMMatrix {
	skew := [
		[1.0, 0.0, 0.0, 0.0]!,
		[math.tan(to_radians(sy)), 1.0, 0.0, 0.0]!,
		[0.0, 0.0, 1.0, 0.0]!,
		[0.0, 0.0, 0.0, 1.0]!,
	]!
	matrix.apply_rows(mat4_multiply(matrix.to_rows(), skew))
	return matrix
}

// https://drafts.fxtf.org/geometry/#dom-dommatrixreadonly-skewx
pub fn (matrix &DOMMatrixReadOnly) skew_x(sx f64) &DOMMatrix {
	mut result := DOMMatrix.create_from_dom_matrix_read_only(matrix)
	return result.skew_x_self(sx)
}

// https://drafts.fxtf.org/geometry/#dom-dommatrixreadonly-skewy
pub fn (matrix &DOMMatrixReadOnly) skew_y(sy f64) &DOMMatrix {
	mut result := DOMMatrix.create_from_dom_matrix_read_only(matrix)
	return result.skew_y_self(sy)
}

// --- Rotate (angles in degrees except rotateFromVector, which is intrinsically radians) ---

// f64 machine epsilon (DBL_EPSILON), used to clamp near-zero cos/sin to exactly zero.
const rotation_epsilon = 2.220446049250313e-16

// The rotation matrix about the unit axis (x, y, z) by `angle` radians (Rodrigues' rotation formula,
// matching Gfx::rotation_matrix, including clamping tiny cos/sin to 0 so e.g. a 90-degree turn is exact).
fn rotation_rows(x f64, y f64, z f64, angle f64) [4][4]f64 {
	mut c := math.cos(angle)
	mut s := math.sin(angle)
	if math.abs(c) < rotation_epsilon {
		c = 0.0
	}
	if math.abs(s) < rotation_epsilon {
		s = 0.0
	}
	t := 1.0 - c
	return [
		[t * x * x + c, t * x * y - z * s, t * x * z + y * s, 0.0]!,
		[t * x * y + z * s, t * y * y + c, t * y * z - x * s, 0.0]!,
		[t * x * z - y * s, t * y * z + x * s, t * z * z + c, 0.0]!,
		[0.0, 0.0, 0.0, 1.0]!,
	]!
}

// https://drafts.fxtf.org/geometry/#dom-dommatrix-rotateself — post-multiply Z, then Y, then X rotations.
pub fn (mut matrix DOMMatrix) rotate_self(rot_x ?f64, rot_y ?f64, rot_z ?f64) &DOMMatrix {
	// rotX has an IDL default of 0; steps 2-3 default the others to 0 as well.
	mut rx := rot_x or { 0.0 }
	mut ry := rot_y or { 0.0 }
	mut rz := rot_z or { 0.0 }
	// 1. rotate(angle): when rotY and rotZ are both missing, the first argument is the Z rotation.
	if rot_y == none && rot_z == none {
		rz = rx
		rx = 0.0
		ry = 0.0
	}
	// 4. An X or Y rotation makes the matrix 3D.
	if rx != 0.0 || ry != 0.0 {
		matrix.is_2d_ = false
	}
	// 5-7. Post-multiply the Z, then Y, then X rotations.
	matrix.apply_rows(mat4_multiply(matrix.to_rows(), rotation_rows(0.0, 0.0, 1.0, to_radians(rz))))
	matrix.apply_rows(mat4_multiply(matrix.to_rows(), rotation_rows(0.0, 1.0, 0.0, to_radians(ry))))
	matrix.apply_rows(mat4_multiply(matrix.to_rows(), rotation_rows(1.0, 0.0, 0.0, to_radians(rx))))
	return matrix
}

// https://drafts.fxtf.org/geometry/#dom-dommatrix-rotateaxisangleself — rotate about an arbitrary axis.
pub fn (mut matrix DOMMatrix) rotate_axis_angle_self(x ?f64, y ?f64, z ?f64, angle ?f64) &DOMMatrix {
	ax := x or { 0.0 }
	ay := y or { 0.0 }
	az := z or { 0.0 }
	// 1. Post-multiply a rotation about the normalized axis by `angle` degrees.
	length := math.sqrt(ax * ax + ay * ay + az * az)
	matrix.apply_rows(mat4_multiply(matrix.to_rows(), rotation_rows(ax / length, ay / length, az / length, to_radians(angle or { 0.0 }))))
	// 2. An x or y axis component makes the matrix 3D.
	if ax != 0.0 || ay != 0.0 {
		matrix.is_2d_ = false
	}
	return matrix
}

// https://drafts.fxtf.org/geometry/#dom-dommatrix-rotatefromvectorself — rotate about Z by the angle
// between (1, 0) and (x, y). The angle is intrinsically in radians (atan2), so it is not converted.
pub fn (mut matrix DOMMatrix) rotate_from_vector_self(x ?f64, y ?f64) &DOMMatrix {
	vx := x or { 0.0 }
	vy := y or { 0.0 }
	angle := if vx == 0.0 && vy == 0.0 { 0.0 } else { math.atan2(vy, vx) }
	matrix.apply_rows(mat4_multiply(matrix.to_rows(), rotation_rows(0.0, 0.0, 1.0, angle)))
	return matrix
}

// https://drafts.fxtf.org/geometry/#dom-dommatrixreadonly-rotate
pub fn (matrix &DOMMatrixReadOnly) rotate(rot_x ?f64, rot_y ?f64, rot_z ?f64) &DOMMatrix {
	mut result := DOMMatrix.create_from_dom_matrix_read_only(matrix)
	return result.rotate_self(rot_x, rot_y, rot_z)
}

// https://drafts.fxtf.org/geometry/#dom-dommatrixreadonly-rotateaxisangle
pub fn (matrix &DOMMatrixReadOnly) rotate_axis_angle(x ?f64, y ?f64, z ?f64, angle ?f64) &DOMMatrix {
	mut result := DOMMatrix.create_from_dom_matrix_read_only(matrix)
	return result.rotate_axis_angle_self(x, y, z, angle)
}

// https://drafts.fxtf.org/geometry/#dom-dommatrixreadonly-rotatefromvector
pub fn (matrix &DOMMatrixReadOnly) rotate_from_vector(x ?f64, y ?f64) &DOMMatrix {
	mut result := DOMMatrix.create_from_dom_matrix_read_only(matrix)
	return result.rotate_from_vector_self(x, y)
}
