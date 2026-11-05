module css

import dom

fn test_repeated_transition_registration_keeps_storage_bounded_after_warmup() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer {
		document.finalize()
		document.release_native_storage()
	}
	element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	subject := dom.AbstractElement.new(element, none)
	mut style := computed_properties_with_initial_values()
	transitions := style.transitions()
	assert transitions.len == 1
	assert transitions[0].properties.len > 100
	document.enable_native_storage()
	mut allocations := document.enter_native_storage()
	defer { allocations.finish() }
	mut storage := CSSTransitionStorage{}
	for _ in 0 .. 8 {
		storage.clear_registered_transitions(subject)
		storage.add_transitioned_properties(subject, transitions)
	}
	mut before := i64(0)
	$if prealloc { before = document.native_storage().arena.usage().used }
	for _ in 0 .. 64 {
		storage.clear_registered_transitions(subject)
		storage.add_transitioned_properties(subject, transitions)
	}
	$if prealloc {
		growth := document.native_storage().arena.usage().used - before
		assert growth < 64 * 1024, '${growth} bytes accumulated when replacing unchanged registrations'
	}
	assert storage.property_ids_with_matching_transition_property_entry(subject) == transitions[0].properties
	assert (storage.property_transition_attributes(subject, .opacity) or { panic('opacity') }).duration == 0
}

fn test_reused_registration_storage_preserves_other_targets_and_published_values() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	subject := dom.AbstractElement.new(element, none)
	before := dom.AbstractElement.new(element, .before)
	after := dom.AbstractElement.new(element, .after)
	mut storage := CSSTransitionStorage{}
	storage.add_transitioned_properties(subject, [TransitionProperties{
		properties: [PropertyID.opacity, .width]
		duration: 200
		delay: -10
		timing_function: EasingFunction{ value: StepsEasingFunction{ interval_count: 4, position: .jump_end } }
	}])
	storage.add_transitioned_properties(before, [TransitionProperties{
		properties: [PropertyID.color]
		duration: 300
	}])
	published_ids := storage.property_ids_with_matching_transition_property_entry(subject)
	published_attributes := storage.property_transition_attributes(subject, .opacity) or { panic('opacity') }
	storage.clear_registered_transitions(subject)
	storage.clear_registered_transitions(subject)
	assert abstract_element_storage_key(subject) !in storage.registered_transition_attributes
	assert storage.property_transition_attributes(subject, .opacity) == none
	storage.add_transitioned_properties(after, [TransitionProperties{
		properties: [PropertyID.height, .height]
		duration: 400
	}])
	assert storage.property_ids_with_matching_transition_property_entry(after) == [PropertyID.height]
	assert storage.property_transition_attributes(after, .width) == none
	assert (storage.property_transition_attributes(after, .height) or { panic('height') }).duration == 400
	assert (storage.property_transition_attributes(before, .color) or { panic('color') }).duration == 300
	assert published_ids == [PropertyID.opacity, .width]
	assert published_attributes.duration == 200
	assert published_attributes.delay == -10
	assert published_attributes.timing_function == EasingFunction{ value: StepsEasingFunction{ interval_count: 4, position: .jump_end } }
}
