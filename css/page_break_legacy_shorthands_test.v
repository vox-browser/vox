module css

fn page_break_serialization(property_id PropertyID, text string) ?string {
	value := parse_css_value_logic(property_id, text) or { return none }
	return value.serialize(.normal)
}

fn test_page_break_legacy_shorthand_metadata_and_parsing() {
	assert property_id_from_string('page-break-after')? == .page_break_after
	assert property_id_from_string('PAGE-BREAK-BEFORE')? == .page_break_before
	assert property_id_from_string('page-break-inside')? == .page_break_inside
	assert property_is_legacy_shorthand(.page_break_after)
	assert property_is_legacy_shorthand(.page_break_before)
	assert property_is_legacy_shorthand(.page_break_inside)
	assert !property_is_legacy_shorthand(.break_before)
	assert generated_longhands_for_shorthand(.page_break_after) == [PropertyID.break_after]
	assert generated_longhands_for_shorthand(.page_break_before) == [PropertyID.break_before]
	assert generated_longhands_for_shorthand(.page_break_inside) == [PropertyID.break_inside]
	assert PropertyID.page_break_before !in generated_shorthands_for_longhand(.break_before)

	for property_id in [PropertyID.page_break_after, .page_break_before] {
		for value in ['auto', 'avoid', 'left', 'right', 'always'] {
			assert page_break_serialization(property_id, value)? == value, '${property_id}: ${value}'
		}
		for invalid in ['page', 'column', 'avoid-page', 'recto', 'auto auto'] {
			assert page_break_serialization(property_id, invalid) == none, '${property_id}: ${invalid}'
		}
	}
	assert page_break_serialization(.page_break_inside, 'auto')? == 'auto'
	assert page_break_serialization(.page_break_inside, 'avoid')? == 'avoid'
	for invalid in ['always', 'left', 'right', 'avoid-page'] {
		assert page_break_serialization(.page_break_inside, invalid) == none, invalid
	}
}

fn test_page_break_legacy_shorthand_cssom_mapping_and_serialization() {
	mut declaration := CSSStyleProperties.create()
	declaration.set_property('page-break-before', 'always', '')!
	assert declaration.get_property_value('page-break-before') == 'always'
	assert declaration.get_property_value('break-before') == 'page'
	assert declaration.css_text() == 'break-before: page;'

	declaration.set_property('break-before', 'column', '')!
	assert declaration.get_property_value('page-break-before') == ''
	assert declaration.get_property_value('break-before') == 'column'

	declaration.set_property('break-inside', 'avoid-page', '')!
	assert declaration.get_property_value('page-break-inside') == 'avoid'
	declaration.set_property('page-break-inside', 'avoid', 'important')!
	assert declaration.get_property_value('break-inside') == 'avoid'
	assert declaration.get_property_priority('break-inside') == 'important'
}

fn test_page_break_legacy_unresolved_values_serialize_under_the_longhand_name() {
	mut declaration := CSSStyleProperties.create()
	declaration.set_property('page-break-after', 'var(--side)', '')!
	assert declaration.get_property_value('page-break-after') == 'var(--side)'
	assert declaration.get_property_value('break-after') == ''
	assert declaration.css_text() == 'break-after: var(--side);'
}
