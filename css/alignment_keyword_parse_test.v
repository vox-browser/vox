module css

fn alignment_value_is_valid(property PropertyID, text string) bool {
	return parse_css_value(ParsingParams{}, text, property) != none
}

fn test_alignment_properties_reject_a_bare_overflow_position_keyword() {
	for property in [PropertyID.align_items, .align_self, .justify_items, .justify_self] {
		assert alignment_value_is_valid(property, 'center')
		assert !alignment_value_is_valid(property, 'safe')
		assert !alignment_value_is_valid(property, 'unsafe')
	}
	assert alignment_value_is_valid(.justify_items, 'legacy')
	assert alignment_value_is_valid(.align_self, 'auto')
}
