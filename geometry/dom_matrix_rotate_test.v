module geometry

import math

fn approx(a f64, b f64) bool {
	return math.abs(a - b) < 1e-9
}

fn test_rotate_z_90_degrees() {
	base := DOMMatrixReadOnly.create()
	// rotate(90): a single argument rotates about Z. (1, 0) -> (0, 1); the epsilon clamp makes it exact.
	rotated := base.rotate(90.0, none, none)
	point := rotated.transform_point_from_init(DOMPointInit{ x: 1.0, y: 0.0 })
	assert point.x() == 0.0
	assert point.y() == 1.0
	assert rotated.is_2d() // a pure Z rotation stays 2D
}

fn test_rotate_three_args_z() {
	base := DOMMatrixReadOnly.create()
	// rotate(0, 0, 90) is the same Z rotation, still 2D.
	rotated := base.rotate(0.0, 0.0, 90.0)
	point := rotated.transform_point_from_init(DOMPointInit{ x: 1.0, y: 0.0 })
	assert point.x() == 0.0 && point.y() == 1.0
	assert rotated.is_2d()
}

fn test_rotate_x_axis_clears_is_2d() {
	base := DOMMatrixReadOnly.create()
	// rotate(90, 0, 0) rotates about X: (0, 1, 0) -> (0, 0, 1); an X rotation makes the matrix 3D.
	rotated := base.rotate(90.0, 0.0, 0.0)
	assert !rotated.is_2d()
	point := rotated.transform_point_from_init(DOMPointInit{ x: 0.0, y: 1.0, z: 0.0 })
	assert approx(point.x(), 0.0)
	assert approx(point.y(), 0.0)
	assert approx(point.z(), 1.0)
}

fn test_rotate_axis_angle_z() {
	base := DOMMatrixReadOnly.create()
	// About the Z axis by 90 degrees: same as rotate(90), stays 2D (x and y axis components are 0).
	rotated := base.rotate_axis_angle(0.0, 0.0, 1.0, 90.0)
	point := rotated.transform_point_from_init(DOMPointInit{ x: 1.0, y: 0.0 })
	assert point.x() == 0.0 && point.y() == 1.0
	assert rotated.is_2d()
}

fn test_rotate_axis_angle_x_clears_is_2d() {
	base := DOMMatrixReadOnly.create()
	rotated := base.rotate_axis_angle(1.0, 0.0, 0.0, 90.0)
	assert !rotated.is_2d()
	point := rotated.transform_point_from_init(DOMPointInit{ x: 0.0, y: 1.0, z: 0.0 })
	assert approx(point.z(), 1.0)
}

fn test_rotate_from_vector() {
	base := DOMMatrixReadOnly.create()
	// The vector (1, 1) is at 45 degrees; rotating (1, 0) by it gives (cos45, sin45).
	rotated := base.rotate_from_vector(1.0, 1.0)
	point := rotated.transform_point_from_init(DOMPointInit{ x: 1.0, y: 0.0 })
	half_sqrt2 := 0.7071067811865476
	assert approx(point.x(), half_sqrt2)
	assert approx(point.y(), half_sqrt2)
	assert rotated.is_2d()
}

fn test_rotate_from_vector_zero_is_identity() {
	base := DOMMatrixReadOnly.create()
	// A zero vector specifies an angle of 0, leaving the point unchanged.
	rotated := base.rotate_from_vector(0.0, 0.0)
	point := rotated.transform_point_from_init(DOMPointInit{ x: 3.0, y: 4.0 })
	assert point.x() == 3.0 && point.y() == 4.0
}

fn test_rotate_composes_to_180() {
	// Two 90-degree rotations compose to 180: (1, 0) -> (-1, 0).
	base := DOMMatrixReadOnly.create()
	once := base.rotate(90.0, none, none)
	twice := once.rotate(90.0, none, none)
	point := twice.transform_point_from_init(DOMPointInit{ x: 1.0, y: 0.0 })
	assert approx(point.x(), -1.0)
	assert approx(point.y(), 0.0)
}
