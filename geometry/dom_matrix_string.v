// Copyright (c) 2023-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// DOMMatrix CSS transform parsing and stringification. The translated CSS
// parser is the same typed parser boundary used by the rest of libweb_v.
module geometry

import css
import math

struct ParsedDOMMatrix {
	rows  [4][4]f64
	is_2d bool
}

fn float_matrix_rows(matrix css.FloatMatrix4x4) [4][4]f64 {
	return [
		[matrix.m11, matrix.m12, matrix.m13, matrix.m14]!,
		[matrix.m21, matrix.m22, matrix.m23, matrix.m24]!,
		[matrix.m31, matrix.m32, matrix.m33, matrix.m34]!,
		[matrix.m41, matrix.m42, matrix.m43, matrix.m44]!,
	]!
}

fn transform_function_is_2d(function css.TransformFunction) bool {
	return function in [.matrix, .translate, .translate_x, .translate_y, .scale, .scale_x, .scale_y,
		.rotate, .skew, .skew_x, .skew_y]
}

fn parse_dom_matrix_init_string(source string) !ParsedDOMMatrix {
	text := if source == '' { 'matrix(1, 0, 0, 1, 0, 0)' } else { source }
	parsed := css.parse_dom_matrix_init_string_value_logic(text) or {
		return error('SyntaxError: Failed to parse CSS transform string')
	}
	mut rows := diagonal_rows(1, 1, 1, 1)
	mut is_2d := true
	if parsed is css.KeywordStyleValue {
		if parsed.keyword() != .none_ {
			return error('SyntaxError: Failed to parse CSS transform string')
		}
		return ParsedDOMMatrix{
			rows:  rows
			is_2d: true
		}
	}
	if parsed !is css.StyleValueList {
		return error('SyntaxError: Failed to parse CSS transform string')
	}
	list := parsed as css.StyleValueList
	for item in list.values() {
		if item !is css.TransformationStyleValue {
			return error('SyntaxError: Failed to parse CSS transform string')
		}
		transformation := item as css.TransformationStyleValue
		// Lengths without absolute units have no reference box to resolve against.
		if !transformation.can_be_converted_to_matrix_without_reference_box() {
			return error('SyntaxError: Failed to parse CSS transform string')
		}
		if !transform_function_is_2d(transformation.transform_function()) {
			is_2d = false
		}
		function_matrix := transformation.to_matrix(none) or {
			return error('SyntaxError: Failed to parse CSS transform string: ${err.msg()}')
		}
		rows = mat4_multiply(rows, float_matrix_rows(function_matrix))
	}
	return ParsedDOMMatrix{
		rows:  rows
		is_2d: is_2d
	}
}

// The DOMString constructor is exposed only in a Window realm upstream. The
// explicit flag preserves that observable restriction without importing a
// LibJS global-object hierarchy.
pub fn DOMMatrixReadOnly.construct_from_string(init string, is_window bool) !&DOMMatrixReadOnly {
	if !is_window {
		return error('TypeError: DOMMatrix string construction is only available in a Window context')
	}
	parsed := parse_dom_matrix_init_string(init)!
	if parsed.is_2d {
		return DOMMatrixReadOnly.create_2d(parsed.rows[0][0], parsed.rows[1][0], parsed.rows[0][1],
			parsed.rows[1][1], parsed.rows[0][3], parsed.rows[1][3])
	}
	return dom_matrix_read_only_from_rows(parsed.rows, false)
}

pub fn DOMMatrix.construct_from_string(init string, is_window bool) !&DOMMatrix {
	read_only := DOMMatrixReadOnly.construct_from_string(init, is_window)!
	return DOMMatrix.create_from_dom_matrix_read_only(read_only)
}

fn dom_matrix_read_only_from_rows(rows [4][4]f64, is_2d bool) &DOMMatrixReadOnly {
	return &DOMMatrixReadOnly{
		m11_:   rows[0][0]
		m12_:   rows[1][0]
		m13_:   rows[2][0]
		m14_:   rows[3][0]
		m21_:   rows[0][1]
		m22_:   rows[1][1]
		m23_:   rows[2][1]
		m24_:   rows[3][1]
		m31_:   rows[0][2]
		m32_:   rows[1][2]
		m33_:   rows[2][2]
		m34_:   rows[3][2]
		m41_:   rows[0][3]
		m42_:   rows[1][3]
		m43_:   rows[2][3]
		m44_:   rows[3][3]
		is_2d_: is_2d
	}
}

