module css

import dom

// Keep the complete context-consuming resolution as the semantic oracle.
fn context_free_length_oracle(style &ComputedProperties, value StyleValue, basis f64) f64 {
	return LengthPercentage.from_style_value_logic(value).to_px(style.length_resolution_context(),
		CSSPixels.nearest_value_for(basis)).to_double()
}

fn test_public_length_resolution_matches_full_context_for_absolute_units_and_percentages() {
	mut style := ComputedProperties.new()
	style.set_property(.font_size, &dom.StyleValue{css_text: '23px'}, .no, .no)
	style.set_property(.line_height, &dom.StyleValue{css_text: '2'}, .no, .no)
	style.viewport_rect_ = CSSPixelRect.new(0, 0, 937, 613)
	for unit in [LengthUnit.px, .cm, .mm, .q, .in_, .pt, .pc] {
		for magnitude in [f64(-100000000), -31.9921875, -0.0078125, 0, 0.0078125, 1.125, 100000000] {
			value := StyleValue(LengthStyleValue.create(Length.new(magnitude, unit)))
			style.set_property(.width, dom_style_value_from_value_logic(value), .no, .no)
			for basis in [f64(-10.125), 0, 1.0078125, 128.125, 100000000] {
				expected := context_free_length_oracle(style, value, basis)
				assert style.length_percentage_to_px(.width, basis)? == expected
				assert style.resolve_length_percentage_value_px(value, basis)? == expected
			}
		}
	}
	for percentage in [f64(-150), -0.5, 0, 0.5, 33.333333, 100, 250] {
		value := StyleValue(PercentageStyleValue.create(Percentage.new(percentage)))
		style.set_property(.width, dom_style_value_from_value_logic(value), .no, .no)
		for basis in [f64(-100000000), -33.125, -0.0078125, 0, 0.0078125, 100.125, 100000000] {
			expected := context_free_length_oracle(style, value, basis)
			assert style.length_percentage_to_px(.width, basis)? == expected
			assert style.resolve_length_percentage_value_px(value, basis)? == expected
		}
	}
	assert style.resolve_length_percentage_value_px(StyleValue(LengthStyleValue.create(Length.new(1, .in_))), 0)? == 96
	assert style.resolve_length_percentage_value_px(StyleValue(PercentageStyleValue.create(Percentage.new(25))), 100.125)? == 25.03125
}

fn test_public_relative_lengths_and_calculations_follow_live_context_changes() {
	mut style := ComputedProperties.new()
	style.set_property(.font_size, &dom.StyleValue{css_text: '20px'}, .no, .no)
	style.set_property(.line_height, &dom.StyleValue{css_text: '2'}, .no, .no)
	style.root_font_size_px_ = 12
	style.root_line_height_px_ = 18
	style.viewport_rect_ = CSSPixelRect.new(0, 0, 800, 600)
	for text in ['2em', '2rem', '2lh', '2rlh', '10vw', '10vh', '10cqi', 'calc(2em + 25%)'] {
		value := parse_css_value(ParsingParams{}, text, .width)?
		typed := style_value_logic_from_dom(.width, value)?
		style.set_property(.width, value, .no, .no)
		for basis in [f64(0), 100.125, 300] {
			assert style.length_percentage_to_px(.width, basis)? == context_free_length_oracle(style, typed, basis)
			assert style.resolve_length_percentage_value_px(typed, basis)? == context_free_length_oracle(style, typed, basis)
		}
	}
	value := parse_css_value(ParsingParams{}, 'calc(2em + 25%)', .width)?
	style.set_property(.width, value, .no, .no)
	assert style.length_percentage_to_px(.width, 100)? == 65
	style.set_property(.font_size, &dom.StyleValue{css_text: '30px'}, .no, .no)
	assert style.length_percentage_to_px(.width, 200)? == 110
	style.set_property(.width, &dom.StyleValue{css_text: '10vw'}, .no, .no)
	assert style.length_percentage_to_px(.width, 0)? == 80
	style.viewport_rect_ = CSSPixelRect.new(0, 0, 400, 300)
	assert style.length_percentage_to_px(.width, 0)? == 40
}

fn test_public_context_free_resolution_keeps_animation_and_svg_number_rules() {
	mut style := ComputedProperties.new()
	style.set_property(.width, &dom.StyleValue{css_text: '10px'}, .no, .no)
	style.set_animated_property(.width, &dom.StyleValue{css_text: '25%'}, .no, .no)
	assert style.length_percentage_to_px(.width, 200)? == 50
	style.remove_animated_property(.width)
	assert style.length_percentage_to_px(.width, 200)? == 10
	for property_id in [PropertyID.stroke_width, .stroke_dashoffset] {
		style.set_property(property_id, &dom.StyleValue{css_text: '2.125'}, .no, .no)
		assert style.length_percentage_to_px(property_id, 200)? == 2.125
	}
	style.set_property(.width, &dom.StyleValue{css_text: 'auto'}, .no, .no)
	assert style.length_percentage_to_px(.width, 200) == none
	for value in [StyleValue(KeywordStyleValue.create(.auto)), StyleValue(NumberStyleValue.create(2)),
		StyleValue(CustomIdentStyleValue.create('2px'))] {
		assert style.resolve_length_percentage_value_px(value, 200) == none
	}
}
