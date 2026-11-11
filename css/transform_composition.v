module css

import dom

// https://drafts.csswg.org/css-transforms-2/#combining-transform-lists
// Addition appends the animated list to the underlying list. Accumulation
// follows the interpolation pairing: the longest prefix of pairs sharing a
// primitive accumulates per function, and the remaining suffix accumulates as
// decomposed matrices.
fn composite_transform_lists(underlying StyleValue, animated StyleValue, operation CompositeOperation) ?StyleValue {
	underlying_list := interpolation_transform_list(underlying) or { return none }
	animated_list := interpolation_transform_list(animated) or { return none }
	if operation == .add {
		mut values := []StyleValue{cap: underlying_list.len + animated_list.len}
		for transform in underlying_list {
			values << StyleValue(transform)
		}
		for transform in animated_list {
			values << StyleValue(transform)
		}
		return transform_list_style_value(values)
	}
	if operation != .accumulate {
		return none
	}
	mut a := underlying_list.clone()
	mut b := animated_list.clone()
	interpolation_extend_transform_list(mut a, b)
	interpolation_extend_transform_list(mut b, a)
	prefix := accumulate_transform_prefix(a, b)
	if prefix.len == a.len {
		return transform_list_style_value(prefix)
	}
	a_matrix := transform_list_matrix(a, prefix.len) or { return none }
	b_matrix := transform_list_matrix(b, prefix.len) or { return none }
	accumulated := accumulate_transform_matrices(a_matrix, b_matrix) or { return none }
	mut values := prefix.clone()
	values << StyleValue(TransformationStyleValue.create(.transform, .matrix3d, matrix_to_style_value_vector(accumulated)))
	return transform_list_style_value(values)
}

fn transform_list_style_value(values []StyleValue) StyleValue {
	if values.len == 0 {
		return StyleValue(KeywordStyleValue.create(.none_))
	}
	return StyleValue(StyleValueList.create(values, .space, .yes))
}

fn transform_list_matrix(list []TransformationStyleValue, start int) ?FloatMatrix4x4 {
	mut matrix := FloatMatrix4x4.identity()
	for index in start .. list.len {
		component := list[index].to_matrix(none) or { return none }
		matrix = cssom_multiply_transform_matrices(matrix, component)
	}
	return matrix
}

// Accumulates the leading pairs that share a primitive and stops at the first
// pair that has to be combined as matrices.
fn accumulate_transform_prefix(a []TransformationStyleValue, b []TransformationStyleValue) []StyleValue {
	mut result := []StyleValue{cap: a.len}
	for index in 0 .. a.len {
		accumulated := accumulate_transform_function_pair(a[index], b[index]) or { break }
		result << StyleValue(accumulated)
	}
	return result
}

fn accumulate_transform_function_pair(a TransformationStyleValue, b TransformationStyleValue) ?TransformationStyleValue {
	a_function := a.transform_function()
	b_function := b.transform_function()
	if a_function in [.matrix, .matrix3d, .perspective] || b_function in [.matrix, .matrix3d, .perspective] {
		return none
	}
	mut left := a
	mut right := b
	if interpolation_is_2d_transform(a_function) && interpolation_is_2d_transform(b_function) {
		left = interpolation_convert_to_2d_primitive(a)
		right = interpolation_convert_to_2d_primitive(b)
	} else if interpolation_is_3d_transform(a_function) || interpolation_is_3d_transform(b_function) {
		if !interpolation_is_3d_primitive(a_function) {
			left = interpolation_convert_to_3d_primitive(a) or { return none }
		}
		if !interpolation_is_3d_primitive(b_function) {
			right = interpolation_convert_to_3d_primitive(b) or { return none }
		}
	}
	function := left.transform_function()
	left_values := left.values()
	right_values := right.values()
	if function != right.transform_function() || left_values.len != right_values.len {
		return none
	}
	if function == .rotate3d {
		return accumulate_rotate3d(left, right)
	}
	multiplicative := function in [.scale, .scale3d, .scale_x, .scale_y, .scale_z]
	mut values := []StyleValue{cap: left_values.len}
	for index in 0 .. left_values.len {
		values << if multiplicative {
			accumulate_scale_factor(left_values[index], right_values[index]) or { return none }
		} else {
			accumulate_transform_argument(left_values[index], right_values[index]) or {
				return none
			}
		}
	}
	return TransformationStyleValue.create(.transform, function, values)
}

fn accumulate_transform_argument(a StyleValue, b StyleValue) ?StyleValue {
	if a is AngleStyleValue && b is AngleStyleValue && a.angle().unit() != b.angle().unit() {
		return StyleValue(AngleStyleValue.create(Angle.make_degrees(a.angle().to_degrees() + b.angle().to_degrees())))
	}
	return composite_style_value(.transform, a, b, .accumulate)
}

fn transform_scale_factor(value StyleValue) ?f64 {
	if value is NumberStyleValue {
		return value.number()
	}
	if value is PercentageStyleValue {
		return value.raw_value() / 100.0
	}
	return none
}

// Scale factors accumulate as Va + Vb - 1, so scale(1) is the neutral value.
fn accumulate_scale_factor(a StyleValue, b StyleValue) ?StyleValue {
	a_factor := transform_scale_factor(a) or { return none }
	b_factor := transform_scale_factor(b) or { return none }
	return StyleValue(NumberStyleValue.create(a_factor + b_factor - 1))
}

