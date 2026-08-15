module geometry

// A 2D matrix built from a/b/c/d/e/f via a 6-element sequence, for readable assertions.
fn matrix_2d(a f64, b f64, c f64, d f64, e f64, f f64) &DOMMatrix {
	return DOMMatrix.construct([a, b, c, d, e, f]) or { panic('${err}') }
}

fn test_create_from_read_only_is_independent_copy() {
	read_only := DOMMatrixReadOnly.construct([2.0, 0.0, 0.0, 3.0, 4.0, 5.0]) or { panic('${err}') }
	mut matrix := DOMMatrix.create_from_dom_matrix_read_only(read_only)
	matrix.set_a(9.0)
	// Mutating the copy does not affect the source.
	assert matrix.a() == 9.0
	assert read_only.a() == 2.0
}

fn test_setters_and_is_2d_flip() {
	mut matrix := DOMMatrix.create()
	assert matrix.is_2d()
	matrix.set_a(2.0)
	matrix.set_f(7.0)
	assert matrix.m11() == 2.0 && matrix.m42() == 7.0
	assert matrix.is_2d() // 2D elements do not clear is2D
	// Setting a 3D element to a non-identity value clears is2D.
	matrix.set_m34(5.0)
	assert matrix.m34() == 5.0
	assert !matrix.is_2d()
}

fn test_set_m33_flips_is_2d_only_when_not_one() {
	mut a := DOMMatrix.create()
	a.set_m33(1.0)
	assert a.is_2d() // m33 == 1 keeps it 2D
	mut b := DOMMatrix.create()
	b.set_m33(2.0)
	assert !b.is_2d()
}

fn test_translate_self_2d() {
	mut matrix := DOMMatrix.create()
	matrix.translate_self(10.0, 20.0, none)
	// e/f are the translation; still 2D.
	assert matrix.e() == 10.0 && matrix.f() == 20.0
	assert matrix.is_2d()
	// Applying the matrix to a point translates it.
	point := matrix.transform_point_from_init(DOMPointInit{ x: 1.0, y: 2.0 })
	assert point.x() == 11.0 && point.y() == 22.0
}

fn test_translate_self_3d_clears_is_2d() {
	mut matrix := DOMMatrix.create()
	matrix.translate_self(0.0, 0.0, 5.0)
	assert !matrix.is_2d()
	assert matrix.m43() == 5.0
}

fn test_translate_returns_new_matrix() {
	base := DOMMatrixReadOnly.create()
	translated := base.translate(3.0, 4.0, none)
	assert translated.e() == 3.0 && translated.f() == 4.0
	// The source read-only matrix is untouched.
	assert base.e() == 0.0 && base.f() == 0.0
}

fn test_multiply_composes_transforms() {
	// translate(10, 20) then scale(2, 3): post-multiplying scale means scale is applied first.
	translate := matrix_2d(1.0, 0.0, 0.0, 1.0, 10.0, 20.0)
	mut scale_init := DOMMatrixInit{
		DOMMatrix2DInit: DOMMatrix2DInit{
			a: 2.0
			d: 3.0
		}
	}
	product := translate.multiply(mut scale_init) or { panic('${err}') }
	// A point (1, 1) is scaled to (2, 3) then translated to (12, 23).
	point := product.transform_point_from_init(DOMPointInit{ x: 1.0, y: 1.0 })
	assert point.x() == 12.0
	assert point.y() == 23.0
	assert product.is_2d()
}

fn test_multiply_with_3d_other_clears_is_2d() {
	base := DOMMatrixReadOnly.create()
	mut other := DOMMatrixInit{
		m13: 5.0
	}
	product := base.multiply(mut other) or { panic('${err}') }
	assert !product.is_2d()
}

fn test_pre_multiply_self_order() {
	// preMultiply(scale) onto a translate applies the translate first, then the scale.
	mut matrix := matrix_2d(1.0, 0.0, 0.0, 1.0, 10.0, 20.0) // translate(10, 20)
	mut scale_init := DOMMatrixInit{
		DOMMatrix2DInit: DOMMatrix2DInit{
			a: 2.0
			d: 3.0
		}
	}
	matrix.pre_multiply_self(mut scale_init) or { panic('${err}') }
	// (1, 1) translated to (11, 21) then scaled to (22, 63).
	point := matrix.transform_point_from_init(DOMPointInit{ x: 1.0, y: 1.0 })
	assert point.x() == 22.0
	assert point.y() == 63.0
}

fn test_flip_x_and_flip_y() {
	base := DOMMatrixReadOnly.create()
	fx := base.flip_x()
	// flipX negates the x axis: a point (2, 3) becomes (-2, 3).
	px := fx.transform_point_from_init(DOMPointInit{ x: 2.0, y: 3.0 })
	assert px.x() == -2.0 && px.y() == 3.0
	fy := base.flip_y()
	py := fy.transform_point_from_init(DOMPointInit{ x: 2.0, y: 3.0 })
	assert py.x() == 2.0 && py.y() == -3.0
	// flips stay 2D.
	assert fx.is_2d() && fy.is_2d()
}
