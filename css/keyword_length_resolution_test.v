module css

import dom

fn test_keyword_numeric_resolution_rejects_intrinsic_and_default_sizes() {
	mut style := computed_properties_with_initial_values()
	for id in [PropertyID.min_width, .min_height, .max_width, .max_height, .width, .height] {
		for keyword in [Keyword.auto, .none_, .min_content, .max_content, .fit_content, .initial, .unset, .inherit] {
			style.set_property(id, dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(keyword))), .no, .no)
			for basis in [0.0, 240.5] {
				actual := style.length_percentage_to_px(id, basis)
				assert actual == none
			}
		}
	}
}

fn test_keyword_numeric_resolution_reads_live_mutable_box_and_animated_overrides() {
	mut style := computed_properties_with_initial_values()
	value := dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.none_)))
	style.set_property(.max_height, value, .no, .no)
	initial := style.length_percentage_to_px(.max_height, 200)
	assert initial == none
	mut box := unsafe { &TypedStyleValueBox(value.css_value_handle) }
	box.value = StyleValue(LengthStyleValue.create(Length.make_px(42.5)))
	assert style.length_percentage_to_px(.max_height, 200) or { panic('numeric replacement') } == 42.5
	box.value = StyleValue(KeywordStyleValue.create(.max_content))
	mutated := style.length_percentage_to_px(.max_height, 200)
	assert mutated == none
	style.set_animated_property(.max_height, dom_style_value_from_value_logic(
		StyleValue(PercentageStyleValue.create(Percentage.new(25)))), .no, .no)
	assert style.length_percentage_to_px(.max_height, 200) or { panic('animated percentage') } == 50
	style.set_animated_property(.max_height, dom_style_value_from_value_logic(
		StyleValue(KeywordStyleValue.create(.none_))), .no, .no)
	animated_keyword := style.length_percentage_to_px(.max_height, 200)
	assert animated_keyword == none
}

fn test_keyword_numeric_resolution_preserves_untyped_and_svg_number_paths() {
	mut style := computed_properties_with_initial_values()
	style.set_property(.max_height, &dom.StyleValue{css_text:'42.5px'}, .no, .no)
	assert style.length_percentage_to_px(.max_height, 200) or { panic('untyped length') } == 42.5
	style.set_property(.max_height, &dom.StyleValue{css_text:'none'}, .no, .no)
	keyword := style.length_percentage_to_px(.max_height, 200)
	assert keyword == none
	for id in [PropertyID.stroke_width, .stroke_dashoffset] {
		style.set_property(id, dom_style_value_from_value_logic(StyleValue(NumberStyleValue.create(3.25))), .no, .no)
		assert style.length_percentage_to_px(id, 200) or { panic('SVG number') } == 3.25
	}
}

fn test_keyword_numeric_resolution_preserves_length_percentage_and_calculation_rounding() {
	mut style := computed_properties_with_initial_values()
	for text, expected in {'42.5px':42.5, '25%':50.0, 'calc(25% + 3px)':53.0, '0px':0.0} {
		value := parse_css_value(ParsingParams{}, text, .max_height) or { panic('numeric fixture') }
		style.set_property(.max_height, value, .no, .no)
		assert style.length_percentage_to_px(.max_height, 200) or { panic('numeric value') } == expected
	}
}
