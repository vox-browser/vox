module css

fn parsed_counter_property(property_id PropertyID, text string) ?StyleValue {
	return parse_css_value_logic(property_id, text)
}

fn test_reversed_counter_reset_parses_and_serializes() {
	for input, expected in {
		'reversed(sec)':          'reversed(sec)'
		'reversed(sec) 7':        'reversed(sec) 7'
		'reversed(sec) -3 foo 2': 'reversed(sec) -3 foo 2'
		'foo reversed(bar)':      'foo 0 reversed(bar)'
	} {
		value := parsed_counter_property(.counter_reset, input) or {
			panic('could not parse ${input}')
		}
		assert value.serialize(.normal) == expected
	}
}

fn test_reversed_counter_reset_rejects_invalid_names_and_values() {
	assert parsed_counter_property(.counter_reset, 'reversed(none)') == none
	assert parsed_counter_property(.counter_reset, 'reversed(sec) 1.5') == none
}

fn test_reversed_counters_are_only_valid_for_counter_reset() {
	assert parsed_counter_property(.counter_increment, 'reversed(sec)') == none
	assert parsed_counter_property(.counter_set, 'reversed(sec)') == none
}
