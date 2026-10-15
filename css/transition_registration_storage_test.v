module css

import dom

fn transition_registration_subject() dom.AbstractElement {
	document := dom.Document.create(dom.url_about_blank())
	element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	return dom.AbstractElement.new(element, none)
}

fn test_registered_all_transition_keeps_last_matching_timing_and_first_property_order() {
	subject := transition_registration_subject()
	mut storage := CSSTransitionStorage{}
	mut style := computed_properties_with_initial_values()
	for property_id, text in {PropertyID.transition_property: 'all, opacity, width',
		.transition_duration: '200ms, 300ms, 400ms', .transition_delay: '5ms, 10ms, 15ms',
		.transition_timing_function: 'linear, ease-in, steps(4, jump-end)',
		.transition_behavior: 'normal, allow-discrete'} {
		style.set_property(property_id, parse_css_value(ParsingParams{}, text, property_id) or { panic('invalid ${text}') }, .no, .no)
	}
	transitions := style.transitions()
	storage.add_transitioned_properties(subject, transitions)
	ids := storage.property_ids_with_matching_transition_property_entry(subject)
	assert ids == transitions[0].properties
	for property_id in ids {
		actual := storage.property_transition_attributes(subject, property_id) or { panic('missing ${property_id}') }
		expected := if property_id == .opacity { transitions[1] } else if property_id == .width { transitions[2] } else { transitions[0] }
		assert actual.duration == expected.duration
		assert actual.delay == expected.delay
		assert actual.timing_function == expected.timing_function
		assert actual.transition_behavior == expected.transition_behavior
	}
	// Retaining the timing once per declaration bounds the data for `all`.
	bucket := storage.registered_transition_attributes[abstract_element_storage_key(subject)] or { panic('missing registrations') }
	assert bucket.attributes.len == 3
	assert bucket.property_ids.len > 100
}

fn test_registered_transition_additions_and_clear_do_not_retain_stale_properties() {
	subject := transition_registration_subject()
	mut storage := CSSTransitionStorage{}
	storage.add_transitioned_properties(subject, [TransitionProperties{
		properties: [PropertyID.width, .opacity]
		duration: 100
	}])
	mut prior_ids := storage.property_ids_with_matching_transition_property_entry(subject)
	prior_ids[0] = .height
	assert storage.property_ids_with_matching_transition_property_entry(subject) == [PropertyID.width, .opacity]
	storage.add_transitioned_properties(subject, [TransitionProperties{
		properties: [PropertyID.opacity, .height, .opacity]
		duration: 250
		delay: -10
	}])
	assert storage.property_ids_with_matching_transition_property_entry(subject) == [PropertyID.width, .opacity, .height]
	assert (storage.property_transition_attributes(subject, .width) or { panic('width') }).duration == 100
	assert (storage.property_transition_attributes(subject, .opacity) or { panic('opacity') }).duration == 250
	storage.clear_registered_transitions(subject)
	assert storage.property_ids_with_matching_transition_property_entry(subject).len == 0
	assert storage.property_transition_attributes(subject, .width) == none
	storage.add_transitioned_properties(subject, [TransitionProperties{
		properties: [PropertyID.color]
		duration: 75
	}])
	gc_collect()
	assert storage.property_transition_attributes(subject, .opacity) == none
	assert storage.property_ids_with_matching_transition_property_entry(subject) == [PropertyID.color]
	assert (storage.property_transition_attributes(subject, .color) or { panic('color') }).duration == 75
}

fn test_registered_transition_timing_is_separate_for_element_and_pseudo_elements() {
	subject := transition_registration_subject()
	before := dom.AbstractElement.new(subject.element(), .before)
	after := dom.AbstractElement.new(subject.element(), .after)
	mut storage := CSSTransitionStorage{}
	for index, target in [subject, before, after] {
		storage.add_transitioned_properties(target, [TransitionProperties{
			properties: [PropertyID.opacity]
			duration: f64(index + 1) * 100
		}])
	}
	storage.clear_registered_transitions(before)
	gc_collect()
	assert (storage.property_transition_attributes(subject, .opacity) or { panic('subject') }).duration == 100
	assert storage.property_transition_attributes(before, .opacity) == none
	assert (storage.property_transition_attributes(after, .opacity) or { panic('after') }).duration == 300
}