pub fn DOMMatrixReadOnly.from_float32_array(values []f32) !&DOMMatrixReadOnly {
	mut converted := []f64{len: values.len}
	for index, value in values {
		converted[index] = f64(value)
	}
	return DOMMatrixReadOnly.construct(converted)
}

pub fn DOMMatrixReadOnly.from_float64_array(values []f64) !&DOMMatrixReadOnly {
	return DOMMatrixReadOnly.construct(values)
}

pub fn DOMMatrix.from_float32_array(values []f32) !&DOMMatrix {
	read_only := DOMMatrixReadOnly.from_float32_array(values)!
	return DOMMatrix.create_from_dom_matrix_read_only(read_only)
}

pub fn DOMMatrix.from_float64_array(values []f64) !&DOMMatrix {
	read_only := DOMMatrixReadOnly.from_float64_array(values)!
	return DOMMatrix.create_from_dom_matrix_read_only(read_only)
}

pub fn (mut matrix DOMMatrix) set_matrix_value(transform_list string) !&DOMMatrix {
	parsed := parse_dom_matrix_init_string(transform_list)!
	matrix.apply_rows(parsed.rows)
	matrix.is_2d_ = parsed.is_2d
	return matrix
}

fn normalize_exponent(value string) string {
	index := value.index('e') or { return value }
	mantissa := value[..index]
	mut exponent := value[index + 1..].clone()
	mut sign := ''
	if exponent.starts_with('+') || exponent.starts_with('-') {
		sign = exponent[..1]
		exponent = exponent[1..]
	}
	exponent = exponent.trim_left('0')
	if exponent == '' {
		exponent = '0'
	}
	return '${mantissa}e${sign}${exponent}'
}

fn expand_scientific(value string) string {
	index := value.index('e') or { return value }
	mut mantissa := value[..index].clone()
	exponent := value[index + 1..].int()
	mut sign := ''
	if mantissa.starts_with('-') {
		sign = '-'
		mantissa = mantissa[1..]
	}
	dot := mantissa.index('.') or { mantissa.len }
	digits := mantissa.replace('.', '')
	decimal_position := dot + exponent
	if decimal_position <= 0 {
		return '${sign}0.${'0'.repeat(-decimal_position)}${digits}'
	}
	if decimal_position >= digits.len {
		return '${sign}${digits}${'0'.repeat(decimal_position - digits.len)}'
	}
	return '${sign}${digits[..decimal_position]}.${digits[decimal_position..]}'
}

// Compact ECMAScript-number formatting boundary used by DOMMatrix's
// stringifier. It preserves JS's integer and negative-zero spellings and V's
// shortest round-trip mantissa for non-integral values.
fn js_number_to_string(value f64) string {
	if value == 0 {
		return '0'
	}
	absolute := math.abs(value)
	mut serialized := value.str()
	if absolute >= 1e-6 && absolute < 1e21 {
		serialized = expand_scientific(serialized)
		if serialized.ends_with('.0') {
			serialized = serialized[..serialized.len - 2]
		}
		return serialized
	}
	return normalize_exponent(serialized)
}

pub fn (matrix &DOMMatrixReadOnly) to_string() !string {
	values := matrix.to_float64_array()
	for value in values {
		if math.is_nan(value) || math.is_inf(value, 0) {
			return error('InvalidStateError: Cannot stringify non-finite matrix values')
		}
	}
	if matrix.is_2d_ {
		return 'matrix(${js_number_to_string(matrix.m11_)}, ${js_number_to_string(matrix.m12_)}, ${js_number_to_string(matrix.m21_)}, ${js_number_to_string(matrix.m22_)}, ${js_number_to_string(matrix.m41_)}, ${js_number_to_string(matrix.m42_)})'
	}
	return 'matrix3d(${values.map(js_number_to_string(it)).join(', ')})'
}
