module css

import dom
import math

fn transform_interpolated(from string, to string, delta f64) string {
	element := unsafe { &dom.Element(nil) }
	result := interpolate_transform(element, InterpolationCalculationContext.for_property(.transform),
		&dom.StyleValue{ css_text: from }, &dom.StyleValue{ css_text: to }, delta, .no) or {
		return 'not interpolated'
	}
	return result.css_text
}

fn transform_matrix_of(text string) FloatMatrix4x4 {
	value := parse_css_value_logic(.transform, text) or { panic('unparsable ${text}') }
	list := interpolation_transform_list(value) or { panic('not a transform list: ${text}') }
	return transform_list_matrix(list, 0) or { panic('no matrix for ${text}') }
}

fn transform_matrices_match(actual FloatMatrix4x4, expected FloatMatrix4x4) bool {
	for row in 0 .. 4 {
		for column in 0 .. 4 {
			if math.abs(actual.at(row, column) - expected.at(row, column)) > 1e-4 {
				return false
			}
		}
	}
	return true
}

fn assert_interpolated_matrix(from string, to string, delta f64, expected string) {
	actual := transform_interpolated(from, to, delta)
	assert transform_matrices_match(transform_matrix_of(actual), transform_matrix_of(expected)), '${from} -> ${to} at ${delta}: ${actual}, expected ${expected}'
}

fn test_decomposed_matrices_recompose_rotations_about_any_axis() {
	for text in ['rotateX(30deg)', 'rotateY(-70deg)', 'rotate3d(1, 2, 3, 100deg)',
		'rotate3d(1, 1, 0, 45deg) translateX(100px)', 'scale3d(2, 3, 4) rotateY(30deg) skew(10deg, 5deg)',
		'perspective(100px) rotateX(20deg)'] {
		matrix := transform_matrix_of(text)
		decomposed := interpolation_decompose_matrix(matrix) or { panic('not decomposable: ${text}') }
		assert transform_matrices_match(interpolation_recompose_matrix(decomposed), matrix), text
	}
}

fn test_matrix_interpolation_turns_about_tilted_axes_in_the_right_direction() {
	// transform-interpolation-005: rotateY(1rad) scale(1, 3) against none.
	to := 'matrix3d(1.0806046117362795, 0, -1.682941969615793, 0, 0, 3, 0, 0, 3.365883939231586, 0, 2.161209223472559, 0, 0, 0, 0, 1)'
	assert_interpolated_matrix('none', to, 1, to)
	assert_interpolated_matrix('none', to, 0.25, 'matrix3d(1.211140527138306, 0, -0.30925494906815365, 0, 0, 1.5, 0, 0, 0.43295692869541513, 0, 1.6955967379936283, 0, 0, 0, 0, 1)')
	assert_interpolated_matrix(to, 'none', 2, 'matrix3d(0, 0, 0, 0, 0, -1, 0, 0, 1.682941969615793, 0, -1.0806046117362795, 0, 0, 0, 0, 1)')
}

fn test_matrix_accumulation_composes_tilted_rotations() {
	underlying := transform_matrix_of('translateX(100px) rotate3d(1, 1, 0, 45deg)')
	animated := transform_matrix_of('translateX(100px)')
	accumulated := accumulate_transform_matrices(underlying, animated) or { panic('not accumulated') }
	assert transform_matrices_match(accumulated, transform_matrix_of('translateX(200px) rotate3d(1, 1, 0, 45deg)'))
}
