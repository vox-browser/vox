module geometry

fn test_default_is_2d_identity() {
	matrix := DOMMatrixReadOnly.create()
	assert matrix.is_2d()
	assert matrix.is_identity()
	assert matrix.a() == 1.0 && matrix.b() == 0.0 && matrix.c() == 0.0
	assert matrix.d() == 1.0 && matrix.e() == 0.0 && matrix.f() == 0.0
	assert matrix.m33() == 1.0 && matrix.m44() == 1.0
}

fn test_construct_omitted_is_identity() {
	matrix := DOMMatrixReadOnly.construct(none) or { panic('${err}') }
	assert matrix.is_2d()
	assert matrix.is_identity()
}

fn test_construct_6_element_sequence_is_2d() {
	matrix := DOMMatrixReadOnly.construct([2.0, 3.0, 4.0, 5.0, 6.0, 7.0]) or { panic('${err}') }
	assert matrix.is_2d()
	// a/b/c/d/e/f are m11/m12/m21/m22/m41/m42.
	assert matrix.a() == 2.0 && matrix.b() == 3.0
	assert matrix.c() == 4.0 && matrix.d() == 5.0
	assert matrix.e() == 6.0 && matrix.f() == 7.0
	// The 3D elements keep their identity defaults.
	assert matrix.m33() == 1.0 && matrix.m44() == 1.0 && matrix.m13() == 0.0
	assert !matrix.is_identity()
}

fn test_construct_16_element_sequence_is_3d() {
	values := [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0,
		16.0]
	matrix := DOMMatrixReadOnly.construct(values) or { panic('${err}') }
	assert !matrix.is_2d()
	assert matrix.m11() == 1.0 && matrix.m12() == 2.0 && matrix.m13() == 3.0 && matrix.m14() == 4.0
	assert matrix.m31() == 9.0 && matrix.m44() == 16.0
	assert !matrix.is_identity()
}

fn test_construct_bad_length_errors() {
	if _ := DOMMatrixReadOnly.construct([1.0, 2.0, 3.0]) {
		assert false, 'expected an error for a 3-element sequence'
	}
}

fn test_is_identity_checks_every_off_diagonal() {
	// A single non-zero off-diagonal element (m23) means the matrix is not the identity — this is the
	// case upstream's typo would miss.
	values := [1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 5.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0]
	matrix := DOMMatrixReadOnly.construct(values) or { panic('${err}') }
	assert matrix.m23() == 5.0
	assert !matrix.is_identity()
}

fn test_create_from_2d_init_fills_aliases() {
	// Only the a/d aliases are given; m11/m22 are filled from them and the rest from defaults.
	mut init := DOMMatrix2DInit{
		a: 2.0
		d: 3.0
	}
	matrix := DOMMatrixReadOnly.create_from_dom_matrix_2d_init(mut init) or { panic('${err}') }
	assert matrix.m11() == 2.0
	assert matrix.m22() == 3.0
	assert matrix.m12() == 0.0 && matrix.m21() == 0.0 && matrix.m41() == 0.0 && matrix.m42() == 0.0
	assert matrix.is_2d()
}

fn test_create_from_2d_init_conflicting_aliases_error() {
	// a and m11 both present but disagreeing is a TypeError.
	mut init := DOMMatrix2DInit{
		a:   2.0
		m11: 3.0
	}
	if _ := DOMMatrixReadOnly.create_from_dom_matrix_2d_init(mut init) {
		assert false, 'expected an error for conflicting a/m11'
	}
	// Agreeing aliases are accepted.
	mut ok := DOMMatrix2DInit{
		a:   2.0
		m11: 2.0
	}
	agreed := DOMMatrixReadOnly.create_from_dom_matrix_2d_init(mut ok) or { panic('${err}') }
	assert agreed.m11() == 2.0
}

