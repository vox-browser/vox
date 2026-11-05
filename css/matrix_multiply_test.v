module css

import math
import platform

fn matrix_test_from_cells(values [16]f64) FloatMatrix4x4 {
	return FloatMatrix4x4.from_values(values[0], values[1], values[2], values[3],
		values[4], values[5], values[6], values[7], values[8], values[9], values[10], values[11],
		values[12], values[13], values[14], values[15])
}

fn assert_matrix_product_matches_accessors(left FloatMatrix4x4, right FloatMatrix4x4) {
	expected := left.multiply_with_accessors(right)
	actual := left.multiply(right)
	for row in 0 .. 4 {
		for column in 0 .. 4 {
			a := actual.at(row, column)
			b := expected.at(row, column)
			if math.is_nan(b) {
				assert math.is_nan(a)
			} else {
				assert math.f64_bits(a) == math.f64_bits(b), '${row},${column}: ${a} versus ${b}'
			}
		}
	}
}

fn test_direct_matrix_product_preserves_noncommuting_transform_order() {
	left := FloatMatrix4x4.from_values(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16)
	right := FloatMatrix4x4.from_values(-3, -2, -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12)
	expected := FloatMatrix4x4.from_values(50, 60, 70, 80, 98, 124, 150, 176,
		146, 188, 230, 272, 194, 252, 310, 368)
	assert left.multiply(right) == expected
	scale := FloatMatrix4x4.from_values(2, 0, 0, 0, 0, 3, 0, 0, 0, 0, 4, 0, 0, 0, 0, 1)
	translate := translation_matrix_4x4(5, 7, 11)
	a := scale.multiply(translate)
	b := translate.multiply(scale)
	assert a.m14 == 10 && a.m24 == 21 && a.m34 == 44
	assert b.m14 == 5 && b.m24 == 7 && b.m34 == 11
	assert_matrix_product_matches_accessors(left, left)
	assert_matrix_product_matches_accessors(right, left)
}

fn test_direct_matrix_product_covers_all_basis_matrix_pairs() {
	for left_index in 0 .. 16 {
		for right_index in 0 .. 16 {
			mut left := [16]f64{}
			mut right := [16]f64{}
			mut expected := [16]f64{}
			left[left_index] = 1
			right[right_index] = 1
			if left_index % 4 == right_index / 4 {
				expected[(left_index / 4) * 4 + right_index % 4] = 1
			}
			assert matrix_test_from_cells(left).multiply(matrix_test_from_cells(right)) == matrix_test_from_cells(expected)
		}
	}
}

fn test_direct_matrix_product_keeps_finite_bits_and_nonfinite_classification() {
	mut seed := u64(0x123456789abcdef)
	for iteration in 0 .. 1024 {
		mut left := [16]f64{}
		mut right := [16]f64{}
		for index in 0 .. 16 {
			seed = seed * u64(6364136223846793005) + 1
			left[index] = math.f64_from_bits(if iteration % 2 == 0 {
				(seed & u64(0x800fffffffffffff)) | (u64(1013 + index) << 52)
			} else {
				seed
			})
			seed = seed * u64(6364136223846793005) + 1
			right[index] = math.f64_from_bits(if iteration % 2 == 0 {
				(seed & u64(0x800fffffffffffff)) | (u64(1029 - index) << 52)
			} else {
				seed
			})
		}
		assert_matrix_product_matches_accessors(matrix_test_from_cells(left), matrix_test_from_cells(right))
	}
	for value in [math.inf(1), math.inf(-1), math.f64_from_bits(u64(0x7ff8000000001234)),
		math.f64_from_bits(1), math.f64_from_bits(u64(1) << 63), f64(0)] {
		mut cells := [16]f64{init: value}
		assert_matrix_product_matches_accessors(FloatMatrix4x4.identity(), matrix_test_from_cells(cells))
		assert_matrix_product_matches_accessors(matrix_test_from_cells(cells), FloatMatrix4x4.identity())
		cells[3] = 1
		assert_matrix_product_matches_accessors(matrix_test_from_cells(cells), matrix_test_from_cells(cells))
	}
}

fn test_direct_matrix_product_keeps_zero_accumulation_and_needs_no_arena_storage() {
	negative_zero := math.f64_from_bits(u64(1) << 63)
	zeros := matrix_test_from_cells([16]f64{init: negative_zero})
	ones := matrix_test_from_cells([16]f64{init: f64(1)})
	product := zeros.multiply(ones)
	for row in 0 .. 4 {
		for column in 0 .. 4 {
			assert math.f64_bits(product.at(row, column)) == 0
		}
	}
	mut left := FloatMatrix4x4.identity()
	before := platform.thread_arena_usage().used
	mut checksum := f64(0)
	for index in 0 .. 4096 {
		left.m14 = f64(index)
		result := left.multiply(ones)
		checksum += result.m14
	}
	assert checksum > 0
	$if prealloc {
		assert platform.thread_arena_usage().used == before
	}
}
