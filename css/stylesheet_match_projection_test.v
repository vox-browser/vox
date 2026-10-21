module css

import platform

fn reference_stylesheet_compound_match_set(compound CompoundSelector) InvalidationSet {
	mut data := StyleInvalidationData{}
	mut result := InvalidationSet{}
	for index in 0 .. compound.simple_selectors.len {
		simple := unsafe { &compound.simple_selectors[index] }
		build_invalidation_sets_for_simple_selector(simple_selector_for_invalidation(simple), mut result, .no, mut data, .no)
	}
	return result
}

fn test_stylesheet_match_projection_preserves_nested_selector_properties() {
	for text in ['.target', '#target[flag]:hover',
		':is(.one, #two):not([hidden]):has(> .child:checked)',
		':nth-child(2n of .row, [visible])', ':host(.active)', '::slotted(span.ready)'] {
		selector := selector_from_text(text)
		compound := selector.compound_selectors()[0]
		expected := reference_stylesheet_compound_match_set(compound)
		actual := style_sheet_compound_invalidation_set(compound)
		assert actual == expected, text
	}
}

fn test_stylesheet_match_projection_owns_its_property_strings() {
	mut input := platform.new_arena('temporary stylesheet selector')
	entry := input.enter()
	selector := selector_from_text(':is(.owned-class, #owned-id)[owned-attribute]'.clone())
	input.leave(entry)
	result := style_sheet_compound_invalidation_set(selector.compound_selectors()[0])
	input.release()
	properties := result.properties()
	assert properties.any(it.type_ == .class && it.value == 'owned-class')
	assert properties.any(it.type_ == .id && it.value == 'owned-id')
	assert properties.any(it.type_ == .attribute && it.value == 'owned-attribute')
}

fn stylesheet_projection_retained_bytes(compound CompoundSelector, workspace bool) u64 {
	mut output := platform.new_arena('stylesheet projection budget')
	entry := output.enter()
	for _ in 0 .. 32 {
		result := if workspace {
			style_sheet_compound_invalidation_set(compound)
		} else {
			reference_stylesheet_compound_match_set(compound)
		}
		assert result.has_properties()
	}
	output.leave(entry)
	used := output.usage().used
	output.release()
	return used
}

fn test_stylesheet_match_projection_retires_unused_dependency_plans() {
	selector := selector_from_text(':is(.one, .two, .three):has(> .child:checked):not([hidden])')
	compound := selector.compound_selectors()[0]
	$if prealloc {
		reference := stylesheet_projection_retained_bytes(compound, false)
		projected := stylesheet_projection_retained_bytes(compound, true)
		assert projected < reference / 2, 'projected=${projected} reference=${reference}'
	}
}
