module css

import math

// Computed corner-shape values retain the CSS superellipse() parameter, whose
// geometric exponent is 2^parameter. Physical property lookup already includes
// the writing-mode mapping of logical longhands.
pub fn (computed &ComputedProperties) corner_shape_parameters() [4]f64 {
	mut result := [f64(1), 1, 1, 1]!
	for index, property in [PropertyID.corner_top_left_shape, .corner_top_right_shape,
		.corner_bottom_right_shape, .corner_bottom_left_shape] {
		value := computed.typed_property_value(property) or { continue }
		if value is SuperellipseStyleValue {
			result[index] = value.parameter()
		} else if value is KeywordStyleValue {
			result[index] = match value.keyword() {
				.bevel { 0.0 }
				.squircle { 2.0 }
				.scoop { -1.0 }
				.square { math.inf(1) }
				.notch { math.inf(-1) }
				else { 1.0 }
			}
		}
	}
	return result
}
