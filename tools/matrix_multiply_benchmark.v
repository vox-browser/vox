// Component diagnostic. Fixture/oracle construction is outside the counters.
module main

import css
import math
import processmetrics

struct MatrixProductCase {
	left     css.FloatMatrix4x4
	right    css.FloatMatrix4x4
	expected css.FloatMatrix4x4
}

fn matrix_from_cells(v [16]f64) css.FloatMatrix4x4 {
	return css.FloatMatrix4x4.from_values(v[0], v[1], v[2], v[3], v[4], v[5], v[6], v[7],
		v[8], v[9], v[10], v[11], v[12], v[13], v[14], v[15])
}

fn reference_matrix_product(left css.FloatMatrix4x4, right css.FloatMatrix4x4) css.FloatMatrix4x4 {
	mut values := [16]f64{}
	for row in 0 .. 4 {
		for column in 0 .. 4 {
			mut value := 0.0
			for index in 0 .. 4 { value += left.at(row, index) * right.at(index, column) }
			values[row * 4 + column] = value
		}
	}
	return matrix_from_cells(values)
}

// Keep repeated fixture operations from being folded out of the counted loop.
// This common call overhead is included in both variants.
@[noinline]
fn measured_matrix_product(left css.FloatMatrix4x4, right css.FloatMatrix4x4) css.FloatMatrix4x4 {
	return left.multiply(right)
}

fn measure_matrix_scene(name string, inputs []MatrixProductCase) {
	mut checksum := u64(14695981039346656037)
	start := processmetrics.instruction_snapshot()
	for _ in 0 .. 2048 {
		for input in inputs {
			actual := measured_matrix_product(input.left, input.right)
			for row in 0 .. 4 {
				for column in 0 .. 4 {
					a := actual.at(row, column)
					b := input.expected.at(row, column)
					if math.is_nan(b) {
						assert math.is_nan(a)
						checksum = (checksum ^ u64(0x7ff8000000000000)) * u64(1099511628211)
					} else {
						bits := math.f64_bits(a)
						assert bits == math.f64_bits(b)
						checksum = (checksum ^ bits) * u64(1099511628211)
					}
				}
			}
		}
	}
	instructions := processmetrics.instruction_snapshot().since(start) or { panic('counter unavailable') }
	println('{"scene":"${name}","instructions":${instructions},"products":${inputs.len * 2048},"checksum":${checksum}}')
}

fn main() {
	for scene in ['identity', 'affine', 'perspective-rotation', 'dense', 'nonfinite'] {
		mut inputs := []MatrixProductCase{}
		for index in 0 .. 16 {
			mut left := css.FloatMatrix4x4{}
			mut right := css.FloatMatrix4x4{}
			match scene {
				'identity' {
					right = css.translation_matrix_4x4(f64(index) * 0.25, -f64(index), 3)
				}
				'affine' {
					left = css.FloatMatrix4x4{
						m11: 1 + f64(index) / 16
						m12: 0.125
						m21: -0.25
						m22: 2
						m14: f64(index) * 3
						m24: -f64(index)
					}
					right = css.translation_matrix_4x4(f64(index) / 7, 4, -2)
				}
				'perspective-rotation' {
					angle := f64(index) / 7
					left = css.FloatMatrix4x4{ m43: -1 / f64(index + 1) }
					right = css.FloatMatrix4x4{
						m11: math.cos(angle)
						m12: -math.sin(angle)
						m21: math.sin(angle)
						m22: math.cos(angle)
						m14: f64(index)
					}
				}
				'dense' {
					mut a := [16]f64{}
					mut b := [16]f64{}
					for cell in 0 .. 16 {
						a[cell] = f64((cell * 173 + index * 31) % 2001 - 1000) / 128
						b[cell] = f64((cell * 31 + index * 173) % 2001 - 1000) / 128
					}
					left = matrix_from_cells(a)
					right = matrix_from_cells(b)
				}
				else {
					left.m11 = if index % 3 == 0 {
						math.inf(1)
					} else if index % 3 == 1 {
						math.f64_from_bits(u64(0x7ff8000000001234))
					} else {
						math.f64_from_bits(u64(1) << 63)
					}
					right = css.translation_matrix_4x4(f64(index), -3, 7)
				}
			}
			inputs << MatrixProductCase{left, right, reference_matrix_product(left, right)}
		}
		// Warm the selected public path before the counters and diagnostics.
		_ = measured_matrix_product(inputs[0].left, inputs[0].right)
		measure_matrix_scene(scene, inputs)
	}
}
