module geometry

import math

fn near(a f64, b f64) bool {
	return math.abs(a - b) < 1e-9
}

fn test_inverse_of_identity() {
	inv := DOMMatrixReadOnly.create().inverse()
	assert inv.is_identity()
	assert inv.is_2d()
}

fn test_inverse_of_translation() {
	// The inverse of translate(10, 20) is translate(-10, -20).
	translated := DOMMatrixReadOnly.create().translate(10.0, 20.0, none)
	inv := translated.inverse()
	assert near(inv.e(), -10.0)
	assert near(inv.f(), -20.0)
	assert inv.is_2d()
}

fn test_inverse_of_scale() {
	// The inverse of scale(2, 4) is scale(1/2, 1/4).
	scaled := DOMMatrixReadOnly.create().scale(2.0, 4.0, none, none, none, none)
	inv := scaled.inverse()
	assert near(inv.a(), 0.5)
	assert near(inv.d(), 0.25)
}

fn test_inverse_round_trips_through_transform_point() {
	// Applying a composed matrix and then its inverse returns the original point.
	matrix := DOMMatrixReadOnly.create().translate(10.0, 20.0, none).scale(2.0, 3.0, none, none,
		none, none)
	inv := matrix.inverse()
	moved := matrix.transform_point_from_init(DOMPointInit{ x: 7.0, y: 9.0 })
	restored := inv.transform_point_from_init(DOMPointInit{
		x: moved.x()
		y: moved.y()
		z: moved.z()
		w: moved.w()
	})
	assert near(restored.x(), 7.0)
	assert near(restored.y(), 9.0)
}

fn test_inverse_does_not_modify_source() {
	base := DOMMatrixReadOnly.create().translate(5.0, 6.0, none)
	_ := base.inverse()
	// The read-only source keeps its original translation.
	assert base.e() == 5.0 && base.f() == 6.0
}

fn test_non_invertible_becomes_nan_and_3d() {
	// scale(0) has a zero determinant, so it is not invertible.
	singular := DOMMatrixReadOnly.create().scale(0.0, none, none, none, none, none)
	inv := singular.inverse()
	assert math.is_nan(inv.m11())
	assert math.is_nan(inv.m44())
	assert !inv.is_2d()
}

fn test_invert_self_mutates_in_place() {
	mut matrix := DOMMatrix.create()
	matrix.translate_self(3.0, 4.0, none)
	matrix.invert_self()
	assert near(matrix.e(), -3.0)
	assert near(matrix.f(), -4.0)
}
