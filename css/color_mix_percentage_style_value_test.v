module css

fn parsed_color_mix(value string) ColorMixStyleValue {
	parsed := parse_css_value_logic(.color, value) or { panic('color-mix() did not parse') }
	if parsed is ColorMixStyleValue {
		return parsed
	}
	panic('color-mix() did not produce a ColorMixStyleValue')
}

fn test_color_mix_retains_percentage_style_values() {
	literal := parsed_color_mix('color-mix(in oklab, red 25%, blue)')
	literal_percentage := literal.first_component.percentage or {
		panic('literal percentage was discarded')
	}
	assert literal_percentage is PercentageStyleValue
	assert literal_percentage.serialize(.normal) == '25%'

	calculated := parsed_color_mix('color-mix(in oklab, red calc(50% / 2), blue)')
	calculated_percentage := calculated.first_component.percentage or {
		panic('calculated percentage was discarded')
	}
	assert calculated_percentage is CalculatedStyleValue
	assert calculated_percentage.serialize(.normal) == 'calc(25%)'
	assert calculated.serialize(.normal).contains('calc(25%)')
}
