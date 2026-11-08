module css

fn test_font_family_identifier_sequences_serialize_without_escaping_their_separators() {
	for text in ['FB Armada', 'Times New Roman', 'One One', 'Menu', r'One\ Two Three',
		r'Two\ Words', 'serif, FB Armada, "Quoted Family"'] {
		value := parse_css_value_logic(.font_family, text) or { panic(text) }
		assert value.serialize(.normal) == text, text
		serialized := value.serialize(.normal)
		roundtrip := parse_css_value_logic(.font_family, serialized) or { panic(serialized) }
		assert roundtrip.serialize(.normal) == serialized
	}
	value := parse_css_value_logic(.font_family, 'Times New Roman') or { panic('family') }
	assert value is StyleValueList
	family := value.values()[0]
	assert family is CustomIdentStyleValue
	assert family.custom_ident() == 'Times New Roman'
	assert serialize_a_series_of_component_values(family.tokenize()) == 'Times New Roman'
}

fn test_font_shorthand_serializes_multi_identifier_family_names() {
	for text in ['16px FB Armada', 'oblique 16px Times New Roman',
		'small-caps 20% / 1.2 FB Armada', 'italic bold 16px Arial, Times New Roman'] {
		value := parse_css_value_logic(.font, text) or { panic(text) }
		assert value.serialize(.normal) == text, text
	}
	// Identifiers for other properties still escape spaces inside one token.
	assert CustomIdentStyleValue.create('Two Words').serialize(.normal) == r'Two\ Words'
}

fn test_font_family_identifier_boundaries_participate_in_equality_and_invalidation() {
	sequence := StyleValue(CustomIdentStyleValue{
		custom_ident_: 'Two Words'
		family_identifiers_: ['Two', 'Words']
	})
	one_ident := StyleValue(CustomIdentStyleValue.create('Two Words'))
	for left in [sequence, one_ident] {
		for right in [sequence, one_ident] {
			expected := style_values_equal_using_union(left, right)
			assert left.equals(right) == expected
			assert style_value_option_changed(dom_style_value_from_value_logic(left),
				dom_style_value_from_value_logic(right)) == !expected
		}
	}
	assert !sequence.equals(one_ident)
}
