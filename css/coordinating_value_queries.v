module css

import dom

// Scalar questions about an immutable coordinated list need no DOM wrappers
// for its items. Serialized compatibility values keep the existing parser.
fn computed_coordinating_value_is_none(value &dom.StyleValue) bool {
	if value.css_value_handle != unsafe { nil } {
		typed := unsafe { &TypedStyleValueBox(value.css_value_handle) }
		match typed.value {
			StyleValueList {
				if typed.value.separator() != .comma { return false }
				for item in typed.value.values_ {
					if item.to_keyword() != .none_ { return false }
				}
				return true
			}
			else { return typed.value.to_keyword() == .none_ }
		}
	}
	return computed_interpolation_style_value_keyword(value) or { Keyword.invalid } == .none_
}

fn typed_coordinating_value_count(value &dom.StyleValue) ?int {
	if value.css_value_handle == unsafe { nil } { return none }
	typed := unsafe { &TypedStyleValueBox(value.css_value_handle) }
	match typed.value {
		StyleValueList {
			if typed.value.separator() != .comma { return none }
			return typed.value.size()
		}
		UnresolvedStyleValue, PendingSubstitutionStyleValue { return none }
		else { return 1 }
	}
}

fn typed_coordinating_keyword_at(value &dom.StyleValue, index int) ?Keyword {
	if value.css_value_handle == unsafe { nil } { return none }
	typed := unsafe { &TypedStyleValueBox(value.css_value_handle) }
	if typed.value is StyleValueList {
		if typed.value.separator() != .comma || index < 0 || index >= typed.value.size() { return none }
		return typed.value.values_[index].to_keyword()
	}
	if index != 0 { return none }
	return typed.value.to_keyword()
}
