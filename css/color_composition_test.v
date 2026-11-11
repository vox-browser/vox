module css

fn test_color_addition_uses_premultiplied_components_and_legacy_serialization() {
	for example in [
		['rgb(100, 100, 100)', 'rgb(50, 50, 50)', 'rgb(150, 150, 150)'],
		['rgba(100, 20, 0, 0.5)', 'rgba(0, 0, 100, 0.5)', 'rgb(50, 10, 50)'],
	] {
		a := parse_css_value_logic(.color, example[0]) or { panic('first color') }
		b := parse_css_value_logic(.color, example[1]) or { panic('second color') }
		result := composite_style_value(.color, a, b, .add) or { panic('color composition') }
		assert result.serialize(.normal) == example[2]
	}
	syntax := parse_as_syntax(Parser.from_css_text('<color>#').component_values) or { panic('syntax') }
	a := parse_with_a_syntax(Parser.from_css_text('rgb(100, 100, 100), rgb(150, 150, 150)').component_values, syntax)
	b := parse_with_a_syntax(Parser.from_css_text('rgb(50, 50, 50), rgb(75, 75, 75)').component_values, syntax)
	result := composite_style_value(.width, a, b, .accumulate) or { panic('color list composition') }
	assert result.serialize(.normal) == 'rgb(150, 150, 150), rgb(225, 225, 225)'
}

fn test_color_iteration_accumulation_keeps_out_of_gamut_endpoints_until_sampling() {
	zero := dom_style_value_from_value_logic(parse_css_value_logic(.color, 'rgb(0, 0, 0)') or { panic('zero') })
	final := dom_style_value_from_value_logic(parse_css_value_logic(.color, 'rgb(100, 100, 100)') or { panic('final') })
	start := accumulate_custom_property_iterations(zero, final, 2)
	end := accumulate_custom_property_iterations(final, final, 2)
	result := interpolate_style_values_color(typed_style_value_logic_from_dom(start) or { panic('start') }, typed_style_value_logic_from_dom(end) or { panic('end') }, 0.5, none, ColorResolutionContext{}) or { panic('interpolation') }
	assert result.serialize(.normal) == 'rgb(250, 250, 250)'
	// Ordinary authored RGB channels still clamp before interpolation.
	a := parse_css_value_logic(.color, 'rgb(300, 300, 300)') or { panic('a') }
	b := parse_css_value_logic(.color, 'rgb(200, 200, 200)') or { panic('b') }
	authored := interpolate_style_values_color(a, b, 0.5, none, ColorResolutionContext{}) or { panic('authored interpolation') }
	assert authored.serialize(.normal) == 'rgb(227, 227, 227)'
}
