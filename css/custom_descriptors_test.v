module css

fn test_custom_descriptor_names_retain_case_sensitive_identity() {
	upper := DescriptorNameAndID.from_name(.page, '--Accent') or {
		panic('custom descriptor name was rejected')
	}
	lower := DescriptorNameAndID.from_name(.page, '--accent') or {
		panic('custom descriptor name was rejected')
	}

	assert upper.id() == .custom
	assert upper.name() == '--Accent'
	assert upper != lower
}

fn test_builtin_descriptor_names_are_canonicalized() {
	margin := DescriptorNameAndID.from_name(.page, 'MARGIN-TOP') or {
		panic('built-in descriptor name was rejected')
	}

	assert margin.id() == .margin_top
	assert margin.name() == 'margin-top'
}

fn test_css_descriptors_address_custom_entries_by_name() {
	first_value := parse_custom_property_value('10px')
	second_value := parse_custom_property_value('red')
	descriptors := CSSDescriptors.create(.page, [
		Descriptor{
			descriptor_name_and_id: DescriptorNameAndID.from_name(.page, '--size') or {
				panic('custom descriptor name was rejected')
			}
			value: first_value
			serialized_value: '10px'
		},
		Descriptor{
			descriptor_name_and_id: DescriptorNameAndID.from_name(.page, '--color') or {
				panic('custom descriptor name was rejected')
			}
			value: second_value
			serialized_value: 'red'
		},
	])

	assert descriptors.length() == 2
	assert descriptors.item(0) == '--size'
	assert descriptors.item(1) == '--color'
	assert descriptors.get_property_value('--size') == '10px'
	assert descriptors.get_property_value('--SIZE') == ''
	stored_color := descriptors.descriptor(DescriptorNameAndID.from_name(.page, '--color') or {
		panic('custom descriptor name was rejected')
	}) or { panic('custom descriptor was not stored') }
	assert stored_color == second_value
	assert descriptors.serialized() == '--size: 10px; --color: red;'
}
