module animations

import dom

struct NotAnAnimation {
mut:
	words [64]u64
}

fn test_comparing_css_animation_events_does_not_read_them_as_api_animations() {
	// CSS transitions and animations are owned by the css module; their handle
	// is not an Animations.Animation, so its fields must not be read as one.
	mut garbage := &NotAnAnimation{}
	for index in 0 .. garbage.words.len {
		garbage.words[index] = 0x3ff0000000000000
	}
	transition_a := &dom.Animation{
		concrete_handle_: voidptr(garbage)
		concrete_kind_:   .css_transition
	}
	transition_b := &dom.Animation{
		concrete_handle_: voidptr(garbage)
		concrete_kind_:   .css_transition
	}
	css_animation := &dom.Animation{
		concrete_handle_: voidptr(garbage)
		concrete_kind_:   .css_animation
	}
	api := Animation.create(none, none)
	assert compare_dom_animations(unsafe { nil }, transition_a, transition_b) == 0
	assert compare_dom_animations(unsafe { nil }, transition_a, css_animation) < 0
	assert compare_dom_animations(unsafe { nil }, css_animation, &api.Animation) < 0
	assert compare_dom_animations(unsafe { nil }, &api.Animation, transition_b) > 0
	assert compare_dom_animations(unsafe { nil }, &api.Animation, &api.Animation) == 0
}
