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

// Repeat the final keyframe once per completed iteration. Binary doubling
// keeps numeric accumulation bounded even for very large iteration counts.
fn accumulate_animation_iterations(property ?PropertyID, value &dom.StyleValue, final_value &dom.StyleValue, count f64) &dom.StyleValue {
	mut remaining := u64(math.min(math.floor(count), 9007199254740991.0))
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
