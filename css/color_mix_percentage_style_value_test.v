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

fn test_color_mix_to_color_uses_the_stored_second_percentage() {
	// to_color() receives normalized values in computed-style use. It must not
	// normalize them again, because doing so changes a stored 20% delta to 50%.
	mix := parsed_color_mix('color-mix(in oklab, red 20%, blue 20%)')
	color := mix.to_color(ColorResolutionContext{}) or { panic('color mix did not resolve') }
	assert color.red() > color.blue()
}

fn test_color_mix_absolutizes_relative_lengths_in_calculated_percentages() {
	font_size := CSSPixels.nearest_value_for(16)
	font_metrics := LengthFontMetrics.new(font_size, CSSPixels.nearest_value_for(8), CSSPixels.nearest_value_for(12), CSSPixels.nearest_value_for(8), CSSPixels.nearest_value_for(19.2))
	context := ComputationContext{
		length_resolution_context: LengthResolutionContext{
			font_metrics: font_metrics
			root_font_metrics: font_metrics
		}
	}
	literal := parsed_color_mix('color-mix(in oklab, red 25%, blue)').absolutized(context)
	calculated := parsed_color_mix('color-mix(in oklab, red calc(100% * (1em / 64px)), blue)').absolutized(context)
	assert calculated.serialize(.normal) == literal.serialize(.normal)
}
