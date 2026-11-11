module css

import dom
import math

fn composite_iteration_value(property ?PropertyID, final_value &dom.StyleValue, current &dom.StyleValue) ?&dom.StyleValue {
	// Web Animations puts the final keyframe first. When accumulation is not
	// defined, its replacement fallback must preserve the current endpoint.
	if id := property {
		return composite_value(id, final_value, current, .accumulate)
	}
	return composite_animated_custom_property(final_value, current, .accumulate)
}

// Accumulating a math function once per iteration keeps one copy of each
// complex term (`max(...) + max(...) + ...`). Scale the final value by the
// iteration count instead, as browsers do: `count * final` simplifies plain
// sums to the same result and keeps complex terms as `2 * max(...)`.
fn scaled_iteration_final(property ?PropertyID, final_value &dom.StyleValue, count u64) ?&dom.StyleValue {
	id := property or { PropertyID.width }
	typed := if property != none {
		style_value_logic_from_dom(id, final_value) or { return none }
	} else {
		typed_style_value_logic_from_dom(final_value) or { return none }
	}
	if typed !is CalculatedStyleValue {
		return none
	}
	numeric := CSSNumericValue.parse('calc(${count} * (${interpolation_calculation_operand(typed)}))') or {
		return none
	}
	scaled := numeric.create_an_internal_representation(PropertyNameAndID.from_id(id), .no) or {
		return none
	}
	return dom_style_value_from_value_logic(scaled)
}

// Repeat the final keyframe once per completed iteration. Binary doubling
// keeps numeric accumulation bounded even for very large iteration counts.
fn accumulate_animation_iterations(property ?PropertyID, value &dom.StyleValue, final_value &dom.StyleValue, count f64) &dom.StyleValue {
	mut remaining := u64(math.min(math.floor(count), 9007199254740991.0))
	if remaining > 1 {
		if scaled := scaled_iteration_final(property, final_value, remaining) {
			return composite_iteration_value(property, scaled, value) or { value }
		}
	}
	mut result := unsafe { value }
	mut increment := unsafe { final_value }
	if id := property {
		if id == .transform {
			if normalized := transform_iteration_increment(final_value, value) {
				increment = normalized
			}
		}
	}
	for remaining > 0 {
		if remaining & 1 != 0 {
			result = composite_iteration_value(property, increment, result) or { return result }
		}
		remaining >>= 1
		if remaining > 0 {
			increment = composite_iteration_value(property, increment, increment) or { return result }
		}
	}
	return result
}
