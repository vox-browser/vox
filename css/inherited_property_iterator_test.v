module css

fn test_inherited_property_iterator_covers_every_flag_and_partial_final_byte() {
	mut style := computed_properties_with_initial_values()
	for id in computed_interpolation_longhand_property_ids() {
		style.set_property_inherited(id, .no)
	}
	for id in style.inherited_property_iterator() {
		assert false, '${id}'
	}
	mut expected := []PropertyID{}
	for index, id in computed_interpolation_longhand_property_ids() {
		if index % 3 == 1 || index == number_of_longhand_properties - 1 {
			style.set_property_inherited(id, .yes)
			expected << id
		}
	}
	mut actual := []PropertyID{}
	for id in style.inherited_property_iterator() {
		actual << id
	}
	assert actual == expected
	for id in computed_interpolation_longhand_property_ids() {
		style.set_property_inherited(id, .yes)
	}
	actual.clear()
	for id in style.inherited_property_iterator() {
		actual << id
	}
	assert actual == computed_interpolation_longhand_property_ids()
}

fn test_inherited_property_iterator_observes_future_flag_changes_in_order() {
	mut style := ComputedProperties.new()
	ids := computed_interpolation_longhand_property_ids()
	style.set_property_inherited(ids[0], .yes)
	style.set_property_inherited(ids[7], .yes)
	mut iterator := style.inherited_property_iterator()
	assert (iterator.next() or { panic('first') }) == ids[0]
	style.set_property_inherited(ids[1], .yes)
	style.set_property_inherited(ids[7], .no)
	style.set_property_inherited(ids[16], .yes)
	assert (iterator.next() or { panic('same byte insertion') }) == ids[1]
	assert (iterator.next() or { panic('next byte insertion') }) == ids[16]
	style.set_property_inherited(ids[0], .yes)
	assert iterator.next() == none
}

fn test_inherited_property_iterator_keeps_independent_copied_flags() {
	mut original := ComputedProperties.new()
	original.set_property_inherited(.width, .yes)
	mut copy := *original
	copy.set_property_inherited(.height, .yes)
	mut first := []PropertyID{}
	mut second := []PropertyID{}
	for id in original.inherited_property_iterator() {
		first << id
	}
	for id in copy.inherited_property_iterator() {
		second << id
	}
	assert first == [PropertyID.width]
	assert second == [PropertyID.height, .width]
}
