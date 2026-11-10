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

fn test_rotate3d_interpolation_takes_the_shortest_path() {
	// transform-interpolation-verify-reftests: rotateX(360deg) is the identity,
	// so halfway to rotateZ(90deg) is rotateZ(45deg), not its opposite turn.
	assert_interpolated_matrix('rotateX(360deg)', 'rotateZ(90deg)', 0.5, 'rotateZ(45deg)')
}

fn test_matrix_pairs_interpolate_without_absorbing_later_functions() {
	assert_interpolated_matrix('matrix(1,0,0,1,0,0) rotate(0deg)', 'matrix(2,0,0,2,0,0) rotate(360deg)', 0.5, 'matrix(1.5,0,0,1.5,0,0) rotate(180deg)')
	assert transform_interpolated('matrix(2, 0, 0, 2, 10, 30)', 'matrix(4, 0, 0, 6, 14, 10)', 0.5) == 'matrix(3, 0, 0, 4, 12, 20)'
	assert transform_interpolated('matrix3d(1, 0, 0, 0, 0, 4, 0, 0, 0, 0, 1, 0, 5, 10, 4, 1)', 'matrix3d(3, 0, 0, 0, 0, 2, 0, 0, 0, 0, 3, 0, -11, 2, 2, 1)', 0.5) == 'matrix3d(2, 0, 0, 0, 0, 3, 0, 0, 0, 0, 2, 0, -3, 6, 3, 1)'
}

fn test_perspective_interpolates_its_reciprocal_depth() {
	assert transform_interpolated('perspective(10px)', 'perspective(2.5px)', 0.5) == 'perspective(4px)'
	assert transform_interpolated('perspective(10px)', 'perspective(none)', 0.5) == 'perspective(20px)'
	assert transform_interpolated('perspective(none)', 'perspective(none)', 0.5) == 'perspective(none)'
	assert transform_interpolated('perspective(100px) translateZ(50px)', 'perspective(none) translateZ(50px)', 0.5) == 'perspective(200px) translateZ(50px)'
	// Depths below 1px interpolate as 1px, and a depth beyond infinity is none.
	assert transform_interpolated('perspective(0.1px)', 'perspective(0.1px)', 0.5) == 'perspective(1px)'
	assert transform_interpolated('perspective(10px)', 'perspective(1px)', -1) == 'perspective(none)'
	assert_interpolated_matrix('perspective(1px) translateZ(0.5px)', 'perspective(10px) translateZ(0.5px)', -1, 'perspective(1px) translateZ(0.5px)')
}

fn test_same_transform_functions_keep_their_type() {
	assert transform_interpolated('translateX(0px)', 'translateX(50px)', 0.5) == 'translateX(25px)'
	assert transform_interpolated('translateZ(-50px)', 'translateZ(50px)', 0.5) == 'translateZ(0px)'
	assert transform_interpolated('rotateZ(30deg)', 'rotateZ(90deg)', 0.5) == 'rotateZ(60deg)'
	assert transform_interpolated('scale(1)', 'scale(2)', 0.5) == 'scale(1.5)'
	assert transform_interpolated('scaleX(1)', 'scaleX(2)', 0.5) == 'scaleX(1.5)'
	assert transform_interpolated('skewX(0deg)', 'skewX(180deg)', 0.5) == 'skewX(90deg)'
	// Different functions still convert to their common primitive.
	assert transform_interpolated('rotate(0deg)', 'rotateZ(90deg)', 0.5) == 'rotate3d(0, 0, 1, 45deg)'
	assert transform_interpolated('scaleZ(1)', 'scale(2)', 0.5) == 'scale3d(1.5, 1.5, 1)'
	assert transform_interpolated('translateX(50px)', 'translateZ(50px)', 0.5) == 'translate3d(25px, 0px, 25px)'
}

fn test_translations_mixing_zero_lengths_and_percentages_stay_percentages() {
	assert transform_interpolated('translateY(0%)', 'translateX(50%)', 0.5) == 'translate(25%, 0%)'
	assert transform_interpolated('translate(50%)', 'translate(100%, 50%)', 0.5) == 'translate(75%, 25%)'
}
