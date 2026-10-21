module css

import dom

// The ordinary initial value is a coordinated list containing `none`.
// Inspect its retained typed items instead of allocating DOM wrappers for a
// list that cannot produce any animation.
fn computed_animation_names_are_none(value &dom.StyleValue) bool {
	return computed_coordinating_value_is_none(value)
}
