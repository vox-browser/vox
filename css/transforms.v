/*
 * Copyright (c) 2018-2025, Ladybird contributors
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */
module css

import math

// Translated from:
// - LibWeb/CSS/CSSPerspective.cpp
// - LibWeb/CSS/CSSRotate.cpp
// - LibWeb/CSS/CSSScale.cpp
// - LibWeb/CSS/CSSSkew.cpp
// - LibWeb/CSS/CSSSkewX.cpp
// - LibWeb/CSS/CSSSkewY.cpp
// - LibWeb/CSS/CSSTransformComponent.cpp
// - LibWeb/CSS/CSSTransformValue.cpp
// - LibWeb/CSS/CSSTranslate.cpp
// - LibWeb/CSS/CSSMatrixComponent.cpp
// - LibWeb/CSS/StyleValues/TransformationStyleValue.cpp/.h

// --- Narrow geometry stand-ins used by the translated transform code ---
pub struct FloatVector3 {
pub mut:
	x f64
	y f64
	z f64
}

pub fn (vector FloatVector3) length() f64 {
	return math.sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
}

pub fn (vector FloatVector3) normalized() FloatVector3 {
	length := vector.length()
	if length == 0 {
		return vector
	}
	return FloatVector3{
		x: vector.x / length
		y: vector.y / length
		z: vector.z / length
	}
}

pub struct FloatMatrix4x4 {
pub mut:
	m11 f64 = 1
	m12 f64
	m13 f64
	m14 f64
	m21 f64
	m22 f64 = 1
	m23 f64
	m24 f64
	m31 f64
	m32 f64
	m33 f64 = 1
	m34 f64
	m41 f64
	m42 f64
	m43 f64
	m44 f64 = 1
}

pub fn FloatMatrix4x4.identity() FloatMatrix4x4 {
	return FloatMatrix4x4{}
}

pub fn FloatMatrix4x4.from_values(m11 f64, m12 f64, m13 f64, m14 f64, m21 f64, m22 f64, m23 f64, m24 f64, m31 f64, m32 f64, m33 f64, m34 f64, m41 f64, m42 f64, m43 f64, m44 f64) FloatMatrix4x4 {
	return FloatMatrix4x4{
		m11: m11
		m12: m12
		m13: m13
		m14: m14
		m21: m21
		m22: m22
		m23: m23
		m24: m24
		m31: m31
		m32: m32
		m33: m33
		m34: m34
		m41: m41
		m42: m42
		m43: m43
		m44: m44
	}
}

pub fn (matrix FloatMatrix4x4) at(row int, column int) f64 {
	return match row {
		0 {
			match column {
				0 { matrix.m11 }
				1 { matrix.m12 }
				2 { matrix.m13 }
				3 { matrix.m14 }
				else { panic('VERIFY_NOT_REACHED') }
			}
		}
		1 {
			match column {
				0 { matrix.m21 }
				1 { matrix.m22 }
				2 { matrix.m23 }
				3 { matrix.m24 }
				else { panic('VERIFY_NOT_REACHED') }
			}
		}
		2 {
			match column {
				0 { matrix.m31 }
				1 { matrix.m32 }
				2 { matrix.m33 }
				3 { matrix.m34 }
				else { panic('VERIFY_NOT_REACHED') }
			}
		}
		3 {
			match column {
				0 { matrix.m41 }
				1 { matrix.m42 }
				2 { matrix.m43 }
				3 { matrix.m44 }
				else { panic('VERIFY_NOT_REACHED') }
			}
		}
		else {
			panic('VERIFY_NOT_REACHED')
		}
	}
}

// Temporaries stay in fixed arrays: these run for every visual-context node
// and hit-test candidate, where heap-allocated scratch dominated their cost.
pub fn (left FloatMatrix4x4) multiply(right FloatMatrix4x4) FloatMatrix4x4 {
	mut values := [16]f64{}
	for row in 0 .. 4 {
		for column in 0 .. 4 {
			mut value := 0.0
			for index in 0 .. 4 {
				value += left.at(row, index) * right.at(index, column)
			}
			values[row * 4 + column] = value
		}
	}
	return FloatMatrix4x4.from_values(values[0], values[1], values[2], values[3], values[4], values[5], values[6], values[7], values[8], values[9], values[10], values[11], values[12], values[13], values[14], values[15])
}

pub fn translation_matrix_4x4(x f64, y f64, z f64) FloatMatrix4x4 {
	return FloatMatrix4x4.from_values(1, 0, 0, x, 0, 1, 0, y, 0, 0, 1, z, 0, 0, 0, 1)
}

fn determinant_3x3(values [9]f64) f64 {
	first := values[0] * (values[4] * values[8] - values[5] * values[7])
	second := values[1] * (values[3] * values[8] - values[5] * values[6])
	third := values[2] * (values[3] * values[7] - values[4] * values[6])
	return first - second + third
}

pub fn (matrix FloatMatrix4x4) first_minor(excluded_row int, excluded_column int) f64 {
	mut values := [9]f64{}
	mut count := 0
	for row in 0 .. 4 {
		if row == excluded_row {
			continue
		}
		for column in 0 .. 4 {
			if column != excluded_column {
				values[count] = matrix.at(row, column)
				count++
			}
		}
	}
	return determinant_3x3(values)
}

pub fn (matrix FloatMatrix4x4) determinant() f64 {
	mut determinant := 0.0
	for column in 0 .. 4 {
		sign := if column % 2 == 0 { 1.0 } else { -1.0 }
		determinant += sign * matrix.at(0, column) * matrix.first_minor(0, column)
	}
	return determinant
}

pub fn (matrix FloatMatrix4x4) inverse() ?FloatMatrix4x4 {
	determinant := matrix.determinant()
	if determinant == 0 {
		return none
	}
	mut values := [16]f64{}
	for row in 0 .. 4 {
		for column in 0 .. 4 {
			// The adjugate is the transpose of the cofactor matrix.
			sign := if (row + column) % 2 == 0 { 1.0 } else { -1.0 }
			values[row * 4 + column] = sign * matrix.first_minor(column, row) / determinant
		}
	}
	return FloatMatrix4x4.from_values(values[0], values[1], values[2], values[3], values[4], values[5], values[6], values[7], values[8], values[9], values[10], values[11], values[12], values[13], values[14], values[15])
}

// The transformed plane normal faces away from the viewer when the z component
// of its inverse-transpose is negative. This matches Gfx::is_back_face_visible().
pub fn is_back_face_visible(matrix FloatMatrix4x4) bool {
	determinant := matrix.determinant()
	if determinant == 0 {
		return false
	}
	return matrix.first_minor(2, 2) / determinant < 0
}

pub fn rotation_matrix(axis FloatVector3, angle_radians f64) FloatMatrix4x4 {
	normalized_axis := axis.normalized()
	x := normalized_axis.x
	y := normalized_axis.y
	z := normalized_axis.z
	c := math.cos(angle_radians)
	s := math.sin(angle_radians)
	t := 1.0 - c

	return FloatMatrix4x4.from_values(t * x * x + c, t * x * y - s * z, t * x * z + s * y, 0, t * x * y + s * z, t * y * y + c, t * y * z - s * x, 0, t * x * z - s * y, t * y * z + s * x, t * z * z + c, 0, 0, 0, 0, 1)
}

pub struct DOMMatrix {
pub mut:
	m11_   f64 = 1
	m12_   f64
	m13_   f64
	m14_   f64
	m21_   f64
	m22_   f64 = 1
	m23_   f64
	m24_   f64
	m31_   f64
	m32_   f64
	m33_   f64 = 1
	m34_   f64
	m41_   f64
	m42_   f64
	m43_   f64
	m44_   f64 = 1
	is_2d_ bool = true
}

pub fn DOMMatrix.create() DOMMatrix {
	return DOMMatrix{}
}

pub fn DOMMatrix.create_from_dom_matrix_read_only(matrix DOMMatrix) DOMMatrix {
	return matrix
}

pub fn (matrix DOMMatrix) is2d() bool {
	return matrix.is_2d_
}

fn (mut matrix DOMMatrix) update_is_2d() {
	matrix.is_2d_ = matrix.m13_ == 0 && matrix.m14_ == 0 && matrix.m23_ == 0 && matrix.m24_ == 0 && matrix.m31_ == 0 && matrix.m32_ == 0 && matrix.m33_ == 1 && matrix.m34_ == 0 && matrix.m43_ == 0 && matrix.m44_ == 1
}

pub fn (matrix DOMMatrix) a() f64 {
	return matrix.m11_
}

pub fn (matrix DOMMatrix) b() f64 {
	return matrix.m12_
}

pub fn (matrix DOMMatrix) c() f64 {
	return matrix.m21_
}

pub fn (matrix DOMMatrix) d() f64 {
	return matrix.m22_
}

pub fn (matrix DOMMatrix) e() f64 {
	return matrix.m41_
}

pub fn (matrix DOMMatrix) f() f64 {
	return matrix.m42_
}

pub fn (matrix DOMMatrix) m11() f64 {
	return matrix.m11_
}

pub fn (matrix DOMMatrix) m12() f64 {
	return matrix.m12_
}

pub fn (matrix DOMMatrix) m13() f64 {
	return matrix.m13_
}

pub fn (matrix DOMMatrix) m14() f64 {
	return matrix.m14_
}

pub fn (matrix DOMMatrix) m21() f64 {
	return matrix.m21_
}

pub fn (matrix DOMMatrix) m22() f64 {
	return matrix.m22_
}

pub fn (matrix DOMMatrix) m23() f64 {
	return matrix.m23_
}

pub fn (matrix DOMMatrix) m24() f64 {
	return matrix.m24_
}

pub fn (matrix DOMMatrix) m31() f64 {
	return matrix.m31_
}

pub fn (matrix DOMMatrix) m32() f64 {
	return matrix.m32_
}

pub fn (matrix DOMMatrix) m33() f64 {
	return matrix.m33_
}

pub fn (matrix DOMMatrix) m34() f64 {
	return matrix.m34_
}

pub fn (matrix DOMMatrix) m41() f64 {
	return matrix.m41_
}

pub fn (matrix DOMMatrix) m42() f64 {
	return matrix.m42_
}

pub fn (matrix DOMMatrix) m43() f64 {
	return matrix.m43_
}

pub fn (matrix DOMMatrix) m44() f64 {
	return matrix.m44_
}

pub fn (mut matrix DOMMatrix) set_m11(value f64) {
	matrix.m11_ = value
	matrix.update_is_2d()
}

pub fn (mut matrix DOMMatrix) set_m12(value f64) {
	matrix.m12_ = value
	matrix.update_is_2d()
}

pub fn (mut matrix DOMMatrix) set_m13(value f64) {
	matrix.m13_ = value
	matrix.update_is_2d()
}

pub fn (mut matrix DOMMatrix) set_m14(value f64) {
	matrix.m14_ = value
	matrix.update_is_2d()
}

pub fn (mut matrix DOMMatrix) set_m21(value f64) {
	matrix.m21_ = value
	matrix.update_is_2d()
}

pub fn (mut matrix DOMMatrix) set_m22(value f64) {
	matrix.m22_ = value
	matrix.update_is_2d()
}

pub fn (mut matrix DOMMatrix) set_m23(value f64) {
	matrix.m23_ = value
	matrix.update_is_2d()
}

pub fn (mut matrix DOMMatrix) set_m24(value f64) {
	matrix.m24_ = value
	matrix.update_is_2d()
}

pub fn (mut matrix DOMMatrix) set_m31(value f64) {
	matrix.m31_ = value
	matrix.update_is_2d()
}

pub fn (mut matrix DOMMatrix) set_m32(value f64) {
	matrix.m32_ = value
	matrix.update_is_2d()
}

pub fn (mut matrix DOMMatrix) set_m33(value f64) {
	matrix.m33_ = value
	matrix.update_is_2d()
}

pub fn (mut matrix DOMMatrix) set_m34(value f64) {
	matrix.m34_ = value
	matrix.update_is_2d()
}

pub fn (mut matrix DOMMatrix) set_m41(value f64) {
	matrix.m41_ = value
	matrix.update_is_2d()
}

pub fn (mut matrix DOMMatrix) set_m42(value f64) {
	matrix.m42_ = value
	matrix.update_is_2d()
}

pub fn (mut matrix DOMMatrix) set_m43(value f64) {
	matrix.m43_ = value
	matrix.update_is_2d()
}

pub fn (mut matrix DOMMatrix) set_m44(value f64) {
	matrix.m44_ = value
	matrix.update_is_2d()
}

fn (matrix DOMMatrix) multiplied_by(other DOMMatrix) DOMMatrix {
	mut result := DOMMatrix{}
	result.m11_ = matrix.m11_ * other.m11_ + matrix.m12_ * other.m21_ + matrix.m13_ * other.m31_ + matrix.m14_ * other.m41_
	result.m12_ = matrix.m11_ * other.m12_ + matrix.m12_ * other.m22_ + matrix.m13_ * other.m32_ + matrix.m14_ * other.m42_
	result.m13_ = matrix.m11_ * other.m13_ + matrix.m12_ * other.m23_ + matrix.m13_ * other.m33_ + matrix.m14_ * other.m43_
	result.m14_ = matrix.m11_ * other.m14_ + matrix.m12_ * other.m24_ + matrix.m13_ * other.m34_ + matrix.m14_ * other.m44_
	result.m21_ = matrix.m21_ * other.m11_ + matrix.m22_ * other.m21_ + matrix.m23_ * other.m31_ + matrix.m24_ * other.m41_
	result.m22_ = matrix.m21_ * other.m12_ + matrix.m22_ * other.m22_ + matrix.m23_ * other.m32_ + matrix.m24_ * other.m42_
	result.m23_ = matrix.m21_ * other.m13_ + matrix.m22_ * other.m23_ + matrix.m23_ * other.m33_ + matrix.m24_ * other.m43_
	result.m24_ = matrix.m21_ * other.m14_ + matrix.m22_ * other.m24_ + matrix.m23_ * other.m34_ + matrix.m24_ * other.m44_
	result.m31_ = matrix.m31_ * other.m11_ + matrix.m32_ * other.m21_ + matrix.m33_ * other.m31_ + matrix.m34_ * other.m41_
	result.m32_ = matrix.m31_ * other.m12_ + matrix.m32_ * other.m22_ + matrix.m33_ * other.m32_ + matrix.m34_ * other.m42_
	result.m33_ = matrix.m31_ * other.m13_ + matrix.m32_ * other.m23_ + matrix.m33_ * other.m33_ + matrix.m34_ * other.m43_
	result.m34_ = matrix.m31_ * other.m14_ + matrix.m32_ * other.m24_ + matrix.m33_ * other.m34_ + matrix.m34_ * other.m44_
	result.m41_ = matrix.m41_ * other.m11_ + matrix.m42_ * other.m21_ + matrix.m43_ * other.m31_ + matrix.m44_ * other.m41_
	result.m42_ = matrix.m41_ * other.m12_ + matrix.m42_ * other.m22_ + matrix.m43_ * other.m32_ + matrix.m44_ * other.m42_
	result.m43_ = matrix.m41_ * other.m13_ + matrix.m42_ * other.m23_ + matrix.m43_ * other.m33_ + matrix.m44_ * other.m43_
	result.m44_ = matrix.m41_ * other.m14_ + matrix.m42_ * other.m24_ + matrix.m43_ * other.m34_ + matrix.m44_ * other.m44_
	result.update_is_2d()
	return result
}

