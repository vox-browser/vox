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
