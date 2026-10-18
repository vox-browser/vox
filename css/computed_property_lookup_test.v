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

fn test_constant_and_dynamic_property_lookups_preserve_every_slot_across_collection() {
	mut style := ComputedProperties.new()
	mut base_values := []&dom.StyleValue{cap: number_of_longhand_properties}
	mut visible_values := []&dom.StyleValue{cap: number_of_longhand_properties}
	for index in 0 .. number_of_longhand_properties {
		id := property_id_from_longhand_index(index) or { panic('missing longhand ID') }
		assert style.property(id, .no) == none
		assert style.property(id, .yes) == none
		// The accessor preserves the opaque DOM value identity supplied by its
		// caller; parsing and property-specific value validation happen earlier.
		base := &dom.StyleValue{css_text: 'base-${index}'}
		important := index % 3 == 0
		style.set_property(id, base, .no, if important { Important.yes } else { Important.no })
		base_values << base
		mut visible := base
		if index % 5 == 0 {
			animated := &dom.StyleValue{css_text: 'animated-${index}'}
			transition := index % 7 == 0
			style.set_animated_property(id, animated,
				if transition { AnimatedPropertyResultOfTransition.yes } else { AnimatedPropertyResultOfTransition.no }, .no)
			if !important || transition { visible = animated }
		}
		visible_values << visible
	}
	for _ in 0 .. 3 {
		gc_collect()
		for index in 0 .. number_of_longhand_properties {
			id := property_id_from_longhand_index(index) or { panic('missing retained ID') }
			assert voidptr(style.property(id, .no) or { panic('missing base') }) == voidptr(base_values[index])
			assert voidptr(style.property(id, .yes) or { panic('missing visible') }) == voidptr(visible_values[index])
		}
		width_index := int(PropertyID.width) - int(first_longhand_property_id())
		last_index := number_of_longhand_properties - 1
		assert voidptr(style.property(.width, .no) or { panic('missing constant width') }) == voidptr(base_values[width_index])
		assert voidptr(style.property(.width, .yes) or { panic('missing constant animated width') }) == voidptr(visible_values[width_index])
		assert voidptr(style.property(.webkit_font_smoothing, .no) or { panic('missing last base') }) == voidptr(base_values[last_index])
		assert voidptr(style.property(.webkit_font_smoothing, .yes) or { panic('missing last visible') }) == voidptr(visible_values[last_index])
	}
	for index in 0 .. number_of_longhand_properties {
		if index % 5 != 0 { continue }
		id := property_id_from_longhand_index(index) or { panic('missing removable ID') }
		style.remove_animated_property(id)
		assert voidptr(style.property(id, .yes) or { panic('missing restored base') }) == voidptr(base_values[index])
	}
}
