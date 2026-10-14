module css

import dom

fn test_computed_scalar_reads_retained_lengths_numbers_and_percentages() {
	for unit in [LengthUnit.px, .cm, .em, .rem, .lh, .rlh, .vw, .dvh, .cqi] {
		for magnitude in [f64(-2.5), 0, 1.125, 100] {
			mut value := dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.new(magnitude, unit))))
			value.css_text = '73%'
			length := computed_interpolation_length_from_dom_style_value(value)?
			assert length.raw_value() == magnitude
			assert length.unit() == unit
			assert computed_interpolation_number_from_dom_style_value(value) == none
			assert computed_interpolation_percentage_from_dom_style_value(value) == none
		}
	}
	for magnitude in [f64(-2.5), 0, 1.125, 100] {
		mut number := dom_style_value_from_value_logic(StyleValue(NumberStyleValue.create(magnitude)))
		number.css_text = '27px'
		assert computed_interpolation_number_from_dom_style_value(number)? == magnitude
		assert computed_interpolation_length_from_dom_style_value(number) == none
		assert computed_interpolation_percentage_from_dom_style_value(number) == none
		mut percentage := dom_style_value_from_value_logic(StyleValue(PercentageStyleValue.create(Percentage.new(magnitude))))
		percentage.css_text = '0.25'
		assert computed_interpolation_percentage_from_dom_style_value(percentage)?.value() == magnitude
		assert computed_interpolation_number_from_dom_style_value(percentage) == none
		assert computed_interpolation_length_from_dom_style_value(percentage) == none
	}
}

fn test_computed_scalar_rejects_other_retained_types_despite_scalar_bridge_text() {
	for typed in [StyleValue(KeywordStyleValue.create(.auto)),
		StyleValue(IntegerStyleValue.create(3)), StyleValue(CustomIdentStyleValue.create('12px')),
		StyleValue(StringStyleValue.create('25%'))] {
		mut value := dom_style_value_from_value_logic(typed)
		for text in ['12px', '25%', '0.5'] {
			value.css_text = text
			assert computed_interpolation_length_from_dom_style_value(value) == none
			assert computed_interpolation_number_from_dom_style_value(value) == none
			assert computed_interpolation_percentage_from_dom_style_value(value) == none
		}
	}
	for property_id, text in {PropertyID.width: 'calc(2px + 3px)', .opacity: 'calc(0.2 + 0.3)', .font_width: 'calc(10% + 15%)'} {
		value := parse_css_value(ParsingParams{}, text, property_id)?
		assert computed_interpolation_length_from_dom_style_value(value) == none
		assert computed_interpolation_number_from_dom_style_value(value) == none
		assert computed_interpolation_percentage_from_dom_style_value(value) == none
	}
}

fn test_computed_scalar_preserves_serialized_fallback_and_rejects_trailing_tokens() {
	length := computed_interpolation_length_from_dom_style_value(&dom.StyleValue{css_text: ' \t-2.5EM\n '})?
	assert length.raw_value() == -2.5
	assert length.unit() == .em
	assert computed_interpolation_number_from_dom_style_value(&dom.StyleValue{css_text: ' /* number */ -1.25 '})? == -1.25
	assert computed_interpolation_percentage_from_dom_style_value(&dom.StyleValue{css_text: ' \t37.5%\n '})?.value() == 37.5
	for text in ['', ' \t\n', '12px trailing', '12px 5px', '25% trailing', '25% 5%', '0.5 trailing', '0.5 1', 'auto', 'calc(1px + 2px)', '"12px"'] {
		value := &dom.StyleValue{css_text: text}
		assert computed_interpolation_length_from_dom_style_value(value) == none
		assert computed_interpolation_number_from_dom_style_value(value) == none
		assert computed_interpolation_percentage_from_dom_style_value(value) == none
	}
}

fn test_computed_scalar_follows_replaced_handles_across_collection() {
	retained := [dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.new(2.5, .em)))),
		dom_style_value_from_value_logic(StyleValue(NumberStyleValue.create(0.75))),
		dom_style_value_from_value_logic(StyleValue(PercentageStyleValue.create(Percentage.new(25)))),
		dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.auto)))]
	mut bridge := &dom.StyleValue{css_text: '9px'}
	for index, value in retained {
		bridge.css_value_handle = value.css_value_handle
		gc_collect()
		if index == 0 {
			length := computed_interpolation_length_from_dom_style_value(bridge)?
			assert length.raw_value() == 2.5 && length.unit() == .em
		} else {
			assert computed_interpolation_length_from_dom_style_value(bridge) == none
		}
		if index == 1 {
			assert computed_interpolation_number_from_dom_style_value(bridge)? == 0.75
		} else {
			assert computed_interpolation_number_from_dom_style_value(bridge) == none
		}
		if index == 2 {
			assert computed_interpolation_percentage_from_dom_style_value(bridge)?.value() == 25
		} else {
			assert computed_interpolation_percentage_from_dom_style_value(bridge) == none
		}
	}
	bridge.css_value_handle = unsafe { nil }
	assert computed_interpolation_length_from_dom_style_value(bridge)?.raw_value() == 9
}
