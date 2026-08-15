module geometry

fn test_scale_uniform_2d() {
	base := DOMMatrixReadOnly.create()
	// scale(2): scaleY follows scaleX, so both axes scale by 2; stays 2D.
	scaled := base.scale(2.0, none, none, none, none, none)
	assert scaled.a() == 2.0 && scaled.d() == 2.0
	assert scaled.is_2d()
	point := scaled.transform_point_from_init(DOMPointInit{ x: 3.0, y: 4.0 })
	assert point.x() == 6.0 && point.y() == 8.0
}

fn test_scale_non_uniform_axes() {
	base := DOMMatrixReadOnly.create()
	scaled := base.scale(2.0, 3.0, none, none, none, none)
	point := scaled.transform_point_from_init(DOMPointInit{ x: 1.0, y: 1.0 })
	assert point.x() == 2.0 && point.y() == 3.0
}

fn test_scale_with_origin() {
	// Scaling by 2 about the origin (10, 10): the fixed point stays put.
	base := DOMMatrixReadOnly.create()
	scaled := base.scale(2.0, none, none, 10.0, 10.0, none)
	fixed := scaled.transform_point_from_init(DOMPointInit{ x: 10.0, y: 10.0 })
	assert fixed.x() == 10.0 && fixed.y() == 10.0
	// A point at (11, 10) moves to (12, 10) — twice as far from the origin.
	moved := scaled.transform_point_from_init(DOMPointInit{ x: 11.0, y: 10.0 })
	assert moved.x() == 12.0 && moved.y() == 10.0
}

fn test_scale_z_clears_is_2d() {
	base := DOMMatrixReadOnly.create()
	// A scaleZ other than 1 makes the matrix 3D.
	scaled := base.scale(1.0, 1.0, 2.0, none, none, none)
	assert !scaled.is_2d()
	// scaleZ of exactly 1 stays 2D.
	flat := base.scale(2.0, 2.0, 1.0, none, none, none)
	assert flat.is_2d()
}

fn test_scale_non_uniform_defaults_y_to_one() {
	base := DOMMatrixReadOnly.create()
	// scaleNonUniform(2): scaleY defaults to 1 (not to scaleX).
	scaled := base.scale_non_uniform(2.0, none)
	point := scaled.transform_point_from_init(DOMPointInit{ x: 1.0, y: 1.0 })
	assert point.x() == 2.0 && point.y() == 1.0
}

fn test_scale3d_uniform() {
	base := DOMMatrixReadOnly.create()
	scaled := base.scale3d(2.0, none, none, none)
	assert !scaled.is_2d() // a uniform 3D scale != 1 is 3D
	point := scaled.transform_point_from_init(DOMPointInit{ x: 1.0, y: 1.0, z: 1.0 })
	assert point.x() == 2.0 && point.y() == 2.0 && point.z() == 2.0
}

fn test_skew_x_shears_x_by_y() {
	base := DOMMatrixReadOnly.create()
	// skewX(45deg): x' = x + tan(45)*y = x + y.
	skewed := base.skew_x(45.0)
	point := skewed.transform_point_from_init(DOMPointInit{ x: 1.0, y: 2.0 })
	// tan(45) is ~1, allow for floating point error.
	assert math_abs(point.x() - 3.0) < 1e-9
	assert point.y() == 2.0
	assert skewed.is_2d()
}

fn test_skew_y_shears_y_by_x() {
	base := DOMMatrixReadOnly.create()
	// skewY(45deg): y' = y + tan(45)*x = y + x.
	skewed := base.skew_y(45.0)
	point := skewed.transform_point_from_init(DOMPointInit{ x: 2.0, y: 1.0 })
	assert point.x() == 2.0
	assert math_abs(point.y() - 3.0) < 1e-9
}

fn math_abs(v f64) f64 {
	return if v < 0.0 { -v } else { v }
}
