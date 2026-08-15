module geometry

fn test_dompointinit_defaults() {
	// x/y/z default to 0, w defaults to 1.
	init := DOMPointInit{}
	assert init.x == 0.0
	assert init.y == 0.0
	assert init.z == 0.0
	assert init.w == 1.0
}

fn test_readonly_construct_and_getters() {
	point := DOMPointReadOnly.construct(1.0, 2.0, 3.0, 4.0)
	assert point.x() == 1.0
	assert point.y() == 2.0
	assert point.z() == 3.0
	assert point.w() == 4.0
}

fn test_readonly_create_empty() {
	// The empty point mirrors the default-initialized C++ constructor: all coordinates 0.
	point := DOMPointReadOnly.create()
	assert point.x() == 0.0
	assert point.y() == 0.0
	assert point.z() == 0.0
	assert point.w() == 0.0
}

fn test_readonly_from_point() {
	// An empty dictionary uses the w=1 default; provided members override.
	default_point := DOMPointReadOnly.from_point(DOMPointInit{})
	assert default_point.x() == 0.0
	assert default_point.w() == 1.0
	partial := DOMPointReadOnly.from_point(DOMPointInit{ x: 5.0, y: 6.0 })
	assert partial.x() == 5.0
	assert partial.y() == 6.0
	assert partial.z() == 0.0
	assert partial.w() == 1.0
}

fn test_dompoint_construct_inherits_getters() {
	point := DOMPoint.construct(1.5, 2.5, 3.5, 4.5)
	// The getters are inherited from DOMPointReadOnly.
	assert point.x() == 1.5
	assert point.y() == 2.5
	assert point.z() == 3.5
	assert point.w() == 4.5
}

fn test_dompoint_setters() {
	mut point := DOMPoint.construct(1.0, 2.0, 3.0, 4.0)
	point.set_x(10.0)
	point.set_y(20.0)
	point.set_z(30.0)
	point.set_w(40.0)
	assert point.x() == 10.0
	assert point.y() == 20.0
	assert point.z() == 30.0
	assert point.w() == 40.0
}

fn test_dompoint_from_point() {
	point := DOMPoint.from_point(DOMPointInit{ x: 1.5, z: 2.5 })
	assert point.x() == 1.5
	assert point.y() == 0.0
	assert point.z() == 2.5
	assert point.w() == 1.0
}

fn test_matrix_transform_translation() {
	// matrixTransform builds a matrix from the init and applies it. A 2D translation (e=5, f=7).
	point := DOMPointReadOnly.construct(1.0, 2.0, 0.0, 1.0)
	mut matrix := DOMMatrixInit{
		DOMMatrix2DInit: DOMMatrix2DInit{
			e: 5.0
			f: 7.0
		}
	}
	result := point.matrix_transform(mut matrix) or { panic('${err}') }
	assert result.x() == 6.0 // 1 + 5
	assert result.y() == 9.0 // 2 + 7
	// The original point is not modified.
	assert point.x() == 1.0 && point.y() == 2.0
}

fn test_matrix_transform_inherited_by_dompoint() {
	// DOMPoint inherits matrixTransform from DOMPointReadOnly via embedding.
	point := DOMPoint.construct(2.0, 3.0, 0.0, 1.0)
	mut identity := DOMMatrixInit{}
	result := point.matrix_transform(mut identity) or { panic('${err}') }
	assert result.x() == 2.0 && result.y() == 3.0
}
