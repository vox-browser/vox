module css

import dom

fn retained_size_old_oracle(style &ComputedProperties, property_id PropertyID) Size {
	value := style.property(property_id, .yes) or { return Size.make_auto() }
	parsed := style_value_logic_from_dom(property_id, value) or { return Size.make_auto() }
	return Size.from_style_value(parsed)
}

fn test_computed_size_retained_owner_precedes_text_for_every_size_kind() {
	fixtures := {PropertyID.width: ['auto', 'min-content', 'max-content', 'fit-content',
		'fit-content(25%)', 'calc(2px + 3%)', '37.5%', '12.5em', 'anchor-size(width, 10px)'],
		.max_width: ['none']}
	for property_id, texts in fixtures {
		for text in texts {
			typed := parse_css_value_logic(property_id, text) or { panic('fixture ${text}') }
			expected := Size.from_style_value(typed)
			mut bridge := dom_style_value_from_value_logic(typed)
			bridge.css_text = 'invalid trailing /*'
			mut style := ComputedProperties.new()
			style.set_property(property_id, bridge, .no, .no)
			actual := style.size_value(property_id)
			assert actual.type_ == expected.type_
			assert actual.serialize(.normal) == expected.serialize(.normal)
			assert actual.serialize(.normal) == retained_size_old_oracle(style, property_id).serialize(.normal)
		}
	}
	for typed in [StyleValue(StringStyleValue.create('12px')), StyleValue(NumberStyleValue.create(3)),
		StyleValue(KeywordStyleValue.create(.normal))] {
		mut bridge := dom_style_value_from_value_logic(typed)
		bridge.css_text = '27px'
		mut style := ComputedProperties.new()
		style.set_property(.width, bridge, .no, .no)
		assert style.size_value(.width).is_auto()
		assert retained_size_old_oracle(style, .width).is_auto()
	}
}

fn test_computed_size_preserves_nil_owner_parsing_and_invalid_fallback() {
	mut style := ComputedProperties.new()
	assert style.size_value(.width).is_auto()
	for text in ['12.5px', '37.5%', 'fit-content(25%)', 'calc(2px + 3%)', 'min-content'] {
		style.set_property(.width, &dom.StyleValue{css_text: text}, .no, .no)
		assert style.size_value(.width).serialize(.normal) == retained_size_old_oracle(style, .width).serialize(.normal)
	}
	for text in ['', ' ', '12px trailing', '12px 5px', 'bogus-value'] {
		style.set_property(.width, &dom.StyleValue{css_text: text}, .no, .no)
		assert style.size_value(.width).is_auto()
		assert retained_size_old_oracle(style, .width).is_auto()
	}
	style.set_property(.width, &dom.StyleValue{css_text: '12.5px'}, .no, .no)
	assert style.size_value(.width).length() == Length.new(12.5, .px)
}

fn test_computed_size_reads_owner_mutation_replacement_and_clearing() {
	mut style := ComputedProperties.new()
	mut bridge := dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.new(2.5, .em))))
	style.set_property(.width, bridge, .no, .no)
	first := style.size_value(.width)
	assert first.length() == Length.new(2.5, .em)
	mut owner := unsafe { &TypedStyleValueBox(bridge.css_value_handle) }
	owner.value = StyleValue(PercentageStyleValue.create(Percentage.new(42)))
	gc_collect()
	assert style.size_value(.width).percentage() == Percentage.new(42)
	assert first.length() == Length.new(2.5, .em)
	replacement := dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.max_content)))
	bridge.css_value_handle = replacement.css_value_handle
	gc_collect()
	assert style.size_value(.width).is_max_content()
	bridge.css_value_handle = unsafe { nil }
	bridge.css_text = '17px'
	assert style.size_value(.width).length() == Length.make_px(17)
	assert first.length() == Length.new(2.5, .em)
}
