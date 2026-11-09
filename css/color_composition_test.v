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
