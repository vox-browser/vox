module css

import dom

// The ordinary initial value is a coordinated list containing `none`.
// Inspect its retained typed items instead of allocating DOM wrappers for a
// list that cannot produce any animation.
fn computed_animation_names_are_none(value &dom.StyleValue) bool {
	if value.css_value_handle != unsafe { nil } {
		typed := unsafe { &TypedStyleValueBox(value.css_value_handle) }
		match typed.value {
			StyleValueList {
				if typed.value.separator() != .comma { return false }
				for name in typed.value.values() {
					if name.to_keyword() != .none_ { return false }
				}
				return true
			}
			else { return typed.value.to_keyword() == .none_ }
		}
	}
	return computed_interpolation_style_value_keyword(value) or { Keyword.invalid } == .none_
}
