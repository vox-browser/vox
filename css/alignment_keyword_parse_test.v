module css

fn alignment_value_is_valid(property PropertyID, text string) bool {
	return parse_css_value(ParsingParams{}, text, property) != none
}

fn test_alignment_properties_reject_a_bare_overflow_position_keyword() {
	for property in [PropertyID.align_items, .align_self, .justify_items, .justify_self] {
		assert alignment_value_is_valid(property, 'center')
		assert alignment_value_is_valid(property, 'anchor-center')
		assert !alignment_value_is_valid(property, 'safe')
		assert !alignment_value_is_valid(property, 'unsafe')
	}
	assert alignment_value_is_valid(.justify_items, 'legacy')
	assert alignment_value_is_valid(.align_self, 'auto')
}

fn test_alignment_qualifiers_round_trip_and_reject_invalid_combinations() {
	for property in [PropertyID.align_items, .align_self, .justify_items, .justify_self] {
		for input, expected in {'safe center':'safe center', 'unsafe self-end':'unsafe self-end',
			'first baseline':'baseline', 'last baseline':'last baseline'} {
			value := parse_css_value(ParsingParams{}, input, property) or { panic(input) }
			assert value.css_text == expected
		}
		for input in ['safe stretch', 'unsafe baseline', 'baseline last', 'center safe', 'safe center end'] {
			assert !alignment_value_is_valid(property, input), input
		}
	}
	for input in ['left legacy', 'legacy left'] {
		value := parse_css_value(ParsingParams{}, input, .justify_items) or { panic(input) }
		assert value.css_text == 'legacy left'
		assert !alignment_value_is_valid(.justify_self, input)
	}
	assert alignment_value_is_valid(.align_self, 'safe normal')
	assert !alignment_value_is_valid(.align_items, 'safe normal')
	assert !alignment_value_is_valid(.align_self, 'safe left')
	assert alignment_value_is_valid(.justify_self, 'safe left')
}

fn test_place_shorthands_keep_qualified_longhands_separate() {
	for property in [PropertyID.place_items, .place_self] {
		for input in ['center end', 'safe center unsafe end', 'last baseline safe end', 'safe start'] {
			assert alignment_value_is_valid(property, input), input
		}
		assert !alignment_value_is_valid(property, 'safe center end start')
	}
	assert alignment_value_is_valid(.place_content, 'safe center unsafe end')
	assert alignment_value_is_valid(.place_content, 'last baseline')
	assert !alignment_value_is_valid(.justify_content, 'last baseline')
}
