module css

fn test_stretch_sizing_parses_physical_logical_and_flex_sizes_without_a_payload() {
	for property in [PropertyID.width, .height, .min_width, .min_height, .max_width,
		.max_height, .inline_size, .block_size, .min_inline_size, .min_block_size,
		.max_inline_size, .max_block_size, .flex_basis] {
		for text in ['stretch', 'StReTcH', '-webkit-fill-available'] {
			value := parse_css_value_logic(property, text) or { panic('${property}: ${text}') }
			size := Size.from_style_value(value)
			assert size.is_stretch()
			assert !size.is_auto() && !size.is_length_percentage()
			assert !size.is_intrinsic_sizing_constraint() && !size.contains_percentage()
			assert size.length_percentage_ == none
			assert size.serialize(.normal) == 'stretch'
			assert cssom_style_value_for_size(size).css_text == 'stretch'
		}
	}
	value := parse_css_value_logic(.flex, '1 0 stretch') or { panic('missing stretch flex basis') }
	assert value.serialize(.normal) == '1 0 stretch'
}

fn test_stretch_sizing_rejects_extra_tokens_and_remains_property_specific() {
	for value in ['stretch 1px', 'stretch()', 'stretch(10px)', 'stretch auto'] {
		assert parse_css_value_logic(.width, value) == none
	}
	assert parse_css_value_logic(.padding_left, 'stretch') == none
	assert parse_css_value_logic(.color, '-webkit-fill-available') == none
	assert Size.make_auto().is_auto()
	assert Size.make_stretch().type_() == .stretch
}
