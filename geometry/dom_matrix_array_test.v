module geometry

fn test_to_float64_array_identity() {
	array := DOMMatrixReadOnly.create().to_float64_array()
	assert array.len == 16
	// Column-major identity: 1s at indices 0, 5, 10, 15.
	expected := [1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0]
	assert array == expected
}

fn test_to_float64_array_column_major_order() {
	// A 16-element sequence is stored as m11..m44 and comes back in the same column-major order.
	values := [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0]
	matrix := DOMMatrixReadOnly.construct(values) or { panic('${err}') }
	assert matrix.to_float64_array() == values
}

fn test_to_float64_array_reflects_translation() {
	// translate(10, 20) puts m41/m42 at column-major indices 12 and 13.
	array := DOMMatrixReadOnly.create().translate(10.0, 20.0, none).to_float64_array()
	assert array[12] == 10.0 // m41
	assert array[13] == 20.0 // m42
}

fn test_to_float32_array() {
	array := DOMMatrixReadOnly.create().to_float32_array()
	assert array.len == 16
	assert array[0] == f32(1.0)
	assert array[5] == f32(1.0)
	assert array[15] == f32(1.0)
	assert array[1] == f32(0.0)
	// The elements are narrowed to f32.
	scaled := DOMMatrixReadOnly.create().scale(2.5, none, none, none, none, none).to_float32_array()
	assert scaled[0] == f32(2.5) // m11
}
