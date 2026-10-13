module css

fn test_length_wrapper_defaults_are_zero_length_or_absent_auto_values() {
	zero := LengthPercentage{}
	assert zero.is_length()
	assert zero.to_px(LengthResolutionContext.default(), CSSPixels.new(100)) == CSSPixels.new(0)
	assert zero.serialize(.normal) == '0px'
	auto := LengthPercentageOrAuto{}
	assert auto.is_auto()
	assert auto.length_percentage_ == none
	size := Size{}
	assert size.is_auto()
	assert size.length_percentage_ == none
}

fn test_length_wrapper_conversion_retains_explicit_length_percentage_and_calculation() {
	for input, expected in {'12px': f64(12), '20%': f64(20), 'calc(10px + 5%)': f64(15)} {
		parsed := parse_css_value_logic(.width, input) or { panic('could not parse ${input}') }
		value := LengthPercentage.from_style_value_logic(parsed)
		assert value.to_px(LengthResolutionContext.default(), CSSPixels.new(100)).to_double() == expected
	}
}
