module aria

import dom

fn role_type_test_element(document &dom.Document, name string) &dom.Element {
	return dom.create_element(document, name, 'http://www.w3.org/1999/xhtml', none, none, false) or {
		panic(err)
	}
}

fn empty_aria_data_for_role_test() AriaData {
	document := dom.Document.create(dom.url_about_blank())
	element := role_type_test_element(document, 'div')
	return AriaData.from_mixin(ARIAMixin.create(element, none, none))
}

fn test_role_type_metadata_required_values_and_serialization() {
	data := empty_aria_data_for_role_test()
	button := build_role_object(.button, true, data)!
	assert button.name_from_source() == .author_content
	assert button.accessible_name_required()
	assert button.children_are_presentational()
	assert StateAndProperty.aria_disabled in button.supported_states()

	checkbox := build_role_object(.checkbox, true, data)!
	assert checkbox.required_states() == [.aria_checked]

	slider := build_role_object(.slider, true, data)!
	assert slider.required_properties() == [.aria_value_now]
	assert slider.default_value_for_property_or_state(.aria_orientation) is AriaOrientation
	assert state_or_property_to_string_value(.aria_value_min, &data,
		slider.default_value_for_property_or_state(.aria_value_min)) == '0.0'
	serialized := slider.serialize_as_json()
	assert serialized.contains('"required_properties"')
	assert serialized.contains('"aria-valuenow"')

	focusable_separator := build_role_object(.separator, true, data)!
	non_focusable_separator := build_role_object(.separator, false, data)!
	assert StateAndProperty.aria_value_now in focusable_separator.required_properties()
	assert non_focusable_separator.required_properties().len == 0
}

fn test_every_non_abstract_role_has_generated_metadata() {
	data := empty_aria_data_for_role_test()
	for role in all_roles {
		if is_abstract_role(role) {
			if _ := build_role_object(role, false, data) {
				assert false
			}
			continue
		}
		role_type := build_role_object(role, false, data) or {
			panic('missing metadata for ${role_name(role)}: ${err}')
		}
		assert role_type.role == role
	}
}

fn test_role_type_exact_build_role_object_entry_point() {
	data := empty_aria_data_for_role_test()
	button := RoleType.build_role_object(.button, true, data)!
	assert button.role == .button
	if _ := RoleType.build_role_object(.command, false, data) {
		assert false
	}
}
