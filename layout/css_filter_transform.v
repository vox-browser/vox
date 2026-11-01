module layout

import math
import painting

// The shell filters an already transformed source bitmap. For a similarity
// transform, Gaussian blur commutes with that transform after scaling sigma;
// shadow offsets must follow its linear part, without its translation.
fn compatibility_transformed_css_filter(filter painting.GfxFilter, transform [6]f64) painting.GfxFilter {
	matrix := normalized_affine(transform)
	if matrix[0] == 1 && matrix[1] == 0 && matrix[2] == 0 && matrix[3] == 1 {
		return filter
	}
	x_squared := matrix[0] * matrix[0] + matrix[1] * matrix[1]
	y_squared := matrix[2] * matrix[2] + matrix[3] * matrix[3]
	dot := matrix[0] * matrix[2] + matrix[1] * matrix[3]
	tolerance := 1e-9 * math.max(x_squared, y_squared)
	if !(x_squared > 0) || math.is_inf(x_squared, 0) || math.is_nan(y_squared)
		|| math.is_inf(y_squared, 0) || math.abs(x_squared - y_squared) > tolerance
		|| math.abs(dot) > tolerance {
		// An anisotropic or skewed filter needs a separate local-space surface.
		// Keep its existing fallback until that surface is represented.
		return filter
	}
	if !filter.operations.any(it.kind in ['blur', 'drop-shadow']) { return filter }
	scale := math.sqrt(x_squared)
	mut operations := []painting.GfxFilterOperation{cap: filter.operations.len}
	for operation in filter.operations {
		if operation.kind == 'blur' {
			operations << painting.GfxFilterOperation{ ...operation, first: operation.first * scale }
		} else if operation.kind == 'drop-shadow' {
			x := operation.first
			y := operation.second
			operations << painting.GfxFilterOperation{
				...operation
				first: matrix[0] * x + matrix[2] * y
				second: matrix[1] * x + matrix[3] * y
				third: operation.third * scale
			}
		} else {
			operations << operation
		}
	}
	return painting.GfxFilter{ ...filter, operations: operations }
}
