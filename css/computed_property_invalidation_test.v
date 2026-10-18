module css

import dom

fn reference_raw_property_invalidation(previous &ComputedProperties,
	current &ComputedProperties) RequiredInvalidationAfterStyleChange {
	mut invalidation := RequiredInvalidationAfterStyleChange{}
	for id in computed_interpolation_longhand_property_ids() {
		invalidation = required_invalidation_after_style_change_or(invalidation, compute_property_invalidation(id,
			previous.property(id, .no), current.property(id, .no)))
	}
	return invalidation
}

fn test_raw_property_invalidation_covers_every_longhand_and_empty_store() {
	original := computed_properties_with_initial_values()
	for id in computed_interpolation_longhand_property_ids() {
		mut changed := &ComputedProperties{
			...original
			property_store_: original.clone_raw_property_store()
		}
		changed.set_property_without_modifying_flags(id, &dom.StyleValue{
			css_text: 'different'
		})
		expected := reference_raw_property_invalidation(original, changed)
		assert compute_raw_property_invalidation(original, changed) == expected
		assert compute_raw_property_invalidation(changed, original) == reference_raw_property_invalidation(changed,
			original)
	}
	for empty in [ComputedProperties.new(), &ComputedProperties{}] {
		assert compute_raw_property_invalidation(empty, original) == reference_raw_property_invalidation(empty,
			original)
		assert compute_raw_property_invalidation(original, empty) == reference_raw_property_invalidation(original,
			empty)
		assert compute_raw_property_invalidation(empty, empty).is_none()
	}
}

fn test_raw_property_invalidation_keeps_copy_on_write_and_equal_values() {
	mut original := computed_properties_with_initial_values()
	value := parse_css_value(ParsingParams{}, '41px', .width) or { panic('width') }
	original.set_property(.width, value, .no, .no)
	mut changed := &ComputedProperties{
		...original
		property_store_: original.clone_raw_property_store()
	}
	changed.set_property(.width, parse_css_value(ParsingParams{}, '41px', .width) or {
		panic('width')
	}, .yes, .yes)
	assert compute_raw_property_invalidation(original, changed).is_none()
	changed.set_property(.width, parse_css_value(ParsingParams{}, '42px', .width) or {
		panic('width')
	}, .no, .no)
	assert compute_raw_property_invalidation(original, changed).needs_relayout()
	assert compute_raw_property_invalidation(original, original).is_none()
}

fn test_raw_property_invalidation_preserves_combined_independent_effects() {
	original := computed_properties_with_initial_values()
	mut changed := &ComputedProperties{
		...original
		property_store_: original.clone_raw_property_store()
	}
	for id, text in {
		PropertyID.width: '42px'
		.visibility:      'hidden'
		.container_name:  'sidebar'
		.transform:       'translateX(3px)'
	} {
		value := parse_css_value(ParsingParams{}, text, id) or { panic(text) }
		changed.set_property_without_modifying_flags(id, value)
	}
	result := compute_raw_property_invalidation(original, changed)
	assert result == reference_raw_property_invalidation(original, changed)
	assert result.needs_relayout()
	assert result.affects_hit_testing
	assert result.recompute_descendant_styles
}
