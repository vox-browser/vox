module main

import math
import painting

// SVG filter primitive lengths are in the filtered element's user space
// (primitiveUnits="userSpaceOnUse"), and Blink filters through the element's
// transform: a shields.io badge's stdDeviation of 16 inside scale(.1) blurs by
// 1.6px. Map the native graph's length parameters through that transform.
fn native_svg_filter_parameters_in_user_space(node painting.GfxFilterNode, matrix [6]f64) [4]f32 {
	mut parameters := native_svg_filter_parameters(node)
	match node.kind {
		'blur', 'erode', 'dilate' {
			parameters[0] = f32(f64(parameters[0]) * math.hypot(matrix[0], matrix[1]))
			parameters[1] = f32(f64(parameters[1]) * math.hypot(matrix[2], matrix[3]))
		}
		'offset' {
			dx := f64(parameters[0])
			dy := f64(parameters[1])
			parameters[0] = f32(matrix[0] * dx + matrix[2] * dy)
			parameters[1] = f32(matrix[1] * dx + matrix[3] * dy)
		}
		'displacement-map' {
			determinant := matrix[0] * matrix[3] - matrix[1] * matrix[2]
			parameters[0] = f32(f64(parameters[0]) * math.sqrt(math.abs(determinant)))
		}
		else {}
	}
	return parameters
}
