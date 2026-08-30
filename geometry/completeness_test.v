module geometry

import math

fn test_dom_rect_list_preserves_objects_and_bounds_checks() {
	first := DOMRect.construct(1, 2, 3, 4)
	second := DOMRect.construct(5, 6, 7, 8)
	list := DOMRectList.create([first, second])
	assert list.length() == 2
	assert list.item(0) or { panic('missing item') } == first
	assert list.item_value(1) or { panic('missing item') } == second
	assert list.item(2) == none
	assert list.values().len == 2
}

fn test_matrix_typed_array_factories_and_stringifier() {
	matrix := DOMMatrixReadOnly.from_float32_array([f32(1), 2, 3, 4, 5, 6])!
	assert matrix.is_2d()
	assert matrix.to_string()! == 'matrix(1, 2, 3, 4, 5, 6)'
	large := DOMMatrixReadOnly.construct([1e20, 0, 0, 1, 0, 0])!
	assert large.to_string()! == 'matrix(100000000000000000000, 0, 0, 1, 0, 0)'
	three_d := DOMMatrix.from_float64_array([1.0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 10, 20, 30,
		1])!
	assert !three_d.is_2d()
	assert three_d.to_string()!.starts_with('matrix3d(1, 0, 0, 0, 0, 1')
	if _ := DOMMatrixReadOnly.from_float32_array([f32(1), 2]) {
		assert false, 'invalid array length must throw'
	}
	mut invalid := DOMMatrix.create()
	invalid.set_m11(math.nan())
	if _ := invalid.to_string() {
		assert false, 'non-finite matrices cannot be stringified'
	}
}

fn test_matrix_css_string_constructor_and_mutating_setter() {
	matrix := DOMMatrixReadOnly.construct_from_string('translate(10px, 20px) scale(2)', true)!
	assert matrix.is_2d()
	assert matrix.m11() == 2
	assert matrix.m22() == 2
	assert matrix.m41() == 10
	assert matrix.m42() == 20
	identity := DOMMatrixReadOnly.construct_from_string('none', true)!
	assert identity.is_identity()
	if _ := DOMMatrixReadOnly.construct_from_string('translate(1em)', true) {
		assert false, 'relative lengths are rejected by DOMMatrix string parsing'
	}
	if _ := DOMMatrixReadOnly.construct_from_string('matrix(1, nope)', true) {
		assert false, 'invalid CSS must throw'
	}
	if _ := DOMMatrixReadOnly.construct_from_string('none', false) {
		assert false, 'string construction is Window-only'
	}
	mut mutable := DOMMatrix.create()
	mutable.set_matrix_value('translate3d(1px, 2px, 3px)')!
	assert !mutable.is_2d()
	assert mutable.m41() == 1
	assert mutable.m42() == 2
	assert mutable.m43() == 3
}

fn test_geometry_serialization_and_json_records_round_trip() {
	point := DOMPoint.construct(1, 2, 3, 4)
	point_copy := DOMPoint.deserialize(point.serialization_steps())
	assert point_copy.to_json() == point.to_json()
	rect := DOMRect.construct(5, 6, 7, 8)
	rect_copy := DOMRect.deserialize(rect.serialization_steps())
	assert rect_copy.to_json() == rect.to_json()
	assert rect.to_json().right == 12
	assert rect.to_json().bottom == 14
	matrix := DOMMatrixReadOnly.construct([1.0, 2, 3, 4, 5, 6])!
	matrix_copy := DOMMatrixReadOnly.deserialize(matrix.serialization_steps())!
	assert matrix_copy.to_float64_array() == matrix.to_float64_array()
	assert matrix.to_json().is_2d
	assert !matrix.to_json().is_identity
	quad := DOMQuad.from_rect(DOMRectInit{ x: 10, y: 20, width: 30, height: 40 })
	quad_copy := DOMQuad.deserialize(quad.serialization_steps())
	assert quad_copy.to_json() == quad.to_json()
	if _ := DOMMatrixReadOnly.deserialize(SerializedDOMMatrix{
		is_2d:    true
		elements: [
			1.0,
		]
	})
	{
		assert false, 'malformed clone records must be rejected'
	}
}

fn test_exact_geometry_constructor_initialization_and_deserialization_entry_points() {
	read_only_identity := DOMMatrixReadOnly.construct_impl(none, true)!
	assert read_only_identity.is2d()
	read_only_sequence := DOMMatrixReadOnly.construct_impl(DOMMatrixConstructorInit([2.0,
		0.0, 0.0, 3.0, 4.0, 5.0]), true)!
	assert read_only_sequence.a() == 2
	assert read_only_sequence.f() == 5
	mutable_string := DOMMatrix.construct_impl(DOMMatrixConstructorInit('matrix(1, 0, 0, 1, 7, 8)'),
		true)!
	assert mutable_string.e() == 7
	assert mutable_string.f() == 8
	mut matrix_2d_init := DOMMatrix2DInit{
		a: 2
		d: 3
	}
	mutable_2d := DOMMatrix.create_from_dom_matrix_2d_init(mut matrix_2d_init)!
	assert mutable_2d.a() == 2
	assert mutable_2d.d() == 3

	mut initialized := DOMMatrixReadOnly.create()
	initialized.initialize_from_create_3d_matrix(1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
		11, 12, 13, 14, 15, 16)
	assert !initialized.is2d()
	assert initialized.m43() == 15
	initialized.initialize_from_create_2d_matrix(1, 2, 3, 4, 5, 6)
	assert initialized.is2d()
	assert initialized.m33() == 1

	mut point := DOMPointReadOnly.create()
	point.deserialization_steps(SerializedDOMPoint{1, 2, 3, 4})
	assert point.to_json() == DOMPointJSON{1, 2, 3, 4}
	mut rect := DOMRectReadOnly.create()
	rect.deserialization_steps(SerializedDOMRect{1, 2, 3, 4})
	assert rect.to_json().width == 3
	mut matrix := DOMMatrixReadOnly.create()
	matrix.deserialization_steps(SerializedDOMMatrix{
		is_2d:    true
		elements: [2.0, 0.0, 0.0, 3.0, 4.0, 5.0]
	})!
	assert matrix.a() == 2
	mut quad := DOMQuad.create()
	quad.deserialization_steps(SerializedDOMQuad{
		p1: SerializedDOMPoint{1, 2, 0, 1}
		p2: SerializedDOMPoint{3, 4, 0, 1}
		p3: SerializedDOMPoint{5, 6, 0, 1}
		p4: SerializedDOMPoint{7, 8, 0, 1}
	})
	assert quad.p4().x() == 7

	assert DOMPointReadOnly.construct_impl(1, 2, 3, 4).w() == 4
	assert DOMPoint.construct_impl(1, 2, 3, 4).z() == 3
	assert DOMRectReadOnly.construct_impl(1, 2, 3, 4).height() == 4
	assert DOMQuad.construct_impl(DOMPointInit{}, DOMPointInit{}, DOMPointInit{},
		DOMPointInit{}).p1().w() == 1
}
