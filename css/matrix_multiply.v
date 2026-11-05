module css

import os
import sync.stdatomic

const retain_accessor_matrix_multiply = os.getenv('VOX_RETAIN_ACCESSOR_MATRIX_MULTIPLY') != ''
const matrix_multiply_diagnostics = os.getenv('VOX_MATRIX_MULTIPLY_DIAGNOSTICS') != ''

__global matrix_multiply_reported stdatomic.AtomicVal[bool]

// Preserve the original zero-initialized, left-to-right accumulation. In
// particular, do not omit zero terms or reassociate products for affine/identity
// inputs: non-finite values and signed zero keep their existing behavior.
@[inline]
fn matrix_dot_product_4(a0 f64, a1 f64, a2 f64, a3 f64, b0 f64, b1 f64, b2 f64, b3 f64) f64 {
	mut value := 0.0
	value += a0 * b0
	value += a1 * b1
	value += a2 * b2
	value += a3 * b3
	return value
}

pub fn (left FloatMatrix4x4) multiply(right FloatMatrix4x4) FloatMatrix4x4 {
	if retain_accessor_matrix_multiply { return left.multiply_with_accessors(right) }
	if matrix_multiply_diagnostics && matrix_multiply_reported.compare_and_swap(false, true) {
		eprintln('Vox matrix multiply: direct field dot products')
	}
	return FloatMatrix4x4{
		m11: matrix_dot_product_4(left.m11, left.m12, left.m13, left.m14, right.m11, right.m21, right.m31, right.m41)
		m12: matrix_dot_product_4(left.m11, left.m12, left.m13, left.m14, right.m12, right.m22, right.m32, right.m42)
		m13: matrix_dot_product_4(left.m11, left.m12, left.m13, left.m14, right.m13, right.m23, right.m33, right.m43)
		m14: matrix_dot_product_4(left.m11, left.m12, left.m13, left.m14, right.m14, right.m24, right.m34, right.m44)
		m21: matrix_dot_product_4(left.m21, left.m22, left.m23, left.m24, right.m11, right.m21, right.m31, right.m41)
		m22: matrix_dot_product_4(left.m21, left.m22, left.m23, left.m24, right.m12, right.m22, right.m32, right.m42)
		m23: matrix_dot_product_4(left.m21, left.m22, left.m23, left.m24, right.m13, right.m23, right.m33, right.m43)
		m24: matrix_dot_product_4(left.m21, left.m22, left.m23, left.m24, right.m14, right.m24, right.m34, right.m44)
		m31: matrix_dot_product_4(left.m31, left.m32, left.m33, left.m34, right.m11, right.m21, right.m31, right.m41)
		m32: matrix_dot_product_4(left.m31, left.m32, left.m33, left.m34, right.m12, right.m22, right.m32, right.m42)
		m33: matrix_dot_product_4(left.m31, left.m32, left.m33, left.m34, right.m13, right.m23, right.m33, right.m43)
		m34: matrix_dot_product_4(left.m31, left.m32, left.m33, left.m34, right.m14, right.m24, right.m34, right.m44)
		m41: matrix_dot_product_4(left.m41, left.m42, left.m43, left.m44, right.m11, right.m21, right.m31, right.m41)
		m42: matrix_dot_product_4(left.m41, left.m42, left.m43, left.m44, right.m12, right.m22, right.m32, right.m42)
		m43: matrix_dot_product_4(left.m41, left.m42, left.m43, left.m44, right.m13, right.m23, right.m33, right.m43)
		m44: matrix_dot_product_4(left.m41, left.m42, left.m43, left.m44, right.m14, right.m24, right.m34, right.m44)
	}
}
