// Copyright (c) 2023-2024, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// DOMMatrix inverse (DOMMatrixReadOnly.inverse / DOMMatrix.invertSelf). The 4x4 inverse is the adjugate
// divided by the determinant, computed with the same cofactor expansion Gfx::Matrix uses. A matrix with
// a zero determinant is not invertible: every element is set to NaN and is2D is cleared.
// https://drafts.fxtf.org/geometry/#dom-dommatrix-invertself
module geometry

import math

// Convert the fixed 4x4 rows into a dynamic n x n matrix (each row independently allocated) for the
// generic recursive cofactor routines, and back.
fn mat4_to_dynamic(rows [4][4]f64) [][]f64 {
	mut m := [][]f64{len: 4}
	for i in 0 .. 4 {
		mut row := []f64{len: 4}
		for j in 0 .. 4 {
			row[j] = rows[i][j]
		}
		m[i] = row
	}
	return m
}

fn dynamic_to_mat4(m [][]f64) [4][4]f64 {
	mut rows := [4][4]f64{}
	for i in 0 .. 4 {
		for j in 0 .. 4 {
			rows[i][j] = m[i][j]
		}
	}
	return rows
}

// The determinant of an n x n matrix by cofactor expansion along the first row (matches Gfx::Matrix).
fn matrix_determinant(m [][]f64) f64 {
	n := m.len
	if n == 1 {
		return m[0][0]
	}
	mut result := 0.0
	mut sign := 1.0
	for j in 0 .. n {
		result += sign * m[0][j] * matrix_first_minor(m, 0, j)
		sign = -sign
	}
	return result
}

// The first minor: the determinant of the submatrix with skip_row and skip_column removed.
fn matrix_first_minor(m [][]f64, skip_row int, skip_column int) f64 {
	n := m.len
	mut sub := [][]f64{}
	for i in 0 .. n {
		if i == skip_row {
			continue
		}
		mut row := []f64{}
		for j in 0 .. n {
			if j == skip_column {
				continue
			}
			row << m[i][j]
		}
		sub << row
	}
	return matrix_determinant(sub)
}

// The adjugate: the transposed cofactor matrix (adjugate[j][i] = (-1)^(i+j) * first_minor(i, j)).
fn matrix_adjugate(m [][]f64) [][]f64 {
	n := m.len
	mut adjugate := [][]f64{len: n}
	for i in 0 .. n {
		adjugate[i] = []f64{len: n}
	}
	for i in 0 .. n {
		for j in 0 .. n {
			sign := if (i + j) % 2 == 0 { 1.0 } else { -1.0 }
			adjugate[j][i] = sign * matrix_first_minor(m, i, j)
		}
	}
	return adjugate
}

// The inverse (adjugate / determinant), or none when the determinant is 0 (not invertible).
fn matrix_inverse(m [][]f64) ?[][]f64 {
	det := matrix_determinant(m)
	if det == 0.0 {
		return none
	}
	n := m.len
	adjugate := matrix_adjugate(m)
	mut result := [][]f64{len: n}
	for i in 0 .. n {
		mut row := []f64{len: n}
		for j in 0 .. n {
			row[j] = adjugate[i][j] / det
		}
		result[i] = row
	}
	return result
}

// https://drafts.fxtf.org/geometry/#dom-dommatrix-invertself — invert in place, or become an all-NaN,
// non-2D matrix when not invertible.
pub fn (mut matrix DOMMatrix) invert_self() &DOMMatrix {
	if inverse := matrix_inverse(mat4_to_dynamic(matrix.to_rows())) {
		matrix.apply_rows(dynamic_to_mat4(inverse))
	} else {
		nan := math.nan()
		matrix.apply_rows([
			[nan, nan, nan, nan]!,
			[nan, nan, nan, nan]!,
			[nan, nan, nan, nan]!,
			[nan, nan, nan, nan]!,
		]!)
		matrix.is_2d_ = false
	}
	return matrix
}

// https://drafts.fxtf.org/geometry/#dom-dommatrixreadonly-inverse — the inverse as a new matrix; this
// matrix is not modified.
pub fn (matrix &DOMMatrixReadOnly) inverse() &DOMMatrix {
	mut result := DOMMatrix.create_from_dom_matrix_read_only(matrix)
	return result.invert_self()
}
