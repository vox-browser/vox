module svg

fn test_author_path_length_scales_stroke_dashes_and_offset_without_changing_geometry() {
	mut element := new_element('path')
	element.attributes['pathLength'] = '100'
	path := parse_path_data('M0 0H200')
	original := [f64(25), 100]
	dashes, offset := element.calibrated_stroke_dashes(path, original, 5)
	assert dashes == [f64(50), 200]
	assert offset == 10
	assert original == [f64(25), 100]
	assert path.length() == 200
}

fn test_zero_author_path_length_makes_a_solid_stroke() {
	mut element := new_element('path')
	element.attributes['pathLength'] = '0'
	for original in [[f64(2), 3], [f64(0), 3], [f64(3), 0]] {
		dashes, offset := element.calibrated_stroke_dashes(parse_path_data('M0 0H100'), original, 5)
		assert dashes.len == 0
		assert offset == 0
	}
}

fn test_missing_invalid_and_negative_path_length_do_not_calibrate_strokes() {
	for value in ['', 'invalid', '100%', '10px', '-5'] {
		mut element := new_element('path')
		element.attributes['pathLength'] = value
		dashes, offset := element.calibrated_stroke_dashes(parse_path_data('M0 0H100'), [f64(2), 3], 5)
		assert dashes == [f64(2), 3]
		assert offset == 5
	}
}