fn test_create_from_init_infers_is_2d() {
	// An init with only 2D members and identity 3D defaults is 2D.
	mut flat := DOMMatrixInit{}
	m2d := DOMMatrixReadOnly.create_from_dom_matrix_init(mut flat) or { panic('${err}') }
	assert m2d.is_2d()
	assert m2d.is_identity()
	// A non-zero 3D member forces the matrix to 3D.
	mut spatial := DOMMatrixInit{
		m13: 5.0
	}
	m3d := DOMMatrixReadOnly.create_from_dom_matrix_init(mut spatial) or { panic('${err}') }
	assert !m3d.is_2d()
	assert m3d.m13() == 5.0
}

fn test_create_from_init_is2d_true_with_3d_member_errors() {
	// Declaring is2D true while a 3D member is set is a contradiction.
	mut init := DOMMatrixInit{
		m13:  5.0
		is2d: true
	}
	if _ := DOMMatrixReadOnly.create_from_dom_matrix_init(mut init) {
		assert false, 'expected an error for is2D true with a 3D member'
	}
}

fn test_transform_point_identity() {
	matrix := DOMMatrixReadOnly.create()
	point := DOMPointReadOnly.construct(3.0, 4.0, 5.0, 1.0)
	result := matrix.transform_point(point)
	assert result.x() == 3.0 && result.y() == 4.0 && result.z() == 5.0 && result.w() == 1.0
}

fn test_transform_point_translation() {
	// A 3D translation (tx=10, ty=20, tz=30) via a 16-element sequence.
	matrix := DOMMatrixReadOnly.construct([1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0,
		0.0, 10.0, 20.0, 30.0, 1.0]) or { panic('${err}') }
	point := DOMPointReadOnly.construct(1.0, 2.0, 3.0, 1.0)
	result := matrix.transform_point(point)
	assert result.x() == 11.0 && result.y() == 22.0 && result.z() == 33.0 && result.w() == 1.0
}

fn test_transform_point_scale_and_translate_2d() {
	// a=2, d=3 (scale), e=5, f=7 (translate).
	mut init := DOMMatrix2DInit{
		a: 2.0
		d: 3.0
		e: 5.0
		f: 7.0
	}
	matrix := DOMMatrixReadOnly.create_from_dom_matrix_2d_init(mut init) or { panic('${err}') }
	result := matrix.transform_point_from_init(DOMPointInit{ x: 1.0, y: 1.0 })
	assert result.x() == 7.0 // 2*1 + 5
	assert result.y() == 10.0 // 3*1 + 7
	assert result.z() == 0.0
	assert result.w() == 1.0
}

fn test_transform_point_from_init_uses_defaults() {
	// An empty DOMPointInit is (0, 0, 0, 1); the identity leaves it unchanged.
	matrix := DOMMatrixReadOnly.create()
	result := matrix.transform_point_from_init(DOMPointInit{})
	assert result.x() == 0.0 && result.y() == 0.0 && result.z() == 0.0 && result.w() == 1.0
}

fn test_from_matrix_matches_create_from_init() {
	mut init := DOMMatrixInit{
		DOMMatrix2DInit: DOMMatrix2DInit{
			a: 4.0
		}
	}
	matrix := DOMMatrixReadOnly.from_matrix(mut init) or { panic('${err}') }
	assert matrix.a() == 4.0
	assert matrix.is_2d()
}

// Transform strings need absolute lengths: there is no element to resolve
// relative units or percentages against, and tree-counting functions are not
// allowed in this context.
fn test_dom_matrix_string_rejects_relative_lengths_and_tree_counting() {
	for source in ['translateX(5em)', 'translateX(5%)', 'translateX(calc(10px * sign(1em - 10px)))',
		'scale(sibling-index())'] {
		DOMMatrix.construct_from_string(source, true) or {
			assert err.msg().starts_with('SyntaxError:'), source
			continue
		}
		assert false, source
	}
	matrix := DOMMatrix.construct_from_string('scale(2) translateX(calc(2 * 2.5px))', true)!
	assert matrix.e() == 10
}
