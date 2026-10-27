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
	literal_percentage := literal.first_component[0].percentage or {
		panic('literal percentage was discarded')
	}
	assert literal_percentage is PercentageStyleValue
	assert literal_percentage.serialize(.normal) == '25%'

	calculated := parsed_color_mix('color-mix(in oklab, red calc(50% / 2), blue)')
	calculated_percentage := calculated.first_component[0].percentage or {
		panic('calculated percentage was discarded')
	}
	assert calculated_percentage is CalculatedStyleValue
	assert calculated_percentage.serialize(.normal) == 'calc(25%)'
	assert calculated.serialize(.normal).contains('calc(25%)')
}

fn test_color_mix_to_color_uses_the_stored_second_percentage() {
	mix := parsed_color_mix('color-mix(in oklab, red 20%, blue 20%)')
	color := mix.to_color(ColorResolutionContext{}) or { panic('color mix did not resolve') }
	opaque_equal_mix := parsed_color_mix('color-mix(in oklab, red, blue)').to_color(ColorResolutionContext{}) or {
		panic('equal color mix did not resolve')
	}
	assert color.red() == opaque_equal_mix.red()
	assert color.green() == opaque_equal_mix.green()
	assert color.blue() == opaque_equal_mix.blue()
	assert color.alpha() == 102

	omitted_second := parsed_color_mix('color-mix(in oklab, red 25%, blue)')
	omitted_second_color := omitted_second.to_color(ColorResolutionContext{}) or {
		panic('color mix with omitted percentage did not resolve')
	}
	explicit_percentages := parsed_color_mix('color-mix(in oklab, red 25%, blue 75%)').to_color(ColorResolutionContext{}) or {
		panic('color mix with explicit percentages did not resolve')
	}
	assert omitted_second_color == explicit_percentages
	assert omitted_second_color.alpha() == 255
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

fn test_shadow_absolutizes_color_mix_color() {
	zero := StyleValue(LengthStyleValue.create(Length.make_px(0)))
	shadow := ShadowStyleValue.create(.text, StyleValue(parsed_color_mix('color-mix(in srgb, red, blue)')), zero, zero, none, none, .outer)
	absolutized := shadow.absolutized(ComputationContext{})
	assert absolutized is ShadowStyleValue
	resolved_shadow := absolutized as ShadowStyleValue
	assert resolved_shadow.color() !is ColorMixStyleValue
}

fn test_scrollbar_colors_absolutize_color_mix_values() {
	value := ScrollbarColorStyleValue.create(StyleValue(parsed_color_mix('color-mix(in srgb, red, blue)')), StyleValue(parsed_color_mix('color-mix(in srgb, white, black)')))
	absolutized := value.absolutized(ComputationContext{})
	assert absolutized is ScrollbarColorStyleValue
	resolved_colors := absolutized as ScrollbarColorStyleValue
	assert resolved_colors.thumb_color() !is ColorMixStyleValue
	assert resolved_colors.track_color() !is ColorMixStyleValue
}