pub fn (mut matrix DOMMatrix) multiply_self(other DOMMatrix) !DOMMatrix {
	result := matrix.multiplied_by(other)
	matrix.m11_ = result.m11_
	matrix.m12_ = result.m12_
	matrix.m13_ = result.m13_
	matrix.m14_ = result.m14_
	matrix.m21_ = result.m21_
	matrix.m22_ = result.m22_
	matrix.m23_ = result.m23_
	matrix.m24_ = result.m24_
	matrix.m31_ = result.m31_
	matrix.m32_ = result.m32_
	matrix.m33_ = result.m33_
	matrix.m34_ = result.m34_
	matrix.m41_ = result.m41_
	matrix.m42_ = result.m42_
	matrix.m43_ = result.m43_
	matrix.m44_ = result.m44_
	matrix.is_2d_ = result.is_2d_
	return matrix
}

fn (mut matrix DOMMatrix) translate_self(x f64, y f64, z f64) !DOMMatrix {
	mut translation := DOMMatrix.create()
	translation.set_m41(x)
	translation.set_m42(y)
	translation.set_m43(z)
	return matrix.multiply_self(translation)
}

pub fn (mut matrix DOMMatrix) scale_self(x f64, y f64, z ?f64, origin_x ?f64, origin_y ?f64, origin_z ?f64) !DOMMatrix {
	origin_x_value := origin_x or { 0 }
	origin_y_value := origin_y or { 0 }
	origin_z_value := origin_z or { 0 }
	if origin_x_value != 0 || origin_y_value != 0 || origin_z_value != 0 {
		matrix.translate_self(origin_x_value, origin_y_value, origin_z_value)!
	}

	mut scale := DOMMatrix.create()
	scale.set_m11(x)
	scale.set_m22(y)
	scale.set_m33(z or { 1 })
	matrix.multiply_self(scale)!

	if origin_x_value != 0 || origin_y_value != 0 || origin_z_value != 0 {
		matrix.translate_self(-origin_x_value, -origin_y_value, -origin_z_value)!
	}
	return matrix
}

pub fn (mut matrix DOMMatrix) rotate_axis_angle_self(x f64, y f64, z f64, angle_degrees f64) !DOMMatrix {
	axis := FloatVector3{
		x: x
		y: y
		z: z
	}
	epsilon := 1e-5
	if axis.length() < epsilon {
		return matrix
	}

	rotation := rotation_matrix(axis.normalized(), angle_degrees * math.pi / 180.0)
	mut dom_rotation := DOMMatrix.create()
	dom_rotation.set_m11(rotation.m11)
	dom_rotation.set_m12(rotation.m12)
	dom_rotation.set_m13(rotation.m13)
	dom_rotation.set_m14(rotation.m14)
	dom_rotation.set_m21(rotation.m21)
	dom_rotation.set_m22(rotation.m22)
	dom_rotation.set_m23(rotation.m23)
	dom_rotation.set_m24(rotation.m24)
	dom_rotation.set_m31(rotation.m31)
	dom_rotation.set_m32(rotation.m32)
	dom_rotation.set_m33(rotation.m33)
	dom_rotation.set_m34(rotation.m34)
	dom_rotation.set_m41(rotation.m41)
	dom_rotation.set_m42(rotation.m42)
	dom_rotation.set_m43(rotation.m43)
	dom_rotation.set_m44(rotation.m44)
	return matrix.multiply_self(dom_rotation)
}

pub fn (matrix DOMMatrix) to_string() string {
	if matrix.is_2d_ {
		return 'matrix(${serialize_a_number(matrix.a())}, ${serialize_a_number(matrix.b())}, ${serialize_a_number(matrix.c())}, ${serialize_a_number(matrix.d())}, ${serialize_a_number(matrix.e())}, ${serialize_a_number(matrix.f())})'
	}
	return 'matrix3d(${serialize_a_number(matrix.m11_)}, ${serialize_a_number(matrix.m12_)}, ${serialize_a_number(matrix.m13_)}, ${serialize_a_number(matrix.m14_)}, ${serialize_a_number(matrix.m21_)}, ${serialize_a_number(matrix.m22_)}, ${serialize_a_number(matrix.m23_)}, ${serialize_a_number(matrix.m24_)}, ${serialize_a_number(matrix.m31_)}, ${serialize_a_number(matrix.m32_)}, ${serialize_a_number(matrix.m33_)}, ${serialize_a_number(matrix.m34_)}, ${serialize_a_number(matrix.m41_)}, ${serialize_a_number(matrix.m42_)}, ${serialize_a_number(matrix.m43_)}, ${serialize_a_number(matrix.m44_)})'
}

pub struct TransformReferenceBox {
pub mut:
	width  CSSPixels
	height CSSPixels
}

pub struct TransformPaintableBox {
pub mut:
	reference_box             TransformReferenceBox
	length_resolution_context LengthResolutionContext = LengthResolutionContext.default()
}

pub fn (box TransformPaintableBox) transform_reference_box() TransformReferenceBox {
	return box.reference_box
}

// --- TransformFunctions.json ---
pub enum TransformFunction {
	matrix
	matrix3d
	perspective
	translate
	translate3d
	translate_x
	translate_y
	translate_z
	scale
	scale3d
	scale_x
	scale_y
	scale_z
	rotate
	rotate3d
	rotate_x
	rotate_y
	rotate_z
	skew
	skew_x
	skew_y
}

pub fn (function TransformFunction) to_string() string {
	return match function {
		.matrix { 'matrix' }
		.matrix3d { 'matrix3d' }
		.perspective { 'perspective' }
		.translate { 'translate' }
		.translate3d { 'translate3d' }
		.translate_x { 'translateX' }
		.translate_y { 'translateY' }
		.translate_z { 'translateZ' }
		.scale { 'scale' }
		.scale3d { 'scale3d' }
		.scale_x { 'scaleX' }
		.scale_y { 'scaleY' }
		.scale_z { 'scaleZ' }
		.rotate { 'rotate' }
		.rotate3d { 'rotate3d' }
		.rotate_x { 'rotateX' }
		.rotate_y { 'rotateY' }
		.rotate_z { 'rotateZ' }
		.skew { 'skew' }
		.skew_x { 'skewX' }
		.skew_y { 'skewY' }
	}
}

pub fn transform_function_from_string(value string) ?TransformFunction {
	return match value.to_lower() {
		'matrix' { TransformFunction.matrix }
		'matrix3d' { TransformFunction.matrix3d }
		'perspective' { TransformFunction.perspective }
		'translate' { TransformFunction.translate }
		'translate3d' { TransformFunction.translate3d }
		'translatex' { TransformFunction.translate_x }
		'translatey' { TransformFunction.translate_y }
		'translatez' { TransformFunction.translate_z }
		'scale' { TransformFunction.scale }
		'scale3d' { TransformFunction.scale3d }
		'scalex' { TransformFunction.scale_x }
		'scaley' { TransformFunction.scale_y }
		'scalez' { TransformFunction.scale_z }
		'rotate' { TransformFunction.rotate }
		'rotate3d' { TransformFunction.rotate3d }
		'rotatex' { TransformFunction.rotate_x }
		'rotatey' { TransformFunction.rotate_y }
		'rotatez' { TransformFunction.rotate_z }
		'skew' { TransformFunction.skew }
		'skewx' { TransformFunction.skew_x }
		'skewy' { TransformFunction.skew_y }
		else { none }
	}
}

pub enum TransformFunctionParameterType {
	angle
	length
	length_none
	length_percentage
	number
	number_percentage
}

pub struct TransformFunctionParameter {
pub mut:
	type_    TransformFunctionParameterType
	required bool
}

pub struct TransformFunctionMetadata {
pub mut:
	parameters []TransformFunctionParameter
}

fn transform_parameter(type_ TransformFunctionParameterType, required bool) TransformFunctionParameter {
	return TransformFunctionParameter{
		type_: type_
		required: required
	}
}

pub fn transform_function_metadata(function TransformFunction) TransformFunctionMetadata {
	return TransformFunctionMetadata{
		parameters: match function {
			.matrix {
				[transform_parameter(.number, true), transform_parameter(.number, true),
					transform_parameter(.number, true), transform_parameter(.number, true),
					transform_parameter(.number, true), transform_parameter(.number, true)]
			}
			.matrix3d {
				[transform_parameter(.number, true), transform_parameter(.number, true),
					transform_parameter(.number, true), transform_parameter(.number, true),
					transform_parameter(.number, true), transform_parameter(.number, true),
					transform_parameter(.number, true), transform_parameter(.number, true),
					transform_parameter(.number, true), transform_parameter(.number, true),
					transform_parameter(.number, true), transform_parameter(.number, true),
					transform_parameter(.number, true), transform_parameter(.number, true),
					transform_parameter(.number, true), transform_parameter(.number, true)]
			}
			.perspective {
				[transform_parameter(.length_none, true)]
			}
			.translate {
				[transform_parameter(.length_percentage, true),
					transform_parameter(.length_percentage, false)]
			}
			.translate3d {
				[transform_parameter(.length_percentage, true),
					transform_parameter(.length_percentage, true),
					transform_parameter(.length, true)]
			}
			.translate_x, .translate_y {
				[transform_parameter(.length_percentage, true)]
			}
			.translate_z {
				[transform_parameter(.length, true)]
			}
			.scale {
				[transform_parameter(.number_percentage, true),
					transform_parameter(.number_percentage, false)]
			}
			.scale3d {
				[transform_parameter(.number_percentage, true),
					transform_parameter(.number_percentage, true),
					transform_parameter(.number_percentage, true)]
			}
			.scale_x, .scale_y, .scale_z {
				[transform_parameter(.number_percentage, true)]
			}
			.rotate {
				[transform_parameter(.angle, true)]
			}
			.rotate3d {
				[transform_parameter(.number, true), transform_parameter(.number, true),
					transform_parameter(.number, true), transform_parameter(.angle, true)]
			}
			.rotate_x, .rotate_y, .rotate_z {
				[transform_parameter(.angle, true)]
			}
			.skew {
				[transform_parameter(.angle, true), transform_parameter(.angle, false)]
			}
			.skew_x, .skew_y {
				[transform_parameter(.angle, true)]
			}
		}
	}
}

// --- Helpers for missing StyleValue affordances used by TransformationStyleValue ---
pub fn (style_value StyleValue) is_length() bool {
	return style_value is LengthStyleValue
}

pub fn (style_value StyleValue) is_angle() bool {
	return style_value is AngleStyleValue
}

