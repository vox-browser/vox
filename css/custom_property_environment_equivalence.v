module css

import dom

fn custom_property_environment_optional_text_equal(left ?string, right ?string) bool {
	if left_text := left {
		right_text := right or { return false }
		return left_text == right_text
	}
	return right == none
}

// Resolved var() aliases acquire a fresh typed wrapper on each style pass.
// Reuse that immutable token environment only when all retained context and
// serialization metadata match, as well as the complete unresolved payload.
fn custom_property_environment_values_equivalent(left &dom.CSSStyleValue_,
	right &dom.CSSStyleValue_) bool {
	if left.css_text != right.css_text || left.guaranteed_invalid != right.guaranteed_invalid {
		return false
	}
	if custom_property_bridge_values_identical(left, right) { return true }
	if left.css_value_handle == unsafe { nil } || right.css_value_handle == unsafe { nil } {
		return false
	}
	left_value := unsafe { &dom.StyleValue(left.css_value_handle) }
	right_value := unsafe { &dom.StyleValue(right.css_value_handle) }
	if left_value.css_text != right_value.css_text
		|| !custom_property_environment_optional_text_equal(left_value.base_url, right_value.base_url) {
		return false
	}
	if left_value.css_value_handle == unsafe { nil } || right_value.css_value_handle == unsafe { nil } {
		return false
	}
	if left_value.css_value_handle == right_value.css_value_handle { return true }
	// Borrow both boxes for this synchronous comparison. Other typed values can
	// carry resource/stylesheet state, so distinct instances remain conservative.
	left_typed := unsafe { &TypedStyleValueBox(left_value.css_value_handle) }
	right_typed := unsafe { &TypedStyleValueBox(right_value.css_value_handle) }
	if left_typed.value is UnresolvedStyleValue {
		if right_typed.value is UnresolvedStyleValue {
			return custom_property_environment_optional_text_equal(left_typed.value.original_source_text,
				right_typed.value.original_source_text)
				&& left_typed.value.substitution_functions_presence == right_typed.value.substitution_functions_presence
				&& left_typed.value.tokens == right_typed.value.tokens
		}
	}
	return false
}