// Rotations about the same axis add their angles. Different axes are combined
// as matrices, as the interpolation of the remaining list would be.
fn accumulate_rotate3d(a TransformationStyleValue, b TransformationStyleValue) ?TransformationStyleValue {
	a_axis, a_angle := interpolation_rotation_axis_and_angle(a)
	b_axis, b_angle := interpolation_rotation_axis_and_angle(b)
	a_normalized := if a_axis.length() > 1e-5 { a_axis.normalized() } else { FloatVector3{
		z: 1
	} }
	b_normalized := if b_axis.length() > 1e-5 { b_axis.normalized() } else { FloatVector3{
		z: 1
	} }
	difference := FloatVector3{
		x: a_normalized.x - b_normalized.x
		y: a_normalized.y - b_normalized.y
		z: a_normalized.z - b_normalized.z
	}
	if difference.length() >= 1e-5 && a_angle != 0 && b_angle != 0 {
		return none
	}
	axis := if b_angle != 0 {
		b_normalized
	} else if a_angle != 0 {
		a_normalized
	} else {
		FloatVector3{
			z: 1
		}
	}
	degrees := Angle.from_style_value(a.values()[3], none).to_degrees() +
		Angle.from_style_value(b.values()[3], none).to_degrees()
	return TransformationStyleValue.create(.transform, .rotate3d, [
		StyleValue(NumberStyleValue.create(axis.x)),
		StyleValue(NumberStyleValue.create(axis.y)),
		StyleValue(NumberStyleValue.create(axis.z)),
		StyleValue(AngleStyleValue.create(Angle.make_degrees(degrees))),
	])
}

fn interpolation_rotation_matrix(quaternion []f64) FloatMatrix4x4 {
	return interpolation_recompose_matrix(InterpolationDecomposedMatrix{
		scale: FloatVector3{
			x: 1
			y: 1
			z: 1
		}
		rotation: quaternion
		perspective: [f64(0), 0, 0, 1]
	})
}

// https://drafts.csswg.org/css-transforms-2/#combining-transform-lists
// Decomposed matrices accumulate translation, skew and perspective by
// addition, scale (and the perspective w component) as Va + Vb - 1, and
// rotation by composing the two rotations.
fn accumulate_transform_matrices(a FloatMatrix4x4, b FloatMatrix4x4) ?FloatMatrix4x4 {
	a_values := interpolation_decompose_matrix(a) or { return none }
	b_values := interpolation_decompose_matrix(b) or { return none }
	identity := [f64(0), 0, 0, 1]
	rotation := if a_values.rotation == identity {
		b_values.rotation
	} else if b_values.rotation == identity {
		a_values.rotation
	} else {
		composed := cssom_multiply_transform_matrices(interpolation_rotation_matrix(a_values.rotation),
			interpolation_rotation_matrix(b_values.rotation))
		(interpolation_decompose_matrix(composed) or { return none }).rotation
	}
	mut perspective := []f64{len: 4}
	for index in 0 .. 3 {
		perspective[index] = a_values.perspective[index] + b_values.perspective[index]
	}
	perspective[3] = a_values.perspective[3] + b_values.perspective[3] - 1
	return interpolation_recompose_matrix(InterpolationDecomposedMatrix{
		translation: FloatVector3{
			x: a_values.translation.x + b_values.translation.x
			y: a_values.translation.y + b_values.translation.y
			z: a_values.translation.z + b_values.translation.z
		}
		scale: FloatVector3{
			x: a_values.scale.x + b_values.scale.x - 1
			y: a_values.scale.y + b_values.scale.y - 1
			z: a_values.scale.z + b_values.scale.z - 1
		}
		skew: FloatVector3{
			x: a_values.skew.x + b_values.skew.x
			y: a_values.skew.y + b_values.skew.y
			z: a_values.skew.z + b_values.skew.z
		}
		rotation: rotation
		perspective: perspective
	})
}

// Web Animations accumulates the final keyframe onto the current value once
// per iteration. Once a pair falls back to matrices, later iterations keep
// accumulating the final list's matrix rather than its functions. Folding the
// final suffix into one matrix lets repeated doubling reproduce that sequence.
fn transform_iteration_increment(final_value &dom.StyleValue, current &dom.StyleValue) ?&dom.StyleValue {
	final_parsed := style_value_logic_from_dom(.transform, final_value) or { return none }
	current_parsed := style_value_logic_from_dom(.transform, current) or { return none }
	mut final_list := interpolation_transform_list(final_parsed) or { return none }
	mut current_list := interpolation_transform_list(current_parsed) or { return none }
	interpolation_extend_transform_list(mut final_list, current_list)
	interpolation_extend_transform_list(mut current_list, final_list)
	prefix := accumulate_transform_prefix(final_list, current_list)
	if prefix.len == final_list.len {
		return none
	}
	suffix := transform_list_matrix(final_list, prefix.len) or { return none }
	mut values := []StyleValue{cap: prefix.len + 1}
	for index in 0 .. prefix.len {
		values << StyleValue(final_list[index])
	}
	values << StyleValue(TransformationStyleValue.create(.transform, .matrix3d, matrix_to_style_value_vector(suffix)))
	return dom_style_value_from_value_logic(transform_list_style_value(values))
}
