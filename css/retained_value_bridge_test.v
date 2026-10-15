module css

import dom

fn retained_bridge_old_oracle(property_id PropertyID, value &dom.StyleValue) ?StyleValue {
	if typed := typed_style_value_logic_from_dom(value) { return typed }
	return parse_css_value_logic(property_id, value.css_text)
}

fn test_retained_bridge_preserves_typed_precedence_and_all_scalar_kinds() {
	values := [StyleValue(KeywordStyleValue.create(.auto)),
		StyleValue(LengthStyleValue.create(Length.new(-1.25, .em))),
		StyleValue(PercentageStyleValue.create(Percentage.new(37.5))),
		StyleValue(NumberStyleValue.create(0.75)), StyleValue(IntegerStyleValue.create(3)),
		StyleValue(StringStyleValue.create('retained string')),
		StyleValue(CustomIdentStyleValue.create('retained-ident'))]
	for expected in values {
		mut bridge := dom_style_value_from_value_logic(expected)
		for serialized in ['12px', 'red', 'invalid trailing /*'] {
			bridge.css_text = serialized
			for property_id in [PropertyID.width, .color] {
				actual := style_value_logic_from_dom(property_id, bridge) or { panic('lost retained owner') }
				oracle := retained_bridge_old_oracle(property_id, bridge) or { panic('oracle lost owner') }
				assert actual.type_() == expected.type_()
				assert actual.equals(expected)
				assert actual.equals(oracle)
			}
		}
	}
}

fn test_retained_bridge_keeps_complex_values_and_strict_serialized_fallback() {
	fixtures := {PropertyID.width: 'fit-content(25%)', .height: 'calc(2px + 3%)',
		.display: 'inline flex', .color: 'rgb(10, 20, 30)',
		.background_image: 'linear-gradient(red, blue)', .font_family: 'SerenitySans, serif'}
	for property_id, text in fixtures {
		expected := parse_css_value_logic(property_id, text) or { panic('fixture ${text}') }
		mut retained := dom_style_value_from_value_logic(expected)
		retained.css_text = 'invalid trailing /*'
		actual := style_value_logic_from_dom(property_id, retained) or { panic('retained complex value') }
		assert actual.type_() == expected.type_() && actual.equals(expected)
		serialized := &dom.StyleValue{css_text: text}
		fallback := style_value_logic_from_dom(property_id, serialized) or { panic('serialized fallback') }
		assert fallback.type_() == expected.type_() && fallback.equals(expected)
		assert fallback.equals(retained_bridge_old_oracle(property_id, serialized) or { panic('oracle fallback') })
	}
	for text in ['', '  ', '12px trailing', '12px 5px', 'bogus-value'] {
		bridge := &dom.StyleValue{css_text: text}
		assert style_value_logic_from_dom(.width, bridge) == none
		assert retained_bridge_old_oracle(.width, bridge) == none
	}
	value := style_value_logic_from_dom(.width, &dom.StyleValue{css_text: '12.5px'}) or { panic('length') }
	assert value is LengthStyleValue
	assert (value as LengthStyleValue).length() == Length.new(12.5, .px)
}

fn test_retained_bridge_observes_owner_replacement_mutation_and_collection() {
	mut bridge := dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.new(2.5, .em))))
	first := style_value_logic_from_dom(.width, bridge) or { panic('first owner') }
	mut owner := unsafe { &TypedStyleValueBox(bridge.css_value_handle) }
	owner.value = StyleValue(StringStyleValue.create('mutated owner'))
	gc_collect()
	mutated := style_value_logic_from_dom(.width, bridge) or { panic('mutated owner') }
	assert mutated is StringStyleValue
	assert mutated.serialize(.normal) == '"mutated owner"'
	assert first is LengthStyleValue
	assert (first as LengthStyleValue).length() == Length.new(2.5, .em)
	replacement := dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.max_content)))
	bridge.css_value_handle = replacement.css_value_handle
	gc_collect()
	assert (style_value_logic_from_dom(.width, bridge) or { panic('replacement') }).to_keyword() == .max_content
	bridge.css_value_handle = unsafe { nil }
	bridge.css_text = '17px'
	fallback := style_value_logic_from_dom(.width, bridge) or { panic('cleared handle fallback') }
	assert fallback is LengthStyleValue
	assert (fallback as LengthStyleValue).length() == Length.make_px(17)
}
