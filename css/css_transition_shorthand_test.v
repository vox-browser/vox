module css

import dom

fn transition_shorthand_test_set(mut style ComputedProperties, property_id PropertyID, text string) {
	value := parse_css_value(ParsingParams{}, text, property_id) or {
		panic('invalid ${property_id}: ${text}')
	}
	style.set_property(property_id, value, .no, .no)
}

fn test_transition_shorthands_register_only_physical_longhands() {
	mut style := computed_properties_with_initial_values()
	for index in int(last_longhand_property_id()) + 1 .. int(PropertyID.container) + 1 {
		shorthand := unsafe { PropertyID(index) }
		if !property_is_shorthand(shorthand) {
			continue
		}
		transition_shorthand_test_set(mut style, .transition_property, string_from_property_id(shorthand))
		transitions := style.transitions()
		assert transitions.len == 1, '${shorthand}'
		assert transitions[0].properties.len > 0, '${shorthand}'
		for property_id in transitions[0].properties {
			assert computed_interpolation_is_longhand_property(property_id), '${shorthand}: ${property_id}'
			assert !property_is_logical_alias(property_id), '${shorthand}: ${property_id}'
		}
		if shorthand == .background {
			assert transitions[0].properties == [PropertyID.background_attachment,
				.background_clip, .background_color, .background_image, .background_origin,
				.background_position_x, .background_position_y, .background_repeat, .background_size]
		}
		if shorthand == .border {
			assert transitions[0].properties.len == 17
			assert PropertyID.border_top_width in transitions[0].properties
			assert PropertyID.border_left_style in transitions[0].properties
			assert PropertyID.border_bottom_color in transitions[0].properties
			assert PropertyID.border_image_source in transitions[0].properties
		}
	}
}

fn test_transition_expansion_preserves_timing_lists_logical_mapping_and_last_match() {
	mut style := computed_properties_with_initial_values()
	transition_shorthand_test_set(mut style, .writing_mode, 'vertical-rl')
	transition_shorthand_test_set(mut style, .direction, 'rtl')
	transition_shorthand_test_set(mut style, .transition_property, 'background, border-inline, border-inline-start-color')
	transition_shorthand_test_set(mut style, .transition_duration, '100ms, 200ms')
	transition_shorthand_test_set(mut style, .transition_delay, '5ms, 10ms, 15ms')
	transition_shorthand_test_set(mut style, .transition_timing_function, 'linear, ease')
	transition_shorthand_test_set(mut style, .transition_behavior, 'normal, allow-discrete')
	transitions := style.transitions()
	assert transitions.len == 3
	assert transitions[0].duration == 100
	assert transitions[1].duration == 200
	assert transitions[2].duration == 100
	assert transitions[1].transition_behavior == .allow_discrete
	assert transitions[2].transition_behavior == .normal
	assert transitions[2].properties == [PropertyID.border_bottom_color]
	assert PropertyID.border_top_width in transitions[1].properties
	assert PropertyID.border_bottom_width in transitions[1].properties

	document := dom.Document.create(dom.url_about_blank())
	target := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	abstract_element := dom.AbstractElement.new(target, none)
	mut storage := CSSTransitionStorage{}
	storage.add_transitioned_properties(abstract_element, transitions)
	background := storage.property_transition_attributes(abstract_element, .background_position_x) or { panic('missing background transition') }
	top := storage.property_transition_attributes(abstract_element, .border_top_color) or { panic('missing inline-end transition') }
	bottom := storage.property_transition_attributes(abstract_element, .border_bottom_color) or { panic('missing inline-start transition') }
	assert background.duration == 100 && background.delay == 5
	assert top.duration == 200 && top.delay == 10
	assert bottom.duration == 100 && bottom.delay == 15
	assert bottom.timing_function == background.timing_function
	assert bottom.transition_behavior == .normal
}

fn test_background_and_border_shorthand_transitions_survive_style_recomputation() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{active_document_: document})
	document.set_navigable(&dom.Navigable{active_document_: document})
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	mut computer := StyleComputer.new(document)
	mut abstract_element := dom.AbstractElement.new(element, none)
	element.set_attribute_value('style', 'background: black; border: 2px solid black; transition: background .1s linear, border .1s linear')
	initial := computer.compute_style(abstract_element)
	abstract_element.set_computed_properties(computed_properties_to_dom(initial))
	element.set_attribute_value('style', 'background: white; border: 6px solid white; transition: background .1s linear, border .1s linear')
	started := computer.compute_style(abstract_element)
	assert (started.property(.border_top_width, .yes) or { panic('missing starting border') }).css_text == '2px'
	initial_background := initial.property(.background_color, .no) or { panic('missing initial background') }
	assert style_values_equal(started.property(.background_color, .yes) or { panic('missing starting background') }, initial_background)
	abstract_element.set_computed_properties(computed_properties_to_dom(started))

	computer.set_animation_time_ms(50)
	midpoint := computer.compute_style(abstract_element)
	assert (midpoint.property(.border_top_width, .yes) or { panic('missing interpolated border') }).css_text == '4px'
	midpoint_background := midpoint.property(.background_color, .yes) or { panic('missing interpolated background') }
	assert !style_values_equal(midpoint_background, initial_background)
	assert !style_values_equal(midpoint_background, midpoint.property(.background_color, .no) or { panic('missing target background') })
}