pub fn (style_value StyleValue) as_length() LengthStyleValue {
	value := style_value
	if value is LengthStyleValue {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (style_value StyleValue) as_angle() AngleStyleValue {
	value := style_value
	if value is AngleStyleValue {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (c CalculatedStyleValue) resolves_to_angle() bool {
	if numeric_type := c.numeric_type() {
		return numeric_type.matches_angle(c.calculation_context.percentages_resolve_as)
	}
	return true
}

pub fn (c CalculatedStyleValue) resolves_to_length() bool {
	if numeric_type := c.numeric_type() {
		return numeric_type.matches_length(c.calculation_context.percentages_resolve_as)
	}
	return true
}

pub fn (c CalculatedStyleValue) resolves_to_length_percentage() bool {
	if numeric_type := c.numeric_type() {
		return numeric_type.matches_length_percentage(c.calculation_context.percentages_resolve_as)
	}
	return true
}

pub fn (value CSSNumericValue) create_an_internal_representation(property PropertyNameAndID, perform_type_check PerformTypeCheck) !StyleValue {
	return match value {
		CSSUnitValue {
			value.create_an_internal_representation(property, perform_type_check)!
		}
		CSSMathSum, CSSMathProduct, CSSMathNegate, CSSMathInvert, CSSMathMin, CSSMathMax, CSSMathClamp {
			CSSMathValue(value).create_an_internal_representation(property, perform_type_check)!
		}
	}
}

fn style_value_is_keyword_none(value StyleValue) bool {
	return match value {
		CustomIdentStyleValue { to_ascii_lowercase(value.custom_ident()) == 'none' }
		else { false }
	}
}

// --- CSSTransformComponent ---
pub enum CSSTransformComponentIs2D {
	no
	yes
}

pub type CSSTransformComponent = CSSMatrixComponent
	| CSSPerspective
	| CSSRotate
	| CSSScale
	| CSSSkew
	| CSSSkewX
	| CSSSkewY
	| CSSTranslate

pub fn transform_component_is_2d_flag(is_2d CSSTransformComponentIs2D) bool {
	return is_2d == .yes
}

pub fn (component CSSTransformComponent) is_2d() bool {
	return match component {
		CSSMatrixComponent { component.is_2d() }
		CSSPerspective { component.is_2d() }
		CSSRotate { component.is_2d() }
		CSSScale { component.is_2d() }
		CSSSkew { component.is_2d() }
		CSSSkewX { component.is_2d() }
		CSSSkewY { component.is_2d() }
		CSSTranslate { component.is_2d() }
	}
}

pub fn (component CSSTransformComponent) to_matrix() !DOMMatrix {
	return match component {
		CSSMatrixComponent { component.to_matrix()! }
		CSSPerspective { component.to_matrix()! }
		CSSRotate { component.to_matrix()! }
		CSSScale { component.to_matrix()! }
		CSSSkew { component.to_matrix()! }
		CSSSkewX { component.to_matrix()! }
		CSSSkewY { component.to_matrix()! }
		CSSTranslate { component.to_matrix()! }
	}
}

pub fn (component CSSTransformComponent) to_string() !string {
	return match component {
		CSSMatrixComponent { component.to_string()! }
		CSSPerspective { component.to_string()! }
		CSSRotate { component.to_string()! }
		CSSScale { component.to_string()! }
		CSSSkew { component.to_string()! }
		CSSSkewX { component.to_string()! }
		CSSSkewY { component.to_string()! }
		CSSTranslate { component.to_string()! }
	}
}

pub fn (component CSSTransformComponent) create_style_value(property PropertyNameAndID) !TransformationStyleValue {
	return match component {
		CSSMatrixComponent { component.create_style_value(property)! }
		CSSPerspective { component.create_style_value(property)! }
		CSSRotate { component.create_style_value(property)! }
		CSSScale { component.create_style_value(property)! }
		CSSSkew { component.create_style_value(property)! }
		CSSSkewX { component.create_style_value(property)! }
		CSSSkewY { component.create_style_value(property)! }
		CSSTranslate { component.create_style_value(property)! }
	}
}

// --- CSSMatrixComponent ---
pub struct CSSMatrixComponentOptions {
pub mut:
	is2d ?bool
}

pub struct CSSMatrixComponent {
pub mut:
	is_2d_  bool
	matrix_ DOMMatrix
}

pub fn CSSMatrixComponent.create(is_2d CSSTransformComponentIs2D, matrix DOMMatrix) CSSMatrixComponent {
	return CSSMatrixComponent{
		is_2d_: transform_component_is_2d_flag(is_2d)
		matrix_: matrix
	}
}

pub fn CSSMatrixComponent.construct_impl(matrix DOMMatrix, options ?CSSMatrixComponentOptions) !CSSMatrixComponent {
	// The CSSMatrixComponent(matrix, options) constructor must, when invoked, perform the following steps:

	// 1. Let this be a new CSSMatrixComponent object with its matrix internal slot set to matrix.
	// NB: Done below.

	// 2. If options was passed and has a is2D field, set this’s is2D internal slot to the value of that field.
	// 3. Otherwise, set this’s is2D internal slot to the value of matrix’s is2D internal slot.
	mut is_2d := if matrix.is2d() {
		CSSTransformComponentIs2D.yes
	} else {
		CSSTransformComponentIs2D.no
	}
	if actual_options := options {
		if option_is_2d := actual_options.is2d {
			is_2d = if option_is_2d {
				CSSTransformComponentIs2D.yes
			} else {
				CSSTransformComponentIs2D.no
			}
		}
	}

	this_ := CSSMatrixComponent.create(is_2d, DOMMatrix.create_from_dom_matrix_read_only(matrix))

	// 4. Return this.
	return this_
}

pub fn (component CSSMatrixComponent) is_2d() bool {
	return component.is_2d_
}

pub fn (mut component CSSMatrixComponent) set_is_2d(value bool) {
	component.is_2d_ = value
}

pub fn (component CSSMatrixComponent) matrix() DOMMatrix {
	return component.matrix_
}

// https://drafts.css-houdini.org/css-typed-om-1/#serialize-a-cssmatrixcomponent
pub fn (component CSSMatrixComponent) to_string() !string {
	// 1. Return the serialization of this’s matrix internal slot.
	// FIXME: This means we ignore our is_2d state. https://github.com/w3c/css-houdini-drafts/issues/1155
	return component.matrix_.to_string()
}

pub fn (component CSSMatrixComponent) to_matrix() !DOMMatrix {
	// AD-HOC: Not specced, but we already have a matrix so use that.
	//          https://github.com/w3c/css-houdini-drafts/issues/1153
	return component.matrix()
}

pub fn (mut component CSSMatrixComponent) set_matrix(matrix DOMMatrix) ! {
	// AD-HOC: Not specced. https://github.com/w3c/css-houdini-drafts/issues/1153
	// FIXME: Should this modify is_2d? Or should we modify the matrix's is_2d?
	component.matrix_ = matrix
}

pub fn (component CSSMatrixComponent) create_style_value(property PropertyNameAndID) !TransformationStyleValue {
	if component.is_2d() {
		return TransformationStyleValue.create(transform_property_from_property(property), .matrix, [
			StyleValue(NumberStyleValue.create(component.matrix_.a())),
			StyleValue(NumberStyleValue.create(component.matrix_.b())),
			StyleValue(NumberStyleValue.create(component.matrix_.c())),
			StyleValue(NumberStyleValue.create(component.matrix_.d())),
			StyleValue(NumberStyleValue.create(component.matrix_.e())),
			StyleValue(NumberStyleValue.create(component.matrix_.f())),
		])
	}

	return TransformationStyleValue.create(transform_property_from_property(property), .matrix3d, [
		StyleValue(NumberStyleValue.create(component.matrix_.m11())),
		StyleValue(NumberStyleValue.create(component.matrix_.m12())),
		StyleValue(NumberStyleValue.create(component.matrix_.m13())),
		StyleValue(NumberStyleValue.create(component.matrix_.m14())),
		StyleValue(NumberStyleValue.create(component.matrix_.m21())),
		StyleValue(NumberStyleValue.create(component.matrix_.m22())),
		StyleValue(NumberStyleValue.create(component.matrix_.m23())),
		StyleValue(NumberStyleValue.create(component.matrix_.m24())),
		StyleValue(NumberStyleValue.create(component.matrix_.m31())),
		StyleValue(NumberStyleValue.create(component.matrix_.m32())),
		StyleValue(NumberStyleValue.create(component.matrix_.m33())),
		StyleValue(NumberStyleValue.create(component.matrix_.m34())),
		StyleValue(NumberStyleValue.create(component.matrix_.m41())),
		StyleValue(NumberStyleValue.create(component.matrix_.m42())),
		StyleValue(NumberStyleValue.create(component.matrix_.m43())),
		StyleValue(NumberStyleValue.create(component.matrix_.m44())),
	])
}

// --- CSSPerspective ---
pub type CSSPerspectiveValue = CSSKeywordValue
	| CSSMathClamp
	| CSSMathInvert
	| CSSMathMax
	| CSSMathMin
	| CSSMathNegate
	| CSSMathProduct
	| CSSMathSum
	| CSSUnitValue
	| string

pub type CSSPerspectiveValueInternal = CSSKeywordValue
	| CSSMathClamp
	| CSSMathInvert
	| CSSMathMax
	| CSSMathMin
	| CSSMathNegate
	| CSSMathProduct
	| CSSMathSum
	| CSSUnitValue

fn css_numeric_value_from_perspective_internal(value CSSPerspectiveValueInternal) ?CSSNumericValue {
	return match value {
		CSSUnitValue { CSSNumericValue(value) }
		CSSMathSum { CSSNumericValue(value) }
		CSSMathProduct { CSSNumericValue(value) }
		CSSMathNegate { CSSNumericValue(value) }
		CSSMathInvert { CSSNumericValue(value) }
		CSSMathMin { CSSNumericValue(value) }
		CSSMathMax { CSSNumericValue(value) }
		CSSMathClamp { CSSNumericValue(value) }
		CSSKeywordValue { none }
	}
}

fn css_keyword_value_from_perspective_internal(value CSSPerspectiveValueInternal) ?CSSKeywordValue {
	return match value {
		CSSKeywordValue {
			value
		}
		CSSUnitValue, CSSMathSum, CSSMathProduct, CSSMathNegate, CSSMathInvert, CSSMathMin, CSSMathMax, CSSMathClamp {
			none
		}
	}
}

fn css_perspective_internal_from_numeric(value CSSNumericValue) CSSPerspectiveValueInternal {
	return match value {
		CSSUnitValue { CSSPerspectiveValueInternal(value) }
		CSSMathSum { CSSPerspectiveValueInternal(value) }
		CSSMathProduct { CSSPerspectiveValueInternal(value) }
		CSSMathNegate { CSSPerspectiveValueInternal(value) }
		CSSMathInvert { CSSPerspectiveValueInternal(value) }
		CSSMathMin { CSSPerspectiveValueInternal(value) }
		CSSMathMax { CSSPerspectiveValueInternal(value) }
		CSSMathClamp { CSSPerspectiveValueInternal(value) }
	}
}

fn to_internal_css_perspective_value(value CSSPerspectiveValue) !CSSPerspectiveValueInternal {
	return match value {
		// 1. If length is a CSSNumericValue:
		CSSUnitValue, CSSMathSum, CSSMathProduct, CSSMathNegate, CSSMathInvert, CSSMathMin, CSSMathMax, CSSMathClamp {
			numeric_value := CSSNumericValue(value)
			// 1. If length does not match <length>, throw a TypeError.
			if !numeric_value.type_().matches_length(none) {
				return error("CSSPerspective length component doesn't match <length>")
			}
			CSSPerspectiveValueInternal(value)
		}

		// 2. Otherwise (that is, if length is not a CSSNumericValue):
		CSSKeywordValue {
			// 1. Rectify a keywordish value from length, then set length to the result’s value.
			rectified_length := value

			// 2. If length does not represent a value that is an ASCII case-insensitive match for the keyword none,
			//    throw a TypeError.
			if to_ascii_lowercase(rectified_length.value()) != 'none' {
				return error('CSSPerspective length component is a keyword other than `none`')
			}

			CSSPerspectiveValueInternal(rectified_length)
		}
		string {
			// 1. Rectify a keywordish value from length, then set length to the result’s value.
			rectified_length := CSSKeywordValue.create(value)

			// 2. If length does not represent a value that is an ASCII case-insensitive match for the keyword none,
			//    throw a TypeError.
			if to_ascii_lowercase(rectified_length.value()) != 'none' {
				return error('CSSPerspective length component is a keyword other than `none`')
			}

			CSSPerspectiveValueInternal(rectified_length)
		}
	}
}

pub struct CSSPerspective {
pub mut:
	is_2d_  bool
	length_ CSSPerspectiveValueInternal
}

pub fn CSSPerspective.create(length CSSPerspectiveValueInternal) CSSPerspective {
	return CSSPerspective{
		is_2d_: false
		length_: length
	}
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssperspective-cssperspective
pub fn CSSPerspective.construct_impl(length CSSPerspectiveValue) !CSSPerspective {
	// The CSSPerspective(length) constructor must, when invoked, perform the following steps:
	// NB: Steps 1 and 2 are implemented in to_internal().
	internal_length := to_internal_css_perspective_value(length)!

	// 3. Return a new CSSPerspective object with its length internal slot set to length, and its is2D internal slot
	//    set to false.
	return CSSPerspective.create(internal_length)
}

pub fn (perspective CSSPerspective) is_2d() bool {
	return perspective.is_2d_
}

pub fn (perspective CSSPerspective) length() CSSPerspectiveValue {
	return match perspective.length_ {
		CSSUnitValue { CSSPerspectiveValue(perspective.length_) }
		CSSMathSum { CSSPerspectiveValue(perspective.length_) }
		CSSMathProduct { CSSPerspectiveValue(perspective.length_) }
		CSSMathNegate { CSSPerspectiveValue(perspective.length_) }
		CSSMathInvert { CSSPerspectiveValue(perspective.length_) }
		CSSMathMin { CSSPerspectiveValue(perspective.length_) }
		CSSMathMax { CSSPerspectiveValue(perspective.length_) }
		CSSMathClamp { CSSPerspectiveValue(perspective.length_) }
		CSSKeywordValue { CSSPerspectiveValue(perspective.length_) }
	}
}

// https://drafts.css-houdini.org/css-typed-om-1/#serialize-a-cssperspective
pub fn (perspective CSSPerspective) to_string() !string {
	// 1. Let s initially be "perspective(".
	mut serialized := 'perspective('

	// 2. Serialize this’s length internal slot, with a minimum of 0px, and append it to s.
	// Match a local: current V miscompiles a multi-variant branch that converts a
	// matched field to another sum type.
	length := perspective.length_
	serialized += match length {
		CSSUnitValue, CSSMathSum, CSSMathProduct, CSSMathNegate, CSSMathInvert, CSSMathMin, CSSMathMax, CSSMathClamp {
			CSSNumericValue(length).serialize(CSSNumericSerializationParams{
				minimum: 0
			})
		}
		CSSKeywordValue {
			length.to_string()
		}
	}

	// 3. Append ")" to s, and return s.
	serialized += ')'
	return serialized
}

pub fn (perspective CSSPerspective) to_matrix() !DOMMatrix {
	// 1. Let matrix be a new DOMMatrix object, initialized to this’s equivalent 4x4 transform matrix, as defined in
	//    CSS Transforms 1 § 12. Mathematical Description of Transform Functions, and with its is2D internal slot set
	//    to the same value as this’s is2D internal slot.
	//    NOTE: Recall that the is2D flag affects what transform, and thus what equivalent matrix, a
	//          CSSTransformComponent represents.
	//    As the entries of such a matrix are defined relative to the px unit, if any <length>s in this involved in
	//    generating the matrix are not compatible units with px (such as relative lengths or percentages), throw a
	//    TypeError.
	mut matrix := DOMMatrix.create()

	if numeric_value := css_numeric_value_from_perspective_internal(perspective.length_) {
		// NB: to() throws a TypeError if the conversion can't be done.
		distance := numeric_value.to('px')!.value()
		matrix.set_m34(-1.0 / math.max(distance, 1.0))
	} else if _ := css_keyword_value_from_perspective_internal(perspective.length_) {
		// NB: This is `none`, so do nothing.
	}

	// 2. Return matrix.
	return matrix
}

pub fn (mut perspective CSSPerspective) set_length(value CSSPerspectiveValue) ! {
	// AD-HOC: Not specced. https://github.com/w3c/css-houdini-drafts/issues/1153
	//         WPT expects this to throw for invalid values, so just reuse the constructor code.
	length := to_internal_css_perspective_value(value)!
	perspective.length_ = length
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssperspective-is2d
pub fn (mut perspective CSSPerspective) set_is_2d(value bool) {
	_ = value
	// The is2D attribute of a CSSPerspective object must, on setting, do nothing.
}

pub fn (perspective CSSPerspective) create_style_value(property PropertyNameAndID) !TransformationStyleValue {
	length := match perspective.length_ {
		CSSUnitValue, CSSMathSum, CSSMathProduct, CSSMathNegate, CSSMathInvert, CSSMathMin, CSSMathMax, CSSMathClamp {
			CSSNumericValue(perspective.length_).create_an_internal_representation(property, .no)!
		}
		CSSKeywordValue {
			perspective.length_.create_an_internal_representation(property, .no)!
		}
	}

	return TransformationStyleValue.create(transform_property_from_property(property), .perspective, [
		length,
	])
}

// --- CSSRotate ---
pub struct CSSRotate {
pub mut:
	is_2d_ bool
	x_     CSSNumericValue
	y_     CSSNumericValue
	z_     CSSNumericValue
	angle_ CSSNumericValue
}

pub fn CSSRotate.create(is_2d CSSTransformComponentIs2D, x CSSNumericValue, y CSSNumericValue, z CSSNumericValue, angle CSSNumericValue) CSSRotate {
	return CSSRotate{
		is_2d_: transform_component_is_2d_flag(is_2d)
		x_: x
		y_: y
		z_: z
		angle_: angle
	}
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssrotate-cssrotate
pub fn CSSRotate.construct_impl(angle CSSNumericValue) !CSSRotate {
	// The CSSRotate(angle) constructor must, when invoked, perform the following steps:

	// 1. If angle doesn’t match <angle>, throw a TypeError.
	if !angle.type_().matches_angle(none) {
		return error("CSSRotate angle component doesn't match <angle>")
	}

	// 2. Return a new CSSRotate with its angle internal slot set to angle, its x and y internal slots set to new unit
	//    values of (0, "number"), its z internal slot set to a new unit value of (1, "number"), and its is2D internal
	//    slot set to true.
	return CSSRotate.create(.yes, CSSUnitValue.create(0, 'number'), CSSUnitValue.create(0, 'number'), CSSUnitValue.create(1, 'number'), angle)
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssrotate-cssrotate-x-y-z-anglec
pub fn CSSRotate.construct_impl_with_axis(x CSSNumberish, y CSSNumberish, z CSSNumberish, angle CSSNumericValue) !CSSRotate {
	// The CSSRotate(x, y, z, angle) constructor must, when invoked, perform the following steps:

	// 1. If angle doesn’t match <angle>, throw a TypeError.
	if !angle.type_().matches_angle(none) {
		return error("CSSRotate angle component doesn't match <angle>")
	}

	// 2. Let x, y, and z be replaced by the result of rectifying a numberish value.
	rectified_x := rectify_a_numberish_value(x)
	rectified_y := rectify_a_numberish_value(y)
	rectified_z := rectify_a_numberish_value(z)

	// 3. If x, y, or z don’t match <number>, throw a TypeError.
	if !rectified_x.type_().matches_number(none) {
		return error("CSSRotate x component doesn't match <number>")
	}
	if !rectified_y.type_().matches_number(none) {
		return error("CSSRotate y component doesn't match <number>")
	}
	if !rectified_z.type_().matches_number(none) {
		return error("CSSRotate z component doesn't match <number>")
	}

	// 4. Return a new CSSRotate with its angle internal slot set to angle, its x, y, z internal slots set to x, y, and
	//    z, and its is2D internal slot set to false.
	return CSSRotate.create(.no, rectified_x, rectified_y, rectified_z, angle)
}

pub fn (rotate CSSRotate) is_2d() bool {
	return rotate.is_2d_
}

pub fn (mut rotate CSSRotate) set_is_2d(value bool) {
	rotate.is_2d_ = value
}

pub fn (rotate CSSRotate) x() CSSNumberish {
	return match rotate.x_ {
		CSSUnitValue {
			CSSNumberish(rotate.x_)
		}
		CSSMathSum, CSSMathProduct, CSSMathNegate, CSSMathInvert, CSSMathMin, CSSMathMax, CSSMathClamp {
			CSSNumberish(rotate.x_)
		}
	}
}

pub fn (rotate CSSRotate) y() CSSNumberish {
	return match rotate.y_ {
		CSSUnitValue {
			CSSNumberish(rotate.y_)
		}
		CSSMathSum, CSSMathProduct, CSSMathNegate, CSSMathInvert, CSSMathMin, CSSMathMax, CSSMathClamp {
			CSSNumberish(rotate.y_)
		}
	}
}

pub fn (rotate CSSRotate) z() CSSNumberish {
	return match rotate.z_ {
		CSSUnitValue {
			CSSNumberish(rotate.z_)
		}
		CSSMathSum, CSSMathProduct, CSSMathNegate, CSSMathInvert, CSSMathMin, CSSMathMax, CSSMathClamp {
			CSSNumberish(rotate.z_)
		}
	}
}

pub fn (rotate CSSRotate) angle() CSSNumericValue {
	return rotate.angle_
}

// https://drafts.css-houdini.org/css-typed-om-1/#serialize-a-cssrotate
pub fn (rotate CSSRotate) to_string() !string {
	// 1. Let s initially be the empty string.
	mut serialized := ''

	// 2. If this’s is2D internal slot is false:
	if !rotate.is_2d() {
		// 1. Append "rotate3d(" to s.
		serialized += 'rotate3d('

		// 2. Serialize this’s x internal slot, and append it to s.
		serialized += rotate.x_.to_string()

		// 3. Append ", " to s.
		serialized += ', '

		// 4. Serialize this’s y internal slot, and append it to s.
		serialized += rotate.y_.to_string()

		// 5. Append ", " to s.
		serialized += ', '

		// 6. Serialize this’s z internal slot, and append it to s.
		serialized += rotate.z_.to_string()

		// 7. Append "," to s.
		serialized += ', '

		// 8. Serialize this’s angle internal slot, and append it to s.
		serialized += rotate.angle_.to_string()

		// 9. Append ")" to s, and return s.
		serialized += ')'
		return serialized
	} else {
		// 2. Otherwise:
		// 1. Append "rotate(" to s.
		serialized += 'rotate('

		// 2. Serialize this’s angle internal slot, and append it to s.
		serialized += rotate.angle_.to_string()

		// 3. Append ")" to s, and return s.
		serialized += ')'
		return serialized
	}
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-csstransformcomponent-tomatrix
pub fn (rotate CSSRotate) to_matrix() !DOMMatrix {
	// 1. Let matrix be a new DOMMatrix object, initialized to this’s equivalent 4x4 transform matrix, as defined in
	//    CSS Transforms 1 § 12. Mathematical Description of Transform Functions, and with its is2D internal slot set
	//    to the same value as this’s is2D internal slot.
	//    NOTE: Recall that the is2D flag affects what transform, and thus what equivalent matrix, a
	//          CSSTransformComponent represents.
	//    As the entries of such a matrix are defined relative to the px unit, if any <length>s in this involved in
	//    generating the matrix are not compatible units with px (such as relative lengths or percentages), throw a
	//    TypeError.
	// 2. Return matrix.
	mut matrix := DOMMatrix.create()

	// NB: to() throws a TypeError if the conversion can't be done.
	angle := rotate.angle_.to('deg')!.value()

	if rotate.is_2d() {
		return matrix.rotate_axis_angle_self(0, 0, 1, angle)
	}

	x := rotate.x_.to('number')!.value()
	y := rotate.y_.to('number')!.value()
	z := rotate.z_.to('number')!.value()

	return matrix.rotate_axis_angle_self(x, y, z, angle)
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssrotate-x
pub fn (mut rotate CSSRotate) set_x(value CSSNumberish) ! {
	// The x, y, and z attributes must, on setting to a new value val, rectify a numberish value from val and set the
	// corresponding internal slot to the result of that.
	// AD-HOC: WPT expects this to throw for invalid values. https://github.com/w3c/css-houdini-drafts/issues/1153
	rectified_x := rectify_a_numberish_value(value)
	if !rectified_x.type_().matches_number(none) {
		return error("CSSRotate x component doesn't match <number>")
	}
	rotate.x_ = rectified_x
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssrotate-y
pub fn (mut rotate CSSRotate) set_y(value CSSNumberish) ! {
	// The x, y, and z attributes must, on setting to a new value val, rectify a numberish value from val and set the
	// corresponding internal slot to the result of that.
	// AD-HOC: WPT expects this to throw for invalid values. https://github.com/w3c/css-houdini-drafts/issues/1153
	rectified_y := rectify_a_numberish_value(value)
	if !rectified_y.type_().matches_number(none) {
		return error("CSSRotate y component doesn't match <number>")
	}
	rotate.y_ = rectified_y
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssrotate-z
pub fn (mut rotate CSSRotate) set_z(value CSSNumberish) ! {
	// The x, y, and z attributes must, on setting to a new value val, rectify a numberish value from val and set the
	// corresponding internal slot to the result of that.
	// AD-HOC: WPT expects this to throw for invalid values. https://github.com/w3c/css-houdini-drafts/issues/1153
	rectified_z := rectify_a_numberish_value(value)
	if !rectified_z.type_().matches_number(none) {
		return error("CSSRotate z component doesn't match <number>")
	}
	rotate.z_ = rectified_z
}

pub fn (mut rotate CSSRotate) set_angle(value CSSNumericValue) ! {
	// AD-HOC: Not specced. WPT expects this to throw for invalid values. https://github.com/w3c/css-houdini-drafts/issues/1153
	if !value.type_().matches_angle(none) {
		return error("CSSRotate angle component doesn't match <angle>")
	}
	rotate.angle_ = value
}

pub fn (rotate CSSRotate) create_style_value(property PropertyNameAndID) !TransformationStyleValue {
	if rotate.is_2d() {
		return TransformationStyleValue.create(transform_property_from_property(property), .rotate, [
			rotate.angle_.create_an_internal_representation(property, .no)!,
		])
	}

	return TransformationStyleValue.create(transform_property_from_property(property), .rotate3d, [
		rotate.x_.create_an_internal_representation(property, .no)!,
		rotate.y_.create_an_internal_representation(property, .no)!,
		rotate.z_.create_an_internal_representation(property, .no)!,
		rotate.angle_.create_an_internal_representation(property, .no)!,
	])
}

// --- CSSScale ---
pub struct CSSScale {
pub mut:
	is_2d_ bool
	x_     CSSNumericValue
	y_     CSSNumericValue
	z_     CSSNumericValue
}

pub fn CSSScale.create(is_2d CSSTransformComponentIs2D, x CSSNumericValue, y CSSNumericValue, z CSSNumericValue) CSSScale {
	return CSSScale{
		is_2d_: transform_component_is_2d_flag(is_2d)
		x_: x
		y_: y
		z_: z
	}
}

pub fn CSSScale.construct_impl(x CSSNumberish, y CSSNumberish, z ?CSSNumberish) !CSSScale {
	// The CSSScale(x, y, z) constructor must, when invoked, perform the following steps:

	// 1. Let x, y, and z (if passed) be replaced by the result of rectifying a numberish value.
	rectified_x := rectify_a_numberish_value(x)
	rectified_y := rectify_a_numberish_value(y)
	mut rectified_z := ?CSSNumericValue(none)
	if z_value := z {
		rectified_z = rectify_a_numberish_value(z_value)
	}

	// 2. If x, y, or z (if passed) don’t match <number>, throw a TypeError.
	if !rectified_x.type_().matches_number(none) {
		return error("CSSScale x component doesn't match <number>")
	}
	if !rectified_y.type_().matches_number(none) {
		return error("CSSScale y component doesn't match <number>")
	}
	if z_value := rectified_z {
		if !z_value.type_().matches_number(none) {
			return error("CSSScale z component doesn't match <number>")
		}
	}

	// 3. Let this be a new CSSScale object, with its x and y internal slots set to x and y.
	// 4. If z was passed, set this’s z internal slot to z, and set this’s is2D internal slot to false.
	// 5. If z was not passed, set this’s z internal slot to a new unit value of (1, "number"), and set this’s is2D internal slot to true.
	mut is_2d := CSSTransformComponentIs2D.no
	if rectified_z == none {
		rectified_z = CSSUnitValue.create(1, 'number')
		is_2d = .yes
	}
	this_ := CSSScale.create(is_2d, rectified_x, rectified_y, rectified_z or {
		CSSUnitValue.create(1, 'number')
	})

	// 6. Return this.
	return this_
}

pub fn (scale CSSScale) is_2d() bool {
	return scale.is_2d_
}

pub fn (mut scale CSSScale) set_is_2d(value bool) {
	scale.is_2d_ = value
}

pub fn (scale CSSScale) x() CSSNumberish {
	return css_numberish_from_numeric_value(scale.x_)
}

pub fn (scale CSSScale) y() CSSNumberish {
	return css_numberish_from_numeric_value(scale.y_)
}

pub fn (scale CSSScale) z() CSSNumberish {
	return css_numberish_from_numeric_value(scale.z_)
}

// https://drafts.css-houdini.org/css-typed-om-1/#serialize-a-cssscale
pub fn (scale CSSScale) to_string() !string {
	// 1. Let s initially be the empty string.
	mut serialized := ''

	// 2. If this’s is2D internal slot is false:
	if !scale.is_2d() {
		// 1. Append "scale3d(" to s.
		serialized += 'scale3d('

		// 2. Serialize this’s x internal slot, and append it to s.
		serialized += scale.x_.to_string()

		// 3. Append ", " to s.
		serialized += ', '

		// 4. Serialize this’s y internal slot, and append it to s.
		serialized += scale.y_.to_string()

		// 5. Append ", " to s.
		serialized += ', '

		// 6. Serialize this’s z internal slot, and append it to s.
		serialized += scale.z_.to_string()

		// 7. Append ")" to s, and return s.
		serialized += ')'
		return serialized
	} else {
		// 3. Otherwise:
		// 1. Append "scale(" to s.
		serialized += 'scale('

		// 2. Serialize this’s x internal slot, and append it to s.
		serialized += scale.x_.to_string()

		// 3. If this’s x and y internal slots are equal numeric values, append ")" to s and return s.
		// AD-HOC: Don't do this - neither Chrome nor Safari show this behavior.
		//         Upstream issue: https://github.com/w3c/css-houdini-drafts/issues/1161

		// 4. Otherwise, append ", " to s.
		serialized += ', '

		// 5. Serialize this’s y internal slot, and append it to s.
		serialized += scale.y_.to_string()

		// 6. Append ")" to s, and return s.
		serialized += ')'
		return serialized
	}
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-csstransformcomponent-tomatrix
pub fn (scale CSSScale) to_matrix() !DOMMatrix {
	// 1. Let matrix be a new DOMMatrix object, initialized to this’s equivalent 4x4 transform matrix, as defined in
	//    CSS Transforms 1 § 12. Mathematical Description of Transform Functions, and with its is2D internal slot set
	//    to the same value as this’s is2D internal slot.
	//    NOTE: Recall that the is2D flag affects what transform, and thus what equivalent matrix, a
	//          CSSTransformComponent represents.
	//    As the entries of such a matrix are defined relative to the px unit, if any <length>s in this involved in
	//    generating the matrix are not compatible units with px (such as relative lengths or percentages), throw a
	//    TypeError.
	// 2. Return matrix.
	mut matrix := DOMMatrix.create()

	// NB: to() throws a TypeError if the conversion can't be done.
	x := scale.x_.to('number')!.value()
	y := scale.y_.to('number')!.value()

	if scale.is_2d() {
		return matrix.scale_self(x, y, none, none, none, none)
	}

	z := scale.z_.to('number')!.value()
	return matrix.scale_self(x, y, z, none, none, none)
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssscale-x
pub fn (mut scale CSSScale) set_x(value CSSNumberish) ! {
	// The x, y, and z attributes must, on setting to a new value val, rectify a numberish value from val and set the
	// corresponding internal slot to the result of that.
	// AD-HOC: WPT expects this to throw for invalid values. https://github.com/w3c/css-houdini-drafts/issues/1153
	rectified_x := rectify_a_numberish_value(value)
	if !rectified_x.type_().matches_number(none) {
		return error("CSSScale x component doesn't match <number>")
	}
	scale.x_ = rectified_x
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssscale-y
pub fn (mut scale CSSScale) set_y(value CSSNumberish) ! {
	// The x, y, and z attributes must, on setting to a new value val, rectify a numberish value from val and set the
	// corresponding internal slot to the result of that.
	// AD-HOC: WPT expects this to throw for invalid values. https://github.com/w3c/css-houdini-drafts/issues/1153
	rectified_y := rectify_a_numberish_value(value)
	if !rectified_y.type_().matches_number(none) {
		return error("CSSScale y component doesn't match <number>")
	}
	scale.y_ = rectified_y
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssscale-z
pub fn (mut scale CSSScale) set_z(value CSSNumberish) ! {
	// The x, y, and z attributes must, on setting to a new value val, rectify a numberish value from val and set the
	// corresponding internal slot to the result of that.
	// AD-HOC: WPT expects this to throw for invalid values. https://github.com/w3c/css-houdini-drafts/issues/1153
	rectified_z := rectify_a_numberish_value(value)
	if !rectified_z.type_().matches_number(none) {
		return error("CSSScale z component doesn't match <number>")
	}
	scale.z_ = rectified_z
}

pub fn (scale CSSScale) create_style_value(property PropertyNameAndID) !TransformationStyleValue {
	if scale.is_2d() {
		return TransformationStyleValue.create(transform_property_from_property(property), .scale, [
			scale.x_.create_an_internal_representation(property, .no)!,
			scale.y_.create_an_internal_representation(property, .no)!,
		])
	}

	return TransformationStyleValue.create(transform_property_from_property(property), .scale3d, [
		scale.x_.create_an_internal_representation(property, .no)!,
		scale.y_.create_an_internal_representation(property, .no)!,
		scale.z_.create_an_internal_representation(property, .no)!,
	])
}

// --- CSSTranslate ---
pub struct CSSTranslate {
pub mut:
	is_2d_ bool
	x_     CSSNumericValue
	y_     CSSNumericValue
	z_     CSSNumericValue
}

pub fn CSSTranslate.create(is_2d CSSTransformComponentIs2D, x CSSNumericValue, y CSSNumericValue, z CSSNumericValue) CSSTranslate {
	return CSSTranslate{
		is_2d_: transform_component_is_2d_flag(is_2d)
		x_: x
		y_: y
		z_: z
	}
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-csstranslate-csstranslate
pub fn CSSTranslate.construct_impl(x CSSNumericValue, y CSSNumericValue, z ?CSSNumericValue) !CSSTranslate {
	// The CSSTranslate(x, y, z) constructor must, when invoked, perform the following steps:

	// 1. If x or y don’t match <length-percentage>, throw a TypeError.
	if !x.type_().matches_length_percentage(none) {
		return error("CSSTranslate x component doesn't match <length-percentage>")
	}

	if !y.type_().matches_length_percentage(none) {
		return error("CSSTranslate y component doesn't match <length-percentage>")
	}

	// 2. If z was passed, but doesn’t match <length>, throw a TypeError.
	if z_value := z {
		if !z_value.type_().matches_length(none) {
			return error("CSSTranslate z component doesn't match <length>")
		}
	}

	// 3. Let this be a new CSSTranslate object, with its x and y internal slots set to x and y.
	// 4. If z was passed, set this’s z internal slot to z, and set this’s is2D internal slot to false.
	// 5. If z was not passed, set this’s z internal slot to a new unit value of (0, "px"), and set this’s is2D internal slot to true.
	mut is_2d := CSSTransformComponentIs2D.no
	mut actual_z := CSSNumericValue(CSSUnitValue.create(0, 'px'))
	if z_value := z {
		actual_z = z_value
	} else {
		is_2d = .yes
	}
	this_ := CSSTranslate.create(is_2d, x, y, actual_z)

	// 6. Return this.
	return this_
}

pub fn (translate CSSTranslate) is_2d() bool {
	return translate.is_2d_
}

pub fn (mut translate CSSTranslate) set_is_2d(value bool) {
	translate.is_2d_ = value
}

pub fn (translate CSSTranslate) x() CSSNumericValue {
	return translate.x_
}

pub fn (translate CSSTranslate) y() CSSNumericValue {
	return translate.y_
}

pub fn (translate CSSTranslate) z() CSSNumericValue {
	return translate.z_
}

// https://drafts.css-houdini.org/css-typed-om-1/#serialize-a-csstranslate
pub fn (translate CSSTranslate) to_string() !string {
	// 1. Let s initially be the empty string.
	mut serialized := ''

	// 2. If this’s is2D internal slot is false:
	if !translate.is_2d() {
		// 1. Append "translate3d(" to s.
		serialized += 'translate3d('

		// 2. Serialize this’s x internal slot, and append it to s.
		serialized += translate.x_.to_string()

		// 3. Append ", " to s.
		serialized += ', '

		// 4. Serialize this’s y internal slot, and append it to s.
		serialized += translate.y_.to_string()

		// 5. Append ", " to s.
		serialized += ', '

		// 6. Serialize this’s z internal slot, and append it to s.
		serialized += translate.z_.to_string()

		// 7. Append ")" to s, and return s.
		serialized += ')'
		return serialized
	} else {
		// 3. Otherwise:
		// 1. Append "translate(" to s.
		serialized += 'translate('

		// 2. Serialize this’s x internal slot, and append it to s.
		serialized += translate.x_.to_string()

		// 3. Append ", " to s.
		serialized += ', '

		// 4. Serialize this’s y internal slot, and append it to s.
		serialized += translate.y_.to_string()

		// 5. Append ")" to s, and return s.
		serialized += ')'
		return serialized
	}
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-csstransformcomponent-tomatrix
pub fn (translate CSSTranslate) to_matrix() !DOMMatrix {
	// 1. Let matrix be a new DOMMatrix object, initialized to this’s equivalent 4x4 transform matrix, as defined in
	//    CSS Transforms 1 § 12. Mathematical Description of Transform Functions, and with its is2D internal slot set
	//    to the same value as this’s is2D internal slot.
	//    NOTE: Recall that the is2D flag affects what transform, and thus what equivalent matrix, a
	//          CSSTransformComponent represents.
	//    As the entries of such a matrix are defined relative to the px unit, if any <length>s in this involved in
	//    generating the matrix are not compatible units with px (such as relative lengths or percentages), throw a
	//    TypeError.
	mut matrix := DOMMatrix.create()

	// NB: to() throws a TypeError if the conversion can't be done.
	matrix.set_m41(translate.x_.to('px')!.value())
	matrix.set_m42(translate.y_.to('px')!.value())
	if !translate.is_2d() {
		matrix.set_m43(translate.z_.to('px')!.value())
	}

	// 2. Return matrix.
	return matrix
}

pub fn (mut translate CSSTranslate) set_x(x CSSNumericValue) ! {
	// AD-HOC: Not specced. https://github.com/w3c/css-houdini-drafts/issues/1153
	//         WPT expects this to throw for invalid values.
	if !x.type_().matches_length_percentage(none) {
		return error("CSSTranslate x component doesn't match <length-percentage>")
	}
	translate.x_ = x
}

pub fn (mut translate CSSTranslate) set_y(y CSSNumericValue) ! {
	// AD-HOC: Not specced. https://github.com/w3c/css-houdini-drafts/issues/1153
	//         WPT expects this to throw for invalid values.
	if !y.type_().matches_length_percentage(none) {
		return error("CSSTranslate y component doesn't match <length-percentage>")
	}
	translate.y_ = y
}

pub fn (mut translate CSSTranslate) set_z(z CSSNumericValue) ! {
	// AD-HOC: Not specced. https://github.com/w3c/css-houdini-drafts/issues/1153
	//         WPT expects this to throw for invalid values.
	if !z.type_().matches_length(none) {
		return error("CSSTranslate z component doesn't match <length>")
	}
	translate.z_ = z
}

pub fn (translate CSSTranslate) create_style_value(property PropertyNameAndID) !TransformationStyleValue {
	if translate.is_2d() {
		return TransformationStyleValue.create(transform_property_from_property(property), .translate, [
			translate.x_.create_an_internal_representation(property, .no)!,
			translate.y_.create_an_internal_representation(property, .no)!,
		])
	}

	return TransformationStyleValue.create(transform_property_from_property(property), .translate3d, [
		translate.x_.create_an_internal_representation(property, .no)!,
		translate.y_.create_an_internal_representation(property, .no)!,
		translate.z_.create_an_internal_representation(property, .no)!,
	])
}

// --- CSSSkew ---
pub struct CSSSkew {
pub mut:
	is_2d_ bool = true
	ax_    CSSNumericValue
	ay_    CSSNumericValue
}

pub fn CSSSkew.create(ax CSSNumericValue, ay CSSNumericValue) CSSSkew {
	return CSSSkew{
		is_2d_: true
		ax_: ax
		ay_: ay
	}
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssskew-cssskew
pub fn CSSSkew.construct_impl(ax CSSNumericValue, ay CSSNumericValue) !CSSSkew {
	// The CSSSkew(ax, ay) constructor must, when invoked, perform the following steps:

	// 1. If ax or ay do not match <angle>, throw a TypeError.
	if !ax.type_().matches_angle(none) {
		return error("CSSSkew ax component doesn't match <angle>")
	}
	if !ay.type_().matches_angle(none) {
		return error("CSSSkew ay component doesn't match <angle>")
	}

	// 2. Return a new CSSSkew object with its ax and ay internal slots set to ax and ay, and its is2D internal slot
	//    set to true.
	return CSSSkew.create(ax, ay)
}

pub fn (skew CSSSkew) is_2d() bool {
	return skew.is_2d_
}

pub fn (skew CSSSkew) ax() CSSNumericValue {
	return skew.ax_
}

pub fn (skew CSSSkew) ay() CSSNumericValue {
	return skew.ay_
}

// https://drafts.css-houdini.org/css-typed-om-1/#serialize-a-cssskew
pub fn (skew CSSSkew) to_string() !string {
	// 1. Let s initially be "skew(".
	mut serialized := 'skew('

	// 2. Serialize this’s ax internal slot, and append it to s.
	serialized += skew.ax_.to_string()

	// 3. If this’s ay internal slot is a CSSUnitValue with a value of 0, then append ")" to s and return s.
	ay_value := skew.ay_
	if ay_value is CSSUnitValue && ay_value.value() == 0 {
		serialized += ')'
		return serialized
	}

	// 4. Otherwise, append ", " to s.
	serialized += ', '

	// 5. Serialize this’s ay internal slot, and append it to s.
	serialized += skew.ay_.to_string()

	// 6. Append ")" to s, and return s.
	serialized += ')'
	return serialized
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-csstransformcomponent-tomatrix
pub fn (skew CSSSkew) to_matrix() !DOMMatrix {
	// 1. Let matrix be a new DOMMatrix object, initialized to this’s equivalent 4x4 transform matrix, as defined in
	//    CSS Transforms 1 § 12. Mathematical Description of Transform Functions, and with its is2D internal slot set
	//    to the same value as this’s is2D internal slot.
	//    NOTE: Recall that the is2D flag affects what transform, and thus what equivalent matrix, a
	//          CSSTransformComponent represents.
	//    As the entries of such a matrix are defined relative to the px unit, if any <length>s in this involved in
	//    generating the matrix are not compatible units with px (such as relative lengths or percentages), throw a
	//    TypeError.
	mut matrix := DOMMatrix.create()

	// NB: to() throws a TypeError if the conversion can't be done.
	ax_rad := skew.ax_.to('rad')!.value()
	ay_rad := skew.ay_.to('rad')!.value()

	matrix.set_m21(math.tan(ax_rad))
	matrix.set_m12(math.tan(ay_rad))

	// 2. Return matrix.
	return matrix
}

pub fn (mut skew CSSSkew) set_ax(ax CSSNumericValue) ! {
	// AD-HOC: Not specced. https://github.com/w3c/css-houdini-drafts/issues/1153
	//         WPT expects this to throw for invalid values.
	if !ax.type_().matches_angle(none) {
		return error("CSSSkew ax component doesn't match <angle>")
	}
	skew.ax_ = ax
}

pub fn (mut skew CSSSkew) set_ay(ay CSSNumericValue) ! {
	// AD-HOC: Not specced. https://github.com/w3c/css-houdini-drafts/issues/1153
	//         WPT expects this to throw for invalid values.
	if !ay.type_().matches_angle(none) {
		return error("CSSSkew ay component doesn't match <angle>")
	}
	skew.ay_ = ay
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssskew-is2d
pub fn (mut skew CSSSkew) set_is_2d(value bool) {
	_ = value
	// The is2D attribute of a CSSSkew, CSSSkewX, or CSSSkewY object must, on setting, do nothing.
}

pub fn (skew CSSSkew) create_style_value(property PropertyNameAndID) !TransformationStyleValue {
	return TransformationStyleValue.create(transform_property_from_property(property), .skew, [
		skew.ax_.create_an_internal_representation(property, .no)!,
		skew.ay_.create_an_internal_representation(property, .no)!,
	])
}

// --- CSSSkewX ---
pub struct CSSSkewX {
pub mut:
	is_2d_ bool = true
	ax_    CSSNumericValue
}

pub fn CSSSkewX.create(ax CSSNumericValue) CSSSkewX {
	return CSSSkewX{
		is_2d_: true
		ax_: ax
	}
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssskewx-cssskewx
pub fn CSSSkewX.construct_impl(ax CSSNumericValue) !CSSSkewX {
	// The CSSSkewX(ax) constructor must, when invoked, perform the following steps:

	// 1. If ax does not match <angle>, throw a TypeError.
	if !ax.type_().matches_angle(none) {
		return error("CSSSkewX ax component doesn't match <angle>")
	}

	// 2. Return a new CSSSkewX object with its ax internal slot set to ax, and its is2D internal slot set to true.
	return CSSSkewX.create(ax)
}

pub fn (skew CSSSkewX) is_2d() bool {
	return skew.is_2d_
}

pub fn (skew CSSSkewX) ax() CSSNumericValue {
	return skew.ax_
}

// https://drafts.css-houdini.org/css-typed-om-1/#serialize-a-cssskewx
pub fn (skew CSSSkewX) to_string() !string {
	// 1. Let s initially be "skewX(".
	mut serialized := 'skewX('

	// 2. Serialize this’s ax internal slot, and append it to s.
	serialized += skew.ax_.to_string()

	// 3. Append ")" to s, and return s.
	serialized += ')'
	return serialized
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-csstransformcomponent-tomatrix
pub fn (skew CSSSkewX) to_matrix() !DOMMatrix {
	// 1. Let matrix be a new DOMMatrix object, initialized to this’s equivalent 4x4 transform matrix, as defined in
	//    CSS Transforms 1 § 12. Mathematical Description of Transform Functions, and with its is2D internal slot set
	//    to the same value as this’s is2D internal slot.
	//    NOTE: Recall that the is2D flag affects what transform, and thus what equivalent matrix, a
	//          CSSTransformComponent represents.
	//    As the entries of such a matrix are defined relative to the px unit, if any <length>s in this involved in
	//    generating the matrix are not compatible units with px (such as relative lengths or percentages), throw a
	//    TypeError.
	mut matrix := DOMMatrix.create()

	// NB: to() throws a TypeError if the conversion can't be done.
	ax_rad := skew.ax_.to('rad')!.value()
	matrix.set_m21(math.tan(ax_rad))

	// 2. Return matrix.
	return matrix
}

pub fn (mut skew CSSSkewX) set_ax(ax CSSNumericValue) ! {
	// AD-HOC: Not specced. https://github.com/w3c/css-houdini-drafts/issues/1153
	//         WPT expects this to throw for invalid values.
	if !ax.type_().matches_angle(none) {
		return error("CSSSkewX ax component doesn't match <angle>")
	}
	skew.ax_ = ax
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssskew-is2d
pub fn (mut skew CSSSkewX) set_is_2d(value bool) {
	_ = value
	// The is2D attribute of a CSSSkewX, CSSSkewXX, or CSSSkewXY object must, on setting, do nothing.
}

pub fn (skew CSSSkewX) create_style_value(property PropertyNameAndID) !TransformationStyleValue {
	return TransformationStyleValue.create(transform_property_from_property(property), .skew_x, [
		skew.ax_.create_an_internal_representation(property, .no)!,
	])
}

// --- CSSSkewY ---
pub struct CSSSkewY {
pub mut:
	is_2d_ bool = true
	ay_    CSSNumericValue
}

pub fn CSSSkewY.create(ay CSSNumericValue) CSSSkewY {
	return CSSSkewY{
		is_2d_: true
		ay_: ay
	}
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssskewy-cssskewy
pub fn CSSSkewY.construct_impl(ay CSSNumericValue) !CSSSkewY {
	// The CSSSkewY(ay) constructor must, when invoked, perform the following steps:

	// 1. If ay does not match <angle>, throw a TypeError.
	if !ay.type_().matches_angle(none) {
		return error("CSSSkewY ay component doesn't match <angle>")
	}

	// 2. Return a new CSSSkewY object with its ay internal slot set to ay, and its is2D internal slot set to true.
	return CSSSkewY.create(ay)
}

pub fn (skew CSSSkewY) is_2d() bool {
	return skew.is_2d_
}

pub fn (skew CSSSkewY) ay() CSSNumericValue {
	return skew.ay_
}

// https://drafts.css-houdini.org/css-typed-om-1/#serialize-a-cssskewy
pub fn (skew CSSSkewY) to_string() !string {
	// 1. Let s initially be "skewY(".
	mut serialized := 'skewY('

	// 2. Serialize this’s ay internal slot, and append it to s.
	serialized += skew.ay_.to_string()

	// 3. Append ")" to s, and return s.
	serialized += ')'
	return serialized
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-csstransformcomponent-tomatrix
pub fn (skew CSSSkewY) to_matrix() !DOMMatrix {
	// 1. Let matrix be a new DOMMatrix object, initialized to this’s equivalent 4x4 transform matrix, as defined in
	//    CSS Transforms 1 § 12. Mathematical Description of Transform Functions, and with its is2D internal slot set
	//    to the same value as this’s is2D internal slot.
	//    NOTE: Recall that the is2D flag affects what transform, and thus what equivalent matrix, a
	//          CSSTransformComponent represents.
	//    As the entries of such a matrix are defined relative to the px unit, if any <length>s in this involved in
	//    generating the matrix are not compatible units with px (such as relative lengths or percentages), throw a
	//    TypeError.
	mut matrix := DOMMatrix.create()

	// NB: to() throws a TypeError if the conversion can't be done.
	ay_rad := skew.ay_.to('rad')!.value()
	matrix.set_m12(math.tan(ay_rad))

	// 2. Return matrix.
	return matrix
}

pub fn (mut skew CSSSkewY) set_ay(ay CSSNumericValue) ! {
	// AD-HOC: Not specced. https://github.com/w3c/css-houdini-drafts/issues/1153
	//         WPT expects this to throw for invalid values.
	if !ay.type_().matches_angle(none) {
		return error("CSSSkewY ay component doesn't match <angle>")
	}
	skew.ay_ = ay
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssskew-is2d
pub fn (mut skew CSSSkewY) set_is_2d(value bool) {
	_ = value
	// The is2D attribute of a CSSSkewY, CSSSkewYX, or CSSSkewYY object must, on setting, do nothing.
}

pub fn (skew CSSSkewY) create_style_value(property PropertyNameAndID) !TransformationStyleValue {
	return TransformationStyleValue.create(transform_property_from_property(property), .skew_y, [
		skew.ay_.create_an_internal_representation(property, .no)!,
	])
}

// --- CSSTransformValue ---
pub struct CSSTransformValue {
pub mut:
	transforms_ []CSSTransformComponent
}

pub fn CSSTransformValue.create(transforms []CSSTransformComponent) CSSTransformValue {
	return CSSTransformValue{
		transforms_: transforms
	}
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-csstransformvalue-csstransformvalue
pub fn CSSTransformValue.construct_impl(transforms []CSSTransformComponent) !CSSTransformValue {
	// The CSSTransformValue(transforms) constructor must, when called, perform the following steps:

	// 1. If transforms is empty, throw a TypeError.
	if transforms.len == 0 {
		return error("CSSTransformValue's transforms list cannot be empty.")
	}

	// 2. Return a new CSSTransformValue whose values to iterate over is transforms.
	return CSSTransformValue.create(transforms.clone())
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-csstransformvalue-length
pub fn (value CSSTransformValue) length() u32 {
	// The length attribute indicates how many transform components are contained within the CSSTransformValue.
	return u32(value.transforms_.len)
}

// https://drafts.css-houdini.org/css-typed-om-1/#ref-for-dfn-determine-the-value-of-an-indexed-property%E2%91%A0
pub fn (value CSSTransformValue) item_value(index int) ?CSSTransformComponent {
	// To determine the value of an indexed property of a CSSTransformValue this and an index n, let values be this’s
	// [[values]] internal slot, and return values[n].
	if index < 0 || index >= value.transforms_.len {
		return none
	}
	return value.transforms_[index]
}

fn transform_component_from_value(value CSSTransformComponent) !CSSTransformComponent {
	return value
}

// https://drafts.css-houdini.org/css-typed-om-1/#ref-for-dfn-set-the-value-of-an-existing-indexed-property%E2%91%A0
pub fn (mut value CSSTransformValue) set_value_of_existing_indexed_property(n u32, new_value CSSTransformComponent) ! {
	// To set the value of an existing indexed property of a CSSTransformValue this, an index n, and a value new value,
	// let values be this’s [[values]] internal slot, and set values[n] to new value.
	value.transforms_[int(n)] = transform_component_from_value(new_value)!
}

// https://drafts.css-houdini.org/css-typed-om-1/#ref-for-dfn-set-the-value-of-a-new-indexed-property①
pub fn (mut value CSSTransformValue) set_value_of_new_indexed_property(n u32, new_value CSSTransformComponent) ! {
	// To set the value of a new indexed property of a CSSTransformValue this, an index n, and a value new value, let
	// values be this’s [[values]] internal slot. If n is not equal to the size of values, throw a RangeError.
	// Otherwise, append new value to values.
	if int(n) != value.transforms_.len {
		return error('Index out of range')
	}

	value.transforms_ << transform_component_from_value(new_value)!
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-csstransformvalue-is2d
pub fn (value CSSTransformValue) is_2d() bool {
	// The is2D attribute of a CSSTransformValue this must, on getting, return true if, for each func in this’s values
	// to iterate over, the func’s is2D attribute would return true; otherwise, the attribute returns false.
	for transform in value.transforms_ {
		if !transform.is_2d() {
			return false
		}
	}
	return true
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-csstransformvalue-tomatrix
pub fn (value CSSTransformValue) to_matrix() !DOMMatrix {
	// The toMatrix() method of a CSSTransformValue this must, when called, perform the following steps:

	// 1. Let matrix be a new DOMMatrix, initialized to the identity matrix, with its is2D internal slot set to true.
	mut matrix := DOMMatrix.create()

	// 2. For each func in this’s values to iterate over:
	for function in value.transforms_ {
		// 1. Let funcMatrix be the DOMMatrix returned by calling toMatrix() on func.
		// AD-HOC: This can throw exceptions.
		function_matrix := function.to_matrix()!

		// 2. Set matrix to the result of multiplying matrix and the matrix represented by funcMatrix.
		matrix.multiply_self(function_matrix)!
	}

	// 3. Return matrix.
	return matrix
}

// https://drafts.css-houdini.org/css-typed-om-1/#serialize-a-csstransformvalue
pub fn (value CSSTransformValue) to_string() !string {
	// 1. Return the result of serializing each item in this’s values to iterate over, then concatenating them
	//    separated by " ".
	mut parts := []string{}
	for transform in value.transforms_ {
		parts << transform.to_string()!
	}
	return parts.join(' ')
}

// https://drafts.css-houdini.org/css-typed-om-1/#create-an-internal-representation
pub fn (value CSSTransformValue) create_an_internal_representation(property PropertyNameAndID, perform_type_check PerformTypeCheck) !StyleValue {
	// NB: This can become <transform-function> or <transform-list>, and we don't know which is wanted without performing the type checking.
	//     We can worry about that if and when we ever do have a CSSTransformValue that isn't top-level.
	if perform_type_check != .yes {
		panic('VERIFY_NOT_REACHED')
	}

	// If value is a CSSStyleValue subclass,
	//     If value does not match the grammar of a list-valued property iteration of property, throw a TypeError.
	//
	//     If any component of property’s CSS grammar has a limited numeric range, and the corresponding part of value
	//     is a CSSUnitValue that is outside of that range, replace that value with the result of wrapping it in a
	//     fresh CSSMathSum whose values internal slot contains only that part of value.
	//
	//     Return the value.

	// NB: We match <transform-function> if we have 1 transform. We match <transform-list> always.
	if value.transforms_.len == 1 && transform_property_accepts_type(property, .transform_function) {
		return StyleValue(value.transforms_[0].create_style_value(property)!)
	}

	if transform_property_accepts_type(property, .transform_list) {
		mut transforms := []StyleValue{cap: value.transforms_.len}
		for transform in value.transforms_ {
			transforms << StyleValue(transform.create_style_value(property)!)
		}
		return StyleValue(StyleValueList.create(transforms, .space, .yes))
	}

	return error('Property does not accept values of this type.')
}

// --- TransformationStyleValue ---
pub enum TransformProperty {
	transform
	rotate
	scale
	translate
}

pub fn transform_property_from_property(property PropertyNameAndID) TransformProperty {
	return match to_ascii_lowercase(property.name()) {
		'rotate' { TransformProperty.rotate }
		'scale' { TransformProperty.scale }
		'translate' { TransformProperty.translate }
		else { TransformProperty.transform }
	}
}

fn transform_property_accepts_type(property PropertyNameAndID, value_type ValueType) bool {
	name := to_ascii_lowercase(property.name())
	if name == 'transform' {
		return value_type == .transform_function || value_type == .transform_list
	}
	if name in ['rotate', 'scale', 'translate'] {
		return value_type == .transform_function
	}
	if property_id := property.id() {
		return property_accepts_type(property_id, value_type)
	}
	return false
}

pub struct TransformationStyleValue {
pub mut:
	property_           TransformProperty
	transform_function_ TransformFunction
	values_             StyleValueVector
}

pub fn TransformationStyleValue.create(property TransformProperty, transform_function TransformFunction, values StyleValueVector) TransformationStyleValue {
	return TransformationStyleValue{
		property_: property
		transform_function_: transform_function
		values_: values
	}
}

pub fn (style_value TransformationStyleValue) transform_function() TransformFunction {
	return style_value.transform_function_
}

pub fn (style_value TransformationStyleValue) values() StyleValueVector {
	return style_value.values_
}

pub enum TransformationStyleValueListSeparator {
	space
}

pub struct TransformationStyleValueList {
pub mut:
	values_    []TransformationStyleValue
	separator_ TransformationStyleValueListSeparator
}

pub fn TransformationStyleValueList.create(values []TransformationStyleValue, separator TransformationStyleValueListSeparator) TransformationStyleValueList {
	return TransformationStyleValueList{
		values_: values
		separator_: separator
	}
}

pub fn (list TransformationStyleValueList) serialize(mode SerializationMode) string {
	mut parts := []string{}
	for value in list.values_ {
		parts << value.serialize(mode)
	}
	return parts.join(' ')
}

pub fn (list TransformationStyleValueList) to_string() string {
	return list.serialize(.normal)
}

// Paintable::compute_transform() consumes the already-computed typed value and
// the layout node's length context. This avoids re-running the compatibility
// cascade and re-parsing transform text from the typed layout adapter.
pub fn resolve_computed_transform_2d_matrix(computed &ComputedProperties, reference_width f64, reference_height f64) ?[6]f64 {
	matrix := resolve_computed_transform_4x4_matrix(computed, reference_width, reference_height) or {
		return none
	}
	return extract_2d_affine_transform(matrix)
}

pub fn resolve_computed_transform_4x4_matrix(computed &ComputedProperties, reference_width f64,
	reference_height f64) ?FloatMatrix4x4 {
	// ViewportPaintable::compute_transform() composes the individual transform
	// properties before the legacy transform list, in this exact order.
	mut transformations := []TransformationStyleValue{}
	for property_id in [PropertyID.translate, .rotate, .scale] {
		value := computed.property(property_id, .yes) or { continue }
		parsed := style_value_logic_from_dom(property_id, value) or { return none }
		if parsed is TransformationStyleValue {
			transformations << parsed
		} else if !(parsed.is_keyword() && parsed.to_keyword() == .none_) {
			return none
		}
	}
	if value := computed.property(.transform, .yes) {
		parsed := style_value_logic_from_dom(.transform, value) or { return none }
		if parsed is TransformationStyleValue {
			transformations << parsed
		} else if parsed is StyleValueList {
			for item in parsed.values() {
				if item !is TransformationStyleValue {
					return none
				}
				transformations << (item as TransformationStyleValue)
			}
		} else if !(parsed.is_keyword() && parsed.to_keyword() == .none_) {
			return none
		}
	}
	return resolve_transformations_4x4_matrix(transformations, reference_width, reference_height, computed.length_resolution_context())
}

pub fn extract_2d_affine_transform(matrix FloatMatrix4x4) ?[6]f64 {
	if matrix.m13 != 0 || matrix.m23 != 0 || matrix.m31 != 0 || matrix.m32 != 0
		|| matrix.m33 != 1 || matrix.m34 != 0 || matrix.m43 != 0 || matrix.m44 != 1 {
		return none
	}
	return [f64(matrix.m11), matrix.m21, matrix.m12, matrix.m22, matrix.m14, matrix.m24]!
}

// Project the element's local z=0 plane when the homogeneous divisor is
// constant. This preserves rotateX/rotateY/translateZ in the compact 2D native
// renderer; matrices with perspective remain in the 4x4 context for culling.
pub fn project_plane_to_affine_transform(matrix FloatMatrix4x4) ?[6]f64 {
	if matrix.m41 != 0 || matrix.m42 != 0 || matrix.m44 == 0 {
		return none
	}
	scale := 1.0 / matrix.m44
	return [f64(matrix.m11 * scale), matrix.m21 * scale, matrix.m12 * scale, matrix.m22 * scale,
		matrix.m14 * scale, matrix.m24 * scale]!
}

fn resolve_transformations_4x4_matrix(transformations []TransformationStyleValue,
	reference_width f64, reference_height f64,
	length_context LengthResolutionContext) ?FloatMatrix4x4 {
	paintable_box := TransformPaintableBox{
		reference_box: TransformReferenceBox{
			width: CSSPixels.nearest_value_for(reference_width)
			height: CSSPixels.nearest_value_for(reference_height)
		}
		length_resolution_context: length_context
	}
	mut result := FloatMatrix4x4.identity()
	for transformation in transformations {
		matrix := transformation.to_matrix(paintable_box) or { return none }
		result = result.multiply(matrix)
	}
	return result
}

pub fn TransformationStyleValue.identity_transformation(transform_function TransformFunction) TransformationStyleValue {
	// https://drafts.csswg.org/css-transforms-1/#identity-transform-function
	// A transform function that is equivalent to a identity 4x4 matrix (see Mathematical Description of Transform
	// Functions). Examples for identity transform functions are translate(0), translateX(0), translateY(0), scale(1),
	// scaleX(1), scaleY(1), rotate(0), skew(0, 0), skewX(0), skewY(0) and matrix(1, 0, 0, 1, 0, 0).

	// https://drafts.csswg.org/css-transforms-2/#identity-transform-function
	// In addition to the identity transform function in CSS Transforms, examples for identity transform functions
	// include translate3d(0, 0, 0), translateZ(0), scaleZ(1), rotate3d(1, 1, 1, 0), rotateX(0), rotateY(0), rotateZ(0)
	// and matrix3d(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1). A special case is perspective: perspective(none).
	// The value of m34 becomes infinitesimal small and the transform function is therefore assumed to be equal to the
	// identity matrix.
	number_zero := StyleValue(NumberStyleValue.create(0.0))
	number_one := StyleValue(NumberStyleValue.create(1.0))
	zero_angle := StyleValue(AngleStyleValue.create(Angle.make_degrees(0.0)))
	zero_length := StyleValue(LengthStyleValue.create(Length.make_px(0.0)))

	identity_parameters := match transform_function {
		.matrix {
			[number_one, number_zero, number_zero, number_one, number_zero, number_zero]
		}
		.matrix3d {
			[number_one, number_zero, number_zero, number_zero, number_zero, number_one, number_zero,
				number_zero, number_zero, number_zero, number_one, number_zero, number_zero,
				number_zero, number_zero, number_one]
		}
		.perspective {
			[StyleValue(CustomIdentStyleValue.create('none'))]
		}
		.rotate, .rotate_x, .rotate_y, .rotate_z {
			[zero_angle]
		}
		.rotate3d {
			[number_one, number_one, number_one, zero_angle]
		}
		.skew, .skew_x, .skew_y, .translate, .translate_x, .translate_y, .translate_z {
			[zero_length]
		}
		.translate3d {
			[zero_length, zero_length, zero_length]
		}
		.scale, .scale_x, .scale_y, .scale_z {
			[number_one]
		}
		.scale3d {
			[number_one, number_one, number_one]
		}
	}

	return TransformationStyleValue.create(.transform, transform_function, identity_parameters)
}

fn (style_value TransformationStyleValue) length_to_px(length Length, paintable_box ?TransformPaintableBox) !f64 {
	if box := paintable_box {
		return length.to_px(box.length_resolution_context).to_double()
	}
	if length.is_absolute() {
		return length.absolute_length_to_px().to_double()
	}
	return error('Transform contains non absolute units')
}

fn (style_value TransformationStyleValue) get_value(argument_index int, reference_length ?CSSPixels, paintable_box ?TransformPaintableBox) !f64 {
	transformation_value := style_value.values_[argument_index]
	function_metadata := transform_function_metadata(style_value.transform_function_)
	mut context := CalculationResolutionContext{}
	if box := paintable_box {
		context.length_resolution_context = box.length_resolution_context
	}
	if reference := reference_length {
		context.percentage_basis = Length.make_css_px(reference)
	}

	if transformation_value.is_calculated() {
		calculated := transformation_value.as_calculated()
		match function_metadata.parameters[argument_index].type_ {
			.angle {
				if !calculated.resolves_to_angle() {
					return error("Calculated angle parameter to transform function doesn't resolve to an angle.")
				}
				if resolved := calculated.resolve_angle(context) {
					return resolved.to_radians()
				}
				return error("Couldn't resolve calculated angle.")
			}
			.length, .length_none {
				if !calculated.resolves_to_length() {
					return error("Calculated length parameter to transform function doesn't resolve to a length.")
				}
				if resolved := calculated.resolve_length(context) {
					return style_value.length_to_px(resolved, paintable_box)
				}
				return error("Couldn't resolve calculated length.")
			}
			.length_percentage {
				if !calculated.resolves_to_length_percentage() {
					return error("Calculated length-percentage parameter to transform function doesn't resolve to a length-percentage.")
				}
				if resolved := calculated.resolve_length(context) {
					return style_value.length_to_px(resolved, paintable_box)
				}
				return error("Couldn't resolve calculated length-percentage.")
			}
			.number {
				if !calculated.resolves_to_number() {
					return error("Calculated number parameter to transform function doesn't resolve to a number.")
				}
				if resolved := calculated.resolve_number(context) {
					return resolved
				}
				return error("Couldn't resolve calculated number.")
			}
			.number_percentage {
				if calculated.resolves_to_number() {
					if resolved := calculated.resolve_number(context) {
						return resolved
					}
					return error("Couldn't resolve calculated number.")
				}
				if calculated.resolves_to_percentage() {
					if resolved := calculated.resolve_percentage(context) {
						return resolved.as_fraction()
					}
					return error("Couldn't resolve calculated percentage.")
				}
				return error("Calculated number/percentage parameter to transform function doesn't resolve to a number or percentage.")
			}
		}
	}

	if transformation_value.is_length() {
		return style_value.length_to_px(transformation_value.as_length().length(), paintable_box)
	}

	if transformation_value.is_percentage() {
		if function_metadata.parameters[argument_index].type_ == .number_percentage {
			return transformation_value.as_percentage().percentage().as_fraction()
		}
		reference := reference_length or {
			return error("Can't resolve percentage to length without a reference value.")
		}

		return style_value.length_to_px(Length.make_css_px(reference).percentage_of(transformation_value.as_percentage().percentage()), paintable_box)
	}

	if transformation_value.is_number() {
		return transformation_value.as_number().number()
	}

	if transformation_value.is_angle() {
		return transformation_value.as_angle().angle().to_radians()
	}

	return error('Unsupported value in transform function: ${transformation_value.to_string()}')
}

pub fn (style_value TransformationStyleValue) to_matrix(paintable_box ?TransformPaintableBox) !FloatMatrix4x4 {
	count := style_value.values_.len

	mut width := ?CSSPixels(none)
	mut height := ?CSSPixels(none)
	if box := paintable_box {
		reference_box := box.transform_reference_box()
		width = reference_box.width
		height = reference_box.height
	}

	match style_value.transform_function_ {
		.perspective {
			// https://drafts.csswg.org/css-transforms-2/#perspective
			if count == 1 {
				if style_value_is_keyword_none(style_value.values_[0]) {
					return FloatMatrix4x4.identity()
				}

				// FIXME: Add support for the 'perspective-origin' CSS property.
				mut distance := style_value.get_value(0, none, paintable_box)!
				// If the depth value is less than '1px', it must be treated as '1px' for the purpose of rendering, for
				// computing the resolved value of 'transform', and when used as the endpoint of interpolation.
				// Note: The intent of the above rules on values less than '1px' is that they cover the cases where
				// the 'perspective()' function needs to be converted into a matrix.
				if distance < 1 {
					distance = 1
				}
				return FloatMatrix4x4.from_values(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, -1.0 / distance, 1)
			}
		}
		.matrix {
			if count == 6 {
				return FloatMatrix4x4.from_values(style_value.get_value(0, none, paintable_box)!, style_value.get_value(2, none, paintable_box)!, 0, style_value.get_value(4, none, paintable_box)!, style_value.get_value(1, none, paintable_box)!, style_value.get_value(3, none, paintable_box)!, 0, style_value.get_value(5, none, paintable_box)!, 0, 0, 1, 0, 0, 0, 0, 1)
			}
		}
		.matrix3d {
			if count == 16 {
				return FloatMatrix4x4.from_values(style_value.get_value(0, none, paintable_box)!, style_value.get_value(4, none, paintable_box)!, style_value.get_value(8, none, paintable_box)!, style_value.get_value(12, none, paintable_box)!, style_value.get_value(1, none, paintable_box)!, style_value.get_value(5, none, paintable_box)!, style_value.get_value(9, none, paintable_box)!, style_value.get_value(13, none, paintable_box)!, style_value.get_value(2, none, paintable_box)!, style_value.get_value(6, none, paintable_box)!, style_value.get_value(10, none, paintable_box)!, style_value.get_value(14, none, paintable_box)!, style_value.get_value(3, none, paintable_box)!, style_value.get_value(7, none, paintable_box)!, style_value.get_value(11, none, paintable_box)!, style_value.get_value(15, none, paintable_box)!)
			}
		}
		.translate {
			if count == 1 {
				return FloatMatrix4x4.from_values(1, 0, 0, style_value.get_value(0, width, paintable_box)!, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
			}
			if count == 2 {
				return FloatMatrix4x4.from_values(1, 0, 0, style_value.get_value(0, width, paintable_box)!, 0, 1, 0, style_value.get_value(1, height, paintable_box)!, 0, 0, 1, 0, 0, 0, 0, 1)
			}
		}
		.translate3d {
			return FloatMatrix4x4.from_values(1, 0, 0, style_value.get_value(0, width, paintable_box)!, 0, 1, 0, style_value.get_value(1, height, paintable_box)!, 0, 0, 1, style_value.get_value(2, none, paintable_box)!, 0, 0, 0, 1)
		}
		.translate_x {
			if count == 1 {
				return FloatMatrix4x4.from_values(1, 0, 0, style_value.get_value(0, width, paintable_box)!, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
			}
		}
		.translate_y {
			if count == 1 {
				return FloatMatrix4x4.from_values(1, 0, 0, 0, 0, 1, 0, style_value.get_value(0, height, paintable_box)!, 0, 0, 1, 0, 0, 0, 0, 1)
			}
		}
		.translate_z {
			if count == 1 {
				return FloatMatrix4x4.from_values(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, style_value.get_value(0, none, paintable_box)!, 0, 0, 0, 1)
			}
		}
		.scale {
			if count == 1 {
				value := style_value.get_value(0, none, paintable_box)!
				return FloatMatrix4x4.from_values(value, 0, 0, 0, 0, value, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
			}
			if count == 2 {
				return FloatMatrix4x4.from_values(style_value.get_value(0, none, paintable_box)!, 0, 0, 0, 0, style_value.get_value(1, none, paintable_box)!, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
			}
		}
		.scale3d {
			if count == 3 {
				return FloatMatrix4x4.from_values(style_value.get_value(0, none, paintable_box)!, 0, 0, 0, 0, style_value.get_value(1, none, paintable_box)!, 0, 0, 0, 0, style_value.get_value(2, none, paintable_box)!, 0, 0, 0, 0, 1)
			}
		}
		.scale_x {
			if count == 1 {
				return FloatMatrix4x4.from_values(style_value.get_value(0, none, paintable_box)!, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
			}
		}
		.scale_y {
			if count == 1 {
				return FloatMatrix4x4.from_values(1, 0, 0, 0, 0, style_value.get_value(0, none, paintable_box)!, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
			}
		}
		.scale_z {
			if count == 1 {
				return FloatMatrix4x4.from_values(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, style_value.get_value(0, none, paintable_box)!, 0, 0, 0, 0, 1)
			}
		}
		.rotate3d {
			if count == 4 {
				axis := FloatVector3{
					x: style_value.get_value(0, none, paintable_box)!
					y: style_value.get_value(1, none, paintable_box)!
					z: style_value.get_value(2, none, paintable_box)!
				}
				epsilon := 1e-5
				if axis.length() < epsilon {
					return FloatMatrix4x4.identity()
				}
				return rotation_matrix(axis.normalized(), style_value.get_value(3, none, paintable_box)!)
			}
		}
		.rotate_x {
			if count == 1 {
				return rotation_matrix(FloatVector3{
					x: 1.0
					y: 0.0
					z: 0.0
				}, style_value.get_value(0, none, paintable_box)!)
			}
		}
		.rotate_y {
			if count == 1 {
				return rotation_matrix(FloatVector3{
					x: 0.0
					y: 1.0
					z: 0.0
				}, style_value.get_value(0, none, paintable_box)!)
			}
		}
		.rotate, .rotate_z {
			if count == 1 {
				return rotation_matrix(FloatVector3{
					x: 0.0
					y: 0.0
					z: 1.0
				}, style_value.get_value(0, none, paintable_box)!)
			}
		}
		.skew {
			if count == 1 {
				return FloatMatrix4x4.from_values(1, math.tan(style_value.get_value(0, none, paintable_box)!), 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
			}
			if count == 2 {
				return FloatMatrix4x4.from_values(1, math.tan(style_value.get_value(0, none, paintable_box)!), 0, 0, math.tan(style_value.get_value(1, none, paintable_box)!), 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
			}
		}
		.skew_x {
			if count == 1 {
				return FloatMatrix4x4.from_values(1, math.tan(style_value.get_value(0, none, paintable_box)!), 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
			}
		}
		.skew_y {
			if count == 1 {
				return FloatMatrix4x4.from_values(1, 0, 0, 0, math.tan(style_value.get_value(0, none, paintable_box)!), 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
			}
		}
	}

	return FloatMatrix4x4.identity()
}

fn resolve_number_style_value_to_string(value StyleValue, mode SerializationMode) string {
	mut raw_value := ?f64(none)

	if value.is_number() {
		raw_value = value.as_number().number()
	}
	if value.is_percentage() {
		raw_value = value.as_percentage().percentage().as_fraction()
	}
	if value.is_calculated() {
		if value.as_calculated().resolves_to_number() {
			if resolved := value.as_calculated().resolve_number(CalculationResolutionContext{}) {
				raw_value = resolved
			}
		}
		if value.as_calculated().resolves_to_percentage() {
			if resolved := value.as_calculated().resolve_percentage(CalculationResolutionContext{}) {
				raw_value = resolved.as_fraction()
			}
		}
	}

	if resolved := raw_value {
		return serialize_a_number(resolved)
	}

	return value.to_string_with_mode(mode)
}

fn resolve_translate_style_value_to_string(value StyleValue, mode SerializationMode) ?string {
	string_value := value.to_string_with_mode(mode)

	if string_value == '0px' {
		return none
	}

	return string_value
}

pub fn (style_value TransformationStyleValue) serialize(mode SerializationMode) string {
	// https://drafts.csswg.org/css-transforms-2/#individual-transform-serialization
	if style_value.property_ == .rotate {
		// NOTE: Serialize simple rotations directly.
		match style_value.transform_function_ {
			// If the axis is parallel with the x or y axes, it must serialize as the appropriate keyword.
			.rotate_x {
				return 'x ${style_value.values_[0].to_string_with_mode(mode)}'
			}
			.rotate_y {
				return 'y ${style_value.values_[0].to_string_with_mode(mode)}'
			}

			// If a rotation about the z axis (that is, in 2D) is specified, the property must serialize as just an <angle>.
			.rotate, .rotate_z {
				return style_value.values_[0].to_string_with_mode(mode)
			}
			else {}
		}

		if style_value.values_.len >= 4 {
			rotation_x := style_value.values_[0]
			rotation_y := style_value.values_[1]
			rotation_z := style_value.values_[2]
			angle := style_value.values_[3]

			mut x_value := 0.0
			mut y_value := 0.0
			mut z_value := 0.0
			if rotation_x.is_number() {
				x_value = rotation_x.as_number().number()
			}
			if rotation_y.is_number() {
				y_value = rotation_y.as_number().number()
			}
			if rotation_z.is_number() {
				z_value = rotation_z.as_number().number()
			}

			// If the axis is parallel with the x or y axes, it must serialize as the appropriate keyword.
			if x_value > 0.0 && y_value == 0 && z_value == 0 {
				return 'x ${angle.to_string_with_mode(mode)}'
			}

			if x_value == 0 && y_value > 0.0 && z_value == 0 {
				return 'y ${angle.to_string_with_mode(mode)}'
			}

			// If a rotation about the z axis (that is, in 2D) is specified, the property must serialize as just an <angle>.
			if x_value == 0 && y_value == 0 && z_value > 0.0 {
				return angle.to_string_with_mode(mode)
			}

			// It must serialize as the keyword none if and only if none was originally specified.
			// NOTE: This is handled by returning a keyword from the parser.

			// If any other rotation is specified, the property must serialize with an axis specified.
			return '${rotation_x.to_string_with_mode(mode)} ${rotation_y.to_string_with_mode(mode)} ${rotation_z.to_string_with_mode(mode)} ${angle.to_string_with_mode(mode)}'
		}
	}
	if style_value.property_ == .scale && style_value.values_.len > 0 {
		x_value := resolve_number_style_value_to_string(style_value.values_[0], mode)
		y_value := if style_value.values_.len > 1 {
			resolve_number_style_value_to_string(style_value.values_[1], mode)
		} else {
			x_value
		}
		mut z_value := ?string(none)
		if style_value.values_.len == 3 && (!style_value.values_[2].is_number() || style_value.values_[2].as_number().number() != 1) {
			z_value = resolve_number_style_value_to_string(style_value.values_[2], mode)
		}

		mut serialized := x_value
		if x_value != y_value || (z_value != none && z_value or { '' } != '1') {
			serialized += ' ${y_value}'
		}
		if actual_z := z_value {
			if actual_z != '1' {
				serialized += ' ${actual_z}'
			}
		}
		return serialized
	}
	if style_value.property_ == .translate && style_value.values_.len > 0 {
		x_value := resolve_translate_style_value_to_string(style_value.values_[0], mode)
		y_value := if style_value.values_.len > 1 {
			resolve_translate_style_value_to_string(style_value.values_[1], mode)
		} else {
			?string(none)
		}
		mut z_value := ?string(none)
		if style_value.values_.len == 3 && (!style_value.values_[2].is_length() || style_value.values_[2].as_length().length() != Length.make_px(0)) {
			z_value = resolve_translate_style_value_to_string(style_value.values_[2], mode)
		}

		mut serialized := x_value or { '0px' }
		if y_value != none || z_value != none {
			serialized += ' ${y_value or { '0px' }}'
		}
		if actual_z := z_value {
			serialized += ' ${actual_z}'
		}
		return serialized
	}

	mut serialized := style_value.transform_function_.to_string()
	serialized += '('
	for i, value in style_value.values_ {
		// https://www.w3.org/TR/css-transforms-2/#individual-transforms
		// A <percentage> is equivalent to a <number>, for example scale: 100% is equivalent to scale: 1.
		// Numbers are used during serialization of specified and computed values.
		if (style_value.transform_function_ == .scale || style_value.transform_function_ == .scale3d || style_value.transform_function_ == .scale_x || style_value.transform_function_ == .scale_y || style_value.transform_function_ == .scale_z) && value.is_percentage() {
			serialized += serialize_a_number(value.as_percentage().percentage().as_fraction())
		} else {
			serialized += value.to_string_with_mode(mode)
		}

		if i != style_value.values_.len - 1 {
			serialized += ', '
		}
	}
	serialized += ')'
	return serialized
}

pub fn (style_value TransformationStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

// https://drafts.css-houdini.org/css-typed-om-1/#reify-a-transform-function
pub fn (style_value TransformationStyleValue) reify_a_transform_function() !CSSTransformComponent {
	reify_numeric_argument := fn [style_value] (index int) !CSSNumericValue {
		reified := style_value.values_[index].reify('')
		if numeric := reified.numeric_value_ {
			return numeric
		}
		return error('Unable to reify transform argument as CSSNumericValue')
	}
	reify_0 := fn () CSSNumericValue {
		return CSSUnitValue.create(0, 'number')
	}
	reify_1 := fn () CSSNumericValue {
		return CSSUnitValue.create(1, 'number')
	}
	reify_0px := fn () CSSNumericValue {
		return CSSUnitValue.create(0, 'px')
	}
	reify_0deg := fn () CSSNumericValue {
		return CSSUnitValue.create(0, 'deg')
	}

	// To reify a <transform-function> func, perform the appropriate set of steps below, based on func:
	match style_value.transform_function_ {
		// -> matrix()
		// -> matrix3d()
		//    1. Return a new CSSMatrixComponent object, whose matrix internal slot is set to a 4x4 matrix representing the
		//       same information as func, and whose is2D internal slot is true if func is matrix(), and false otherwise.
		.matrix, .matrix3d {
			transform_as_matrix := style_value.to_matrix(none)!
			mut matrix := DOMMatrix.create()
			matrix.set_m11(transform_as_matrix.at(0, 0))
			matrix.set_m12(transform_as_matrix.at(1, 0))
			matrix.set_m13(transform_as_matrix.at(2, 0))
			matrix.set_m14(transform_as_matrix.at(3, 0))
			matrix.set_m21(transform_as_matrix.at(0, 1))
			matrix.set_m22(transform_as_matrix.at(1, 1))
			matrix.set_m23(transform_as_matrix.at(2, 1))
			matrix.set_m24(transform_as_matrix.at(3, 1))
			matrix.set_m31(transform_as_matrix.at(0, 2))
			matrix.set_m32(transform_as_matrix.at(1, 2))
			matrix.set_m33(transform_as_matrix.at(2, 2))
			matrix.set_m34(transform_as_matrix.at(3, 2))
			matrix.set_m41(transform_as_matrix.at(0, 3))
			matrix.set_m42(transform_as_matrix.at(1, 3))
			matrix.set_m43(transform_as_matrix.at(2, 3))
			matrix.set_m44(transform_as_matrix.at(3, 3))

			is_2d := if style_value.transform_function_ == .matrix {
				CSSTransformComponentIs2D.yes
			} else {
				CSSTransformComponentIs2D.no
			}
			return CSSTransformComponent(CSSMatrixComponent.create(is_2d, matrix))
		}

		// -> translate()
		// -> translateX()
		// -> translateY()
		// -> translate3d()
		// -> translateZ()
		//    1. Return a new CSSTranslate object, whose x, y, and z internal slots are set to the reification of the
		//       specified x/y/z offsets, or the reification of 0px if not specified in func, and whose is2D internal slot
		//       is true if func is translate(), translateX(), or translateY(), and false otherwise.
		.translate {
			// NB: Default y to 0px if it's not specified.
			y := if style_value.values_.len > 1 { reify_numeric_argument(1)! } else { reify_0px() }
			return CSSTransformComponent(CSSTranslate.create(.yes, reify_numeric_argument(0)!, y, reify_0px()))
		}
		.translate_x {
			return CSSTransformComponent(CSSTranslate.create(.yes, reify_numeric_argument(0)!, reify_0px(), reify_0px()))
		}
		.translate_y {
			return CSSTransformComponent(CSSTranslate.create(.yes, reify_0px(), reify_numeric_argument(0)!, reify_0px()))
		}
		.translate3d {
			return CSSTransformComponent(CSSTranslate.create(.no, reify_numeric_argument(0)!, reify_numeric_argument(1)!, reify_numeric_argument(2)!))
		}
		.translate_z {
			return CSSTransformComponent(CSSTranslate.create(.no, reify_0px(), reify_0px(), reify_numeric_argument(0)!))
		}

		// -> scale()
		// -> scaleX()
		// -> scaleY()
		// -> scale3d()
		// -> scaleZ()
		//    1. Return a new CSSScale object, whose x, y, and z internal slots are set to the specified x/y/z scales, or
		//       to 1 if not specified in func and whose is2D internal slot is true if func is scale(), scaleX(), or
		//       scaleY(), and false otherwise.
		.scale {
			// NB: Default y to a copy of x if it's not specified.
			y := if style_value.values_.len > 1 {
				reify_numeric_argument(1)!
			} else {
				reify_numeric_argument(0)!
			}
			return CSSTransformComponent(CSSScale.create(.yes, reify_numeric_argument(0)!, y, reify_1()))
		}
		.scale_x {
			return CSSTransformComponent(CSSScale.create(.yes, reify_numeric_argument(0)!, reify_1(), reify_1()))
		}
		.scale_y {
			return CSSTransformComponent(CSSScale.create(.yes, reify_1(), reify_numeric_argument(0)!, reify_1()))
		}
		.scale3d {
			return CSSTransformComponent(CSSScale.create(.no, reify_numeric_argument(0)!, reify_numeric_argument(1)!, reify_numeric_argument(2)!))
		}
		.scale_z {
			return CSSTransformComponent(CSSScale.create(.no, reify_1(), reify_1(), reify_numeric_argument(0)!))
		}

		// -> rotate()
		// -> rotate3d()
		// -> rotateX()
		// -> rotateY()
		// -> rotateZ()
		//    1. Return a new CSSRotate object, whose angle internal slot is set to the reification of the specified angle,
		//       and whose x, y, and z internal slots are set to the specified rotation axis coordinates, or the implicit
		//       axis coordinates if not specified in func and whose is2D internal slot is true if func is rotate(), and
		//       false otherwise.
		.rotate {
			return CSSTransformComponent(CSSRotate.create(.yes, reify_0(), reify_0(), reify_1(), reify_numeric_argument(0)!))
		}
		.rotate3d {
			return CSSTransformComponent(CSSRotate.create(.no, reify_numeric_argument(0)!, reify_numeric_argument(1)!, reify_numeric_argument(2)!, reify_numeric_argument(3)!))
		}
		.rotate_x {
			return CSSTransformComponent(CSSRotate.create(.no, reify_1(), reify_0(), reify_0(), reify_numeric_argument(0)!))
		}
		.rotate_y {
			return CSSTransformComponent(CSSRotate.create(.no, reify_0(), reify_1(), reify_0(), reify_numeric_argument(0)!))
		}
		.rotate_z {
			return CSSTransformComponent(CSSRotate.create(.no, reify_0(), reify_0(), reify_1(), reify_numeric_argument(0)!))
		}

		// -> skew()
		//    1. Return a new CSSSkew object, whose ax and ay internal slots are set to the reification of the specified x
		//       and y angles, or the reification of 0deg if not specified in func, and whose is2D internal slot is true.
		.skew {
			// NB: Default y to 0deg if it's not specified.
			y := if style_value.values_.len > 1 { reify_numeric_argument(1)! } else { reify_0deg() }
			return CSSTransformComponent(CSSSkew.create(reify_numeric_argument(0)!, y))
		}

		// -> skewX()
		//    1. Return a new CSSSkewX object, whose ax internal slot is set to the reification of the specified x angle,
		//       or the reification of 0deg if not specified in func, and whose is2D internal slot is true.
		.skew_x {
			return CSSTransformComponent(CSSSkewX.create(reify_numeric_argument(0)!))
		}

		// -> skewY()
		//    1. Return a new CSSSkewY object, whose ay internal slot is set to the reification of the specified y angle,
		//       or the reification of 0deg if not specified in func, and whose is2D internal slot is true.
		.skew_y {
			return CSSTransformComponent(CSSSkewY.create(reify_numeric_argument(0)!))
		}

		// -> perspective()
		//    1. Return a new CSSPerspective object, whose length internal slot is set to the reification of the specified
		//       length (see reify a numeric value if it is a length, and reify an identifier if it is the keyword none)
		//       and whose is2D internal slot is false.
		.perspective {
			if style_value_is_keyword_none(style_value.values_[0]) {
				return CSSTransformComponent(CSSPerspective.create(CSSKeywordValue.create('none')))
			}
			return CSSTransformComponent(CSSPerspective.create(css_perspective_internal_from_numeric(reify_numeric_argument(0)!)))
		}
	}
}

pub fn (style_value TransformationStyleValue) absolutized(computation_context ComputationContext) TransformationStyleValue {
	mut absolutized_values := StyleValueVector{}

	mut absolutized_values_different := false

	for index, value in style_value.values_ {
		mut absolutized_value := value.absolutized(computation_context)
		scale := computation_context.length_resolution_context.absolute_length_scale
		if scale != 1 && value is NumberStyleValue {
			if (style_value.transform_function_ == .matrix && index in [4, 5])
				|| (style_value.transform_function_ == .matrix3d && index in [12, 13, 14]) {
				absolutized_value = StyleValue(NumberStyleValue.create(value.number() * scale))
			} else if style_value.transform_function_ == .matrix3d && index in [3, 7, 11] {
				absolutized_value = StyleValue(NumberStyleValue.create(value.number() / scale))
			}
		}

		if absolutized_value != value {
			absolutized_values_different = true
		}

		absolutized_values << absolutized_value
	}

	if !absolutized_values_different {
		return style_value
	}

	return TransformationStyleValue.create(style_value.property_, style_value.transform_function_, absolutized_values)
}

pub fn (style_value TransformationStyleValue) properties_equal(other TransformationStyleValue) bool {
	if style_value.property_ != other.property_ || style_value.transform_function_ != other.transform_function_ || style_value.values_.len != other.values_.len {
		return false
	}
	for index, value in style_value.values_ {
		if !value.equals(other.values_[index]) {
			return false
		}
	}
	return true
}
