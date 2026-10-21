module css

import dom

fn test_property_lookup_preserves_important_animation_and_transition_precedence() {
	mut style := ComputedProperties.new()
	base := &dom.StyleValue{css_text: '10px'}
	animated := &dom.StyleValue{css_text: '20px'}
	assert style.property(.width, .yes) == none
	style.set_property(.width, base, .no, .yes)
	assert voidptr(style.property(.width, .yes) or { panic('missing base') }) == voidptr(base)
	style.set_animated_property(.height, animated, .no, .no)
	assert voidptr(style.property(.width, .yes) or { panic('missing base') }) == voidptr(base)
	style.set_animated_property(.width, animated, .no, .no)
	assert voidptr(style.property(.width, .yes) or { panic('missing important') }) == voidptr(base)
	style.set_animated_property(.width, animated, .yes, .no)
	assert voidptr(style.property(.width, .yes) or { panic('missing transition') }) == voidptr(animated)
	assert voidptr(style.property(.width, .no) or { panic('missing unanimated') }) == voidptr(base)
	style.remove_animated_property(.width)
	style.set_property_important(.width, .no)
	style.set_animated_property(.width, animated, .no, .no)
	assert voidptr(style.property(.width, .yes) or { panic('missing animation') }) == voidptr(animated)
	assert style.property(.opacity, .yes) == none
}

fn test_property_lookup_keeps_optional_pointer_identity_across_every_longhand_slot() {
	ids := computed_interpolation_longhand_property_ids()
	mut first := ComputedProperties.new()
	mut second := ComputedProperties.new()
	mut first_values := []&dom.StyleValue{}
	mut second_values := []&dom.StyleValue{}
	for index, id in ids {
		assert first.property(id, .no) == none
		assert first.property(id, .yes) == none
		// Equal serialized values still have distinct owners in each style.
		a := &dom.StyleValue{css_text: 'slot-${index}'}
		b := &dom.StyleValue{css_text: 'slot-${index}'}
		first.set_property(id, a, .no, .no)
		second.set_property(id, b, .no, .no)
		first_values << a
		second_values << b
	}
	for index, id in ids {
		assert voidptr(first.property(id, .no) or { panic('missing first base') }) == voidptr(first_values[index])
		assert voidptr(first.property(id, .yes) or { panic('missing first animated fallback') }) == voidptr(first_values[index])
		assert voidptr(second.property(id, .no) or { panic('missing second base') }) == voidptr(second_values[index])
		assert voidptr(second.property(id, .yes) or { panic('missing second animated fallback') }) == voidptr(second_values[index])
		assert voidptr(first_values[index]) != voidptr(second_values[index])
	}
}
